#!/bin/bash
set -e

# Read passwords from Docker Secrets
DB_PWD=$(cat /run/secrets/db_password)
DB_ROOT_PWD=$(cat /run/secrets/db_root_password)

# Check if the database is already initialized
# (If /var/lib/mysql/mysql exists, it means we already set it up previously)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB for the first time..."
    
    # 1. Initialize the empty data directory
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # 2. Start MariaDB temporarily in the background
    mysqld --user=mysql --datadir=/var/lib/mysql &
    pid="$!"
    
    # 3. Wait until it is fully started
    echo "Waiting for MariaDB to start..."
    while ! mysqladmin ping --silent; do
        sleep 1
    done

    # 4. Run the SQL commands to create the database and users
    echo "Setting up database and users..."
    mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PWD}';
FLUSH PRIVILEGES;
EOF

    # 5. Shut down the temporary background database securely
    mysqladmin -u root -p"${DB_ROOT_PWD}" shutdown
    
    # Wait for the background process to completely finish closing
    wait "$pid"
    echo "MariaDB initialization complete."
fi

# 6. Launch the final MariaDB process in the foreground!
echo "Starting MariaDB..."
exec mysqld --user=mysql
