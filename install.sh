#!/bin/bash

clear
echo "=============================================="
echo "Professional WordPress Installation Wizard"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ask user for domain
read -p "Enter your domain (e.g., wp-ac.ir): " DOMAIN
DOMAIN=${DOMAIN:-wp-ac.ir}
SITE_DIR="/var/www/${DOMAIN}"
SITE_URL="https://${DOMAIN}"

# Ask for admin email
read -p "Enter admin email [m4tinbeigi@gmail.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-m4tinbeigi@gmail.com}

# Ask for admin username and password
read -p "Enter WordPress admin username [ricksanchez]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-ricksanchez}

read -p "Enter WordPress admin password (leave empty for auto-generate): " ADMIN_PASS_INPUT
if [ -z "$ADMIN_PASS_INPUT" ]; then
    ADMIN_PASS="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 16)"
    echo -e "${GREEN}Auto-generated password: $ADMIN_PASS${NC}"
else
    ADMIN_PASS="$ADMIN_PASS_INPUT"
fi

# Ask for admin display name
read -p "Enter admin display name [ریک سانچز]: " ADMIN_DISPLAY_NAME
ADMIN_DISPLAY_NAME=${ADMIN_DISPLAY_NAME:-ریک سانچز}

# Ask for cleanup
echo ""
echo -e "${YELLOW}=== Cleanup Options ===${NC}"
read -p "Remove previous installation? (y/n) [y]: " CLEANUP
CLEANUP=${CLEANUP:-y}

read -p "Remove default plugins? (y/n) [y]: " REMOVE_DEFAULT_PLUGINS
REMOVE_DEFAULT_PLUGINS=${REMOVE_DEFAULT_PLUGINS:-y}

read -p "Remove default themes? (y/n) [y]: " REMOVE_DEFAULT_THEMES
REMOVE_DEFAULT_THEMES=${REMOVE_DEFAULT_THEMES:-y}

# Plugin selection
echo ""
echo -e "${YELLOW}=== Plugin Selection ===${NC}"
echo "Available plugins:"
echo "1) SEO by Rank Math (recommended)"
echo "2) WP-Parsidate (Persian support)"
echo "3) Contact Form 7"
echo "4) WooCommerce"
echo "5) All in One SEO"
echo "6) Wordfence Security"
echo "7) Elementor"
echo "8) WP Super Cache"

declare -A PLUGINS
PLUGINS[1]="seo-by-rank-math"
PLUGINS[2]="wp-parsidate"
PLUGINS[3]="contact-form-7"
PLUGINS[4]="woocommerce"
PLUGINS[5]="all-in-one-seo-pack"
PLUGINS[6]="wordfence"
PLUGINS[7]="elementor"
PLUGINS[8]="wp-super-cache"

SELECTED_PLUGINS=()
read -p "Enter plugin numbers (comma-separated, e.g., 1,2,3) or 'all' [1,2]: " PLUGIN_CHOICE
PLUGIN_CHOICE=${PLUGIN_CHOICE:-1,2}

if [ "$PLUGIN_CHOICE" = "all" ]; then
    SELECTED_PLUGINS=("${PLUGINS[@]}")
else
    IFS=',' read -ra PLUGIN_NUMS <<< "$PLUGIN_CHOICE"
    for num in "${PLUGIN_NUMS[@]}"; do
        if [ -n "${PLUGINS[$num]}" ]; then
            SELECTED_PLUGINS+=("${PLUGINS[$num]}")
        fi
    done
fi

# SSL Certificate
echo ""
echo -e "${YELLOW}=== SSL Certificate ===${NC}"
read -p "Install SSL certificate with Let's Encrypt? (y/n) [y]: " INSTALL_SSL
INSTALL_SSL=${INSTALL_SSL:-y}

# Database prefix
read -p "Enter custom database prefix [wp_]: " DB_PREFIX
DB_PREFIX=${DB_PREFIX:-wp_}

# Timezone
read -p "Enter timezone [Asia/Tehran]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Tehran}

# Start of week
read -p "Start of week (0=Sunday, 6=Saturday) [6]: " START_OF_WEEK
START_OF_WEEK=${START_OF_WEEK:-6}

# phpMyAdmin
echo ""
echo -e "${YELLOW}=== phpMyAdmin ===${NC}"
read -p "Install phpMyAdmin? (y/n) [y]: " INSTALL_PHPMYADMIN
INSTALL_PHPMYADMIN=${INSTALL_PHPMYADMIN:-y}

if [ "$INSTALL_PHPMYADMIN" = "y" ]; then
    read -p "phpMyAdmin username [phpadmin]: " HTPASS_USER
    HTPASS_USER=${HTPASS_USER:-phpadmin}
    read -p "phpMyAdmin password (leave empty for auto-generate): " HTPASS_PASS_INPUT
    if [ -z "$HTPASS_PASS_INPUT" ]; then
        HTPASS_PASS="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 16)"
        echo -e "${GREEN}Auto-generated phpMyAdmin password: $HTPASS_PASS${NC}"
    else
        HTPASS_PASS="$HTPASS_PASS_INPUT"
    fi
fi

# Summary
echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}Installation Summary${NC}"
echo -e "${GREEN}==============================================${NC}"
echo "Domain: $DOMAIN"
echo "Site Directory: $SITE_DIR"
echo "Admin User: $ADMIN_USER"
echo "Admin Email: $ADMIN_EMAIL"
echo "Selected Plugins (${#SELECTED_PLUGINS[@]}): ${SELECTED_PLUGINS[*]}"
echo "Timezone: $TIMEZONE"
echo "SSL: $INSTALL_SSL"
echo "phpMyAdmin: $INSTALL_PHPMYADMIN"
echo -e "${GREEN}==============================================${NC}"

read -p "Continue with installation? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}

if [ "$CONFIRM" != "y" ]; then
    echo "Installation cancelled."
    exit 0
fi

# Generate random credentials
DB_NAME="${DB_PREFIX}$(date +%s)"
DB_USER="user_$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 8)"
DB_PASS="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 16)"

# Functions
ensure_service() {
    local service=$1
    if ! systemctl is-active --quiet $service; then
        echo "Starting $service..."
        systemctl start $service
        sleep 3
        if ! systemctl is-active --quiet $service; then
            echo "ERROR: $service failed to start. Exiting."
            exit 1
        fi
    fi
}

fix_permissions() {
    echo "Setting secure permissions..."
    
    chown -R www-data:www-data "$SITE_DIR"
    find "$SITE_DIR" -type d -exec chmod 755 {} \;
    find "$SITE_DIR" -type f -exec chmod 644 {} \;
    
    chmod -R 755 "$SITE_DIR/wp-content"
    chmod -R 775 "$SITE_DIR/wp-content/uploads"
    chmod -R 775 "$SITE_DIR/wp-content/cache"
    chmod -R 775 "$SITE_DIR/wp-content/upgrade"
    chmod -R 775 "$SITE_DIR/wp-content/plugins"
    chmod -R 775 "$SITE_DIR/wp-content/themes"
    chmod 644 "$SITE_DIR/wp-config.php"
    
    find "$SITE_DIR" -name ".htaccess" -exec chmod 644 {} \;
    
    echo "Permissions fixed for safe plugin/theme management."
}

# Start installation
echo ""
echo -e "${BLUE}Starting installation...${NC}"

# Stop services
systemctl stop apache2 >/dev/null 2>&1
systemctl stop mariadb >/dev/null 2>&1

# Cleanup if requested
if [ "$CLEANUP" = "y" ]; then
    echo "Cleaning previous installation..."
    rm -rf "$SITE_DIR"
    rm -rf /usr/share/phpmyadmin 2>/dev/null
    rm -rf "$SITE_DIR/phpmyadmin" 2>/dev/null
fi

mkdir -p "$SITE_DIR"

# Update and install prerequisites
echo "Updating and installing prerequisites..."
apt update -y
apt upgrade -y
apt --fix-broken install -y
apt autoremove -y
DEBIAN_FRONTEND=noninteractive apt install -y apache2 mariadb-server php php-mysql php-xml php-gd php-curl php-zip php-mbstring php-intl unzip wget curl certbot python3-certbot-apache apache2-utils

# Start services
ensure_service mariadb
ensure_service apache2

# Database setup
echo "Creating database and user..."
for i in {1..5}; do
    mysql -e "DROP DATABASE IF EXISTS $DB_NAME;" >/dev/null 2>&1
    mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" >/dev/null 2>&1
    mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null
    mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" >/dev/null
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" >/dev/null
    mysql -e "FLUSH PRIVILEGES;" >/dev/null
    if mysql -u"$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" >/dev/null 2>&1; then
        echo "Database ready."
        break
    else
        echo "Retrying database setup..."
        sleep 3
    fi
done

# Download WordPress Persian
echo "Downloading WordPress Persian..."
cd "$SITE_DIR"
wget -q https://fa.wordpress.org/latest-fa_IR.zip -O wordpress.zip
unzip -q wordpress.zip
mv wordpress/* .
rm -rf wordpress wordpress.zip

# Configure wp-config.php
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASS/" wp-config.php
sed -i "s/table_prefix  = 'wp_'/table_prefix  = '${DB_PREFIX}'/" wp-config.php
sed -i '1s/^\xEF\xBB\xBF//' wp-config.php

# Add security keys
curl -s https://api.wordpress.org/secret-key/1.1/salt/ > temp_keys.txt
sed -i '/AUTH_KEY/,$d' wp-config.php
cat temp_keys.txt >> wp-config.php
rm temp_keys.txt

# Add ABSPATH
echo -e "\nif ( !defined('ABSPATH') )\n    define('ABSPATH', __DIR__ . '/');\n\nrequire_once ABSPATH . 'wp-settings.php';" >> wp-config.php

# Set initial permissions
fix_permissions

# Install phpMyAdmin if requested
if [ "$INSTALL_PHPMYADMIN" = "y" ]; then
    echo "Installing phpMyAdmin..."
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $DB_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DB_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $DB_PASS" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin
    ln -sf /usr/share/phpmyadmin "$SITE_DIR/phpmyadmin"
    
    # Protect phpMyAdmin
    htpasswd -b -c /etc/phpmyadmin/.htpasswd $HTPASS_USER $HTPASS_PASS
    
    cat > /etc/apache2/conf-available/phpmyadmin.conf <<EOL
Alias /phpmyadmin "$SITE_DIR/phpmyadmin"
<Directory "$SITE_DIR/phpmyadmin">
    Options Indexes FollowSymLinks
    DirectoryIndex index.php
    AllowOverride All
    Require all granted
    AuthType Basic
    AuthName "Restricted Access"
    AuthUserFile /etc/phpmyadmin/.htpasswd
    Require valid-user
</Directory>
EOL
    
    a2enconf phpmyadmin
    systemctl reload apache2 || systemctl restart apache2
fi

# Remove default plugins if requested
if [ "$REMOVE_DEFAULT_PLUGINS" = "y" ]; then
    echo "Removing default plugins..."
    cd "$SITE_DIR/wp-content/plugins"
    rm -rf akismet hello.php 2>/dev/null
fi

# Remove default themes if requested
if [ "$REMOVE_DEFAULT_THEMES" = "y" ]; then
    echo "Removing default themes..."
    cd "$SITE_DIR/wp-content/themes"
    # Keep only one default theme
    KEEP_THEME="twentytwentythree"
    for theme in $(ls); do
        [[ "$theme" != "$KEEP_THEME" ]] && rm -rf "$theme"
    done
fi

# Install selected plugins
if [ ${#SELECTED_PLUGINS[@]} -gt 0 ]; then
    echo "Installing selected plugins..."
    cd "$SITE_DIR/wp-content/plugins"
    for plugin in "${SELECTED_PLUGINS[@]}"; do
        echo "Installing $plugin..."
        wget -q https://downloads.wordpress.org/plugin/$plugin.zip
        unzip -q $plugin.zip
        rm $plugin.zip
    done
fi

# Install WP-CLI
echo "Installing WP-CLI..."
cd "$SITE_DIR"
wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Fix permissions again after plugin installation
fix_permissions

# Install WordPress in Persian
echo "Installing WordPress..."
wp core install \
  --url="$SITE_URL" \
  --title="$DOMAIN" \
  --admin_user="$ADMIN_USER" \
  --admin_password="$ADMIN_PASS" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email \
  --locale=fa \
  --allow-root

# Set timezone and start of week
wp option update timezone_string "$TIMEZONE" --allow-root
wp option update start_of_week "$START_OF_WEEK" --allow-root

# Set display name
wp user update "$ADMIN_USER" --display_name="$ADMIN_DISPLAY_NAME" --allow-root

# Activate installed plugins
if [ ${#SELECTED_PLUGINS[@]} -gt 0 ]; then
    echo "Activating plugins..."
    wp plugin activate "${SELECTED_PLUGINS[@]}" --allow-root
fi

# Install SSL if requested
if [ "$INSTALL_SSL" = "y" ]; then
    echo "Installing SSL certificate..."
    certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $ADMIN_EMAIL || echo "SSL deployment skipped."
fi

# Final permission fix
fix_permissions

# Create reset-permissions script
cat > "$SITE_DIR/reset-wp-permissions.sh" <<'EOL'
#!/bin/bash
echo "Resetting WordPress permissions for safe plugin/theme management..."
SITE_DIR="/var/www/'"$DOMAIN"'"

# Reset to safe permissions
chown -R www-data:www-data "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod 755 {} \;
find "$SITE_DIR" -type f -exec chmod 644 {} \;

# Special permissions
chmod -R 775 "$SITE_DIR/wp-content/plugins"
chmod -R 775 "$SITE_DIR/wp-content/themes"
chmod -R 775 "$SITE_DIR/wp-content/uploads"
chmod -R 775 "$SITE_DIR/wp-content/cache"
chmod -R 775 "$SITE_DIR/wp-content/upgrade"
chmod 644 "$SITE_DIR/wp-config.php"

echo "Permissions reset successfully!"
echo "You can now safely delete plugins/themes from WordPress admin."
EOL

chmod +x "$SITE_DIR/reset-wp-permissions.sh"

# Create site management script
cat > "$SITE_DIR/manage-site.sh" <<'EOL'
#!/bin/bash
DOMAIN="'"$DOMAIN"'"
SITE_DIR="/var/www/$DOMAIN"

echo "Site Management for $DOMAIN"
echo "1) Reset permissions"
echo "2) Backup database"
echo "3) Update WordPress"
echo "4) Update plugins"
echo "5) Reinstall WordPress"
echo "6) Show site info"

read -p "Choose option: " OPTION

case $OPTION in
    1)
        bash "$SITE_DIR/reset-wp-permissions.sh"
        ;;
    2)
        DB_NAME=$(grep DB_NAME "$SITE_DIR/wp-config.php" | cut -d"'" -f4)
        BACKUP_FILE="$SITE_DIR/backup-$(date +%Y%m%d-%H%M%S).sql"
        mysqldump -u root $DB_NAME > $BACKUP_FILE
        echo "Backup created: $BACKUP_FILE"
        ;;
    3)
        cd "$SITE_DIR"
        wp core update --allow-root
        ;;
    4)
        cd "$SITE_DIR"
        wp plugin update --all --allow-root
        ;;
    5)
        cd "$SITE_DIR"
        wp core download --locale=fa --force --allow-root
        ;;
    6)
        echo "Site Directory: $SITE_DIR"
        echo "URL: https://$DOMAIN"
        grep "DB_NAME\|DB_USER" "$SITE_DIR/wp-config.php" | head -2
        ;;
    *)
        echo "Invalid option"
        ;;
esac
EOL

chmod +x "$SITE_DIR/manage-site.sh"

# Restart services
systemctl restart apache2
systemctl restart mariadb

# Output final information
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}WordPress:${NC}"
echo "  URL: $SITE_URL"
echo "  Admin URL: $SITE_URL/wp-admin"
echo "  Admin User: $ADMIN_USER"
echo "  Admin Password: $ADMIN_PASS"
echo "  Admin Email: $ADMIN_EMAIL"
echo ""
echo -e "${BLUE}Database:${NC}"
echo "  Name: $DB_NAME"
echo "  User: $DB_USER"
echo "  Password: $DB_PASS"
echo "  Prefix: ${DB_PREFIX}"
echo ""
if [ "$INSTALL_PHPMYADMIN" = "y" ]; then
    echo -e "${BLUE}phpMyAdmin:${NC}"
    echo "  URL: $SITE_URL/phpmyadmin"
    echo "  Username: $HTPASS_USER"
    echo "  Password: $HTPASS_PASS"
    echo ""
fi
echo -e "${BLUE}Plugins Installed (${#SELECTED_PLUGINS[@]}):${NC}"
for plugin in "${SELECTED_PLUGINS[@]}"; do
    echo "  - $plugin"
done
echo ""
echo -e "${BLUE}Management Scripts:${NC}"
echo "  Reset permissions: sudo bash $SITE_DIR/reset-wp-permissions.sh"
echo "  Site management: sudo bash $SITE_DIR/manage-site.sh"
echo ""
echo -e "${YELLOW}IMPORTANT: Save this information in a secure place!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"

# Save credentials to file
CREDENTIALS_FILE="/root/${DOMAIN}-credentials.txt"
cat > "$CREDENTIALS_FILE" <<EOL
==========================================
WordPress Installation Credentials
Domain: $DOMAIN
Date: $(date)
==========================================
WORDPRESS:
URL: $SITE_URL
Admin URL: $SITE_URL/wp-admin
Username: $ADMIN_USER
Password: $ADMIN_PASS
Email: $ADMIN_EMAIL

DATABASE:
Name: $DB_NAME
User: $DB_USER
Password: $DB_PASS
Prefix: ${DB_PREFIX}

$(if [ "$INSTALL_PHPMYADMIN" = "y" ]; then
echo "PHPMYADMIN:"
echo "URL: $SITE_URL/phpmyadmin"
echo "Username: $HTPASS_USER"
echo "Password: $HTPASS_PASS"
echo ""
fi)

PLUGINS:
$(for plugin in "${SELECTED_PLUGINS[@]}"; do echo "- $plugin"; done)

MANAGEMENT:
Reset permissions: sudo bash $SITE_DIR/reset-wp-permissions.sh
Site management: sudo bash $SITE_DIR/manage-site.sh
Credentials saved: $CREDENTIALS_FILE
EOL

echo -e "${GREEN}Credentials saved to: $CREDENTIALS_FILE${NC}"
