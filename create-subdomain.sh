#!/usr/bin/bash

# Make sure that the subdomain has first been set up in the DNS records, without this, the script will fail at LetsEncrypt

read -p "Have you setup your DNS records? (Y/N) " cr
if [ $cr == "N" ]; then
	echo "You MUST do this step first, please create and return"
	exit;
fi
echo "Starting Script now....."
# To allow the script to be used by anyone, ask for the servername - e.g. example.com
read -p "Enter server domain: " servername 

# Subdomain to be created .e.g. example (Therefore example.example.com
read -p "Enter the subdomain name: " name

while [ -f "/etc/apache2/sites-available/${name}.${servername}.conf" ]
do
 # If the subdomain already exists, ask them for another one
 read -p "That domain already exists, try again: " name
done

# Create the necessary HTML folders (If your server WWW docs are hosted in a different folder - be sure to change this!) 

mkdir /var/www/html/${name}
sudo chmod -R 755 /var/www/html/${name}
sudo chown -R www-data: /var/www/html/${name}

# save stdout to fd 3; redirect fd 1 to my.config
exec 3>&1 >/etc/apache2/sites-available/${name}.${servername}.conf

# Create the VirtualHost file for Apache

echo "<VirtualHost *:80>"
echo "  DocumentRoot /var/www/html/$name"
echo "  ServerName ${name}.${servername}"
echo ""
echo "  <Directory /var/www/html/$name/>"
echo "    AllowOverride All"
echo "    Order Allow,Deny"
echo "    Allow from All"
echo "  </Directory>"
echo ""
echo "  ErrorLog /var/log/apache2/$name-error.log"
echo "  CustomLog /var/log/apache2/$name.log combined"
echo "  RewriteEngine on"
echo "  RewriteCond %{SERVER_NAME} =$name.${servername}"
echo "  RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]"
echo "<FilesMatch \.php$>"
echo '    SetHandler "proxy:unix:/var/run/php/php8.1-fpm.sock|fcgi://localhost"'
echo "</FilesMatch>"
echo "</VirtualHost>"

# restore original stdout to fd 1
exec >&3-

echo "Config is created, enabling site"
a2ensite ${name}.${servername}

echo "Running Apache Tests..."
sudo apachectl configtest
sudo systemctl reload apache2

# Generate a HTTPS certificate with Letsencrypt

sudo certbot --apache --agree-tos --preferred-challenges http -d ${name}.${servername}
