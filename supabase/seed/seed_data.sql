-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Seed Data
-- ============================================================

-- ============================================================
-- ECOSYSTEM COMPANIES
-- ============================================================
INSERT INTO ecosystem_companies (code, name, description) VALUES
  ('JLW', 'Jules Luxury Worldwide', 'Parent company — Jules Luxury Worldwide'),
  ('RF', 'Rockstin Farms', 'Rockstin Farms division'),
  ('JLF', 'Jules Luxury Fashion', 'Fashion division'),
  ('JLE', 'Jules Luxury Estate', 'Real estate division'),
  ('JLS', 'Jules Luxury Styles', 'Styles division'),
  ('JLL', 'Jules Luxury Cars & Logistics', 'Logistics and cars division'),
  ('EXT', 'External Customer', 'External customers not part of the Jules ecosystem')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- DEFAULT PRICING RULES — Lagos Operations
-- ============================================================
INSERT INTO pricing_rules (name, delivery_type, base_price, per_km_rate, per_kg_rate, minimum_price, priority_fee_normal, priority_fee_express, priority_fee_urgent) VALUES
  ('Lagos Bike Standard', 'lagos_bike', 1000.00, 150.00, 50.00, 1500.00, 0.00, 500.00, 1000.00),
  ('Lagos Vehicle Standard', 'lagos_vehicle', 3000.00, 200.00, 100.00, 5000.00, 0.00, 1000.00, 2000.00),
  ('Interstate Standard', 'interstate', 5000.00, 300.00, 100.00, 8000.00, 0.00, 2000.00, 4000.00),
  ('Truck Standard', 'truck', 10000.00, 500.00, 200.00, 15000.00, 0.00, 3000.00, 5000.00),
  ('Air Freight Standard', 'air_freight', 50000.00, 0.00, 0.00, 50000.00, 0.00, 0.00, 0.00),
  ('Sea Freight Standard', 'sea_freight', 30000.00, 0.00, 0.00, 30000.00, 0.00, 0.00, 0.00),
  ('International Courier Standard', 'international_courier', 25000.00, 0.00, 0.00, 25000.00, 0.00, 0.00, 0.00);
