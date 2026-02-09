# Use official PHP image with Apache
FROM php:8.2-apache

# Install required packages and MySQL PDO extension
RUN apt-get update && apt-get install -y gettext-base && \
    docker-php-ext-install pdo pdo_mysql && \
    a2enmod rewrite && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy application files
COPY app/index_standalone.php /var/www/html/index.php

# Set working directory
WORKDIR /var/www/html

# Create a startup script that configures Apache port dynamically
RUN echo '#!/bin/bash\n\
    PORT=${PORT:-80}\n\
    sed -i "s/Listen 80/Listen $PORT/" /etc/apache2/ports.conf\n\
    sed -i "s/:80/:$PORT/" /etc/apache2/sites-available/000-default.conf\n\
    apache2-foreground' > /start.sh && chmod +x /start.sh

# Expose port
EXPOSE 80

# Start with the dynamic port script
CMD ["/start.sh"]
