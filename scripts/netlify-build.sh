#!/usr/bin/env bash
# Netlify build: install Flutter, build the web app, add SPA redirects.
set -euo pipefail

git clone https://github.com/flutter/flutter.git --depth 1 -b stable
export PATH="$PATH:$PWD/flutter/bin"
flutter config --no-analytics >/dev/null 2>&1 || true

# pubspec.yaml declares .env as an asset but it is gitignored, so the build
# fails with "No file or variants found" unless we create one. The real
# credentials are compiled in below via --dart-define from Netlify's env vars.
touch .env

flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"

# Flutter web is a single page app: any unknown path must serve index.html.
printf '/*    /index.html   200\n' > build/web/_redirects
