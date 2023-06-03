#!/bin/bash

# Update package lists
echo "🔄 Updating package lists..."
sudo apt update

# Install Python3 pip
echo "🔧 Installing Python3 pip..."
sudo apt install python3-pip -y

# Install Certbot
echo "🔧 Installing Certbot..."
sudo apt-get install certbot -y

# Install Python Certbot Nginx
echo "🔧 Installing Python Certbot Nginx..."
sudo apt-get install python3-certbot-nginx -y

# Obtain and install certificate
echo "🔐 Obtaining and installing SSL certificate..."
sudo certbot --nginx

# Add certbot renewal command to crontab
echo "⏰ Adding Certbot renewal command to crontab..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -

echo "✅ All done!"

sudo rm -rm create-ssl-certificate.sh
