-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00004
-- Database Functions: Core Operations
-- ============================================================

-- ============================================================
-- HELPER: Get current user's profile
-- ============================================================
CREATE OR REPLACE FUNCTION get_current_profile()
RETURNS SETOF profiles AS $$
  SELECT * FROM profiles WHERE auth_user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- HELPER: Get current user's role
-- ============================================================
CREATE OR REPLACE FUNCTION get_current_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE auth_user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- HELPER: Check if user is admin or dispatcher
-- ============================================================
CREATE OR REPLACE FUNCTION is_admin_or_dispatcher()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE auth_user_id = auth.uid()
    AND role IN ('super_admin', 'dispatcher')
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- TRACKING NUMBER GENERATION
-- Format: JLL-YYYYMMDD-XXXX
-- ============================================================
CREATE OR REPLACE FUNCTION generate_tracking_number()
RETURNS TEXT AS $$
DECLARE
  date_part TEXT;
  sequence_num INTEGER;
  tracking_num TEXT;
BEGIN
  date_part := TO_CHAR(NOW(), 'YYYYMMDD');
  
  -- Get next sequence number for today
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(tracking_number FROM 'JLL-\d{8}-(\d+)$') AS INTEGER)
  ), 0) + 1
  INTO sequence_num
  FROM deliveries
  WHERE tracking_number LIKE 'JLL-' || date_part || '-%';
  
  tracking_num := 'JLL-' || date_part || '-' || LPAD(sequence_num::TEXT, 4, '0');
  
  RETURN tracking_num;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DELIVERY STATE MACHINE
-- ============================================================

-- Define valid transitions
CREATE OR REPLACE FUNCTION is_valid_transition(
  from_status delivery_status,
  to_status delivery_status
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN CASE from_status
    WHEN 'created' THEN to_status IN ('priced', 'cancelled')
    WHEN 'priced' THEN to_status IN ('assigned', 'cancelled')
    WHEN 'assigned' THEN to_status IN ('accepted', 'cancelled')
    WHEN 'accepted' THEN to_status IN ('en_route_to_pickup', 'cancelled')
    WHEN 'en_route_to_pickup' THEN to_status IN ('arrived_at_pickup', 'cancelled')
    WHEN 'arrived_at_pickup' THEN to_status IN ('picked_up', 'cancelled')
    WHEN 'picked_up' THEN to_status IN ('in_transit', 'failed', 'returning_to_sender')
    WHEN 'in_transit' THEN to_status IN ('arriving', 'failed', 'returning_to_sender')
    WHEN 'arriving' THEN to_status IN ('delivered', 'failed')
    WHEN 'delivered' THEN FALSE
    WHEN 'cancelled' THEN FALSE
    WHEN 'failed' THEN to_status IN ('returning_to_sender')
    WHEN 'returning_to_sender' THEN to_status IN ('returned')
    WHEN 'returned' THEN FALSE
    ELSE FALSE
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- DELIVERY STATUS TRANSITION FUNCTION
-- Atomic, server-enforced state machine
-- ============================================================
CREATE OR REPLACE FUNCTION transition_delivery_status(
  p_delivery_id UUID,
  p_new_status delivery_status,
  p_notes TEXT DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_delivery RECORD;
  v_current_role user_role;
  v_current_profile_id UUID;
  v_old_status delivery_status;
BEGIN
  -- 1. Authenticate caller
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- 2. Get caller's profile and role
  SELECT id, role INTO v_current_profile_id, v_current_role
  FROM profiles WHERE auth_user_id = auth.uid();

  IF v_current_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  -- 3. Get the delivery
  SELECT * INTO v_delivery FROM deliveries WHERE id = p_delivery_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delivery not found');
  END IF;

  v_old_status := v_delivery.status;

  -- 4. Verify the transition is legal
  IF NOT is_valid_transition(v_old_status, p_new_status) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid transition from ' || v_old_status || ' to ' || p_new_status
    );
  END IF;

  -- 5. Verify caller has permission
  -- Admin/dispatcher can do most transitions
  -- Rider can only do rider-specific transitions on their assigned delivery
  IF v_current_role IN ('super_admin', 'dispatcher') THEN
    -- Admin/dispatcher can do all valid transitions
    NULL;
  ELSIF v_current_role = 'rider' THEN
    -- Rider can only transition their assigned delivery
    IF v_delivery.assigned_rider_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'No rider assigned');
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM riders WHERE id = v_delivery.assigned_rider_id AND profile_id = v_current_profile_id
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Not your assigned delivery');
    END IF;

    -- Rider-specific transitions
    IF p_new_status NOT IN (
      'accepted', 'en_route_to_pickup', 'arrived_at_pickup',
      'picked_up', 'in_transit', 'arriving', 'delivered',
      'failed', 'returning_to_sender'
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Rider cannot perform this transition');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient permissions');
  END IF;

  -- 6. Update the delivery
  UPDATE deliveries
  SET
    status = p_new_status,
    updated_at = NOW(),
    actual_pickup_time = CASE
      WHEN p_new_status = 'picked_up' AND actual_pickup_time IS NULL THEN NOW()
      ELSE actual_pickup_time
    END,
    delivered_at = CASE
      WHEN p_new_status = 'delivered' THEN NOW()
      ELSE delivered_at
    END,
    cancelled_at = CASE
      WHEN p_new_status = 'cancelled' THEN NOW()
      ELSE cancelled_at
    END,
    cancellation_reason = CASE
      WHEN p_new_status = 'cancelled' THEN p_notes
      ELSE cancellation_reason
    END
  WHERE id = p_delivery_id;

  -- 7. Create status history record
  INSERT INTO delivery_status_history (
    delivery_id, previous_status, new_status, changed_by,
    latitude, longitude, notes
  ) VALUES (
    p_delivery_id, v_old_status, p_new_status, v_current_profile_id,
    p_latitude, p_longitude, p_notes
  );

  -- 8. Update rider availability based on status
  IF v_delivery.assigned_rider_id IS NOT NULL THEN
    UPDATE riders
    SET availability_status = CASE p_new_status
      WHEN 'accepted' THEN 'assigned'::rider_availability
      WHEN 'en_route_to_pickup' THEN 'on_pickup'::rider_availability
      WHEN 'picked_up' THEN 'delivering'::rider_availability
      WHEN 'in_transit' THEN 'delivering'::rider_availability
      WHEN 'arriving' THEN 'delivering'::rider_availability
      WHEN 'delivered' THEN 'available'::rider_availability
      WHEN 'cancelled' THEN 'available'::rider_availability
      WHEN 'failed' THEN 'available'::rider_availability
      ELSE availability_status
    END,
    current_delivery_id = CASE
      WHEN p_new_status IN ('delivered', 'cancelled', 'failed') THEN NULL
      ELSE current_delivery_id
    END,
    updated_at = NOW()
    WHERE id = v_delivery.assigned_rider_id;
  END IF;

  -- 9. Create audit log for sensitive transitions
  IF p_new_status IN ('cancelled', 'delivered', 'priced') THEN
    INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, old_values, new_values)
    VALUES (
      v_current_profile_id,
      'status_change',
      'delivery',
      p_delivery_id,
      jsonb_build_object('status', v_old_status),
      jsonb_build_object('status', p_new_status, 'notes', p_notes)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'old_status', v_old_status,
    'new_status', p_new_status,
    'delivery_id', p_delivery_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PRICING CALCULATION
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_suggested_price(
  p_delivery_type delivery_type,
  p_distance_km NUMERIC DEFAULT 0,
  p_weight_kg NUMERIC DEFAULT 0,
  p_priority delivery_priority DEFAULT 'normal'
) RETURNS NUMERIC AS $$
DECLARE
  v_rule RECORD;
  v_price NUMERIC;
BEGIN
  -- Find active pricing rule for this delivery type
  SELECT * INTO v_rule
  FROM pricing_rules
  WHERE delivery_type = p_delivery_type AND is_active = true
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Calculate base price
  v_price := v_rule.base_price
    + (p_distance_km * v_rule.per_km_rate)
    + (p_weight_kg * v_rule.per_kg_rate);

  -- Add priority fee
  v_price := v_price + CASE p_priority
    WHEN 'express' THEN v_rule.priority_fee_express
    WHEN 'urgent' THEN v_rule.priority_fee_urgent
    ELSE v_rule.priority_fee_normal
  END;

  -- Enforce minimum price
  IF v_price < v_rule.minimum_price THEN
    v_price := v_rule.minimum_price;
  END IF;

  RETURN ROUND(v_price, 2);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DELIVERY PIN GENERATION
-- ============================================================
CREATE OR REPLACE FUNCTION generate_delivery_pin(
  p_delivery_id UUID
) RETURNS TEXT AS $$
DECLARE
  v_pin TEXT;
  v_hash TEXT;
BEGIN
  -- Generate 6-digit PIN
  v_pin := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

  -- Hash the PIN
  v_hash := md5(v_pin);

  -- Store only the hash
  UPDATE deliveries
  SET delivery_pin_hash = v_hash,
      delivery_pin_enabled = true,
      updated_at = NOW()
  WHERE id = p_delivery_id;

  -- Return plaintext PIN (only time it's returned)
  RETURN v_pin;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DELIVERY PIN VERIFICATION
-- ============================================================
CREATE OR REPLACE FUNCTION verify_delivery_pin(
  p_delivery_id UUID,
  p_pin TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  v_hash TEXT;
  v_provided_hash TEXT;
  v_enabled BOOLEAN;
BEGIN
  -- Get the stored hash and enabled status
  SELECT delivery_pin_hash, delivery_pin_enabled
  INTO v_hash, v_enabled
  FROM deliveries WHERE id = p_delivery_id;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  IF NOT v_enabled THEN
    RETURN FALSE;
  END IF;

  -- Hash the provided PIN
  v_provided_hash := md5(p_pin);

  -- Compare
  IF v_hash = v_provided_hash THEN
    -- Disable PIN after successful verification
    UPDATE deliveries
    SET delivery_pin_enabled = false,
        updated_at = NOW()
    WHERE id = p_delivery_id;
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RIDER ASSIGNMENT
-- ============================================================
CREATE OR REPLACE FUNCTION assign_rider(
  p_delivery_id UUID,
  p_rider_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_delivery RECORD;
  v_rider RECORD;
  v_current_role user_role;
BEGIN
  -- 1. Authenticate
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT role INTO v_current_role FROM profiles WHERE auth_user_id = auth.uid();

  -- 2. Only admin/dispatcher can assign
  IF v_current_role NOT IN ('super_admin', 'dispatcher') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only admin/dispatcher can assign riders');
  END IF;

  -- 3. Get delivery
  SELECT * INTO v_delivery FROM deliveries WHERE id = p_delivery_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delivery not found');
  END IF;

  -- 4. Verify delivery is assignable
  IF v_delivery.status NOT IN ('priced', 'assigned') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delivery is not in an assignable state');
  END IF;

  -- 5. Get rider
  SELECT * INTO v_rider FROM riders WHERE id = p_rider_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rider not found');
  END IF;

  -- 6. Verify rider is active and available
  IF v_rider.employment_status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rider is not active');
  END IF;

  IF v_rider.availability_status != 'available' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rider is not available');
  END IF;

  -- 7. Assign rider and vehicle
  UPDATE deliveries
  SET assigned_rider_id = p_rider_id,
      assigned_vehicle_id = v_rider.vehicle_id,
      updated_at = NOW()
  WHERE id = p_delivery_id;

  -- 8. Update rider
  UPDATE riders
  SET availability_status = 'assigned'::rider_availability,
      current_delivery_id = p_delivery_id,
      updated_at = NOW()
  WHERE id = p_rider_id;

  -- 9. Transition status to 'assigned' if currently 'priced'
  IF v_delivery.status = 'priced' THEN
    PERFORM transition_delivery_status(p_delivery_id, 'assigned'::delivery_status);
  END IF;

  -- 10. Create audit log
  INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, old_values, new_values)
  SELECT
    (SELECT id FROM profiles WHERE auth_user_id = auth.uid()),
    'rider_assigned',
    'delivery',
    p_delivery_id,
    jsonb_build_object('rider_id', v_delivery.assigned_rider_id),
    jsonb_build_object('rider_id', p_rider_id);

  -- 11. Create notification
  INSERT INTO notifications (user_id, delivery_id, type, title, message)
  SELECT
    r.profile_id,
    p_delivery_id,
    'assignment',
    'New Delivery Assignment',
    'You have been assigned delivery ' || v_delivery.tracking_number
  FROM riders r WHERE r.id = p_rider_id;

  RETURN jsonb_build_object(
    'success', true,
    'delivery_id', p_delivery_id,
    'rider_id', p_rider_id,
    'tracking_number', v_delivery.tracking_number
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- REASSIGN RIDER
-- ============================================================
CREATE OR REPLACE FUNCTION reassign_rider(
  p_delivery_id UUID,
  p_new_rider_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_delivery RECORD;
  v_old_rider_id UUID;
  v_current_role user_role;
BEGIN
  -- Authenticate
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT role INTO v_current_role FROM profiles WHERE auth_user_id = auth.uid();
  IF v_current_role NOT IN ('super_admin', 'dispatcher') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only admin/dispatcher can reassign');
  END IF;

  -- Get delivery
  SELECT * INTO v_delivery FROM deliveries WHERE id = p_delivery_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delivery not found');
  END IF;

  v_old_rider_id := v_delivery.assigned_rider_id;

  -- Free old rider
  IF v_old_rider_id IS NOT NULL THEN
    UPDATE riders
    SET availability_status = 'available'::rider_availability,
        current_delivery_id = NULL,
        updated_at = NOW()
    WHERE id = v_old_rider_id;
  END IF;

  -- Use assign_rider for the new assignment
  RETURN assign_rider(p_delivery_id, p_new_rider_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- GET AVAILABLE RIDERS
-- ============================================================
CREATE OR REPLACE FUNCTION get_available_riders()
RETURNS TABLE (
  rider_id UUID,
  profile_id UUID,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  vehicle_id UUID,
  vehicle_code TEXT,
  vehicle_type vehicle_type
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id AS rider_id,
    r.profile_id,
    p.first_name,
    p.last_name,
    r.phone,
    r.vehicle_id,
    v.vehicle_code,
    v.vehicle_type
  FROM riders r
  JOIN profiles p ON r.profile_id = p.id
  LEFT JOIN vehicles v ON r.vehicle_id = v.id
  WHERE r.availability_status = 'available'
    AND r.employment_status = 'active'
    AND p.status = 'active'
  ORDER BY r.updated_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- PUBLIC TRACKING (Sanitized)
-- ============================================================
CREATE OR REPLACE FUNCTION get_public_tracking(
  p_tracking_number TEXT
) RETURNS JSONB AS $$
DECLARE
  v_delivery RECORD;
  v_history JSONB;
BEGIN
  -- Get delivery by tracking number
  SELECT
    tracking_number,
    delivery_type,
    status,
    pickup_address,
    destination_address,
    created_at,
    estimated_weight,
    package_description,
    quantity
  INTO v_delivery
  FROM deliveries
  WHERE tracking_number = p_tracking_number;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tracking number not found');
  END IF;

  -- Get sanitized status history
  SELECT jsonb_agg(
    jsonb_build_object(
      'status', dsh.new_status,
      'timestamp', dsh.timestamp
    )
    ORDER BY dsh.timestamp ASC
  )
  INTO v_history
  FROM delivery_status_history dsh
  JOIN deliveries d ON dsh.delivery_id = d.id
  WHERE d.tracking_number = p_tracking_number;

  -- Build sanitized response (NO sensitive data)
  RETURN jsonb_build_object(
    'success', true,
    'tracking_number', v_delivery.tracking_number,
    'delivery_type', v_delivery.delivery_type,
    'status', v_delivery.status,
    'pickup_area', v_delivery.pickup_address,
    'destination_area', v_delivery.destination_address,
    'package_description', v_delivery.package_description,
    'quantity', v_delivery.quantity,
    'created_at', v_delivery.created_at,
    'timeline', COALESCE(v_history, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- CREATE DELIVERY (with tracking number generation)
-- ============================================================
CREATE OR REPLACE FUNCTION create_delivery(
  p_customer_id UUID DEFAULT NULL,
  p_ecosystem_company_id UUID DEFAULT NULL,
  p_delivery_type delivery_type DEFAULT 'lagos_bike',
  p_priority delivery_priority DEFAULT 'normal',
  p_pickup_contact_name TEXT DEFAULT '',
  p_pickup_contact_phone TEXT DEFAULT '',
  p_pickup_address TEXT DEFAULT '',
  p_pickup_latitude DOUBLE PRECISION DEFAULT NULL,
  p_pickup_longitude DOUBLE PRECISION DEFAULT NULL,
  p_pickup_notes TEXT DEFAULT NULL,
  p_recipient_name TEXT DEFAULT '',
  p_recipient_phone TEXT DEFAULT '',
  p_destination_address TEXT DEFAULT '',
  p_destination_latitude DOUBLE PRECISION DEFAULT NULL,
  p_destination_longitude DOUBLE PRECISION DEFAULT NULL,
  p_delivery_notes TEXT DEFAULT NULL,
  p_package_type TEXT DEFAULT NULL,
  p_package_description TEXT DEFAULT NULL,
  p_quantity INTEGER DEFAULT 1,
  p_estimated_weight NUMERIC DEFAULT NULL,
  p_special_handling_notes TEXT DEFAULT NULL,
  p_requested_pickup_time TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_tracking_number TEXT;
  v_delivery_id UUID;
  v_creator_id UUID;
  v_current_role user_role;
BEGIN
  -- Get creator
  SELECT p.id, p.role INTO v_creator_id, v_current_role
  FROM profiles p WHERE p.auth_user_id = auth.uid();

  IF v_creator_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  -- Generate tracking number
  v_tracking_number := generate_tracking_number();

  -- Create delivery
  INSERT INTO deliveries (
    tracking_number, ecosystem_company_id, customer_id, created_by,
    delivery_type, priority,
    pickup_contact_name, pickup_contact_phone, pickup_address,
    pickup_latitude, pickup_longitude, pickup_notes,
    recipient_name, recipient_phone, destination_address,
    destination_latitude, destination_longitude, delivery_notes,
    package_type, package_description, quantity,
    estimated_weight, special_handling_notes,
    requested_pickup_time, status
  ) VALUES (
    v_tracking_number,
    p_ecosystem_company_id,
    COALESCE(p_customer_id, v_creator_id),
    v_creator_id,
    p_delivery_type,
    p_priority,
    p_pickup_contact_name,
    p_pickup_contact_phone,
    p_pickup_address,
    p_pickup_latitude,
    p_pickup_longitude,
    p_pickup_notes,
    p_recipient_name,
    p_recipient_phone,
    p_destination_address,
    p_destination_latitude,
    p_destination_longitude,
    p_delivery_notes,
    p_package_type,
    p_package_description,
    p_quantity,
    p_estimated_weight,
    p_special_handling_notes,
    p_requested_pickup_time,
    'created'::delivery_status
  )
  RETURNING id INTO v_delivery_id;

  -- Create initial status history
  INSERT INTO delivery_status_history (
    delivery_id, previous_status, new_status, changed_by, notes
  ) VALUES (
    v_delivery_id, NULL, 'created'::delivery_status, v_creator_id, 'Delivery created'
  );

  -- Create audit log
  INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, new_values)
  VALUES (
    v_creator_id,
    'delivery_created',
    'delivery',
    v_delivery_id,
    jsonb_build_object('tracking_number', v_tracking_number)
  );

  RETURN jsonb_build_object(
    'success', true,
    'delivery_id', v_delivery_id,
    'tracking_number', v_tracking_number
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATE DELIVERY PRICING (admin/dispatcher only)
-- ============================================================
CREATE OR REPLACE FUNCTION update_delivery_pricing(
  p_delivery_id UUID,
  p_suggested_price NUMERIC,
  p_final_price NUMERIC,
  p_pricing_method pricing_method DEFAULT 'automatic'
) RETURNS JSONB AS $$
DECLARE
  v_current_role user_role;
  v_delivery RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT role INTO v_current_role FROM profiles WHERE auth_user_id = auth.uid();
  IF v_current_role NOT IN ('super_admin', 'dispatcher') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only admin/dispatcher can set pricing');
  END IF;

  SELECT * INTO v_delivery FROM deliveries WHERE id = p_delivery_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delivery not found');
  END IF;

  UPDATE deliveries
  SET suggested_price = p_suggested_price,
      final_price = p_final_price,
      pricing_method = p_pricing_method,
      updated_at = NOW()
  WHERE id = p_delivery_id;

  -- Create audit log
  INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, old_values, new_values)
  SELECT
    (SELECT id FROM profiles WHERE auth_user_id = auth.uid()),
    'price_updated',
    'delivery',
    p_delivery_id,
    jsonb_build_object('suggested_price', v_delivery.suggested_price, 'final_price', v_delivery.final_price),
    jsonb_build_object('suggested_price', p_suggested_price, 'final_price', p_final_price, 'pricing_method', p_pricing_method);

  -- Transition to 'priced' if currently 'created'
  IF v_delivery.status = 'created' THEN
    PERFORM transition_delivery_status(p_delivery_id, 'priced'::delivery_status, 'Price set');
  END IF;

  RETURN jsonb_build_object('success', true, 'delivery_id', p_delivery_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- COMPLETE DELIVERY WITH PROOF
-- ============================================================
CREATE OR REPLACE FUNCTION complete_delivery(
  p_delivery_id UUID,
  p_recipient_name TEXT DEFAULT NULL,
  p_photo_url TEXT DEFAULT NULL,
  p_signature_url TEXT DEFAULT NULL,
  p_otp_verified BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_delivery RECORD;
BEGIN
  -- Get delivery
  SELECT * INTO v_delivery FROM deliveries WHERE id = p_delivery_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delivery not found');
  END IF;

  -- Check PIN if enabled
  IF v_delivery.delivery_pin_enabled AND NOT p_otp_verified THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN verification required');
  END IF;

  -- Create proof of delivery
  INSERT INTO proof_of_delivery (
    delivery_id, rider_id, recipient_name, photo_url,
    signature_url, otp_verified, notes, latitude, longitude
  ) VALUES (
    p_delivery_id, v_delivery.assigned_rider_id, p_recipient_name,
    p_photo_url, p_signature_url, p_otp_verified, p_notes,
    p_latitude, p_longitude
  );

  -- Transition to delivered
  v_result := transition_delivery_status(
    p_delivery_id,
    'delivered'::delivery_status,
    'Delivery completed with proof',
    p_latitude,
    p_longitude
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
