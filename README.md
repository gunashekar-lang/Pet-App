# PetHub

A Flutter marketplace for buying and selling pets and pet products, built for
India.

## What it does

- **Buy** — one merged browse experience with search, category tabs, filters,
  sorting and a results grid, plus pet detail pages, favourites and contact-the-seller.
- **Sell** — list a pet (photos, price, vaccination history, health issues) or
  list a product on your own shop, which carries a verified badge.
- **Shop** — pet store catalogue, cart, checkout and order history, with free
  delivery over ₹499.
- **Messages** — real buyer/seller conversations per listing, with unread
  badges, typing state and read receipts.
- **Healthcare** — care tips and written guides (guidance only, no clinics or
  bookings).
- **Profile** — listings, favourites, orders, cart, shop, messages, dark mode,
  help centre and privacy policy.

## Tech

- Flutter 3.44.9 / Dart 3.12.2
- `provider` for state, `intl` for Indian-format currency
- `image_picker` for listing photos

## Structure

```
lib/
  app/          routes, theme, app shell
  data/         category taxonomy
  models/       pet, product, order, chat, user
  services/     auth, pet, store, messaging, notifications, healthcare
  screens/      one folder per feature
  widgets/      shared UI
  utils/        constants, helpers, validators
test/
  widget_test.dart
```

## Running

```bash
flutter pub get
flutter run
```

## Verifying

```bash
dart format lib test
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
```

## Current state

The app is local-first and backend-ready. Data is held in in-memory services
and starts empty — no seeded demo content. Authentication, real-time message
delivery, push notifications and shop verification review are local stand-ins
until the API is connected, and the UI reflects the current state rather than
assuming success.
