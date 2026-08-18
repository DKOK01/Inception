FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php8.2-cli \
    php8.2-mysql \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html/adminer && \
    wget "https://www.adminer.org/latest.php" -O /var/www/html/adminer/index.php && \
    chown -R www-data:www-data /var/www/html/adminer

WORKDIR /var/www/html
EXPOSE 8080

ENTRYPOINT ["php", "-S", "[::]:8080", "-t", "/var/www/html"]
