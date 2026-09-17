FROM wordpress:6.8.2-php8.3-apache

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates mariadb-client unzip \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp

COPY packages/zosha-luxe-theme.zip /tmp/zosha-luxe-theme.zip
COPY packages/zosha-suite-plugin.zip /tmp/zosha-suite-plugin.zip
RUN unzip -q /tmp/zosha-luxe-theme.zip -d /usr/src/wordpress/wp-content/themes/ \
 && unzip -q /tmp/zosha-suite-plugin.zip -d /usr/src/wordpress/wp-content/plugins/ \
 && rm -f /tmp/zosha-luxe-theme.zip /tmp/zosha-suite-plugin.zip

COPY railway-entrypoint.sh /usr/local/bin/zosha-railway-entrypoint
RUN chmod +x /usr/local/bin/zosha-railway-entrypoint

ENV WP_CLI_ALLOW_ROOT=1
ENTRYPOINT ["zosha-railway-entrypoint"]
CMD ["apache2-foreground"]
