#!/bin/bash
set -e

# Read the password from the Docker secret
FTP_PWD=$(cat /run/secrets/ftp_password)

# Check if the user already exists to prevent errors on restart
if ! id "$FTP_USER" &>/dev/null; then
    echo "Creating FTP user..."
    
    # Create the user and explicitly set their home directory to the WordPress volume
    useradd -d /var/www/wordpress -s /bin/bash "$FTP_USER"
    
    # Set the password securely
    echo "$FTP_USER:$FTP_PWD" | chpasswd
    
    # Add the FTP user to the www-data group so they can edit WordPress files
    usermod -aG www-data "$FTP_USER"
fi

# Ensure permissions on the WordPress volume are correct for FTP and NGINX
mkdir -p /var/www/wordpress
chown -R www-data:www-data /var/www/wordpress
# Ensure the group has write permissions
chmod -R 775 /var/www/wordpress

echo "FTP server starting..."
# Run vsftpd in the foreground
exec /usr/sbin/vsftpd /etc/vsftpd.conf
