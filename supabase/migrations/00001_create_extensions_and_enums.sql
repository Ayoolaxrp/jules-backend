-- ============================================================
-- JULES LUXURY CARS & LOGISTICS — Migration 00001
-- Extensions, Enums, and Core Types
-- ============================================================

-- Enable required extensions
-- gen_random_uuid() is built-in to PostgreSQL 13+ (no uuid-ossp needed)
-- pgcrypto needed for digest() (SHA-256 PIN hashing)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUM TYPES
-- ============================================================

-- User roles
CREATE TYPE user_role AS ENUM (
  'super_admin',
  'dispatcher',
  'rider',
  'customer'
);

-- User status
CREATE TYPE user_status AS ENUM (
  'active',
  'suspended',
  'inactive'
);

-- Rider availability
CREATE TYPE rider_availability AS ENUM (
  'available',
  'assigned',
  'on_pickup',
  'delivering',
  'off_duty'
);

-- Rider employment status
CREATE TYPE rider_employment AS ENUM (
  'active',
  'suspended',
  'inactive'
);

-- Vehicle type
CREATE TYPE vehicle_type AS ENUM (
  'dispatch_bike',
  'car',
  'van',
  'truck',
  'other'
);

-- Vehicle status
CREATE TYPE vehicle_status AS ENUM (
  'available',
  'on_delivery',
  'maintenance',
  'unavailable'
);

-- Delivery type
CREATE TYPE delivery_type AS ENUM (
  'lagos_bike',
  'lagos_vehicle',
  'interstate',
  'truck',
  'air_freight',
  'sea_freight',
  'international_courier'
);

-- Delivery priority
CREATE TYPE delivery_priority AS ENUM (
  'normal',
  'express',
  'urgent'
);

-- Delivery status — the state machine
CREATE TYPE delivery_status AS ENUM (
  'created',
  'priced',
  'assigned',
  'accepted',
  'en_route_to_pickup',
  'arrived_at_pickup',
  'picked_up',
  'in_transit',
  'arriving',
  'delivered',
  'cancelled',
  'failed',
  'returning_to_sender',
  'returned'
);

-- Pricing method
CREATE TYPE pricing_method AS ENUM (
  'automatic',
  'manual',
  'override'
);

-- Payment status
CREATE TYPE payment_status AS ENUM (
  'pending',
  'paid',
  'failed',
  'refunded'
);

-- Notification type
CREATE TYPE notification_type AS ENUM (
  'assignment',
  'status_update',
  'delivery_complete',
  'price_update',
  'system',
  'cancellation'
);

-- Notification channel
CREATE TYPE notification_channel AS ENUM (
  'in_app',
  'email',
  'sms',
  'whatsapp',
  'push'
);

-- Notification status
CREATE TYPE notification_status AS ENUM (
  'pending',
  'sent',
  'delivered',
  'failed',
  'read'
);

-- International request status
CREATE TYPE intl_request_status AS ENUM (
  'pending',
  'quoted',
  'approved',
  'in_transit',
  'delivered',
  'cancelled'
);

-- Car status
CREATE TYPE car_status AS ENUM (
  'available',
  'sold',
  'reserved'
);

-- Car inquiry status
CREATE TYPE car_inquiry_status AS ENUM (
  'new',
  'contacted',
  'closed'
);
