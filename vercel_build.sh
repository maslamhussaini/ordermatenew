#!/bin/bash
echo "🚀 Starting Flutter Build on Vercel..."

# 1. Install Flutter (Shallow clone for speed)
if [ ! -d "flutter" ]; then
  git clone --depth 1 https://github.com/flutter/flutter.git -b stable
fi
export PATH="$PATH:`pwd`/flutter/bin"

echo "✅ Flutter PATH updated"
flutter doctor -v

# 2. Re-create .env file safely
echo "📝 Creating .env file..."

# Remove spaces from the Gmail App Password if they exist
CLEAN_GMAIL_PASS=$(echo "$GMAIL_APP_PASSWORD" | tr -d ' ')

cat <<EOT > .env
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
GMAIL_USERNAME=$GMAIL_USERNAME
GMAIL_APP_PASSWORD=$CLEAN_GMAIL_PASS
FRONTEND_URL=$FRONTEND_URL
EOT

# Explicitly ensure the .env is in the right place
mkdir -p web/assets
cp .env web/assets/.env

echo "✅ Environment and SQLite assets prepared"

# 3. Build the Web App
echo "🔨 Building web app..."
rm -rf build/web  # Clean start
flutter config --enable-web
flutter pub get
flutter build web --release --no-tree-shake-icons --base-href /


# Final forced copy of assets to the build output
mkdir -p build/web/assets
cp .env build/web/assets/.env
# Copy SQLite worker files to the root of the build output for production
cp web/sqlite3.wasm web/sqflite_sw.js build/web/ 2>/dev/null || true

echo "✅ Final verification: Assets and SQLite workers in build/web/"

echo "📂 Verifying build output..."
ls -R build/web

echo "🎉 Build complete!"
