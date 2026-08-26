-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00006
-- Storage Policies and Realtime
-- ============================================================

-- ============================================================
-- STORAGE BUCKETS (created via config.toml, but ensure they exist)
-- ============================================================

-- Create storage buckets if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('proof-of-delivery', 'proof-of-delivery', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('car-images', 'car-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- STORAGE POLICIES — proof-of-delivery (private)
-- ============================================================

-- Rider can upload to proof-of-delivery
CREATE POLICY "Rider can upload proof of delivery"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'proof-of-delivery'
  AND auth.uid() IN (
    SELECT p.auth_user_id FROM profiles p
    WHERE p.role = 'rider'
  )
);

-- Delivery participants can view proof-of-delivery
CREATE POLICY "Delivery participants can view proof of delivery"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'proof-of-delivery'
  AND (
    -- Admin can view all
    EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role IN ('super_admin', 'dispatcher'))
    OR
    -- Customer can view their deliveries' proof
    EXISTS (
      SELECT 1 FROM proof_of_delivery pod
      JOIN deliveries d ON pod.delivery_id = d.id
      WHERE d.customer_id IN (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
      AND pod.photo_url LIKE '%' || name || '%'
    )
    OR
    -- Rider can view their own uploads
    EXISTS (
      SELECT 1 FROM proof_of_delivery pod
      JOIN riders r ON pod.rider_id = r.id
      JOIN profiles p ON r.profile_id = p.id
      WHERE p.auth_user_id = auth.uid()
      AND pod.photo_url LIKE '%' || name || '%'
    )
  )
);

-- ============================================================
-- STORAGE POLICIES — car-images (public)
-- ============================================================

-- Anyone can view car images
CREATE POLICY "Anyone can view car images"
ON storage.objects FOR SELECT
USING (bucket_id = 'car-images');

-- Admin can upload car images
CREATE POLICY "Admin can upload car images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'car-images'
  AND EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
);

-- Admin can delete car images
CREATE POLICY "Admin can delete car images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'car-images'
  AND EXISTS (SELECT 1 FROM profiles WHERE auth_user_id = auth.uid() AND role = 'super_admin')
);

-- ============================================================
-- REALTIME — Enable on key tables
-- ============================================================

-- Enable realtime for deliveries (admin dispatch board, customer tracking)
ALTER PUBLICATION supabase_realtime ADD TABLE deliveries;

-- Enable realtime for notifications (user notifications)
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Enable realtime for rider_locations (admin visibility)
ALTER PUBLICATION supabase_realtime ADD TABLE rider_locations;
