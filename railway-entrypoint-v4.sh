#!/usr/bin/env bash
set -euo pipefail
ROOT=/var/www/html
SRC=/usr/src/wordpress
mkdir -p "$ROOT"
if [ ! -f "$ROOT/index.php" ]; then cp -a "$SRC/." "$ROOT/"; fi
mkdir -p "$ROOT/wp-content/themes" "$ROOT/wp-content/plugins"
rm -rf "$ROOT/wp-content/themes/zosha-luxe" "$ROOT/wp-content/plugins/zosha-suite"
cp -a "$SRC/wp-content/themes/zosha-luxe" "$ROOT/wp-content/themes/"
cp -a "$SRC/wp-content/plugins/zosha-suite" "$ROOT/wp-content/plugins/"
if [ ! -f "$ROOT/wp-config.php" ]; then cp "$ROOT/wp-config-docker.php" "$ROOT/wp-config.php"; fi
cd "$ROOT"
for _ in $(seq 1 90); do wp db check --allow-root --path="$ROOT" >/dev/null 2>&1 && break; sleep 2; done
wp db check --allow-root --path="$ROOT" >/dev/null 2>&1 || { echo 'ZOSHA_BOOTSTRAP: database unavailable' >&2; exit 1; }
SITE_URL="${WP_SITE_URL:-}"
if [ -z "$SITE_URL" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then SITE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"; fi
[ -n "$SITE_URL" ] || SITE_URL="http://localhost:${PORT:-8080}"
if ! wp core is-installed --allow-root --path="$ROOT" >/dev/null 2>&1; then
  wp core install --allow-root --path="$ROOT" --url="$SITE_URL" --title="کلینیک زیبایی و پوست زوشا" \
    --admin_user="${WP_ADMIN_USER:-zoshaadmin}" --admin_password="${WP_ADMIN_PASSWORD:-ChangeMeNow-$(date +%s)}" \
    --admin_email="${WP_ADMIN_EMAIL:-admin@example.com}" --skip-email
fi
CURRENT_WP="$(wp core version --allow-root --path="$ROOT" 2>/dev/null || true)"
if [ "$CURRENT_WP" != "6.8.8" ]; then wp core update --version=6.8.8 --force --allow-root --path="$ROOT"; wp core update-db --allow-root --path="$ROOT"; fi
wp option update home "$SITE_URL" --allow-root --path="$ROOT" >/dev/null
wp option update siteurl "$SITE_URL" --allow-root --path="$ROOT" >/dev/null
wp option update blogname "کلینیک زیبایی و پوست زوشا" --allow-root --path="$ROOT" >/dev/null
wp option update blogdescription "زیبایی، پوست و جوانسازی در زوشا" --allow-root --path="$ROOT" >/dev/null
wp theme activate zosha-luxe --allow-root --path="$ROOT" >/dev/null 2>&1 || true
wp plugin activate zosha-suite --allow-root --path="$ROOT" >/dev/null 2>&1 || true
wp plugin install woocommerce --version=10.7.0 --force --activate --allow-root --path="$ROOT" >/dev/null
wp rewrite structure '/%postname%/' --allow-root --path="$ROOT" >/dev/null || true
wp rewrite flush --allow-root --path="$ROOT" >/dev/null || true
create_page(){ local title="$1" slug="$2" template="${3:-default}" id; id="$(wp post list --post_type=page --name="$slug" --field=ID --allow-root --path="$ROOT" | head -n1)"; [ -n "$id" ] || id="$(wp post create --post_type=page --post_status=publish --post_title="$title" --post_name="$slug" --porcelain --allow-root --path="$ROOT")"; if [ "$template" != default ] && [ -f "$ROOT/wp-content/themes/zosha-luxe/$template" ]; then wp post meta update "$id" _wp_page_template "$template" --allow-root --path="$ROOT" >/dev/null; fi; }
create_page "خانه" home
create_page "درباره ما" about page-about.php
create_page "تماس با ما" contact page-contact.php
create_page "رزرو آنلاین" booking
create_page "حساب من" my-account
HOME_ID="$(wp post list --post_type=page --name=home --field=ID --allow-root --path="$ROOT" | head -n1)"
if [ -n "$HOME_ID" ]; then wp option update show_on_front page --allow-root --path="$ROOT" >/dev/null; wp option update page_on_front "$HOME_ID" --allow-root --path="$ROOT" >/dev/null; fi
BOOKING_ID="$(wp post list --post_type=page --name=booking --field=ID --allow-root --path="$ROOT" | head -n1)"
ACCOUNT_ID="$(wp post list --post_type=page --name=my-account --field=ID --allow-root --path="$ROOT" | head -n1)"
[ -n "$BOOKING_ID" ] && wp post update "$BOOKING_ID" --post_content='[zosha_booking]' --allow-root --path="$ROOT" >/dev/null
[ -n "$ACCOUNT_ID" ] && wp post update "$ACCOUNT_ID" --post_content='[zosha_dashboard]' --allow-root --path="$ROOT" >/dev/null
import_public_asset(){ local key="$1" url="$2" filename="$3" title="$4" current tmp id; current="$(wp option get "zosha_media_${key}" --allow-root --path="$ROOT" 2>/dev/null || true)"; if [ -n "$current" ] && wp post get "$current" --field=ID --allow-root --path="$ROOT" >/dev/null 2>&1; then echo "ZOSHA_MEDIA: ${key}=cached"; return 0; fi; tmp="/tmp/${filename}"; if curl -fL --retry 2 --connect-timeout 15 -A 'Mozilla/5.0' "$url" -o "$tmp" >/dev/null 2>&1; then id="$(wp media import "$tmp" --title="$title" --porcelain --allow-root --path="$ROOT" 2>/dev/null || true)"; if [ -n "$id" ]; then wp option update "zosha_media_${key}" "$id" --allow-root --path="$ROOT" >/dev/null; wp post meta update "$id" _wp_attachment_image_alt "$title" --allow-root --path="$ROOT" >/dev/null 2>&1 || true; echo "ZOSHA_MEDIA: ${key}=imported"; rm -f "$tmp"; return 0; fi; fi; rm -f "$tmp"; echo "ZOSHA_MEDIA: ${key}=missing"; }
import_public_asset instagram_profile 'https://salademod.ir/wp-content/uploads/2025/09/zosha.clinic.png' zosha-instagram-profile.png 'صفحه عمومی اینستاگرام زوشا'
import_public_asset instagram_grid 'https://salademod.ir/wp-content/uploads/2025/09/zosha.clinic1.png' zosha-instagram-grid.png 'منتخب محتوای عمومی زوشا'
import_public_asset interior 'https://tarhoteb.ir/wp-content/uploads/2025/10/%D8%A8%D8%A7%D8%B2%D8%B3%D8%A7%D8%B2%DB%8C-%DA%A9%D9%84%DB%8C%D9%86%DB%8C%DA%A9-%D9%BE%D9%88%D8%B3%D8%AA-%D9%88-%D8%B2%DB%8C%D8%A8%D8%A7%DB%8C%DB%8C-%D8%B2%D9%88%D8%B4%D8%A7-%D9%85%D8%AC%D8%AA%D9%85%D8%B9-%D8%AA%D8%AC%D8%A7%D8%B1%DB%8C-%D8%AA%D9%86%D8%AF%DB%8C%D8%B3.jpg' zosha-clinic-interior.jpg 'فضای کلینیک زوشا در تندیس'
import_public_asset stock_facial 'https://images.pexels.com/photos/7789655/pexels-photo-7789655.jpeg?auto=compress&dpr=1&h=1400&w=1800' zosha-facial.jpg 'درمان تخصصی پوست'
import_public_asset stock_laser 'https://images.pexels.com/photos/4586744/pexels-photo-4586744.jpeg?auto=compress&dpr=1&h=1400&w=1800' zosha-laser.jpg 'لیزر و جوانسازی'
import_public_asset stock_spa 'https://images.pexels.com/photos/3985332/pexels-photo-3985332.jpeg?auto=compress&dpr=1&h=1400&w=1800' zosha-skincare.jpg 'مراقبت تخصصی پوست'
import_public_asset stock_facial2 'https://images.pexels.com/photos/4586745/pexels-photo-4586745.jpeg?auto=compress&dpr=1&h=1500&w=1900' zosha-facial-2.jpg 'درمان زیبایی پوست'
import_public_asset stock_laser2 'https://images.pexels.com/photos/4586755/pexels-photo-4586755.jpeg?auto=compress&dpr=1&h=1400&w=1800' zosha-laser-2.jpg 'لیزر تخصصی پوست'
import_public_asset stock_skincare2 'https://images.pexels.com/photos/5069603/pexels-photo-5069603.jpeg?auto=compress&dpr=1&h=1400&w=1800' zosha-skincare-2.jpg 'مراقبت و فیشال پوست'
import_public_asset stock_detail 'https://images.pexels.com/photos/7789649/pexels-photo-7789649.jpeg?auto=compress&dpr=1&h=1400&w=1800' zosha-detail.jpg 'جزئیات درمان پوستی'
cat > "$ROOT/router.php" <<'PHP'
<?php
$path=parse_url($_SERVER['REQUEST_URI'],PHP_URL_PATH)?:'/';
$file=__DIR__.$path;
if($path!=='/' && is_file($file)) return false;
require __DIR__.'/index.php';
PHP
echo "ZOSHA_BOOTSTRAP: wordpress=$(wp core version --allow-root --path="$ROOT")"
echo "ZOSHA_BOOTSTRAP: theme=$(wp theme is-active zosha-luxe --allow-root --path="$ROOT" >/dev/null 2>&1 && echo active || echo inactive)"
echo "ZOSHA_BOOTSTRAP: plugin=$(wp plugin is-active zosha-suite --allow-root --path="$ROOT" >/dev/null 2>&1 && echo active || echo inactive)"
echo "ZOSHA_BOOTSTRAP: woocommerce=$(wp plugin is-active woocommerce --allow-root --path="$ROOT" >/dev/null 2>&1 && echo active || echo inactive)"
echo "ZOSHA_BOOTSTRAP: design=4.0.0"
echo "ZOSHA_BOOTSTRAP: ready $SITE_URL"
PORT_NUM="${PORT:-8080}"
PUBLIC_HOST="${RAILWAY_PUBLIC_DOMAIN:-wordpress-v3-production.up.railway.app}"
(
 sleep 4
 for PAGE in / /about/ /contact/ /services/ /portfolio/ /booking/ /my-account/; do CODE="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: $PUBLIC_HOST" -H 'X-Forwarded-Proto: https' "http://127.0.0.1:${PORT_NUM}${PAGE}" || true)"; echo "ZOSHA_QA: ${PAGE}=${CODE}"; done
 HOME_HTML="$(curl -sS -H "Host: $PUBLIC_HOST" -H 'X-Forwarded-Proto: https' "http://127.0.0.1:${PORT_NUM}/" || true)"
 HERO_COUNT="$(printf '%s' "$HOME_HTML" | grep -o 'hero-v4' | wc -l | tr -d ' ')"
 IMG_COUNT="$(printf '%s' "$HOME_HTML" | grep -o '/wp-content/uploads/' | wc -l | tr -d ' ')"
 echo "ZOSHA_QA: hero-v4=${HERO_COUNT}"
 echo "ZOSHA_QA: local-images=${IMG_COUNT}"
) &
exec php -S "0.0.0:${PORT_NUM}" -t "$ROOT" "$ROOT/router.php"
