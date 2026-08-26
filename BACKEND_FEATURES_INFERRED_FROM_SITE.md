# Backend Features Inferred From Site Scrape

> **Source:** julesluxurytransports.com (scraped 2026-08-26)
> **Framework:** Lovable-exported TanStack Start SSR on Cloudflare
> **Status:** INFERENCE — based on public site observation

---

## 1. Site Architecture

| Property | Value |
|----------|-------|
| Framework | TanStack Start (SSR) |
| Hosting | Cloudflare |
| Exported from | Lovable |
| Backend | Supabase (inferred from auth patterns) |

---

## 2. Route Map

### Public Routes (Live)

| Route | Function | Backend Need |
|-------|----------|--------------|
| `/` | Marketing homepage | None (static) |
| `/auth` | Sign in (email/password + Google OAuth) | Supabase Auth |
| `/request-delivery` | 13-field delivery form | `create_delivery()` or `create_international_request()` |
| `/track` | Tracking number lookup | `get_public_tracking()` RPC |
| `/cars` | Mercedes-Benz vehicle catalogue | `cars` + `car_images` tables |
| `/international` | 14-field RFQ form | `international_shipping_requests` table |
| `/support` | Contact/enquiry form | `support_enquiries` table |

### Protected Routes (404 or SPA catch-all)

| Route | Status | Notes |
|-------|--------|-------|
| `/admin` | 404 | Good — no exposed admin shell |
| `/dashboard` | 404 | Good — no exposed dashboard |
| `/customer` | 404 | Needs build |
| `/rider` | SPA catch-all | Returns marketing shell |

---

## 3. Form Field Mapping

### /request-delivery (13 fields)

| Form Field | Database Column | Table | Notes |
|------------|-----------------|-------|-------|
| Pickup Location | `pickup_address` | `deliveries` | Text input |
| Destination | `destination_address` | `deliveries` | Text input |
| Sender Name | `pickup_contact_name` | `deliveries` | Required |
| Sender Phone | `pickup_contact_phone` | `deliveries` | Required |
| Recipient Name | `recipient_name` | `deliveries` | Required |
| Recipient Phone | `recipient_phone` | `deliveries` | Required |
| Package Type | `package_type` | `deliveries` | Optional text |
| Delivery Type | `delivery_type` | `deliveries` | Enum selection |
| Ecosystem Company | `ecosystem_company_id` | `deliveries` | FK to ecosystem_companies |
| Preferred Pickup Time | `requested_pickup_time` | `deliveries` | Timestamp |
| Package Description | `package_description` | `deliveries` | Text |
| Special Instructions | `special_handling_notes` | `deliveries` | Text |

**Routing Logic:**
- Lagos Bike, Lagos Vehicle, Interstate, Truck → `deliveries` table (status: `awaiting_quote`)
- Air Freight, Sea Freight, International Courier → `international_shipping_requests` table (status: `submitted`)

### /international (14 fields)

| Form Field | Database Column | Table | Notes |
|------------|-----------------|-------|-------|
| Origin Country | `origin_country` | `international_shipping_requests` | Required |
| Origin City | `origin_city` | `international_shipping_requests` | Optional |
| Destination Country | `destination_country` | `international_shipping_requests` | Required |
| Destination City | `destination_city` | `international_shipping_requests` | Optional |
| Cargo Type | `cargo_type` | `international_shipping_requests` | Text |
| Preferred Method | `preferred_method` | `international_shipping_requests` | air/sea/courier/not_sure |
| Weight | `weight` | `international_shipping_requests` | Numeric |
| Dimensions | `dimensions` | `international_shipping_requests` | Text |
| Description | `description` | `international_shipping_requests` | Text |
| Customer Name | `customer_name` | `international_shipping_requests` | Required |
| Company | `company` | `international_shipping_requests` | Optional |
| Phone | `phone` | `international_shipping_requests` | Required |
| Email | `email` | `international_shipping_requests` | Optional |
| Special Requirements | `special_requirements` | `international_shipping_requests` | Text |

### /support (8 fields)

| Form Field | Database Column | Table | Notes |
|------------|-----------------|-------|-------|
| Full Name | `full_name` | `support_enquiries` | Required |
| Email | `email` | `support_enquiries` | Required |
| Phone | `phone` | `support_enquiries` | Optional |
| Category | `category` | `support_enquiries` | Enum selection |
| Subject | `subject` | `support_enquiries` | Required |
| Tracking Number | `tracking_number` | `support_enquiries` | Optional |
| Message | `message` | `support_enquiries` | Required |

---

## 4. Delivery Type Routing

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

## 5. Ecosystem Companies (Confirmed)

| Website Label | Database Code | Company |
|---------------|---------------|---------|
| Rockstin Farms | `RF` | Rockstin Farms |
| Jules Luxury Fashion | `JLF` | Jules Luxury Fashion |
| Jules Luxury Estate | `JLE` | Jules Luxury Estate |
| Jules Luxury Styles | `JLS` | Jules Luxury Styles |
| Jules Luxury Worldwide | `JLW` | Jules Luxury Worldwide |
| Other / External | `EXT` | External Customer |

---

## 6. Auth System

| Feature | Implementation |
|---------|----------------|
| Sign In | Email/password + Google OAuth |
| Roles | Admins, dispatchers, riders (staff accounts), customers (self-signup) |
| Signup | Customer self-registration (not yet live — `/auth/signup` returns 404) |

---

## 7. Open Questions for Stakeholder

1. **Same Supabase project for marketing + ops, or separate?**
2. **Should `/request-delivery` stay public-no-login in V1?** (currently no auth required)
3. **International form** — deliveries row with `awaiting_quote`, or only `international_shipping_requests`?
4. **Cars inventory** — public catalogue in V1, or admin-only?
5. **Which notification channels must be live day one?** (email only, or WhatsApp/Termii too?)
6. **Preferred Lagos zone model** — polygons, named areas, or postcodes?

---

## 8. Database Schema Updates Required

Based on the site scrape, the following updates were made:

### New Migration: 00008_update_for_website_alignment.sql

| Change | Reason |
|--------|--------|
| Added `awaiting_quote` to `delivery_status` enum | `/request-delivery` creates deliveries with this status |
| Added `submitted` to `intl_request_status` enum | `/international` form uses this status |
| Updated `is_valid_transition()` | Added `awaiting_quote` → `created` transition |
| Updated `create_delivery()` | Sets initial status to `awaiting_quote` |
| Created `support_enquiries` table | `/support` form needs backend storage |
| Added RLS for `support_enquiries` | Public insert, admin read |

---

## 9. What's Missing (Backend Gaps)

| Gap | Priority | Notes |
|-----|----------|-------|
| Customer dashboard | P0 | `/customer` is 404 |
| Admin dashboard | P0 | `/admin` is 404 |
| Rider dashboard | P0 | `/rider` returns marketing shell |
| Customer signup | P1 | `/auth/signup` is 404 |
| Delivery detail views | P1 | No page shows delivery details |
| Real-time tracking map | P1 | `/track` exists but no map |
| Form-to-backend connection | P0 | Forms exist but aren't connected to Supabase |

---

## 10. Non-Negotiables (From Handoff Brief)

1. **RLS on every table** — no exceptions
2. **Status history** — every transition logged immutably
3. **Simple rider app** — mobile-friendly, touch-optimized
4. **No Supabase dashboard for ops staff** — all operations through the app

---

## 11. Acceptance Tests (From Handoff Brief)

1. Rider A cannot access Rider B's deliveries
2. Rider cannot modify price
3. Customer cannot see other customers' deliveries
4. Public tracking exposes zero sensitive fields
5. Invalid status transition is rejected server-side
