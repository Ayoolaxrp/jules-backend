# Jules Luxury Logistics — Backend Architecture

## Overview

This document describes the Supabase backend architecture for Jules Luxury Cars & Logistics Version 1.

**Target:** Lagos 24/7 dispatch-bike logistics
**Workflow:** REQUEST → QUOTE → ASSIGN → ACCEPT → PICK UP → TRACK → DELIVER → PROOF

**Website:** julesluxurytransports.com (Lovable-exported TanStack Start SSR on Cloudflare)

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Database | PostgreSQL (Supabase) |
| Authentication | Supabase Auth (Email + Google OAuth) |
| Security | Row Level Security (RLS) |
| Realtime | Supabase Realtime |
| Storage | Supabase Storage |
| Edge Functions | Deno (Supabase Edge Functions) |
| Geospatial | PostGIS |

---

## Delivery State Machine (Updated)

```
awaiting_quote → created → priced → assigned → accepted →
en_route_to_pickup → arrived_at_pickup → picked_up →
in_transit → arriving → delivered
```

Exception states: `cancelled`, `failed`, `returning_to_sender`, `returned`

**Initial Status:** `awaiting_quote` (set by `/request-delivery` form)

---

## Delivery Type Routing (From Website Scrape)

```
/request-delivery form
    │
    ├── Lagos Bike → deliveries (awaiting_quote)
    ├── Lagos Vehicle → deliveries (awaiting_quote)
    ├── Interstate → deliveries (awaiting_quote)
    ├── Truck → deliveries (awaiting_quote)
    │
    ├── Air Freight → international_shipping_requests (submitted)
    ├── Sea Freight → international_shipping_requests (submitted)
    └── International Courier → international_shipping_requests (submitted)
```

---

## Database Schema

### Core Tables

#### profiles
User profiles linked to Supabase Auth users.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Profile ID |
| auth_user_id | UUID (FK → auth.users) | Supabase Auth user |
| first_name | TEXT | First name |
| last_name | TEXT | Last name |
| email | TEXT | Email address |
| phone | TEXT | Phone number |
| role | ENUM | super_admin, dispatcher, rider, customer |
| status | ENUM | active, suspended, inactive |
| profile_photo | TEXT | Photo URL |
| created_at | TIMESTAMPTZ | Created timestamp |
| updated_at | TIMESTAMPTZ | Updated timestamp |

**Trigger:** Auto-creates profile on auth.users signup.

#### riders
Rider profiles with availability and employment status.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Rider ID |
| profile_id | UUID (FK → profiles) | Linked profile |
| employee_id | TEXT | Employee identifier |
| phone | TEXT | Contact phone |
| emergency_contact | TEXT | Emergency contact |
| vehicle_id | UUID (FK → vehicles) | Assigned vehicle |
| availability_status | ENUM | available, assigned, on_pickup, delivering, off_duty |
| employment_status | ENUM | active, suspended, inactive |
| current_delivery_id | UUID (FK → deliveries) | Current delivery |
| last_known_latitude | DOUBLE | Last GPS latitude |
| last_known_longitude | DOUBLE | Last GPS longitude |
| last_location_update | TIMESTAMPTZ | Last location timestamp |

#### vehicles
Fleet vehicles for dispatch operations.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Vehicle ID |
| vehicle_code | TEXT (UNIQUE) | Vehicle identifier |
| vehicle_type | ENUM | dispatch_bike, car, van, truck, other |
| registration_number | TEXT | Registration plate |
| make | TEXT | Manufacturer |
| model | TEXT | Model |
| assigned_rider_id | UUID (FK → riders) | Assigned rider |
| status | ENUM | available, on_delivery, maintenance, unavailable |

#### ecosystem_companies
Jules Luxury Worldwide company attribution.

| Code | Company |
|------|---------|
| JLW | Jules Luxury Worldwide |
| RF | Rockstin Farms |
| JLF | Jules Luxury Fashion |
| JLE | Jules Luxury Estate |
| JLS | Jules Luxury Styles |
| JLL | Jules Luxury Cars & Logistics |
| EXT | External Customer |

#### deliveries
Core delivery records with full lifecycle.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Delivery ID |
| tracking_number | TEXT (UNIQUE) | Format: JLL-YYYYMMDD-XXXX |
| tracking_token | TEXT (UNIQUE) | Secure token for tracking |
| ecosystem_company_id | UUID (FK) | Source company |
| customer_id | UUID (FK → profiles) | Customer |
| created_by | UUID (FK → profiles) | Creator |
| assigned_rider_id | UUID (FK → riders) | Assigned rider |
| assigned_vehicle_id | UUID (FK → vehicles) | Assigned vehicle |
| pickup_* | Various | Pickup details |
| recipient_* | Various | Recipient details |
| destination_* | Various | Destination details |
| package_* | Various | Package details |
| delivery_type | ENUM | lagos_bike, lagos_vehicle, etc. |
| priority | ENUM | normal, express, urgent |
| status | ENUM | awaiting_quote, created, priced, etc. |
| suggested_price | NUMERIC | System-calculated price |
| final_price | NUMERIC | Final agreed price |
| pricing_method | ENUM | automatic, manual, override |
| delivery_pin_hash | TEXT | Hashed delivery PIN |
| created_at | TIMESTAMPTZ | Created timestamp |
| updated_at | TIMESTAMPTZ | Updated timestamp |

### Supporting Tables

| Table | Purpose |
|-------|---------|
| delivery_status_history | Immutable audit trail of all status changes |
| pricing_rules | Configurable pricing by delivery type |
| delivery_zones | Geographic delivery zones (PostGIS) |
| proof_of_delivery | Delivery confirmation with photo/PIN |
| rider_locations | GPS tracking during active deliveries |
| notifications | In-app and multi-channel notifications |
| audit_logs | Immutable security audit trail |
| international_shipping_requests | International shipping quotes |
| support_enquiries | Contact form submissions |
| cars | Car inventory |
| car_images | Car listing images |
| car_inquiries | Customer inquiries about cars |

---

## Delivery State Machine

```
awaiting_quote → created → priced → assigned → accepted →
en_route_to_pickup → arrived_at_pickup → picked_up →
in_transit → arriving → delivered
```

Exception states: `cancelled`, `failed`, `returning_to_sender`, `returned`

**Enforcement:** Server-side via `transition_delivery_status()` function.
**History:** Every transition creates a `delivery_status_history` record.

---

## Roles & Permissions

| Role | Deliveries | Pricing | Assignment | Tracking | Cars |
|------|-----------|---------|------------|----------|------|
| super_admin | Full CRUD | Set price | Assign/Reassign | All | Full CRUD |
| dispatcher | Full CRUD | Set price | Assign/Reassign | All | Read |
| rider | Read assigned | None | None | Own | Read |
| customer | Read own | None | None | Own | Read |
| anonymous | Public tracking | None | None | Public only | Read |

---

## RLS Model

- **Default deny:** No access unless explicitly granted
- **Role-based policies:** Every table has policies per role
- **Server-enforced:** State transitions, pricing, and assignment via SECURITY DEFINER functions
- **No client-trusted roles:** Roles are never read from client requests

---

## Secure Functions

| Function | Purpose | Security |
|----------|---------|----------|
| `transition_delivery_status()` | Enforce state machine | SECURITY DEFINER, role validation |
| `assign_rider()` | Assign rider to delivery | Admin/dispatcher only |
| `reassign_rider()` | Reassign rider | Admin/dispatcher only |
| `calculate_suggested_price()` | Calculate price | Server-side only |
| `generate_delivery_pin()` | Generate delivery PIN | Server-side, hash only |
| `verify_delivery_pin()` | Verify PIN | Server-side, disable after use |
| `create_delivery()` | Create new delivery | Authenticated users |
| `update_delivery_pricing()` | Set pricing | Admin/dispatcher only |
| `complete_delivery()` | Complete with proof | Rider (assigned) only |
| `get_public_tracking()` | Public tracking | Anonymous, sanitized output |
| `get_available_riders()` | List available riders | Admin/dispatcher only |

---

## Tracking Number Format

```
JLL-YYYYMMDD-XXXX
```

Example: `JLL-20260826-0001`

- Unique, never recycled
- Generated server-side
- Indexed for fast lookup
- NOT used as security credential

---

## Public Tracking Security

The `get_public_tracking()` function returns ONLY:
- Tracking number
- Delivery type
- Status
- Pickup area (address only)
- Destination area (address only)
- Package description
- Created timestamp
- Sanitized timeline (status + timestamp only)

**NEVER exposed:** customer phone, recipient phone, private notes, rider info, pricing, GPS history.

---

## Pricing Engine

**Calculation:**
```
suggested_price = base_price + (distance × per_km_rate) + (weight × per_kg_rate) + priority_fee
```

**Enforcement:**
- System calculates `suggested_price`
- Dispatcher/admin sets `final_price`
- `pricing_method` records how price was determined
- Riders CANNOT modify prices
- Historical prices preserved on delivery record

---

## Storage

| Bucket | Privacy | Purpose |
|--------|---------|---------|
| proof-of-delivery | Private | Delivery photos, signed URLs |
| car-images | Public | Car listing photos |

---

## Realtime

| Table | Use Case |
|-------|----------|
| deliveries | Admin dispatch board, customer tracking |
| notifications | User notification feed |
| rider_locations | Admin rider visibility |

---

## Deployment

### Local Development
```bash
npx supabase start
```

### Link to Remote Project
```bash
npx supabase link --project-ref <project-id>
```

### Push Migrations
```bash
npx supabase db push
```

### Deploy Edge Functions
```bash
npx supabase functions deploy public-tracking
```

---

## File Structure

```
supabase/
├── config.toml                    # Supabase project configuration
├── migrations/
│   ├── 00001_create_extensions_and_enums.sql
│   ├── 00002_create_core_tables.sql
│   ├── 00003_create_deliveries_tables.sql
│   ├── 00004_create_functions.sql
│   ├── 00005_rls_policies.sql
│   ├── 00006_storage_and_realtime.sql
│   ├── 00007_triggers_and_timestamps.sql
│   └── 00008_update_for_website_alignment.sql
├── functions/
│   └── public-tracking/
│       └── index.ts
└── seed/
    └── seed_data.sql
```

---

## Open Questions

1. Same Supabase project for marketing + ops, or separate?
2. Should `/request-delivery` stay public-no-login in V1?
3. International form — deliveries row with `awaiting_quote`, or only `international_shipping_requests`?
4. Cars inventory — public catalogue in V1, or admin-only?
5. Which notification channels must be live day one (email only, or WhatsApp/Termii too)?
6. Preferred Lagos zone model — polygons, named areas, or postcodes?
