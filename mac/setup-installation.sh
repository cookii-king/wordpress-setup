#!/bin/bash

# Set default values
BACKUP_SERVER=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
DOMAIN_NAME=""

# Ask for the domain name first
if [ ! -z "$1" ]; then
  DOMAIN_NAME="$1"
else
  read -p "Enter domain name e.g. pagebunnii.com (leave empty if not using domain name): " DOMAIN_NAME
fi

# Ask if the user wants to use the domain name for the MYSQL_DATABASE and MYSQL_USER values
if [ ! -z "$DOMAIN_NAME" ]; then
  read -p "Do you want to use your domain name for the database name and user? (y/n): " USE_DOMAIN_NAME
  if [ "$USE_DOMAIN_NAME" == "y" ]; then
    MYSQL_DATABASE=$(echo "$DOMAIN_NAME" | sed 's/https\?:\/\///' | sed 's/\..*//')
    MYSQL_USER="$MYSQL_DATABASE-user"
  fi
fi

# Check if command line arguments are provided for the other values
if [ ! -z "$2" ]; then
  MYSQL_DATABASE="$2"
else
  if [ -z "$MYSQL_DATABASE" ]; then
    read -p "Enter database name: " MYSQL_DATABASE
  fi
fi

if [ ! -z "$3" ]; then
  MYSQL_USER="$3"
else
  if [ -z "$MYSQL_USER" ]; then
    read -p "Enter database user: " MYSQL_USER
  fi
fi

if [ ! -z "$4" ]; then
  MYSQL_PASSWORD="$4"
else
  read -p "Do you want to use your own password or generate a new one? (own/generate): " PASSWORD_CHOICE
  if [ "$PASSWORD_CHOICE" == "own" ]; then
    read -sp "Enter database password: " MYSQL_PASSWORD
    echo ""
  else
    # Generate a random password
    MYSQL_PASSWORD=$(LC_ALL=C </dev/urandom tr -dc 'a-zA-Z0-9!@#$%^&*()_-+=' | fold -w 16 | head -n 1)
    echo "Generated MySQL password: $MYSQL_PASSWORD"
  fi
fi

if [ ! -z "$5" ]; then
  BACKUP_SERVER="$5"
else
  read -p "Enter backup server username (leave empty if not using a backup server): " BACKUP_SERVER
fi

# Get the latest PHP version number
PHP_VERSION=$(sudo apt-cache search php | grep -oP 'php\d\.\d' | sort -V | tail -n 1)

sudo apt update -y
sudo apt install nginx -y
sudo apt install software-properties-common -y
sudo apt install mysql-server -y
sudo apt install mysql-client -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt install "${PHP_VERSION}" -y
sudo apt install "${PHP_VERSION}-fpm" -y
sudo apt install "${PHP_VERSION}-mysql" -y
sudo systemctl status nginx
sudo wget -O /var/www/html/latest.tar.gz https://wordpress.org/latest.tar.gz
sudo tar -xzf /var/www/html/latest.tar.gz -C /var/www/html/
sudo mv /var/www/html/index.nginx-debian.html /var/www/html/index.html
sudo cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
ls /var/www/html/wordpress

sudo sed -i "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', '$MYSQL_DATABASE' );/g" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', '$MYSQL_USER' );/g" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', '$MYSQL_PASSWORD' );/g" /var/www/html/wordpress/wp-config.php

# Check if the domain name is provided
if [ -z "$DOMAIN_NAME" ]; then
  DOMAIN_NAME="localhost"
  REDIRECT_SERVER=""
else
  REDIRECT_SERVER="server {
    listen 80;
    server_name $(curl ifconfig.me);
    return 301 http://${DOMAIN_NAME};
  }"
fi

# Replace the document root in the Nginx configuration file
sudo bash -c "cat > /etc/nginx/sites-available/default" << EOL
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  root /var/www/html/wordpress;

  index index.php index.html index.htm index.nginx-debian.html;

  server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};

  location / {
    try_files \$uri \$uri/ /index.php?\$args;
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;

    fastcgi_pass unix:/var/run/php/${PHP_VERSION}-fpm.sock;
  }
}

${REDIRECT_SERVER}
EOL

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

echo "done ✅ ∙ to get rid of error just setup your WordPress and update the backup script to your liking..."
echo "Go to http://${DOMAIN_NAME:-$(curl ifconfig.me)} to finish setting up your WordPress website. 😁"
