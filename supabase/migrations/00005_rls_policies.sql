-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00005
-- Row Level Security Policies
-- ============================================================

-- ============================================================
-- PROFILES
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Everyone can read their own profile
CREATE POLICY profiles_select_own ON profiles
  FOR SELECT USING (auth_user_id = auth.uid());

-- Admin can read all profiles
CREATE POLICY profiles_select_admin ON profiles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Users can update their own profile (limited fields)
CREATE POLICY profiles_update_own ON profiles
  FOR UPDATE USING (auth_user_id = auth.uid());

-- Admin can update any profile
CREATE POLICY profiles_update_admin ON profiles
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- ECOSYSTEM COMPANIES
-- ============================================================
ALTER TABLE ecosystem_companies ENABLE ROW LEVEL SECURITY;

-- Everyone can read active companies
CREATE POLICY ecosystem_companies_select ON ecosystem_companies
  FOR SELECT USING (is_active = true);

-- Only super_admin can modify
CREATE POLICY ecosystem_companies_insert_admin ON ecosystem_companies
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY ecosystem_companies_update_admin ON ecosystem_companies
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY ecosystem_companies_delete_admin ON ecosystem_companies
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- RIDERS
-- ============================================================
ALTER TABLE riders ENABLE ROW LEVEL SECURITY;

-- Rider can read own record
CREATE POLICY riders_select_own ON riders
  FOR SELECT USING (
    profile_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Admin/dispatcher can read all riders
CREATE POLICY riders_select_admin ON riders
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Admin/dispatcher can update riders
CREATE POLICY riders_update_admin ON riders
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Rider can update limited fields on own record
CREATE POLICY riders_update_own ON riders
  FOR UPDATE USING (
    profile_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Only admin can insert riders
CREATE POLICY riders_insert_admin ON riders
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- ============================================================
-- VEHICLES
-- ============================================================
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

-- Everyone can read vehicles
CREATE POLICY vehicles_select ON vehicles
  FOR SELECT USING (true);

-- Only admin can modify vehicles
CREATE POLICY vehicles_insert_admin ON vehicles
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

CREATE POLICY vehicles_update_admin ON vehicles
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

CREATE POLICY vehicles_delete_admin ON vehicles
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- PRICING RULES
-- ============================================================
ALTER TABLE pricing_rules ENABLE ROW LEVEL SECURITY;

-- Everyone can read active pricing rules
CREATE POLICY pricing_rules_select ON pricing_rules
  FOR SELECT USING (is_active = true);

-- Only admin can modify pricing rules
CREATE POLICY pricing_rules_insert_admin ON pricing_rules
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY pricing_rules_update_admin ON pricing_rules
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- DELIVERY ZONES
-- ============================================================
ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY delivery_zones_select ON delivery_zones
  FOR SELECT USING (is_active = true);

CREATE POLICY delivery_zones_insert_admin ON delivery_zones
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- DELIVERIES — Most critical RLS
-- ============================================================
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;

-- Customer can read own deliveries
CREATE POLICY deliveries_select_customer ON deliveries
  FOR SELECT USING (
    customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Rider can read assigned deliveries
CREATE POLICY deliveries_select_rider ON deliveries
  FOR SELECT USING (
    assigned_rider_id IN (
      SELECT r.id FROM riders r
      JOIN profiles p ON r.profile_id = p.id
      WHERE p.auth_user_id = auth.uid()
    )
  );

-- Admin/dispatcher can read all deliveries
CREATE POLICY deliveries_select_admin ON deliveries
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Admin/dispatcher can insert deliveries
CREATE POLICY deliveries_insert_admin ON deliveries
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Customer can create deliveries
CREATE POLICY deliveries_insert_customer ON deliveries
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'customer')
  );

-- IMPORTANT: No broad UPDATE policy for riders
-- Status transitions are handled exclusively by the transition_delivery_status() function
-- which uses SECURITY DEFINER and validates permissions internally.

-- Admin can update deliveries
CREATE POLICY deliveries_update_admin ON deliveries
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- ============================================================
-- DELIVERY STATUS HISTORY — Read only
-- ============================================================
ALTER TABLE delivery_status_history ENABLE ROW LEVEL SECURITY;

-- Delivery participants can read history
CREATE POLICY status_history_select_customer ON delivery_status_history
  FOR SELECT USING (
    delivery_id IN (
      SELECT d.id FROM deliveries d
      WHERE d.customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
    )
  );

CREATE POLICY status_history_select_rider ON delivery_status_history
  FOR SELECT USING (
    delivery_id IN (
      SELECT d.id FROM deliveries d
      WHERE d.assigned_rider_id IN (
        SELECT r.id FROM riders r
        JOIN profiles p ON r.profile_id = p.id
        WHERE p.auth_user_id = auth.uid()
      )
    )
  );

CREATE POLICY status_history_select_admin ON delivery_status_history
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- ============================================================
-- PROOF OF DELIVERY
-- ============================================================
ALTER TABLE proof_of_delivery ENABLE ROW LEVEL SECURITY;

-- Delivery participants can read POD
CREATE POLICY pod_select_customer ON proof_of_delivery
  FOR SELECT USING (
    delivery_id IN (
      SELECT d.id FROM deliveries d
      WHERE d.customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
    )
  );

CREATE POLICY pod_select_rider ON proof_of_delivery
  FOR SELECT USING (
    rider_id IN (
      SELECT r.id FROM riders r
      JOIN profiles p ON r.profile_id = p.id
      WHERE p.auth_user_id = auth.uid()
    )
  );

CREATE POLICY pod_select_admin ON proof_of_delivery
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Rider can insert POD (via function)
CREATE POLICY pod_insert_rider ON proof_of_delivery
  FOR INSERT WITH CHECK (
    rider_id IN (
      SELECT r.id FROM riders r
      JOIN profiles p ON r.profile_id = p.id
      WHERE p.auth_user_id = auth.uid()
    )
  );

-- ============================================================
-- RIDER LOCATIONS
-- ============================================================
ALTER TABLE rider_locations ENABLE ROW LEVEL SECURITY;

-- Rider can insert own location
CREATE POLICY rider_locations_insert_own ON rider_locations
  FOR INSERT WITH CHECK (
    rider_id IN (
      SELECT r.id FROM riders r
      JOIN profiles p ON r.profile_id = p.id
      WHERE p.auth_user_id = auth.uid()
    )
  );

-- Rider can read own locations
CREATE POLICY rider_locations_select_own ON rider_locations
  FOR SELECT USING (
    rider_id IN (
      SELECT r.id FROM riders r
      JOIN profiles p ON r.profile_id = p.id
      WHERE p.auth_user_id = auth.uid()
    )
  );

-- Admin can read all rider locations
CREATE POLICY rider_locations_select_admin ON rider_locations
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- User can read own notifications
CREATE POLICY notifications_select_own ON notifications
  FOR SELECT USING (
    user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- User can update own notifications (mark as read)
CREATE POLICY notifications_update_own ON notifications
  FOR UPDATE USING (
    user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- System can insert notifications (via function)
CREATE POLICY notifications_insert_system ON notifications
  FOR INSERT WITH CHECK (true);

-- ============================================================
-- AUDIT LOGS — Read only, admin only
-- ============================================================
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Only super_admin can read audit logs
CREATE POLICY audit_logs_select_admin ON audit_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- System can insert audit logs (via function)
CREATE POLICY audit_logs_insert_system ON audit_logs
  FOR INSERT WITH CHECK (true);

-- ============================================================
-- INTERNATIONAL SHIPPING REQUESTS
-- ============================================================
ALTER TABLE international_shipping_requests ENABLE ROW LEVEL SECURITY;

-- Customer can read own requests
CREATE POLICY intl_requests_select_customer ON international_shipping_requests
  FOR SELECT USING (
    customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Admin can read all requests
CREATE POLICY intl_requests_select_admin ON international_shipping_requests
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- Customer can create requests
CREATE POLICY intl_requests_insert_customer ON international_shipping_requests
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'customer')
  );

-- Admin can update requests
CREATE POLICY intl_requests_update_admin ON international_shipping_requests
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
  );

-- ============================================================
-- CARS — Public read, admin write
-- ============================================================
ALTER TABLE cars ENABLE ROW LEVEL SECURITY;

CREATE POLICY cars_select ON cars
  FOR SELECT USING (true);

CREATE POLICY cars_insert_admin ON cars
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY cars_update_admin ON cars
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY cars_delete_admin ON cars
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- CAR IMAGES — Public read, admin write
-- ============================================================
ALTER TABLE car_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY car_images_select ON car_images
  FOR SELECT USING (true);

CREATE POLICY car_images_insert_admin ON car_images
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

CREATE POLICY car_images_delete_admin ON car_images
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- ============================================================
-- CAR INQUIRIES — Public insert, admin read
-- ============================================================
ALTER TABLE car_inquiries ENABLE ROW LEVEL SECURITY;

-- Anyone can create inquiries
CREATE POLICY car_inquiries_insert ON car_inquiries
  FOR INSERT WITH CHECK (true);

-- Admin can read all inquiries
CREATE POLICY car_inquiries_select_admin ON car_inquiries
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );

-- User can read own inquiries
CREATE POLICY car_inquiries_select_own ON car_inquiries
  FOR SELECT USING (
    user_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Admin can update inquiries
CREATE POLICY car_inquiries_update_admin ON car_inquiries
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
  );
