-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00007
-- Triggers and Timestamps
-- ============================================================

-- ============================================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRACKING TOKEN GENERATION TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION generate_tracking_token()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tracking_token IS NULL THEN
    NEW.tracking_token := md5(random()::text || clock_timestamp()::text || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_delivery_tracking_token
  BEFORE INSERT ON deliveries
  FOR EACH ROW
  EXECUTE FUNCTION generate_tracking_token();

-- ============================================================
-- APPLY UPDATED_AT TRIGGERS
-- ============================================================

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_riders_updated_at
  BEFORE UPDATE ON riders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at
  BEFORE UPDATE ON vehicles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pricing_rules_updated_at
  BEFORE UPDATE ON pricing_rules
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deliveries_updated_at
  BEFORE UPDATE ON deliveries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_intl_requests_updated_at
  BEFORE UPDATE ON international_shipping_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cars_updated_at
  BEFORE UPDATE ON cars
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- NOTIFICATION AUTO-CREATION TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION create_delivery_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Create notification for status updates
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO notifications (user_id, delivery_id, type, title, message)
    SELECT
      CASE
        WHEN NEW.status IN ('accepted', 'en_route_to_pickup', 'arrived_at_pickup', 'picked_up', 'in_transit', 'arriving', 'delivered')
          THEN (SELECT customer_id FROM deliveries WHERE id = NEW.id)
        ELSE (SELECT created_by FROM deliveries WHERE id = NEW.id)
      END,
      NEW.id,
      'status_update',
      'Delivery Status Update',
      'Delivery ' || NEW.tracking_number || ' is now ' || NEW.status;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_delivery_status_change
  AFTER UPDATE OF status ON deliveries
  FOR EACH ROW
  EXECUTE FUNCTION create_delivery_notification();

-- ============================================================
-- RIDER LOCATION UPDATE TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION update_rider_location_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE riders
  SET last_known_latitude = NEW.latitude,
      last_known_longitude = NEW.longitude,
      last_location_update = NEW.recorded_at
  WHERE id = NEW.rider_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_rider_location_insert
  AFTER INSERT ON rider_locations
  FOR EACH ROW
  EXECUTE FUNCTION update_rider_location_timestamp();
