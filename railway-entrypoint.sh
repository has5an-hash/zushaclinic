#!/usr/bin/env bash
set -euo pipefail

ROOT=/var/www/html
SRC=/usr/src/wordpress
mkdir -p "$ROOT"

# Seed WordPress into a fresh Railway volume. Custom Zosha code is refreshed
# on every deployment so production always follows the GitHub repository.
if [ ! -f "$ROOT/index.php" ]; then
  cp -a "$SRC/." "$ROOT/"
fi
mkdir -p "$ROOT/wp-content/themes" "$ROOT/wp-content/plugins"
rm -rf "$ROOT/wp-content/themes/zosha-luxe" "$ROOT/wp-content/plugins/zosha-suite"
cp -a "$SRC/wp-content/themes/zosha-luxe" "$ROOT/wp-content/themes/"
cp -a "$SRC/wp-content/plugins/zosha-suite" "$ROOT/wp-content/plugins/"

if [ ! -f "$ROOT/wp-config.php" ]; then
  cp "$ROOT/wp-config-docker.php" "$ROOT/wp-config.php"
fi

cd "$ROOT"

# Wait for the private MariaDB service.
db_ready=0
for _ in $(seq 1 90); do
  if wp db check --allow-root --path="$ROOT" >/dev/null 2>&1; then
    db_ready=1
    break
  fi
  sleep 2
done
if [ "$db_ready" -ne 1 ]; then
  echo 'ZOSHA_BOOTSTRAP: database unavailable' >&2
  exit 1
fi

SITE_URL="${WP_SITE_URL:-}"
if [ -z "$SITE_URL" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  SITE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
if [ -z "$SITE_URL" ]; then
  SITE_URL="http://localhost:${PORT:-8080}"
fi

if ! wp core is-installed --allow-root --path="$ROOT" >/dev/null 2>&1; then
  wp core install --allow-root --path="$ROOT" \
    --url="$SITE_URL" \
    --title="کلینیک زیبایی زوشا" \
    --admin_user="${WP_ADMIN_USER:-zoshaadmin}" \
    --admin_password="${WP_ADMIN_PASSWORD:-ChangeMeNow-$(date +%s)}" \
    --admin_email="${WP_ADMIN_EMAIL:-admin@example.com}" \
    --skip-email
fi

# Keep the persisted core on the latest security patch in the 6.8 line.
CURRENT_WP="$(wp core version --allow-root --path="$ROOT" 2>/dev/null || true)"
if [ "$CURRENT_WP" != "6.8.8" ]; then
  wp core update --version=6.8.8 --force --allow-root --path="$ROOT"
  wp core update-db --allow-root --path="$ROOT"
fi

wp option update home "$SITE_URL" --allow-root --path="$ROOT" >/dev/null
wp option update siteurl "$SITE_URL" --allow-root --path="$ROOT" >/dev/null
wp option update blogname "کلینیک زیبایی زوشا" --allow-root --path="$ROOT" >/dev/null
wp option update blogdescription "زیبایی، پوست و مراقبت حرفه‌ای در زوشا" --allow-root --path="$ROOT" >/dev/null
wp rewrite structure '/%postname%/' --allow-root --path="$ROOT" >/dev/null || true

wp theme activate zosha-luxe --allow-root --path="$ROOT" >/dev/null 2>&1 || true
wp plugin activate zosha-suite --allow-root --path="$ROOT" >/dev/null 2>&1 || true

# WooCommerce 10.8+ requires WordPress 6.9+. 10.7.0 is pinned for WP 6.8.x.
wp plugin install woocommerce --version=10.7.0 --force --activate --allow-root --path="$ROOT" >/dev/null
wp wc tool run update_db --user="${WP_ADMIN_USER:-zoshaadmin}" --allow-root --path="$ROOT" >/dev/null 2>&1 || true

create_page() {
  local title="$1" slug="$2" template="${3:-default}" id
  id="$(wp post list --post_type=page --name="$slug" --field=ID --allow-root --path="$ROOT" | head -n1)"
  if [ -z "$id" ]; then
    id="$(wp post create --post_type=page --post_status=publish --post_title="$title" --post_name="$slug" --porcelain --allow-root --path="$ROOT")"
  fi
  if [ "$template" != "default" ] && [ -f "$ROOT/wp-content/themes/zosha-luxe/$template" ]; then
    wp post meta update "$id" _wp_page_template "$template" --allow-root --path="$ROOT" >/dev/null
  fi
}

create_page "درباره ما" "about" "page-about.php"
create_page "تماس با ما" "contact" "page-contact.php"
create_page "خدمات" "services"
create_page "نمونه کارها" "portfolio"
create_page "دانستنی‌های زوشا" "blog"
create_page "رزرو آنلاین" "booking"
create_page "حساب من" "my-account"

# Ensure the custom shortcodes are present even if the pages existed beforehand.
BOOKING_ID="$(wp post list --post_type=page --name=booking --field=ID --allow-root --path="$ROOT" | head -n1)"
ACCOUNT_ID="$(wp post list --post_type=page --name=my-account --field=ID --allow-root --path="$ROOT" | head -n1)"
[ -n "$BOOKING_ID" ] && wp post update "$BOOKING_ID" --post_content='[zosha_booking]' --allow-root --path="$ROOT" >/dev/null
[ -n "$ACCOUNT_ID" ] && wp post update "$ACCOUNT_ID" --post_content='[zosha_dashboard]' --allow-root --path="$ROOT" >/dev/null

# Router for PHP's built-in server so pretty permalinks work without Apache/Nginx.
cat > "$ROOT/router.php" <<'PHP'
<?php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$file = __DIR__ . $path;
if ($path !== '/' && is_file($file)) {
    return false;
}
require __DIR__ . '/index.php';
PHP

THEME_STATE=inactive
PLUGIN_STATE=inactive
WOO_STATE=inactive
wp theme is-active zosha-luxe --allow-root --path="$ROOT" >/dev/null 2>&1 && THEME_STATE=active
wp plugin is-active zosha-suite --allow-root --path="$ROOT" >/dev/null 2>&1 && PLUGIN_STATE=active
wp plugin is-active woocommerce --allow-root --path="$ROOT" >/dev/null 2>&1 && WOO_STATE=active

echo "ZOSHA_BOOTSTRAP: wordpress=$(wp core version --allow-root --path="$ROOT")"
echo "ZOSHA_BOOTSTRAP: theme=$THEME_STATE"
echo "ZOSHA_BOOTSTRAP: plugin=$PLUGIN_STATE"
echo "ZOSHA_BOOTSTRAP: woocommerce=$WOO_STATE"
echo "ZOSHA_BOOTSTRAP: ready $SITE_URL"

PORT_NUM="${PORT:-8080}"
PUBLIC_HOST="${RAILWAY_PUBLIC_DOMAIN:-wordpress-production-9ffa.up.railway.app}"
(
  sleep 3
  for PAGE in / /about/ /contact/ /services/ /portfolio/ /blog/ /booking/ /my-account/; do
    CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
      -H "Host: $PUBLIC_HOST" -H 'X-Forwarded-Proto: https' \
      "http://127.0.0.1:${PORT_NUM}${PAGE}" || true)"
    echo "ZOSHA_QA: ${PAGE}=${CODE}"
  done
) &

exec php -S "0.0.0.0:${PORT_NUM}" -t "$ROOT" "$ROOT/router.php"
