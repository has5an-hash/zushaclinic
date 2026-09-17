#!/usr/bin/env bash
set -euo pipefail

ROOT=/var/www/html
SRC=/usr/src/wordpress
mkdir -p "$ROOT"

# A Railway volume can start empty. Seed WordPress core once, then refresh our
# custom theme/plugin on every deploy so code follows the GitHub repository.
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

# Wait for MariaDB before bootstrapping WordPress.
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

wp option update home "$SITE_URL" --allow-root --path="$ROOT" >/dev/null
wp option update siteurl "$SITE_URL" --allow-root --path="$ROOT" >/dev/null
wp option update blogname "کلینیک زیبایی زوشا" --allow-root --path="$ROOT" >/dev/null
wp option update blogdescription "زیبایی، پوست و مراقبت حرفه‌ای در زوشا" --allow-root --path="$ROOT" >/dev/null
wp rewrite structure '/%postname%/' --hard --allow-root --path="$ROOT" >/dev/null || true

wp theme activate zosha-luxe --allow-root --path="$ROOT"
wp plugin activate zosha-suite --allow-root --path="$ROOT"

if ! wp plugin is-installed woocommerce --allow-root --path="$ROOT" >/dev/null 2>&1; then
  wp plugin install woocommerce --activate --allow-root --path="$ROOT" || true
else
  wp plugin activate woocommerce --allow-root --path="$ROOT" || true
fi

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

echo "ZOSHA_BOOTSTRAP: theme=$(wp theme status zosha-luxe --field=status --allow-root --path="$ROOT" 2>/dev/null || true)"
echo "ZOSHA_BOOTSTRAP: plugin=$(wp plugin status zosha-suite --field=status --allow-root --path="$ROOT" 2>/dev/null || true)"
echo "ZOSHA_BOOTSTRAP: woocommerce=$(wp plugin status woocommerce --field=status --allow-root --path="$ROOT" 2>/dev/null || true)"
echo "ZOSHA_BOOTSTRAP: ready $SITE_URL"

exec php -S "0.0.0.0:${PORT:-8080}" -t "$ROOT" "$ROOT/router.php"
