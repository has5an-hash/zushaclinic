#!/usr/bin/env bash
set -u
/usr/local/bin/zosha-railway-entrypoint &
child=$!
sleep 28
ROOT=/var/www/html
HOST="${RAILWAY_PUBLIC_DOMAIN:-wordpress-production-9ffa.up.railway.app}"
PORT_NUM="${PORT:-8080}"
FRONT="$ROOT/wp-content/themes/zosha-luxe/front-page.php"
CSS="$ROOT/wp-content/themes/zosha-luxe/assets/css/main.css"
echo "ZOSHA_DEBUG: front_exists=$([ -f "$FRONT" ] && echo yes || echo no)"
echo "ZOSHA_DEBUG: front_hero=$(grep -c 'hero-v2' "$FRONT" 2>/dev/null || true)"
echo "ZOSHA_DEBUG: css_hero=$(grep -c 'hero-v2' "$CSS" 2>/dev/null || true)"
echo "ZOSHA_DEBUG: css_font=$(grep -c 'Vazirmatn Z' "$CSS" 2>/dev/null || true)"
HOME_HTML="$(curl -sS -L --max-redirs 3 -H "Host: $HOST" -H 'X-Forwarded-Proto: https' "http://127.0.0.1:${PORT_NUM}/" 2>/dev/null || true)"
echo "ZOSHA_DEBUG: home_len=${#HOME_HTML}"
echo "ZOSHA_DEBUG: home_hero=$(printf '%s' "$HOME_HTML" | grep -c 'hero-v2' || true)"
echo "ZOSHA_DEBUG: home_marker=$(printf '%s' "$HOME_HTML" | grep -c 'ZOSHA-LUXE-V2' || true)"
echo "ZOSHA_DEBUG: home_uploads=$(printf '%s' "$HOME_HTML" | grep -c '/wp-content/uploads/' || true)"
printf '%s' "$HOME_HTML" | head -c 500 | tr '\n\r' '  ' | sed 's/[[:space:]]\+/ /g' | sed 's/^/ZOSHA_DEBUG_HTML: /'
echo
wait "$child"
