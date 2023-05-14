#!/bin/bash

# Set default values
BACKUP_SERVER=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
SYSTEM_PATH="/home/ubuntu/system/"

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
  read -p "Enter backup server username: " BACKUP_SERVER
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

# MYSQL_FILE="${SYSTEM_PATH}backup_on_$(date +"%d_%m_%Y_at_%H_%M_%S").sql"
# LOG_FILE="${SYSTEM_PATH}suretide.log"

# # Calculate the length of the LOG_ENTRY_DATE_TIME text
# LOG_ENTRY_DATE_TIME="$(date +"%Y-%m-%d %H:%M:%S")"

# # Dump the MySQL database and save it to a file
# /usr/bin/mysqldump -u$MYSQL_USER $MYSQL_DATABASE > "$MYSQL_FILE"
# # Upload the MySQL backup file to the backup server using SFTP
# echo -e "put $MYSQL_FILE\nexit" | /usr/bin/sftp -o StrictHostKeyChecking=no -i "${SYSTEM_PATH}backup.pem" $BACKUP_SERVER >> "$LOG_FILE"

# # Create a tarball of the WordPress directory and save it to a file
# WORDPRESS_DIRECTORY_TAR_FILE="${SYSTEM_PATH}wordpress_backup_on_$(date +"%d_%m_%Y_at_%H_%M_%S").tar.gz"
# WORDPRESS_DIRECTORY="/var/www/html/wordpress"
# tar -czf "$WORDPRESS_DIRECTORY_TAR_FILE" "$WORDPRESS_DIRECTORY" >> "$LOG_FILE"
# # Upload the WordPress backup file to the backup server using SFTP
# echo -e "put $WORDPRESS_DIRECTORY_TAR_FILE\nexit" | /usr/bin/sftp -o StrictHostKeyChecking=no -i "${SYSTEM_PATH}backup.pem" $BACKUP_SERVER >> "$LOG_FILE"

# # Create a tarball of the Nginx directory and save it to a file
# NGINX_DIRECTORY_TAR_FILE="${SYSTEM_PATH}nginx_backup_on_$(date +"%d_%m_%Y_at_%H_%M_%S").tar.gz"
# NGINX_DIRECTORY="/etc/nginx"
# tar -czf "$NGINX_DIRECTORY_TAR_FILE" "$NGINX_DIRECTORY" >> "$LOG_FILE"
# # Upload the Nginx backup file to the backup server using SFTP
# echo -e "put $NGINX_DIRECTORY_TAR_FILE\nexit" | /usr/bin/sftp -o StrictHostKeyChecking=no -i "${SYSTEM_PATH}backup.pem" $BACKUP_SERVER >> "$LOG_FILE"

# # Print the MySQL backup file path
# echo "$MYSQL_FILE"
# # Print the log file content
# cat "$LOG_FILE"

# # Remove the backup files from the local system
# rm $MYSQL_FILE
# rm $WORDPRESS_DIRECTORY_TAR_FILE
# rm $NGINX_DIRECTORY_TAR_FILE

# # Check if the home and site URLs in the database match the current server URL
# # If not, update the URLs in the database
# OUTPUT=$(mysql -u$MYSQL_USER -e "use $MYSQL_DATABASE;
# SELECT option_name, option_value FROM wp_options WHERE option_name IN ('siteurl', 'home');")
# HOME_URL=$(echo "$OUTPUT" | grep "home" | awk '{print $2}')
# SITE_URL=$(echo "$OUTPUT" | grep "siteurl" | awk '{print $2}')
# CURRENT_URL="http://$(curl ifconfig.me)"

# if [ "$HOME_URL" != "$CURRENT_URL" ] && [ "$SITE_URL" != "$CURRENT_URL" ]; then
#     mysql -u$MYSQL_USER -e "use $MYSQL_DATABASE;
#     UPDATE wp_options SET option_value = '$CURRENT_URL' WHERE option_name = 'siteurl';
#     UPDATE wp_options SET option_value = '$CURRENT_URL' WHERE option_name = 'home';"
#     echo "🔄 Updated home and siteurl values in the database." >> "$LOG_FILE"
# else
#     echo "ℹ️ Current homeurl is: $HOME_URL" >> "$LOG_FILE"
#     echo "ℹ️ Current siteurl is: $SITE_URL" >> "$LOG_FILE"
# fi

# # Update the cron job to run this script every minute
# (crontab -l | grep -v "${SYSTEM_PATH}backup.sh"; echo " * * * * * /usr/bin/bash ${SYSTEM_PATH}backup.sh $MYSQL_DATABASE $MYSQL_USER $MYSQL_PASSWORD $BACKUP_SERVER") | sort -u | crontab -

echo "done ✅ ∙ to get rid of error just setup your wordpres and update the backup script to your liking..."
echo "go to http://$(curl ifconfig.me) to see finish setting up your wordpress website. 😁"

