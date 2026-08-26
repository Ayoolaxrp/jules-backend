-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00003
-- Deliveries and Status History
-- ============================================================

-- ============================================================
-- DELIVERIES
-- ============================================================
CREATE TABLE deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identity
  tracking_number TEXT UNIQUE NOT NULL,
  tracking_token TEXT UNIQUE NOT NULL,
  ecosystem_company_id UUID REFERENCES ecosystem_companies(id),
  customer_id UUID REFERENCES profiles(id),
  created_by UUID REFERENCES profiles(id),
  assigned_rider_id UUID REFERENCES riders(id),
  assigned_vehicle_id UUID REFERENCES vehicles(id),
  
  -- Pickup
  pickup_contact_name TEXT NOT NULL,
  pickup_contact_phone TEXT NOT NULL,
  pickup_address TEXT NOT NULL,
  pickup_latitude DOUBLE PRECISION,
  pickup_longitude DOUBLE PRECISION,
  pickup_notes TEXT,
  
  -- Destination
  recipient_name TEXT NOT NULL,
  recipient_phone TEXT NOT NULL,
  destination_address TEXT NOT NULL,
  destination_latitude DOUBLE PRECISION,
  destination_longitude DOUBLE PRECISION,
  delivery_notes TEXT,
  
  -- Package
  package_type TEXT,
  package_description TEXT,
  quantity INTEGER DEFAULT 1,
  estimated_weight NUMERIC(10,2),
  special_handling_notes TEXT,
  
  -- Delivery config
  delivery_type delivery_type NOT NULL DEFAULT 'lagos_bike',
  priority delivery_priority NOT NULL DEFAULT 'normal',
  status delivery_status NOT NULL DEFAULT 'created',
  requested_pickup_time TIMESTAMPTZ,
  actual_pickup_time TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  
  -- Pricing
  suggested_price NUMERIC(10,2),
  final_price NUMERIC(10,2),
  currency TEXT NOT NULL DEFAULT 'NGN',
  pricing_method pricing_method,
  payment_status payment_status NOT NULL DEFAULT 'pending',
  
  -- Verification
  delivery_pin_enabled BOOLEAN NOT NULL DEFAULT true,
  delivery_pin_hash TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT
);

-- ============================================================
-- DELIVERY STATUS HISTORY
-- ============================================================
CREATE TABLE delivery_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
  previous_status delivery_status,
  new_status delivery_status NOT NULL,
  changed_by UUID REFERENCES profiles(id),
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  notes TEXT
);

-- ============================================================
-- PROOF OF DELIVERY
-- ============================================================
CREATE TABLE proof_of_delivery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
  rider_id UUID NOT NULL REFERENCES riders(id),
  recipient_name TEXT,
  photo_url TEXT,
  signature_url TEXT,
  otp_verified BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  delivered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- RIDER LOCATIONS
-- ============================================================
CREATE TABLE rider_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
  delivery_id UUID REFERENCES deliveries(id) ON DELETE SET NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  delivery_id UUID REFERENCES deliveries(id) ON DELETE SET NULL,
  type notification_type NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  channel notification_channel NOT NULL DEFAULT 'in_app',
  status notification_status NOT NULL DEFAULT 'pending',
  sent_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- AUDIT LOGS
-- ============================================================
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  old_values JSONB,
  new_values JSONB,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INTERNATIONAL SHIPPING REQUESTS
-- ============================================================
CREATE TABLE international_shipping_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES profiles(id),
  origin_country TEXT NOT NULL,
  destination_country TEXT NOT NULL,
  description TEXT,
  weight NUMERIC(10,2),
  dimensions TEXT,
  status intl_request_status NOT NULL DEFAULT 'pending',
  quoted_price NUMERIC(10,2),
  final_price NUMERIC(10,2),
  currency TEXT NOT NULL DEFAULT 'USD',
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CARS
-- ============================================================
CREATE TABLE cars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  make TEXT NOT NULL,
  model TEXT NOT NULL,
  year INTEGER NOT NULL,
  price NUMERIC(12,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NGN',
  description TEXT,
  mileage INTEGER,
  fuel_type TEXT,
  transmission TEXT,
  color TEXT,
  status car_status NOT NULL DEFAULT 'available',
  is_featured BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CAR IMAGES
-- ============================================================
CREATE TABLE car_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CAR INQUIRIES
-- ============================================================
CREATE TABLE car_inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  message TEXT,
  status car_inquiry_status NOT NULL DEFAULT 'new',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Deliveries
CREATE INDEX idx_deliveries_tracking ON deliveries(tracking_number);
CREATE INDEX idx_deliveries_tracking_token ON deliveries(tracking_token);
CREATE INDEX idx_deliveries_customer ON deliveries(customer_id);
CREATE INDEX idx_deliveries_rider ON deliveries(assigned_rider_id);
CREATE INDEX idx_deliveries_status ON deliveries(status);
CREATE INDEX idx_deliveries_created ON deliveries(created_at);
CREATE INDEX idx_deliveries_company ON deliveries(ecosystem_company_id);
CREATE INDEX idx_deliveries_delivery_type ON deliveries(delivery_type);

-- Status History
CREATE INDEX idx_status_history_delivery ON delivery_status_history(delivery_id);
CREATE INDEX idx_status_history_timestamp ON delivery_status_history(timestamp);

-- Proof of Delivery
CREATE INDEX idx_pod_delivery ON proof_of_delivery(delivery_id);
CREATE INDEX idx_pod_rider ON proof_of_delivery(rider_id);

-- Rider Locations
CREATE INDEX idx_rider_locations_rider ON rider_locations(rider_id);
CREATE INDEX idx_rider_locations_delivery ON rider_locations(delivery_id);
CREATE INDEX idx_rider_locations_time ON rider_locations(recorded_at);

-- Notifications
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_delivery ON notifications(delivery_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_created ON notifications(created_at);

-- Audit Logs
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);

-- International Requests
CREATE INDEX idx_intl_requests_customer ON international_shipping_requests(customer_id);
CREATE INDEX idx_intl_requests_status ON international_shipping_requests(status);

-- Cars
CREATE INDEX idx_cars_make ON cars(make);
CREATE INDEX idx_cars_model ON cars(model);
CREATE INDEX idx_cars_status ON cars(status);
CREATE INDEX idx_cars_featured ON cars(is_featured);

-- Car Images
CREATE INDEX idx_car_images_car ON car_images(car_id);

-- Car Inquiries
CREATE INDEX idx_car_inquiries_car ON car_inquiries(car_id);
CREATE INDEX idx_car_inquiries_user ON car_inquiries(user_id);
CREATE INDEX idx_car_inquiries_status ON car_inquiries(status);
