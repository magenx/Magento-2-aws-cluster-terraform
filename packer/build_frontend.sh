#!/bin/bash

. /tmp/build_header.sh

###################################################################################
###                           FRONTEND ADMIN  CONFIGURATION                     ###
###################################################################################

if [[ "${INSTANCE_NAME}" =~ (frontend|admin) ]]; then
# Debian

# PHP packages 
PHP_PACKAGES=(cli fpm common mysql zip gd mbstring curl xml bcmath intl soap oauth apcu)
# Linux packages
LINUX_PACKAGES="nfs-common unzip git patch python3-pip acl attr imagemagick binutils pkg-config libssl-dev ruby"

apt -qqy update
apt -qq -y install ${LINUX_PACKAGES}

# CODEDEPLOY AGENT
cd /tmp
wget https://aws-codedeploy-${parameter["AWS_DEFAULT_REGION"]}.s3.amazonaws.com/latest/install
chmod +x ./install
./install auto

# BUILD EFS UTILS
cd /tmp
git clone https://github.com/aws/efs-utils
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
cd efs-utils
./build-deb.sh
apt-get -y install ./build/amazon-efs-utils*deb
rustup self uninstall -y

# NGINX INSTALLATION
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" > /etc/apt/preferences.d/99nginx
apt -qq update
apt -qq -y install nginx nginx-module-perl nginx-module-image-filter nginx-module-geoip
systemctl enable nginx

# VARNISH INSTALLATION
curl -s https://packagecloud.io/install/repositories/varnishcache/varnish${VARNISH_VERSION}/script.deb.sh | bash
apt -qq update
apt -qq -y install varnish
curl -sSo /etc/systemd/system/varnish.service ${MAGENX_INSTALL_GITHUB_REPO}/varnish.service
curl -sSo /etc/varnish/varnish.params ${MAGENX_INSTALL_GITHUB_REPO}/varnish.params
uuidgen > /etc/varnish/secret
systemctl daemon-reload
# Varnish Cache configuration file
systemctl enable varnish.service
curl -o /etc/varnish/devicedetect.vcl https://raw.githubusercontent.com/varnishcache/varnish-devicedetect/master/devicedetect.vcl
curl -o /etc/varnish/devicedetect-include.vcl ${MAGENX_INSTALL_GITHUB_REPO}/devicedetect-include.vcl
curl -o /etc/varnish/default.vcl ${MAGENX_INSTALL_GITHUB_REPO}/default.vcl
sed -i "s/PROFILER_PLACEHOLDER/${parameter["PROFILER_PLACEHOLDER"]}/" /etc/varnish/default.vcl
sed -i "s/example.com/${parameter["DOMAIN"]}/" /etc/varnish/default.vcl

# PHP INSTALLATION
curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

apt -qq update
apt -qq -y install php${parameter["PHP_VERSION"]} ${PHP_PACKAGES[@]/#/php${parameter["PHP_VERSION"]}-} php-pear
 
# SYSCTL PARAMETERS
cat <<END > /etc/sysctl.conf
fs.file-max = 1000000
fs.inotify.max_user_watches = 1000000
vm.swappiness = 10
net.ipv4.ip_forward = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.msgmnb = 65535
kernel.msgmax = 65535
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 8388608 8388608 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65535 8388608
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_challenge_ack_limit = 1073741823
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 15
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 400000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_sack = 1
net.ipv4.route.flush = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
END

sysctl -q -p

for dir in cli fpm
do
cat <<END > /etc/php/${parameter["PHP_VERSION"]}/$dir/conf.d/zz-magenx-overrides.ini
opcache.enable_cli = 1
opcache.memory_consumption = 512
opcache.interned_strings_buffer = 4
opcache.max_accelerated_files = 60000
opcache.max_wasted_percentage = 5
opcache.use_cwd = 1
opcache.validate_timestamps = 0
;opcache.revalidate_freq = 2
;opcache.validate_permission= 1
opcache.validate_root= 1
opcache.file_update_protection = 2
opcache.revalidate_path = 0
opcache.save_comments = 1
opcache.load_comments = 1
opcache.fast_shutdown = 1
opcache.enable_file_override = 0
opcache.optimization_level = 0xffffffff
opcache.inherited_hack = 1
opcache.blacklist_filename=/etc/opcache-default.blacklist
opcache.max_file_size = 0
opcache.consistency_checks = 0
opcache.force_restart_timeout = 60
opcache.error_log = "/var/log/php-fpm/opcache.log"
opcache.log_verbosity_level = 1
opcache.preferred_memory_model = ""
opcache.protect_memory = 0
;opcache.mmap_base = ""

max_execution_time = 7200
max_input_time = 7200
memory_limit = 2048M
post_max_size = 64M
upload_max_filesize = 64M
expose_php = Off
realpath_cache_size = 4096k
realpath_cache_ttl = 86400
short_open_tag = On
max_input_vars = 50000
session.gc_maxlifetime = 28800
mysql.allow_persistent = On
mysqli.allow_persistent = On
date.timezone = "${parameter["TIMEZONE"]}"
END
done

## CRAETE MAGENTO USER
useradd -d /home/${parameter["BRAND"]} -s /bin/bash ${parameter["BRAND"]}

## CREATE MAGENTO PHP USER
useradd -M -s /sbin/nologin -d /home/${parameter["BRAND"]} php-${parameter["BRAND"]}
usermod -g php-${parameter["BRAND"]} ${parameter["BRAND"]}

# MAGENTO FOLDERS PERMISSIONS | release/shared symlink to public_html deployment
mkdir -p /home/${parameter["BRAND"]}/{releases,shared}
chmod 711 /home/${parameter["BRAND"]}
mkdir -p /home/${parameter["BRAND"]}/shared/{pub/media,var}
chown -R ${parameter["BRAND"]}:php-${parameter["BRAND"]} /home/${parameter["BRAND"]}/{releases,shared}
chmod 2750 /home/${parameter["BRAND"]}/releases
chmod 2770 /home/${parameter["BRAND"]}/shared/{pub/media,var}
setfacl -R -m m:r-X,u:${parameter["BRAND"]}:rwX,g:php-${parameter["BRAND"]}:r-X,o::-,d:u:${parameter["BRAND"]}:rwX,d:g:php-${parameter["BRAND"]}:r-X,d:o::- /home/${parameter["BRAND"]}/releases
setfacl -R -m m:r-X,u:${parameter["BRAND"]}:rwX,g:php-${parameter["BRAND"]}:rwX,o::-,d:u:${parameter["BRAND"]}:rwX,d:g:php-${parameter["BRAND"]}:rwX,d:o::- /home/${parameter["BRAND"]}/shared
setfacl -R -m u:nginx:r-X,d:u:nginx:r-X /home/${parameter["BRAND"]}/{releases,shared}

echo "${parameter["EFS_SYSTEM_ID"]}:/ /home/${parameter["BRAND"]}/shared/var efs _netdev,noresvport,tls,iam,accesspoint=${parameter["EFS_ACCESS_POINT_VAR"]} 0 0" >> /etc/fstab
echo "${parameter["EFS_SYSTEM_ID"]}:/ /home/${parameter["BRAND"]}/shared/pub/media efs _netdev,noresvport,tls,iam,accesspoint=${parameter["EFS_ACCESS_POINT_MEDIA"]} 0 0" >> /etc/fstab

# DOWNLOADING NGINX CONFIG FILES
curl -o /etc/nginx/fastcgi_params  ${MAGENX_NGINX_GITHUB_REPO}magento2/fastcgi_params
curl -o /etc/nginx/nginx.conf  ${MAGENX_NGINX_GITHUB_REPO}magento2/nginx.conf
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/sites-available && cd $_
curl ${MAGENX_NGINX_GITHUB_REPO_API}/sites-available 2>&1 | awk -F'"' '/download_url/ {print $4 ; system("curl -O "$4)}' >/dev/null
mkdir -p /etc/nginx/conf_m2 && cd /etc/nginx/conf_m2/
curl ${MAGENX_NGINX_GITHUB_REPO_API}/conf_m2 2>&1 | awk -F'"' '/download_url/ {print $4 ; system("curl -O "$4)}' >/dev/null

# NGINX CONFIGURATION FOR DOMAIN
cp /etc/nginx/sites-available/magento2.conf  /etc/nginx/sites-available/${parameter["DOMAIN"]}.conf
ln -s /etc/nginx/sites-available/${parameter["DOMAIN"]}.conf /etc/nginx/sites-enabled/${parameter["DOMAIN"]}.conf
sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/sites-available/${parameter["DOMAIN"]}.conf

sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/nginx.conf
sed -i "s/set_real_ip_from.*127.0.0.1/set_real_ip_from ${parameter["CIDR"]}/" /etc/nginx/nginx.conf
sed -i "s,default.*production php-fpm,default unix:/var/run/php/${parameter["BRAND"]}.sock; # php-fpm,"  /etc/nginx/conf_m2/maps.conf
sed -i "s,default.*production app folder,default ${parameter["WEB_ROOT_PATH"]}; # magento folder," /etc/nginx/conf_m2/maps.conf

# MAGENTO PROFILER
sed -i "s/PROFILER_PLACEHOLDER/${parameter["PROFILER"]}/" /etc/nginx/conf_m2/maps.conf

# PHP_FPM POOL CONFIGURATION
cat <<END > /etc/php/${parameter["PHP_VERSION"]}/fpm/pool.d/${parameter["BRAND"]}.conf
[${parameter["BRAND"]}]

;;
;; Pool user
user = php-\$pool
group = php-\$pool

listen = /var/run/php/\$pool.sock
listen.owner = nginx
listen.group = php-\$pool
listen.mode = 0660

;;
;; Pool size and settings
pm = ondemand
pm.max_children = 100
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 10000

;;
;; [php ini] settings
php_admin_flag[expose_php] = Off
php_admin_flag[short_open_tag] = On
php_admin_flag[display_errors] = Off
php_admin_flag[log_errors] = On
php_admin_flag[mysql.allow_persistent] = On
php_admin_flag[mysqli.allow_persistent] = On
php_admin_value[default_charset] = "UTF-8"
php_admin_value[memory_limit] = 1024M
php_admin_value[max_execution_time] = 7200
php_admin_value[max_input_time] = 7200
php_admin_value[max_input_vars] = 50000
php_admin_value[post_max_size] = 64M
php_admin_value[upload_max_filesize] = 64M
php_admin_value[realpath_cache_size] = 4096k
php_admin_value[realpath_cache_ttl] = 86400
php_admin_value[session.gc_maxlifetime] = 28800
php_admin_value[error_log] = "/home/\$pool/public_html/var/log/php-fpm-error.log"
php_admin_value[date.timezone] = "${parameter["TIMEZONE"]}"
php_admin_value[upload_tmp_dir] = "/home/\$pool/public_html/var/tmp"
php_admin_value[sys_temp_dir] = "/home/\$pool/public_html/var/tmp"

;;
;; [opcache] settings
php_admin_flag[opcache.enable] = On
php_admin_flag[opcache.use_cwd] = On
php_admin_flag[opcache.validate_root] = On
php_admin_flag[opcache.revalidate_path] = Off
php_admin_flag[opcache.validate_timestamps] = Off
php_admin_flag[opcache.save_comments] = On
php_admin_flag[opcache.load_comments] = On
php_admin_flag[opcache.fast_shutdown] = On
php_admin_flag[opcache.enable_file_override] = Off
php_admin_flag[opcache.inherited_hack] = On
php_admin_flag[opcache.consistency_checks] = Off
php_admin_flag[opcache.protect_memory] = Off
php_admin_value[opcache.memory_consumption] = 512
php_admin_value[opcache.interned_strings_buffer] = 4
php_admin_value[opcache.max_accelerated_files] = 60000
php_admin_value[opcache.max_wasted_percentage] = 5
php_admin_value[opcache.file_update_protection] = 2
php_admin_value[opcache.optimization_level] = 0xffffffff
php_admin_value[opcache.blacklist_filename] = "/home/\$pool/opcache.blacklist"
php_admin_value[opcache.max_file_size] = 0
php_admin_value[opcache.force_restart_timeout] = 60
php_admin_value[opcache.error_log] = "/home/\$pool/public_html/var/log/opcache.log"
php_admin_value[opcache.log_verbosity_level] = 1
php_admin_value[opcache.preferred_memory_model] = ""
php_admin_value[opcache.jit_buffer_size] = 536870912
php_admin_value[opcache.jit] = 1235

env[MODE] = "production"
env[BRAND] = "${parameter["BRAND"]}"
env[DOMAIN] = "${parameter["DOMAIN"]}"
env[ADMIN_PATH] = "${parameter["ADMIN_PATH"]}"
env[REDIS_PASSWORD] = "${parameter["REDIS_PASSWORD"]}"
env[RABBITMQ_PASSWORD] = "${parameter["RABBITMQ_PASSWORD"]}"
env[INDEXER_PASSWORD] = "${parameter["INDEXER_PASSWORD"]}"
env[CRYPT_KEY] = "${parameter["CRYPT_KEY"]}"
env[GRAPHQL_ID_SALT] = "${parameter["GRAPHQL_ID_SALT"]}"
env[DATABASE_NAME] = "${parameter["DATABASE_NAME"]}"
env[DATABASE_USER] = "${parameter["DATABASE_USER"]}"
env[DATABASE_PASSWORD] = "${parameter["DATABASE_PASSWORD"]}"
env[CONFIGURATION_DATE] = "$(date -u "+%a, %d %b %Y %H:%M:%S %z")"

END


# TIMESTAMP TO BASH HISTORY
cat <<END >> ~/.bashrc
export HISTTIMEFORMAT="%d/%m/%y %T "
END


#################################
# ADMIN INSTANCE CONFIGURATION
#################################
if [ "${INSTANCE_NAME}" == "admin" ]; then

# ADD MAGENTO CRONJOB
BP_HASH="$(echo -n "${parameter["WEB_ROOT_PATH"]}" | openssl dgst -sha256 | awk '{print $2}')"
crontab -l -u ${parameter["PHP_USER"]} > /tmp/${parameter["PHP_USER"]}_crontab
tee -a /tmp/${parameter["PHP_USER"]}_crontab <<END
#~ MAGENTO START ${BP_HASH}
* * * * * /usr/bin/php${parameter["PHP_VERSION"]} ${parameter["WEB_ROOT_PATH"]}/bin/magento cron:run 2>&1 | grep -v "Ran jobs by schedule" >> ${parameter["WEB_ROOT_PATH"]}/var/log/magento.cron.log
#~ MAGENTO END ${BP_HASH}
END
crontab -u ${parameter["PHP_USER"]} /tmp/${parameter["PHP_USER"]}_crontab
rm /tmp/${parameter["PHP_USER"]}_crontab

# SUDO CONFIGURATION
tee -a /etc/sudoers <<END
${parameter["BRAND"]} ALL=(ALL) NOPASSWD: /usr/local/bin/cacheflush
END

# CREATE LOGROTATE
tee /etc/logrotate.d/${parameter["BRAND"]} <<END
${parameter["WEB_ROOT_PATH"]}/var/log/*.log
{
su ${parameter["BRAND"]} ${parameter["PHP_USER"]}
create 660 ${parameter["BRAND"]} ${parameter["PHP_USER"]}
weekly
rotate 2
notifempty
missingok
compress
}
END

curl -o /usr/local/bin/n98-magerun2 https://files.magerun.net/n98-magerun2.phar

tee /usr/local/bin/cacheflush <<END
#!/bin/bash
sudo -u \${SUDO_USER} n98-magerun2 --root-dir=/home/\${SUDO_USER}/public_html cache:flush
/usr/bin/systemctl restart php${parameter["PHP_VERSION"]}-fpm.service
nginx -t && /usr/bin/systemctl restart nginx.service || echo "[!] Error: check nginx config"
END

# COMPOSER INSTALLATION
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --${COMPOSER_VERSION} --install-dir=/usr/bin --filename=composer
php -r "unlink('composer-setup.php');"

# PHPMYADMIN CONFIGURATION
mkdir -p /usr/share/phpMyAdmin && cd $_
composer -n create-project phpmyadmin/phpmyadmin .
cp config.sample.inc.php config.inc.php
sed -i "s/.*blowfish_secret.*/\$cfg['blowfish_secret'] = '${parameter["BLOWFISH"]}';/" config.inc.php
sed -i "s|.*UploadDir.*|\$cfg['UploadDir'] = '/tmp/';|"  config.inc.php
sed -i "s|.*SaveDir.*|\$cfg['SaveDir'] = '/tmp/';|"  config.inc.php
sed -i "/SaveDir/a\
\$cfg['TempDir'] = '\/tmp\/';"  config.inc.php

sed -i "s/PHPMYADMIN_PLACEHOLDER/${parameter["PHPMYADMIN"]}/g" /etc/nginx/conf_m2/phpmyadmin.conf
	 	   
sed -i "s|^listen =.*|listen = /var/run/php/php${parameter["PHP_VERSION"]}-fpm.sock|" /etc/php/${parameter["PHP_VERSION"]}/fpm/pool.d/www.conf
sed -i "s/^listen.owner.*/listen.owner = nginx/" /etc/php/${parameter["PHP_VERSION"]}/fpm/pool.d/www.conf
sed -i "s|127.0.0.1:9000|unix:/var/run/php/php${parameter["PHP_VERSION"]}-fpm.sock|"  /etc/nginx/conf_m2/phpmyadmin.conf


fi

cat <<END > /home/${parameter["BRAND"]}/.env
MODE="production"
BRAND="${parameter["BRAND"]}"
DOMAIN="${parameter["DOMAIN"]}"
ADMIN_PATH="${parameter["ADMIN_PATH"]}"
REDIS_PASSWORD="${parameter["REDIS_PASSWORD"]}"
RABBITMQ_PASSWORD="${parameter["RABBITMQ_PASSWORD"]}"
INDEXER_PASSWORD="${parameter["INDEXER_PASSWORD"]}"
CRYPT_KEY="${parameter["CRYPT_KEY"]}"
GRAPHQL_ID_SALT="${parameter["GRAPHQL_ID_SALT"]}"
DATABASE_NAME="${parameter["DATABASE_NAME"]}"
DATABASE_USER="${parameter["DATABASE_USER"]}"
DATABASE_PASSWORD="${parameter["DATABASE_PASSWORD"]}"
CONFIGURATION_DATE="$(date -u "+%a, %d %b %Y %H:%M:%S %z")"
END

cat <<END > /usr/local/bin/vhost-config
#!/bin/bash
. /usr/local/bin/metadata
sed -i "s/listen 80;/listen \${INSTANCE_IP}:80;/" /etc/nginx/sites-available/${parameter["DOMAIN"]}.conf
sed -i "s/localhost/\${INSTANCE_IP}/g" /etc/varnish/default.vcl
systemctl restart varnish nginx php${parameter["PHP_VERSION"]}-fpm
END

cat <<END > /etc/systemd/system/vhost-config.service
[Unit]
Description=Configure instance IP address
Requires=network-online.target
After=network-online.target

[Service]
Type=oneshot
KillMode=process
RemainAfterExit=no

ExecStart=/usr/local/bin/vhost-config

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable vhost-config.service

fi

###################################################################################

. /tmp/build_footer.sh
