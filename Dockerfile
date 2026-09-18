FROM wordpress:6.8.2-php8.3-fpm

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates unzip default-mysql-client \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp

COPY packages/plugin.part* /tmp/plugin-parts/
RUN cat /tmp/plugin-parts/plugin.part* > /tmp/zosha-suite-plugin.zip \
 && unzip -q /tmp/zosha-suite-plugin.zip -d /usr/src/wordpress/wp-content/plugins/ \
 && rm -rf /tmp/plugin-parts /tmp/zosha-suite-plugin.zip

COPY theme-v4/theme.b64.part* /tmp/theme-v4/
RUN cat /tmp/theme-v4/theme.b64.part* | base64 -d > /tmp/zosha-luxe-v4.tar.gz \
 && rm -rf /usr/src/wordpress/wp-content/themes/zosha-luxe \
 && mkdir -p /usr/src/wordpress/wp-content/themes/zosha-luxe \
 && tar -xzf /tmp/zosha-luxe-v4.tar.gz -C /usr/src/wordpress/wp-content/themes/zosha-luxe --strip-components=1 \
 && rm -rf /tmp/theme-v4 /tmp/zosha-luxe-v4.tar.gz

RUN mkdir -p /usr/src/wordpress/wp-content/themes/zosha-luxe/assets/fonts \
 && curl -fsSL 'https://raw.githubusercontent.com/rastikerdar/vazirmatn/master/fonts/webfonts/Vazirmatn%5Bwght%5D.woff2' \
    -o /usr/src/wordpress/wp-content/themes/zosha-luxe/assets/fonts/Vazirmatn.woff2

COPY build/patch-zosha.php /tmp/patch-zosha.php
RUN php /tmp/patch-zosha.php \
 && php -l /usr/src/wordpress/wp-content/plugins/zosha-suite/zosha-suite.php \
 && php -l /usr/src/wordpress/wp-content/themes/zosha-luxe/functions.php \
 && php -l /usr/src/wordpress/wp-content/themes/zosha-luxe/front-page.php \
 && rm -f /tmp/patch-zosha.php

COPY railway-entrypoint-v4.sh /usr/local/bin/zosha-railway-entrypoint
RUN chmod +x /usr/local/bin/zosha-railway-entrypoint
ENV WP_CLI_ALLOW_ROOT=1
ENTRYPOINT ["zosha-railway-entrypoint"]
