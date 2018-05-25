# Server Deployer

### Intro

This is a shell script for setting up php environment for laravel on Linux.

### Software

 - Debian 8 / 9
 - Git
 - PHP 7.2
 - Nginx
 - MySQL
 - Sqlite3
 - Composer
 - Node 8
 - Redis
 - Memcached
 - Beanstalkd
 - acme.sh

### Installation

##### Download script

    wget https://raw.githubusercontent.com/kotoyuuko/laravel-server-init/master/debian/deploy.sh
    chmod +x deploy.sh

##### Config MySQL password

Open `deploy.sh` to edit your password.

    # Configure
    MYSQL_ROOT_PASSWORD="qwerty123456"
    MYSQL_NORMAL_USER="kotoyuuko"
    MYSQL_NORMAL_USER_PASSWORD="123456"

##### Start install

    ./deploy.sh | tee deploy.log

> Attention: You `must` run as `root`.

### After

##### Webroot

Please put your project into `/data/www/{{ -- PROJECT NAME -- }}`.

Then set correct permission for `/data/www`.

    chown -R www:www /data/www

##### Nginx http site

This is an example.

    server {
        listen 80;
        server_name {{ -- DOMAIN NAME -- }};
        root {{ -- PROJECT FOLDER -- }};

        index index.html index.htm index.php;

        charset utf-8;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        access_log /data/log/nginx/{{ -- PROJECT NAME -- }}-access.log;
        error_log  /data/log/nginx/{{ -- PROJECT NAME -- }}-error.log error;

        sendfile off;

        client_max_body_size 100m;

        include fastcgi.conf;

        location ~ /\.ht {
            deny all;
        }

        location ~ \.php$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }

Then force reload nginx.

    systemctl force-reload nginx

##### Nginx https site

This is an example config file for http.

    server {
        listen 80;
        server_name {{ -- DOMAIN NAME -- }};
        location /.well-known/acme-challenge {
            root /data/acme;
        }
        location / {
            return 301 https://$server_name$request_uri;
        }
    }

Then force reload nginx.

    systemctl force-reload nginx

Generate your own ssl certs.

    acme.sh --issue -d {{ -- DOMAIN NAME -- }} --webroot /data/www/{{ -- DOMAIN NAME -- }}

Install certs.

    acme.sh --installcert -d {{ -- DOMAIN NAME -- }} \
        --key-file /data/ssl/{{ -- DOMAIN NAME -- }}/priv.key \
        --fullchain-file /data/ssl/{{ -- DOMAIN NAME -- }}/fullchain.crt \
        --reloadcmd  "systemctl force-reload nginx"

This is an example config file for https.

    server {
        listen 443 ssl http2;
        server_name {{ -- DOMAIN NAME -- }};
        root {{ -- PROJECT FOLDER -- }};

        index index.html index.htm index.php;

        charset utf-8;

        ssl_certificate /data/ssl/{{ -- DOMAIN NAME -- }}/fullchain.crt;
        ssl_certificate_key /data/ssl/{{ -- DOMAIN NAME -- }}/priv.key;
        ssl_protocols TLSv1.2 TLSv1.1 TLSv1;
        ssl_prefer_server_ciphers on;
        ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4";
        keepalive_timeout 70;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        ssl_dhparam /etc/ssl/certs/dhparam.pem;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        access_log /data/log/nginx/{{ -- PROJECT NAME -- }}-access.log;
        error_log  /data/log/nginx/{{ -- PROJECT NAME -- }}-error.log error;

        sendfile off;

        client_max_body_size 100m;

        include fastcgi.conf;

        location ~ /\.ht {
            deny all;
        }

        location ~ \.php$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }

Then force reload nginx.

    systemctl force-reload nginx

##### HSTS configure (optional)

    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

### License

MIT
