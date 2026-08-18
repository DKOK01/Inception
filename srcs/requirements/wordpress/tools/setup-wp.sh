#!/bin/bash
set -e

# 1. Read passwords from our separate Docker Secrets files
DB_PWD=$(cat /run/secrets/db_password)
WP_ADMIN_PWD=$(cat /run/secrets/wp_admin_password)
WP_USER_PWD=$(cat /run/secrets/wp_user_password)

# 2. The Waiting Loop: Ping MariaDB across the Docker network
echo "Waiting for MariaDB..."
while ! mariadb -h mariadb -u "${MYSQL_USER}" -p"${DB_PWD}" "${MYSQL_DATABASE}" -e "SELECT 1;" &>/dev/null; do
    sleep 2
done
echo "MariaDB is awake and ready!"

# 3. Go to the web folder
mkdir -p /var/www/wordpress
cd /var/www/wordpress

# 4. Installation check
# If wp-config.php doesn't exist, it means the volume is empty and we need to install WP
if [ ! -f "wp-config.php" ]; then
    echo "Downloading WordPress core files..."
    wp core download --allow-root

    echo "Generating wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PWD}" \
        --dbhost="mariadb:3306" \
        --allow-root

    echo "Installing WordPress..."
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PWD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root

    echo "Creating the second user..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PWD}" \
        --allow-root

    # Give the web server permission to read these files
    chown -R www-data:www-data /var/www/wordpress

    echo "Configuring Redis Cache..."
    wp config set WP_REDIS_HOST 'redis' --allow-root
    wp config set WP_REDIS_PORT 6379 --raw --allow-root
    wp config set WP_CACHE true --raw --allow-root
    wp plugin install redis-cache --activate --allow-root
    wp redis enable --allow-root

    echo "WordPress initialization complete!"
fi

# 5. Create the required directory for PHP-FPM's background processes
mkdir -p /run/php

# 6. The Grand Finale: Launch the PHP engine in the foreground as PID 1
echo "Starting PHP-FPM..."
exec php-fpm8.2 -F
