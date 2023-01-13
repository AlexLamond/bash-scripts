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

# ---- Now we've set up the domain, let's configure Wordpress ----

# Create a random name for the database, the database username and database password
db=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-20})
un=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-20})
pw=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-20})

# Remove any hypens that damage the script
db_nm="${$name//-}"
db="${db//-}"
un"${un//-}"
pw"${pw//-}"

echo "============================================"
echo "Setting up the Database"
echo "============================================"

#https://stackoverflow.com/questions/33470753/create-mysql-database-and-user-in-bash-script

# If /root/.my.cnf exists then it won't ask for root password
if [ -f /root/.my.cnf ]; then

    mysql -e "CREATE DATABASE ${db_nm}_${db} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -e "CREATE USER ${un}@localhost IDENTIFIED BY '${pw}';"
    mysql -e "GRANT ALL PRIVILEGES ON ${db_nm}_${db}.* TO '${un}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

# If /root/.my.cnf doesn't exist then it'll ask for root password   
else
    echo "Please enter root user MySQL password!"
    echo "Note: password will be hidden when typing"
    read -sp "Enter password: "  rootpassword
    mysql -u root --password=${rootpassword} -e "CREATE DATABASE ${db_nm}_${db} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -u root --password=${rootpassword} -e "CREATE USER ${un}@localhost IDENTIFIED BY '${pw}';"
    mysql -u root --password=${rootpassword} -e "GRANT ALL PRIVILEGES ON ${db_nm}_${db}.* TO '${un}'@'localhost';"
    mysql -u root --password=${rootpassword} -e "FLUSH PRIVILEGES;"
fi

#https://gist.github.com/bgallagh3r/2853221
