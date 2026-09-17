FROM wordpress:6.8.2-php8.3-fpm

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates unzip default-mysql-client \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp

COPY packages/theme.part* /tmp/theme-parts/
COPY packages/plugin.part* /tmp/plugin-parts/
RUN cat /tmp/theme-parts/theme.part* > /tmp/zosha-luxe-theme.zip \
 && cat /tmp/plugin-parts/plugin.part* > /tmp/zosha-suite-plugin.zip \
 && unzip -q /tmp/zosha-luxe-theme.zip -d /usr/src/wordpress/wp-content/themes/ \
 && unzip -q /tmp/zosha-suite-plugin.zip -d /usr/src/wordpress/wp-content/plugins/ \
 && rm -rf /tmp/theme-parts /tmp/plugin-parts /tmp/zosha-luxe-theme.zip /tmp/zosha-suite-plugin.zip

COPY build/patch-zosha.php /tmp/patch-zosha.php
RUN php /tmp/patch-zosha.php \
 && php -l /usr/src/wordpress/wp-content/plugins/zosha-suite/zosha-suite.php \
 && rm -f /tmp/patch-zosha.php

COPY railway-entrypoint.sh /usr/local/bin/zosha-railway-entrypoint
RUN chmod +x /usr/local/bin/zosha-railway-entrypoint

ENV WP_CLI_ALLOW_ROOT=1
ENTRYPOINT ["zosha-railway-entrypoint"]
