#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

# Check user
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

# Configure
MYSQL_ROOT_PASSWORD="qwerty123456"
MYSQL_NORMAL_USER="kotoyuuko"
MYSQL_NORMAL_USER_PASSWORD="123456"

# Check if password is defined
if [[ "$MYSQL_ROOT_PASSWORD" == "" ]]; then
    echo "${CFAILURE}Error: MYSQL_ROOT_PASSWORD not define!!${CEND}";
    exit 1;
fi
if [[ "$MYSQL_NORMAL_USER_PASSWORD" == "" ]]; then
    echo "${CFAILURE}Error: MYSQL_NORMAL_USER_PASSWORD not define!!${CEND}";
    exit 1;
fi

# Force locale
export LC_ALL="en_US.UTF-8"
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Create folders
mkdir -p /data/www/default
mkdir -p /data/log/nginx
mkdir -p /data/acme
mkdir -p /data/ssl

# Add www user and group
addgroup www
useradd -g www -d /home/www -c "www" -m -s /usr/sbin/nologin www

# Update package list & Upgrade system packages
apt-get update && apt-get -y upgrade

# remove apache2
apt-get purge apache2 -y

# Install common packages
apt-get install -y curl wget unzip build-essential dos2unix gcc git libmcrypt4 libpcre3-dev \
make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim libnotify-bin \
apt-transport-https lsb-release ca-certificates openssl

# Add backports source
cat >> /etc/apt/sources.list.d/backports.list << EOF
deb http://deb.debian.org/debian $(lsb_release -sc)-backports main
deb-src http://deb.debian.org/debian $(lsb_release -sc)-backports main
EOF
apt-get -t stretch-backports update -y && apt-get -t stretch-backports upgrade -y

# Import key for nginx
wget -O /etc/apt/trusted.gpg.d/nginx-mainline.gpg https://packages.sury.org/nginx-mainline/apt.gpg

# Add source for nginx
cat >> /etc/apt/sources.list.d/nginx.list << EOF
deb https://packages.sury.org/nginx-mainline/ $(lsb_release -sc) main
EOF

# Set priority for nginx
cat >> /etc/apt/preferences << EOF
Package: nginx*
Pin: release a=stretch-backports
Pin-Priority: 499
EOF

# Import key for php
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg

# Add source for php
sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

# Add source for mysql
wget -O /tmp/percona.deb https://repo.percona.com/apt/percona-release_0.1-5.$(lsb_release -sc)_all.deb
dpkg -i /tmp/percona.deb
rm -f /tmp/percona.deb

# Add source for node.js
curl -sL https://deb.nodesource.com/setup_8.x | bash -

# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# Install nginx
apt-get install -y nginx-extras

# Install php and extensions
apt-get install -y php7.2-fpm php7.2-cli php7.2-mysql php7.2-curl php7.2-gd php7.2-mbstring php7.2-xml \
php7.2-xmlrpc php7.2-zip php7.2-json php7.2-imap php7.2-opcache php7.2-intl php7.2-pgsql php7.2-sqlite3 \
php7.2-gd php-apcu php7.2-curl php7.2-memcached php7.2-readline php7.2-bcmath php7.2-soap

# Install composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Add composer global bin to path
printf "\nPATH=\"$(composer config -g home 2>/dev/null)/vendor/bin:\$PATH\"\n" | tee -a ~/.profile

# Install mysql
debconf-set-selections <<< "percona-server-server-5.7 percona-server-server/root_password password ${MYSQL_ROOT_PASSWORD}"
debconf-set-selections <<< "percona-server-server-5.7 percona-server-server/root_password_again password ${MYSQL_ROOT_PASSWORD}"
apt-get install -y percona-server-server-5.7

# Install sqlite3
apt-get install -y sqlite3 libsqlite3-dev

# Install node.js
apt-get install -y nodejs

# Configure mysql password lifetime
echo "default_password_lifetime = 0" >> /etc/mysql/mysql.conf.d/mysqld.cnf

# Add mysql user
mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "CREATE USER '${MYSQL_NORMAL_USER}'@'0.0.0.0'IDENTIFIED BY'${MYSQL_NORMAL_USER_PASSWORD}';"
mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL ON *.* TO '${MYSQL_NORMAL_USER}'@'127.0.0.1'IDENTIFIED BY'${MYSQL_NORMAL_USER_PASSWORD}' WITH GRANT OPTION;"
mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL ON *.* TO '${MYSQL_NORMAL_USER}'@'localhost'IDENTIFIED BY'${MYSQL_NORMAL_USER_PASSWORD}' WITH GRANT OPTION;"
mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
systemctl restart mysql

# Add timezone support to mysql
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --user=root --password=${MYSQL_ROOT_PASSWORD} mysql

# Set php-cli settings
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.2/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.2/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.2/cli/php.ini

# Set php-fpm settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL \& ~E_NOTICE \& ~E_STRICT \& ~E_DEPRECATED/" /etc/php/7.2/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/7.2/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.2/fpm/php.ini
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 50M/" /etc/php/7.2/fpm/php.ini
sed -i "s/post_max_size = .*/post_max_size = 50M/" /etc/php/7.2/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.2/fpm/php.ini
sed -i "s/listen =.*/listen = 127.0.0.1:9000/" /etc/php/7.2/fpm/pool.d/www.conf

# Setup Some fastcgi_params Options
cat > /etc/nginx/fastcgi_params << EOF
fastcgi_param   QUERY_STRING        \$query_string;
fastcgi_param   REQUEST_METHOD      \$request_method;
fastcgi_param   CONTENT_TYPE        \$content_type;
fastcgi_param   CONTENT_LENGTH      \$content_length;
fastcgi_param   SCRIPT_FILENAME     \$request_filename;
fastcgi_param   SCRIPT_NAME     \$fastcgi_script_name;
fastcgi_param   REQUEST_URI     \$request_uri;
fastcgi_param   DOCUMENT_URI        \$document_uri;
fastcgi_param   DOCUMENT_ROOT       \$document_root;
fastcgi_param   SERVER_PROTOCOL     \$server_protocol;
fastcgi_param   GATEWAY_INTERFACE   CGI/1.1;
fastcgi_param   SERVER_SOFTWARE     nginx/\$nginx_version;
fastcgi_param   REMOTE_ADDR     \$remote_addr;
fastcgi_param   REMOTE_PORT     \$remote_port;
fastcgi_param   SERVER_ADDR     \$server_addr;
fastcgi_param   SERVER_PORT     \$server_port;
fastcgi_param   SERVER_NAME     \$server_name;
fastcgi_param   HTTPS           \$https if_not_empty;
fastcgi_param   REDIRECT_STATUS     200;
EOF

# Set nginx & php-fpm user
sed -i "s/user www-data;/user www;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
sed -i "s/user = www-data/user = www/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = www/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/listen\.owner.*/listen.owner = www/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = www/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.2/fpm/pool.d/www.conf

# Install some npm packages
/usr/bin/npm install -g gulp
/usr/bin/npm install -g bower

# Restart and enable nginx
systemctl restart nginx
systemctl enable nginx

# Restart and enable php
systemctl restart php7.2-fpm
systemctl enable php7.2-fpm

# Restart and enable mysql
systemctl restart mysql
systemctl enable mysql

# Install acme.sh
curl https://get.acme.sh | sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade

# Install other things
apt-get install -y redis-server memcached beanstalkd

# Configure redis-server
systemctl enable redis-server
systemctl start redis-server

# Configure memcached
systemctl enable memcached
systemctl start memcached

# Configure supervisor
systemctl enable supervisor
systemctl start supervisor

# Configure beanstalkd
sed -i "s/#START=yes/START=yes/" /etc/default/beanstalkd
systemctl enable beanstalkd
systemctl start beanstalkd

# Setup default site
echo 'IT WORKS!' > /data/www/default/index.html
echo '<?php phpinfo();' > /data/www/default/info.php
cat > /etc/nginx/sites-enabled/default << EOF
server {
    listen 80;
    server_name _;
    root /data/www/default;

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log /data/log/nginx/default-access.log;
    error_log  /data/log/nginx/default-error.log error;

    sendfile off;

    client_max_body_size 100m;

    include fastcgi.conf;

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php$ {
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }
}
EOF
chown www:www -R /data/www
systemctl restart nginx

# Generate dhparam
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

clear
echo "---"
echo "IT WORKS."
echo "MySQL Root Password: ${MYSQL_ROOT_PASSWORD}"
echo "MySQL Normal User: ${MYSQL_NORMAL_USER}"
echo "MySQL Normal User Password: ${MYSQL_NORMAL_USER_PASSWORD}"
echo "---"
