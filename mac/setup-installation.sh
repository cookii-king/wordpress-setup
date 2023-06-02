#!/bin/bash

# Set default values
BACKUP_SERVER=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
# SYSTEM_PATH="/home/ubuntu/system/"

# sudo chmod 400 "${SYSTEM_PATH}backup.pem"

# Check if command line arguments are provided
if [ ! -z "$1" ]; then
  MYSQL_DATABASE="$1"
else
  read -p "Enter database name: " MYSQL_DATABASE
fi

if [ ! -z "$2" ]; then
  MYSQL_USER="$2"
else
  read -p "Enter database user: " MYSQL_USER
fi

if [ ! -z "$3" ]; then
  MYSQL_PASSWORD="$3"
else
  read -sp "Enter database password: " MYSQL_PASSWORD
  echo ""
fi

if [ ! -z "$4" ]; then
  BACKUP_SERVER="$4"
else
  read -p "Enter backup server username (leave empty if not using a backup server): " BACKUP_SERVER
fi

sudo apt update -y
sudo apt install nginx -y
sudo apt install software-properties-common -y
sudo apt install mysql-server -y
sudo apt install mysql-client -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt install php8.1 -y
sudo apt install php8.1-fpm -y
sudo apt install php8.1-mysql -y
sudo systemctl status nginx
sudo wget -O /var/www/html/latest.tar.gz https://wordpress.org/latest.tar.gz
sudo tar -xzf /var/www/html/latest.tar.gz -C /var/www/html/
sudo mv /var/www/html/index.nginx-debian.html /var/www/html/index.html
sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
ls /var/www/html/wordpress

sudo sed -i "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', '$MYSQL_DATABASE' );/g" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', '$MYSQL_USER' );/g" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', '$MYSQL_PASSWORD' );/g" /var/www/html/wordpress/wp-config.php

config_file="/var/www/html/wordpress/wp-config.php"

# Download the salts and store them in a variable
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

# Define the search string
STRING='put your unique phrase here'

# Replace the placeholders in the wp-config.php file
sed -i "/$STRING/ { N; d }" $config_file
printf '%s\n' "/**#@-/i" "$SALT" "." "w" | ed -s $config_file

# Replace the document root in the Nginx configuration file
sudo sed -i "s#root /var/www/html;#root /var/www/html/wordpress;#g" /etc/nginx/sites-available/default
sudo sed -i "s#index index.html index.htm index.nginx-debian.html;#index index.php index.html index.htm index.nginx-debian.html;#g" /etc/nginx/sites-available/default
sudo sed -i "s/server_name _;/server_name localhost;/g" /etc/nginx/sites-available/default
sudo sed -i 's#try_files $uri $uri/ =404;#try_files $uri $uri/ /index.php?$args;#g' /etc/nginx/sites-available/default

sudo sed -i '60s/php7.4-fpm.sock/php8.1-fpm.sock/' /etc/nginx/sites-available/default

sudo sed -i -e '56, 61 s/#//' -e '63 s/#//' /etc/nginx/sites-available/default

# Create the database, user, and grant privileges
sudo mysql <<EOF
CREATE DATABASE $MYSQL_DATABASE DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'localhost';
GRANT SELECT, SHOW VIEW, RELOAD, REPLICATION CLIENT, LOCK TABLES, PROCESS ON *.* TO '$MYSQL_USER'@'localhost';
FLUSH PRIVILEGES;
EOF


sudo systemctl restart nginx

sudo chown -R www-data:www-data /var/www

if [ ! -z "$BACKUP_SERVER" ]; then
  # Add your backup script here
  echo "Backup server is set up."
fi

echo "done ✅ ∙ to get rid of error just setup your wordpres and update the backup script to your liking..."
echo "go to http://$(curl ifconfig.me) to see finish setting up your wordpress website. 😁"
