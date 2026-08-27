# JULES LUXURY CARS & LOGISTICS — Project Context

> **Use this file as context when resuming work on this project.**
> Invoke it by sharing this file at the start of a conversation.

---

## 1. PROJECT OVERVIEW

**Jules Luxury Cars & Logistics** is the logistics arm of **Jules Luxury Worldwide**.

- **Market:** Lagos, Nigeria
- **Operations:** 24/7 company-operated dispatch-bike delivery
- **Core Workflow:** CREATE → PRICE → ASSIGN → ACCEPT → PICK UP → TRACK → DELIVER → PROOF OF DELIVERY
- **Tech Stack:** Supabase (PostgreSQL, Auth, RLS, Realtime, Storage, Edge Functions) + Lovable Frontend
- **Live Website:** https://julesluxurytransports.com

---

## 2. WHAT HAS BEEN BUILT

### Supabase Backend (DEPLOYED ✅)

| Component | Status | Details |
|-----------|--------|---------|
| Supabase Project | ✅ LIVE | Project ID: `uhbmmwqyjjxemcrgudvv` |
| Dashboard | ✅ | https://supabase.com/dashboard/project/uhbmmwqyjjxemcrgudvv |
| Database Tables | ✅ | 17 tables deployed |
| Database Functions | ✅ | 7 functions deployed |
| RLS Policies | ✅ | Enabled on all private tables |
| Edge Functions | ✅ | `public-tracking` deployed |
| Triggers | ✅ | Auto timestamps, tracking tokens, notifications, rider locations |
| Seed Data | ✅ | 7 ecosystem companies, 7 pricing rules |
| GitHub Integration | ✅ | Auto-deploys on push to main |

### Cloned Website (HOSTED ✅)

| Component | Status | Details |
|-----------|--------|---------|
| GitHub Repo | ✅ | https://github.com/Ayoolaxrp/jules-backend |
| GitHub Pages | ✅ | https://ayoolaxrp.github.io/jules-backend |
| Pages Cloned | ✅ | 7 pages (homepage, auth, request-delivery, track, cars, international, support) |

---

## 3. DATABASE SCHEMA

### Tables (17 total)

**Core:**
- `profiles` — User profiles (linked to Supabase Auth)
- `riders` — Rider profiles with availability tracking
- `vehicles` — Fleet vehicles
- `ecosystem_companies` — Jules Luxury Worldwide subsidiaries

**Deliveries:**
- `deliveries` — Core delivery records with full field map
- `delivery_status_history` — Immutable status change log
- `pricing_rules` — Configurable pricing per delivery type/zone
- `delivery_zones` — Geographic zones (lat/lng bounding box)
- `proof_of_delivery` — Delivery confirmation (photo, PIN, recipient)
- `rider_locations` — GPS tracking points

**Support:**
- `notifications` — Multi-channel notifications
- `audit_logs` — Security audit trail
- `international_shipping_requests` — International quotes
- `support_enquiries` — Contact form submissions
- `cars` — Car inventory
- `car_images` — Car listing images
- `car_inquiries` — Customer inquiries

### Enums (17 custom)

- `user_role`: super_admin, dispatcher, rider, customer
- `delivery_status`: awaiting_quote, created, priced, assigned, accepted, en_route_to_pickup, arrived_at_pickup, picked_up, in_transit, arriving, delivered, cancelled, failed, returning_to_sender, returned
- `delivery_type`: lagos_bike, lagos_vehicle, interstate, truck, air_freight, sea_freight, international_courier
- `delivery_priority`: normal, express, urgent
- `rider_availability`: available, assigned, on_pickup, delivering, off_duty
- `vehicle_type`: dispatch_bike, car, van, truck, other
- `vehicle_status`: available, on_delivery, maintenance, unavailable
- `pricing_method`: automatic, manual, override
- `payment_status`: pending, paid, failed, refunded
- `notification_type`: assignment, status_update, delivery_complete, price_update, system, cancellation
- `notification_channel`: in_app, email, sms, whatsapp, push
- `notification_status`: pending, sent, delivered, failed, read
- `intl_request_status`: submitted, pending, quoted, approved, in_transit, delivered, cancelled
- `car_status`: available, sold, reserved
- `car_inquiry_status`: new, contacted, closed
- `user_status`: active, suspended, inactive
- `rider_employment`: active, suspended, inactive

### Key Database Functions

| Function | Purpose |
|----------|---------|
| `create_delivery()` | Creates delivery with auto-generated tracking number, sets status to `awaiting_quote` |
| `transition_delivery_status()` | Enforces state machine, validates permissions, creates status history + audit log |
| `is_valid_transition()` | Validates legal status transitions |
| `assign_rider()` / `reassign_rider()` | Rider assignment with availability validation |
| `calculate_suggested_price()` | Calculates price based on pricing rules |
| `generate_delivery_pin()` / `verify_delivery_pin()` | Secure PIN generation (md5 hash) and verification |
| `complete_delivery()` | Completes delivery with proof of delivery |
| `get_public_tracking()` | Returns sanitized tracking data (no sensitive info) |
| `generate_tracking_number()` | Generates `JLL-YYYYMMDD-XXXX` format tracking numbers |

---

## 4. DELIVERY STATE MACHINE

```
awaiting_quote → created → priced → assigned → accepted → en_route_to_pickup
→ arrived_at_pickup → picked_up → in_transit → arriving → delivered

Exception states: cancelled, failed, returning_to_sender, returned
```

**Rules:**
- Transitions are enforced server-side (no client bypass)
- Riders can only transition their own assigned deliveries
- Admin/dispatchers can do all valid transitions
- Every transition creates a status history record
- Sensitive transitions create audit logs

---

## 5. SECURITY MODEL

| Role | Access |
|------|--------|
| super_admin | Full operational access |
| dispatcher | Operational management |
| rider | Only assigned deliveries |
| customer | Only their own deliveries |
| anonymous | Only sanitized public tracking |

**Key Security Features:**
- RLS enabled on ALL private tables
- Roles validated server-side (not client-trusted)
- PIN stored as md5 hash (never plaintext)
- Public tracking returns only sanitized data
- Audit logs for price changes, assignments, cancellations

---

## 6. ECOSYSTEM COMPANIES (SEEDED)

| Code | Company |
|------|---------|
| JLW | Jules Luxury Worldwide |
| RF | Rockstin Farms |
| JLF | Jules Luxury Fashion |
| JLE | Jules Luxury Estate |
| JLS | Jules Luxury Styles |
| JLL | Jules Luxury Cars & Logistics |
| EXT | External Customer |

---

## 7. PRICING RULES (SEEDED)

7 pricing rules covering: lagos_bike, lagos_vehicle, interstate, truck, air_freight, sea_freight, international_courier

---

## 8. WHAT IS NOT DONE YET

### Admin User
- ❌ **No admin user created yet**
- When ready, create via Supabase Dashboard → Authentication → Add User
- Then manually insert into `profiles` table with role `super_admin`

### Frontend Connection
- ❌ Lovable frontend not connected to Supabase
- Needs: Supabase URL (`https://uhbmmwqyjjxemcrgudvv.supabase.co`) + anon key
- Anon key: Supabase Dashboard → Settings → API → `anon` `public` key

### Dashboards
- ❌ Admin dashboard (dispatch board, rider management)
- ❌ Customer dashboard (view own deliveries)
- ❌ Rider dashboard (accept/complete deliveries)

### Notifications
- ❌ Email provider not configured
- ❌ SMS provider not configured
- ❌ WhatsApp provider not configured

### Testing
- ❌ Full workflow not tested end-to-end
- ❌ RLS policies not tested with real users
- ❌ PIN verification not tested

---

## 9. SUPABASE CREDENTIALS

| Item | Value |
|------|-------|
| Project ID | `uhbmmwqyjjxemcrgudvv` |
| Supabase URL | `https://uhbmmwqyjjxemcrgudvv.supabase.co` |
| Region | East US (North Virginia) |
| Dashboard | https://supabase.com/dashboard/project/uhbmmwqyjjxemcrgudvv |
| Database Password | *(known to project owner)* |

**Anon Key:** Get from Dashboard → Settings → API → `anon` `public` key

---

## 10. GITHUB REPOSITORY

| Item | Value |
|------|-------|
| Repo | https://github.com/Ayoolaxrp/jules-backend |
| Branch | `main` |
| GitHub Pages | https://ayoolaxrp.github.io/jules-backend |
| GitHub Integration | Connected to Supabase (auto-deploy on push) |

### Repo Structure

```
jules-backend/
├── README.md
├── PROJECT_CONTEXT.md          ← You are here
├── AUDIT_CHECKLIST.md
├── AUDIT_REPORT.md
├── BACKEND_ARCHITECTURE.md
├── BACKEND_FEATURES_INFERRED_FROM_SITE.md
├── BUILD_PLAN.md
├── docs/                       ← GitHub Pages (cloned website)
│   ├── index.html
│   ├── auth.html
│   ├── request-delivery.html
│   ├── track.html
│   ├── cars.html
│   ├── international.html
│   └── support.html
├── cloned_site/                ← Local clone (not pushed)
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   │   ├── 00001_create_extensions_and_enums.sql
│   │   ├── 00002_create_core_tables.sql
│   │   ├── 00003_create_deliveries_tables.sql
│   │   ├── 00004_create_functions.sql
│   │   ├── 00005_rls_policies.sql
│   │   ├── 00006_storage_and_realtime.sql
│   │   ├── 00007_triggers_and_timestamps.sql
│   │   └── 00008_update_for_website_alignment.sql
│   ├── functions/
│   │   └── public-tracking/index.ts
│   └── seed/
│       └── seed_data.sql
├── clone_site.py
└── fix_clone.py
```

---

## 11. COMMON COMMANDS

```bash
# Push migrations to Supabase
cd /c/Users/User/jules-logistics
npx supabase db push

# Deploy Edge Functions
npx supabase functions deploy public-tracking

# Run SQL queries against remote DB
npx supabase db query --linked --file query.sql

# Push to GitHub
git add -A && git commit -m "message" && git push origin main

# Serve cloned site locally
cd cloned_site && python -m http.server 8080
```

---

## 12. WEBSITE AUDIT FINDINGS

### Live Pages (from julesluxurytransports.com)
- Homepage, Auth, Request Delivery, Track, Cars, International, Support

### Missing Pages (404)
- Customer Dashboard, Admin Dashboard, Rider Dashboard, Signup

### Confirmed Form Fields (Request Delivery)
All 13 fields match the database schema:
pickup_address, destination_address, pickup_contact_name, pickup_contact_phone,
recipient_name, recipient_phone, package_type, delivery_type, ecosystem_company_id,
requested_pickup_time, package_description, special_handling_notes

### Delivery Type Routing
- Lagos Bike/Vehicle, Interstate, Truck → `deliveries` table (status: `awaiting_quote`)
- Air/Sea/Courier → `international_shipping_requests` table (status: `submitted`)

---

## 13. NEXT STEPS (IN ORDER)

1. **Create admin user** — via Supabase Dashboard
2. **Connect Lovable frontend** — add Supabase URL + anon key
3. **Test delivery workflow** — create → price → assign → track → deliver
4. **Build admin dashboard** — dispatch board, rider management
5. **Build customer dashboard** — view own deliveries
6. **Build rider dashboard** — accept/complete deliveries
7. **Configure notifications** — email/SMS provider
8. **End-to-end testing** — full workflow with real users

---

*Last updated: August 27, 2026*
*Project: Jules Luxury Cars & Logistics*
*Backend: Supabase (uhbmmwqyjjxemcrgudvv)*
*Frontend: Lovable (pending connection)*
