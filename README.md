# PetHub

A Flutter pet marketplace: browse and sell pet listings, run a pet-supply store
with cart/checkout, message sellers, and read pet-care guides. Data lives in
Supabase (Postgres) with Row Level Security protecting every row.

## Tech stack

- **Flutter** (Dart SDK ^3.12) — `/lib`
- **Supabase** — Auth, PostgREST tables, Storage buckets
- Packages: `supabase_flutter`, `provider`, `image_picker`, `shared_preferences`,
  `flutter_dotenv`, `google_fonts`, `intl`

## Project layout

```
lib/
  app/          app bootstrap, routes, theme
  data/         static data + DB row mappers (pet_mapper, product_mapper)
  models/       PetModel, ProductModel, SellerModel, chat/health/order models
  screens/      auth, marketplace, sell_pet, store, cart, orders, chat, profile,
                healthcare, notifications, favorites, splash, onboarding
  services/     pet_service, store_service, auth_service, repositories,
                image_storage_service, supabase_config, messaging/healthcare/…
  utils/        validators, constants, formatting helpers
  widgets/      cards, headers, bottom navigation, shared widgets
supabase/       SQL scripts to build the backend (run in Supabase SQL Editor)
test/           74 tests (mappers, services, offline fallbacks, widget smoke)
```

## Prerequisites

- Flutter SDK installed (`flutter doctor` clean for your target device)
- A Supabase project (free tier is fine)

## Setup

### 1. Environment

```bash
cp .env.example .env
```

Fill in from **Supabase Dashboard → Project Settings → API**:

| Variable                    | Value |
| --------------------------- | ----- |
| `SUPABASE_URL`              | `https://<project-ref>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY`  | the **publishable** key (`sb_publishable_…` or anon `eyJ…`) |

`.env` is gitignored and bundled into the app at build time. **Never** put the
`service_role` / secret key there — it bypasses RLS and anyone who unpacks the
APK would own every row.

### 2. Backend

In **Supabase Dashboard → SQL Editor**, create a query and paste the single
authoritative script:

- `supabase/schema.sql` — profiles + signup trigger, pets, products,
  conversations/messages, RLS for everything, the storage buckets, and the
  Realtime publication, all in one idempotent file.

It is destructive of nothing, so re-running is safe. The verification queries
at the end (section 9) confirm success — the key one: `profiles` count equals
`auth.users` count (proves the signup trigger works).

The older split scripts (`run_this_first.sql`, `connect_supabase.sql`,
`messaging.sql`, `public_marketplace.sql`) are superseded by `schema.sql` and
are kept only for reference.

> Already configured? This project's database is live and migrated. You only
> need to paste the scripts when moving to a fresh Supabase project.

### 3. Run

```bash
flutter pub get
flutter run          # pick your device after it builds
```

## Data model

Ownership is `seller_id uuid` on both listing tables, referencing
`profiles(id)` and enforced by RLS. Carts, orders and local enquiries are
in-memory services; conversations and messages are persisted in Supabase and
synced over Realtime.

**profiles** — app-facing mirror of `auth.users`
`id` (pk), `full_name`, `phone`, `city`, `bio`, `avatar_url`,
`is_verified` (server-managed badge, never self-issuable), `created_at`, `updated_at`

**pets** — adoption/sale listings (matches `PetMapper`/`PetModel`)
`id`, `seller_id`, `name`, `species`, `breed`, `age_in_months`, `gender`,
`price`, `negotiable`, `image_urls` (text[]), `description`, `location`,
`vaccinated`, `dewormed`, `health_checked`, `microchipped`, `neutered`,
`vaccine_details`, `vaccinations` (jsonb), `health_issues`, `status`
(`available|reserved|sold|pending`), `condition`
(`newArrival|excellent|good|needsCare`), `is_featured`, `tags` (text[]),
`views`, `favorite_count`, `created_at`, `updated_at`

**products** — store listings (matches `ProductMapper`/`ProductModel`)
`id`, `seller_id`, `name`, `brand`, `category`, `price`, `old_price`,
`image_url`, `description`, `highlights` (text[]), `stock`, `sold_count`,
`is_featured`, `is_best_seller`, `free_shipping`, `species_tags` (text[]),
`rating`, `review_count`, `shop_name`, `shop_verified`, `created_at`,
`updated_at`
(legacy hand-built columns `store_id`, `category_id`, `selling_price`, `mrp`,
`free_delivery`, `status` are kept nullable/defaulted for compatibility.)

**Storage buckets** — public read, owner write under `<uid>/…`:
`avatars`, `pet-images`, `product-images`.

**conversations** — one per (pet, buyer), so every chat is about a listing
`id`, `pet_id`, `buyer_id`, `seller_id`, `created_at`, unique `(pet_id, buyer_id)`

**messages** — the chat log
`id`, `conversation_id`, `sender_id`, `body`, `created_at`
(inbox previews join the last message via `messages(order=created_at.desc,
limit=1)`; opening a thread swaps in the full history.)

## Row Level Security

The app ships the publishable key, so RLS is the entire security boundary:

- **select** — **anyone**, even a visitor who is not signed in (public
  marketplace, `using (true)` for both `anon` and `authenticated`). Pets and
  products are browsable by everyone; `profiles` rows stay visible only to
  signed-in users.
- **insert / update / delete** — only when `auth.uid() = seller_id`
  (`profiles`: `auth.uid() = id`, and `is_verified` cannot be changed by the
  owner)
- **messages** — a conversation exists only for the buyer and seller who own
  it (participant `using` on `conversations` and `messages`); you can only
  write as yourself. Realtime broadcasts inserts on `messages` and RLS filters
  who receives them.

Mapped in code: `supabase_config.dart`, `pet_repository.dart` (joins the seller
via `pets_seller_id_fkey`), `product_repository.dart`. The repositories read
with the session-optional `isReadable` gate and write with the session-required
`isAvailable` gate.

## Testing

```bash
flutter analyze --no-fatal-infos   # static analysis, zero issues expected
flutter test                       # 74 tests
```

Tests cover row mappers round-tripping every column, offline fallbacks (the app
keeps working with no backend and flags unsaved writes honestly), service
behavior, and validation rules.

## Troubleshooting

These five failures were all observed live and are fixed by the scripts above.
If any recur, the cause is almost always a hand-edited table drifting from the
app again:

| Symptom | Root cause | Fix location |
| ------- | ---------- | ------------ |
| Pet list fetch fails (HTTP 400) | `profiles.is_verified` missing from a hand-made `profiles` | `schema.sql` §1 |
| Insert rejected `row violates row-level security policy` (403) | hand-made RLS policies | `schema.sql` §1–§4 |
| Insert rejected `null value in column "store_id"/"age"` (400) | hand-made `NOT NULL` columns the app never sends | `schema.sql` §5 |
| Insert rejected `violates check constraint "pets_status_check"` | CHECK whitelist excluded app statuses | `schema.sql` §5 |
| App says "could not be saved to the server" after a fresh login | services still resolving user id as `'me'`; fixed in code | `pet_service.dart` `_resolveCurrentUser()` |

## Security notes

- Publishable key only in `.env`; `service_role` keys are for admin tooling and
  must never be shipped or committed.
- If a `service_role` key was ever added to `.env`, remove it and rebuild the
  APK before distributing it — the packed `.env` travels inside the bundle.
- RLS, not key secrecy, is what protects the data. Always re-check policies
  before turning anything permissive.