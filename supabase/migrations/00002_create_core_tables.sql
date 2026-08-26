-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00002
-- Core Tables: Profiles, Riders, Vehicles, Ecosystem Companies
-- ============================================================


-- ============================================================
-- PROFILES
-- ============================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL DEFAULT '',
  last_name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  role user_role NOT NULL DEFAULT 'customer',
  status user_status NOT NULL DEFAULT 'active',
  profile_photo TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (auth_user_id, email, first_name, last_name, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- ECOSYSTEM COMPANIES
-- ============================================================
CREATE TABLE ecosystem_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- RIDERS
-- ============================================================
CREATE TABLE riders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  employee_id TEXT UNIQUE,
  phone TEXT NOT NULL DEFAULT '',
  emergency_contact TEXT,
  vehicle_id UUID,
  availability_status rider_availability NOT NULL DEFAULT 'off_duty',
  employment_status rider_employment NOT NULL DEFAULT 'active',
  current_delivery_id UUID,
  last_known_latitude DOUBLE PRECISION,
  last_known_longitude DOUBLE PRECISION,
  last_location_update TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- VEHICLES
-- ============================================================
CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_code TEXT UNIQUE NOT NULL,
  vehicle_type vehicle_type NOT NULL DEFAULT 'dispatch_bike',
  registration_number TEXT,
  make TEXT,
  model TEXT,
  assigned_rider_id UUID REFERENCES riders(id) ON DELETE SET NULL,
  status vehicle_status NOT NULL DEFAULT 'available',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add foreign key from riders to vehicles
ALTER TABLE riders
  ADD CONSTRAINT fk_riders_vehicle
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE SET NULL;

-- ============================================================
-- PRICING RULES
-- ============================================================
CREATE TABLE pricing_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  delivery_type delivery_type NOT NULL,
  base_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  per_km_rate NUMERIC(10,2) NOT NULL DEFAULT 0,
  per_kg_rate NUMERIC(10,2) NOT NULL DEFAULT 0,
  minimum_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  priority_fee_normal NUMERIC(10,2) NOT NULL DEFAULT 0,
  priority_fee_express NUMERIC(10,2) NOT NULL DEFAULT 0,
  priority_fee_urgent NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DELIVERY ZONES
-- ============================================================
CREATE TABLE delivery_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  -- Simple bounding box for V1 (no PostGIS dependency)
  min_latitude NUMERIC(9,6),
  max_latitude NUMERIC(9,6),
  min_longitude NUMERIC(9,6),
  max_longitude NUMERIC(9,6),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_profiles_auth_user_id ON profiles(auth_user_id);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_phone ON profiles(phone);

CREATE INDEX idx_riders_profile_id ON riders(profile_id);
CREATE INDEX idx_riders_availability ON riders(availability_status);
CREATE INDEX idx_riders_employment ON riders(employment_status);
CREATE INDEX idx_riders_vehicle_id ON riders(vehicle_id);

CREATE INDEX idx_vehicles_code ON vehicles(vehicle_code);
CREATE INDEX idx_vehicles_type ON vehicles(vehicle_type);
CREATE INDEX idx_vehicles_status ON vehicles(status);
CREATE INDEX idx_vehicles_rider ON vehicles(assigned_rider_id);

CREATE INDEX idx_pricing_rules_delivery_type ON pricing_rules(delivery_type);
CREATE INDEX idx_pricing_rules_active ON pricing_rules(is_active);

CREATE INDEX idx_ecosystem_companies_code ON ecosystem_companies(code);
