# Jules Luxury Cars & Logistics — Backend

Supabase backend for Jules Luxury Cars & Logistics Version 1.

**Target:** Lagos 24/7 dispatch-bike logistics
**Stack:** Supabase (PostgreSQL, Auth, RLS, Realtime, Storage, Edge Functions)

---

## Quick Start

### Prerequisites

- Node.js 18+
- npm or npx
- Supabase CLI (installed via npx)

### Local Development

```bash
# Install dependencies (if needed)
npm install

# Start local Supabase
npx supabase start

# This will start:
# - PostgreSQL on port 54322
# - API on port 54321
# - Studio on port 54323
```

### Link to Remote Project

```bash
# Login to Supabase
npx supabase login

# Link to your project
npx supabase link --project-ref <your-project-id>

# Push database migrations
npx supabase db push

# Deploy Edge Functions
npx supabase functions deploy public-tracking
```

---

## Project Structure

```
├── AUDIT_CHECKLIST.md          # Audit preparation document
├── AUDIT_REPORT.md             # Audit report template
├── BUILD_PLAN.md               # Implementation plan
├── BACKEND_ARCHITECTURE.md     # Architecture documentation
├── README.md                   # This file
└── supabase/
    ├── config.toml             # Supabase configuration
    ├── migrations/             # Database migrations
    │   ├── 00001_*.sql         # Extensions & enums
    │   ├── 00002_*.sql         # Core tables
    │   ├── 00003_*.sql         # Deliveries & related
    │   ├── 00004_*.sql         # Database functions
    │   ├── 00005_*.sql         # RLS policies
    │   ├── 00006_*.sql         # Storage & realtime
    │   └── 00007_*.sql         # Triggers & timestamps
    ├── functions/              # Edge Functions
    │   └── public-tracking/    # Public tracking endpoint
    └── seed/
        └── seed_data.sql       # Ecosystem companies & pricing
```

---

## Database Tables

### Core
- `profiles` — User profiles (linked to Supabase Auth)
- `riders` — Rider profiles with availability
- `vehicles` — Fleet vehicles
- `ecosystem_companies` — Jules Luxury Worldwide companies

### Deliveries
- `deliveries` — Core delivery records
- `delivery_status_history` — Immutable status change log
- `pricing_rules` — Configurable pricing
- `delivery_zones` — Geographic zones (PostGIS)
- `proof_of_delivery` — Delivery confirmation
- `rider_locations` — GPS tracking

### Support
- `notifications` — Multi-channel notifications
- `audit_logs` — Security audit trail
- `international_shipping_requests` — International quotes
- `cars` — Car inventory
- `car_images` — Car listing images
- `car_inquiries` — Customer inquiries

---

## Key Functions

| Function | Description |
|----------|-------------|
| `create_delivery()` | Create new delivery with auto-generated tracking number |
| `transition_delivery_status()` | Enforce state machine for status changes |
| `assign_rider()` / `reassign_rider()` | Rider assignment with validation |
| `calculate_suggested_price()` | Calculate price based on rules |
| `generate_delivery_pin()` / `verify_delivery_pin()` | Secure PIN management |
| `complete_delivery()` | Complete delivery with proof |
| `get_public_tracking()` | Sanitized public tracking |

---

## Security

- **RLS enabled** on all private tables
- **Server-enforced** state machine (no client bypass)
- **No client-trusted roles** (roles validated server-side)
- **PIN hashed** (never stored plaintext)
- **Public tracking** returns only sanitized data
- **Audit logs** for sensitive operations

---

## Deployment Status

| Component | Status |
|-----------|--------|
| Database migrations | ✅ Deployed (8 migrations, 17 tables) |
| RLS policies | ✅ Deployed |
| Database functions | ✅ Deployed (7 functions) |
| Edge Functions | ✅ Deployed (public-tracking) |
| Storage buckets | ✅ Configured (proof-of-delivery, car-images) |
| Realtime | ✅ Configured (deliveries, notifications, rider_locations) |
| Seed data | ✅ Applied (7 ecosystem companies, 7 pricing rules) |
| Supabase project | ✅ **uhbmmwqyjjxemcrgudvv** (East US) |

**Project Dashboard:** https://supabase.com/dashboard/project/uhbmmwqyjjxemcrgudvv

---

## Next Steps

1. Create admin user in Supabase Dashboard
2. Connect Lovable frontend to Supabase
3. Test full delivery workflow
4. Configure notification providers (email/SMS)

---

## Documentation

- [Backend Architecture](BACKEND_ARCHITECTURE.md)
- [Audit Checklist](AUDIT_CHECKLIST.md)
- [Build Plan](BUILD_PLAN.md)
