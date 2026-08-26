-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00008
-- Update schema to match actual website behavior
-- ============================================================

-- ============================================================
-- ADD awaitiNG_QUOTE TO DELIVERY STATUS ENUM
-- ============================================================
ALTER TYPE delivery_status ADD VALUE IF NOT EXISTS 'awaiting_quote';

-- ============================================================
-- ADD submitted TO intl_request_status ENUM
-- ============================================================
ALTER TYPE intl_request_status ADD VALUE IF NOT EXISTS 'submitted';

-- ============================================================
-- UPDATE FUNCTIONS THAT REFERENCE THE ENUM
-- ============================================================

-- Update is_valid_transition function
CREATE OR REPLACE FUNCTION is_valid_transition(
  from_status delivery_status,
  to_status delivery_status
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN CASE from_status
    WHEN 'awaiting_quote' THEN to_status IN ('created', 'cancelled')
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

-- Update create_delivery function to use awaiting_quote as initial status
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
  v_initial_status delivery_status;
BEGIN
  -- Get creator
  SELECT p.id, p.role INTO v_creator_id, v_current_role
  FROM profiles p WHERE p.auth_user_id = auth.uid();

  IF v_creator_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  -- Generate tracking number
  v_tracking_number := generate_tracking_number();

  -- All deliveries start as awaiting_quote
  v_initial_status := 'awaiting_quote'::delivery_status;

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
    v_initial_status
  )
  RETURNING id INTO v_delivery_id;

  -- Create initial status history
  INSERT INTO delivery_status_history (
    delivery_id, previous_status, new_status, changed_by, notes
  ) VALUES (
    v_delivery_id, NULL, v_initial_status, v_creator_id, 'Delivery request submitted'
  );

  -- Create audit log
  INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, new_values)
  VALUES (
    v_creator_id,
    'delivery_created',
    'delivery',
    v_delivery_id,
    jsonb_build_object('tracking_number', v_tracking_number, 'delivery_type', p_delivery_type)
  );

  RETURN jsonb_build_object(
    'success', true,
    'delivery_id', v_delivery_id,
    'tracking_number', v_tracking_number,
    'status', v_initial_status
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update transition_delivery_status function to handle awaiting_quote
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
  IF p_new_status IN ('cancelled', 'delivered', 'priced', 'awaiting_quote') THEN
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
-- ADD SUPPORT FORM TABLE
-- The /support page has a contact form that needs a backend
-- ============================================================

CREATE TABLE support_enquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  category TEXT NOT NULL DEFAULT 'general',
  subject TEXT NOT NULL,
  tracking_number TEXT,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'new',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS for support enquiries
ALTER TABLE support_enquiries ENABLE ROW LEVEL SECURITY;

-- Anyone can create enquiries
CREATE POLICY support_enquiries_insert ON support_enquiries
  FOR INSERT WITH CHECK (true);

-- Admin can read all enquiries
CREATE POLICY support_enquiries_select_admin ON support_enquiries
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- User can read own enquiries
CREATE POLICY support_enquiries_select_own ON support_enquiries
  FOR SELECT USING (
    email = (SELECT email FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Admin can update enquiries
CREATE POLICY support_enquiries_update_admin ON support_enquiries
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Updated_at trigger
CREATE TRIGGER update_support_enquiries_updated_at
  BEFORE UPDATE ON support_enquiries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Index
CREATE INDEX idx_support_enquiries_status ON support_enquiries(status);
CREATE INDEX idx_support_enquiries_created ON support_enquiries(created_at);
CREATE INDEX idx_support_enquiries_tracking ON support_enquiries(tracking_number);
