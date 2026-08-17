FROM debian:bookworm

# Install NGINX and OpenSSL in a single layer, then clear the apt cache
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copy our custom NGINX configuration rulebook
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Copy the setup script
COPY tools/setup-ssl.sh /usr/local/bin/setup-ssl.sh

# Expose port 443 (HTTPS)
EXPOSE 443

# Set the setup script to run as PID 1
ENTRYPOINT ["/usr/local/bin/setup-ssl.sh"]
