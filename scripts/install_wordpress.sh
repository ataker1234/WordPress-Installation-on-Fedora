#!/bin/bash
set -e

# === Configuration ===
SITE_NAME="example.com"
DB_NAME="wp_example"
DB_USER="wp_user"
DB_PASS="changeme"
SITE_DIR="/var/www/$SITE_NAME"

# === Install required packages ===
dnf install -y httpd php php-mysqlnd mariadb-server unzip wget policycoreutils-python-utils

# === Start and enable services ===
systemctl enable --now httpd mariadb

# === MariaDB: Create DB and user ===
mysql -u root <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# === Download and extract WordPress ===
mkdir -p $SITE_DIR
cd /tmp
wget -q https://wordpress.org/latest.zip
unzip -q latest.zip
cp -r wordpress/* $SITE_DIR

# === Create wp-config.php ===
cp $SITE_DIR/wp-config-sample.php $SITE_DIR/wp-config.php

sed -i "s/database_name_here/$DB_NAME/" $SITE_DIR/wp-config.php
sed -i "s/username_here/$DB_USER/" $SITE_DIR/wp-config.php
sed -i "s/password_here/$DB_PASS/" $SITE_DIR/wp-config.php
sed -i "s/localhost/127.0.0.1/" $SITE_DIR/wp-config.php

# === Optional: set FS_METHOD for plugin install ===
sed -i "/^\/\* That's all, stop editing! Happy publishing. \*\//i define('FS_METHOD', 'direct');" $SITE_DIR/wp-config.php

# === Set correct permissions ===
chown -R root:root $SITE_DIR
chown -R apache:apache $SITE_DIR/wp-content
find $SITE_DIR -type d -exec chmod 755 {} \;
find $SITE_DIR -type f -exec chmod 644 {} \;

# === SELinux config ===
semanage fcontext -a -t httpd_sys_rw_content_t "$SITE_DIR/wp-content(/.*)?"
restorecon -Rv $SITE_DIR/wp-content
setsebool -P httpd_can_network_connect on

# === Apache Virtual Host config ===
cat > /etc/httpd/conf.d/$SITE_NAME.conf <<EOL
<VirtualHost *:80>
    ServerName $SITE_NAME
    DocumentRoot $SITE_DIR
    <Directory $SITE_DIR>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL

# === Restart Apache ===
systemctl restart httpd

echo "✅ WordPress installed and ready at http://$SITE_NAME"

