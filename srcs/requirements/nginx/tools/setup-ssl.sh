#!/bin/bash
set -e

# 1. Check if the SSL certificate already exists
if [ ! -f "/etc/ssl/certs/nginx.crt" ]; then
    echo "Generating self-signed SSL certificate..."
    
    # 2. Use OpenSSL to create the certificate (.crt) and the private key (.key)
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/nginx.key \
        -out /etc/ssl/certs/nginx.crt \
        -subj "/C=MA/ST=State/L=City/O=42/CN=${DOMAIN_NAME}"
        
    echo "SSL certificate generated successfully!"
else
    echo "SSL certificate already exists. Skipping generation."
fi

# 3. The Grand Finale: Launch NGINX in the foreground as PID 1
echo "Starting NGINX..."
exec nginx -g "daemon off;"
