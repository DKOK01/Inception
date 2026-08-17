FROM debian:bookworm

# Install PHP and dependencies, and download WP-CLI in a single layer
RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    php-curl \
    php-gd \
    php-xml \
    php-mbstring \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copy our configuration and setup script
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/setup-wp.sh /usr/local/bin/setup-wp.sh

# Expose the PHP-FPM network port
EXPOSE 9000

# Set the script as PID 1
ENTRYPOINT ["/usr/local/bin/setup-wp.sh"]
