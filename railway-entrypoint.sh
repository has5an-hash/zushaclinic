#!/usr/bin/env bash
set -euo pipefail

docker-entrypoint.sh "$@" &
apache_pid=$!

cd /var/www/html

for i in $(seq 1 90); do
  if [ -f wp-config.php ]; then break; fi
  sleep 2
done

for i in $(seq 1 90); do
  if wp db check --allow-root >/dev/null 2>&1; then break; fi
  sleep 2
done

SITE_URL="${WP_SITE_URL:-}"
if [ -z "$SITE_URL" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  SITE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
if [ -z "$SITE_URL" ]; then SITE_URL="http://localhost:${PORT:-80}"; fi

if ! wp core is-installed --allow-root >/dev/null 2>&1; then
  wp core install --allow-root \
    --url="$SITE_URL" \
    --title="کلینیک زیبایی زوشا" \
    --admin_user="${WP_ADMIN_USER:-zoshaadmin}" \
    --admin_password="${WP_ADMIN_PASSWORD:-ChangeMeNow-$(date +%s)}" \
    --admin_email="${WP_ADMIN_EMAIL:-admin@example.com}" \
    --skip-email
fi

wp option update home "$SITE_URL" --allow-root >/dev/null
wp option update siteurl "$SITE_URL" --allow-root >/dev/null
wp option update blogdescription "زیبایی، پوست و مراقبت حرفه‌ای در زوشا" --allow-root >/dev/null
wp rewrite structure '/%postname%/' --hard --allow-root >/dev/null || true
wp theme activate zosha-luxe --allow-root >/dev/null || true
wp plugin activate zosha-suite --allow-root >/dev/null || true

if ! wp plugin is-installed woocommerce --allow-root >/dev/null 2>&1; then
  wp plugin install woocommerce --activate --allow-root >/dev/null 2>&1 || true
else
  wp plugin activate woocommerce --allow-root >/dev/null 2>&1 || true
fi

create_page() {
  local title="$1" slug="$2" template="${3:-default}"
  if ! wp post list --post_type=page --name="$slug" --field=ID --allow-root | grep -q '[0-9]'; then
    id=$(wp post create --post_type=page --post_status=publish --post_title="$title" --post_name="$slug" --porcelain --allow-root)
    if [ "$template" != "default" ]; then wp post meta update "$id" _wp_page_template "$template" --allow-root >/dev/null; fi
  fi
}
create_page "درباره ما" "about" "page-about.php"
create_page "تماس با ما" "contact" "page-contact.php"
create_page "خدمات" "services"
create_page "نمونه کارها" "portfolio"
create_page "دانستنی‌های زوشا" "blog"

wait "$apache_pid"
