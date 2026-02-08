# Use official PHP image with Apache
FROM php:8.2-apache

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Install MySQL PDO extension
RUN docker-php-ext-install pdo pdo_mysql

# Copy application files
COPY app/index_standalone.php /var/www/html/index.php

# Set working directory
WORKDIR /var/www/html

# Configure Apache to listen on Railway's PORT (defaults to 80 for local Docker)
RUN sed -i 's/Listen 80/Listen ${PORT:-80}/' /etc/apache2/ports.conf && \
    sed -i 's/:80/:${PORT:-80}/' /etc/apache2/sites-available/000-default.conf

# Expose port (Railway ignores this, uses PORT env var)
EXPOSE ${PORT:-80}

# Start Apache with environment variable substitution
CMD ["sh", "-c", "envsubst < /etc/apache2/ports.conf > /tmp/ports.conf && mv /tmp/ports.conf /etc/apache2/ports.conf && envsubst < /etc/apache2/sites-available/000-default.conf > /tmp/000-default.conf && mv /tmp/000-default.conf /etc/apache2/sites-available/000-default.conf && apache2-foreground"]
