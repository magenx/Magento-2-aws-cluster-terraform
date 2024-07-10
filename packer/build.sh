#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#

AWSTOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: ${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: ${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-type)

# get parameters
sudo apt-get update
sudo apt-get -qqy install jq

sudo sh -c "echo 'export PARAMETERSTORE_NAME=${PARAMETERSTORE_NAME}' >> /root/.bashrc"
PARAMETER=$(sudo aws ssm get-parameter --name "${PARAMETERSTORE_NAME}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$key"]="$value"; done < <(echo ${PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')

## installation
sudo apt-get -qqy install ${parameter["LINUX_PACKAGES"]}
sudo pip3 install git-remote-codecommit
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
. "$HOME/.cargo/env"

# # ---------------------------------------------------------------------------------------------------------------------#
# Frontend and admin instance configuration
# # ---------------------------------------------------------------------------------------------------------------------#

if [ "${parameter["INSTANCE_NAME"]}" != "varnish" ]; then
## create user
sudo useradd -d /home/${parameter["BRAND"]} -s /sbin/nologin ${parameter["BRAND"]}
## create root php user
sudo useradd -M -s /sbin/nologin -d /home/${parameter["BRAND"]} ${parameter["PHP_USER"]}
sudo usermod -g ${parameter["PHP_USER"]} ${parameter["BRAND"]}
 
sudo mkdir -p ${parameter["WEB_ROOT_PATH"]}
sudo chmod 711 /home/${parameter["BRAND"]}
sudo mkdir -p /home/${parameter["BRAND"]}/{.config,.cache,.local,.composer}
sudo chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} ${parameter["WEB_ROOT_PATH"]}
sudo chown -R ${parameter["BRAND"]}:${parameter["BRAND"]} /home/${parameter["BRAND"]}/{.config,.cache,.local,.composer}
sudo chmod 2750 ${parameter["WEB_ROOT_PATH"]} /home/${parameter["BRAND"]}/{.config,.cache,.local,.composer}
sudo setfacl -R -m m:rx,u:${parameter["BRAND"]}:rwX,g:${parameter["PHP_USER"]}:r-X,o::-,d:u:${parameter["BRAND"]}:rwX,d:g:${parameter["PHP_USER"]}:r-X,d:o::- ${parameter["WEB_ROOT_PATH"]}


sudo sh -c "cat > /home/${parameter["BRAND"]}/.env <<END
MODE="production"
DOMAIN="${parameter["BRAND"]}"
ADMIN_PATH="${parameter["BRAND"]}"
EXTERNAL_ALB_DNS_NAME="${parameter["EXTERNAL_ALB_DNS_NAME"]}"
INTERNAL_ALB_DNS_NAME="${parameter["INTERNAL_ALB_DNS_NAME"]}"
SES_ENDPOINT="${parameter["SES_ENDPOINT"]}"
REDIS_CACHE_BACKEND="${parameter["REDIS_CACHE_BACKEND"]}"
REDIS_SESSION_BACKEND="${parameter["REDIS_SESSION_BACKEND"]}"
REDIS_CACHE_BACKEND_RO="${parameter["REDIS_CACHE_BACKEND_RO"]}"
REDIS_SESSION_BACKEND_RO="${parameter["REDIS_SESSION_BACKEND_RO"]}"
REDIS_PASSWORD="${parameter["REDIS_PASSWORD"]}"
RABBITMQ_ENDPOINT="${parameter["RABBITMQ_ENDPOINT"]}"
RABBITMQ_PASSWORD="${parameter["RABBITMQ_PASSWORD"]}"
CRYPT_KEY="${parameter["CRYPT_KEY"]}"
GRAPHQL_ID_SALT="${parameter["GRAPHQL_ID_SALT"]}"
DATABASE_ENDPOINT="${parameter["DATABASE_ENDPOINT"]}"
DATABASE_NAME="${parameter["DATABASE_NAME"]}"
DATABASE_USER="${parameter["DATABASE_USER"]}"
DATABASE_PASSWORD="${parameter["DATABASE_PASSWORD"]}"
OPENSEARCH_ENDPOINT="${parameter["OPENSEARCH_ENDPOINT"]}"
OPENSEARCH_ADMIN="${parameter["OPENSEARCH_ADMIN"]}"
INDEXER_PASSWORD="${parameter["INDEXER_PASSWORD"]}"
ENV_DATE="$(date -u "+%a, %d %b %Y %H:%M:%S %z")"
END
"

cd /tmp
sudo git clone https://github.com/aws/efs-utils
cd efs-utils
sudo ./build-deb.sh
sudo apt-get -y install ./build/amazon-efs-utils*deb
sudo rm -rf ~/.cargo ~/.rustup

sudo sh -c "echo '${parameter["EFS_SYSTEM_ID"]}:/ ${parameter["WEB_ROOT_PATH"]}/var efs _netdev,noresvport,tls,iam,accesspoint=${parameter["EFS_ACCESS_POINT_VAR"]} 0 0' >> /etc/fstab"
sudo sh -c "echo '${parameter["EFS_SYSTEM_ID"]}:/ ${parameter["WEB_ROOT_PATH"]}/pub/media efs _netdev,noresvport,tls,iam,accesspoint=${parameter["EFS_ACCESS_POINT_MEDIA"]} 0 0' >> /etc/fstab"

sudo mkdir -p ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}
sudo chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} ${parameter["WEB_ROOT_PATH"]}/
sudo chmod 2770 ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}

## install nginx
curl https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list'

## install php + phpmyadmin
sudo wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

sudo apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/nginx.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
sudo apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/php.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

_PHP_PACKAGES+=(${parameter["PHP_PACKAGES"]})
sudo apt-get -qqy install nginx php-pear php${parameter["PHP_VERSION"]} ${_PHP_PACKAGES[@]/#/php${parameter["PHP_VERSION"]}-}

sudo setfacl -R -m u:nginx:r-X,d:u:nginx:r-X ${parameter["WEB_ROOT_PATH"]}

sudo sh -c "cat > /etc/sysctl.conf <<END
fs.file-max = 1000000
fs.inotify.max_user_watches = 1000000
vm.swappiness = 5
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
"

sudo sh -c "cat > ${parameter["PHP_FPM_POOL"]} <<END
[${parameter["BRAND"]}]

;;
;; Pool user
user = php-${parameter["BRAND"]}
group = php-${parameter["BRAND"]}

listen = /var/run/${parameter["BRAND"]}.sock
listen.owner = nginx
listen.group = php-${parameter["BRAND"]}
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
php_admin_value[error_log] = "${parameter["WEB_ROOT_PATH"]}/var/log/php-fpm-error.log"
php_admin_value[date.timezone] = "${parameter["TIMEZONE"]}"
php_admin_value[upload_tmp_dir] = "${parameter["WEB_ROOT_PATH"]}/var/tmp"
php_admin_value[sys_temp_dir] = "${parameter["WEB_ROOT_PATH"]}/var/tmp"

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
php_admin_value[opcache.blacklist_filename] = "/etc/php/${parameter["PHP_VERSION"]}/fpm/conf.d/opcache.blacklist"
php_admin_value[opcache.max_file_size] = 0
php_admin_value[opcache.force_restart_timeout] = 60
php_admin_value[opcache.error_log] = "${parameter["WEB_ROOT_PATH"]}/var/log/opcache.log"
php_admin_value[opcache.log_verbosity_level] = 1
php_admin_value[opcache.preferred_memory_model] = ""
php_admin_value[opcache.jit_buffer_size] = 536870912
php_admin_value[opcache.jit] = 1235
END
"

sudo sh -c "cat > /etc/php/${parameter["PHP_VERSION"]}/cli/conf.d/zz-${parameter["BRAND"]}-overrides.ini <<END
opcache.enable_cli = 1
opcache.memory_consumption = 512
opcache.interned_strings_buffer = 4
opcache.max_accelerated_files = 60000
opcache.max_wasted_percentage = 5
opcache.use_cwd = 1
opcache.validate_timestamps = 0
;opcache.revalidate_freq = 2
;opcache.validate_permission = 1
opcache.validate_root = 1
opcache.file_update_protection = 2
opcache.revalidate_path = 0
opcache.save_comments = 1
opcache.load_comments = 1
opcache.fast_shutdown = 1
opcache.enable_file_override = 0
opcache.optimization_level = 0xffffffff
opcache.inherited_hack = 1
opcache.blacklist_filename=/etc/php/${parameter["PHP_VERSION"]}/cli/conf.d/opcache.blacklist
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
"
cd /etc/nginx
sudo git init
sudo git remote add origin ${parameter["CODECOMMIT_SERVICES_REPO"]}
sudo git fetch
sudo git reset --hard origin/nginx_${INSTANCE_NAME}
sudo git checkout -t origin/nginx_${INSTANCE_NAME}

if [ "${INSTANCE_NAME}" == "admin" ]; then
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/internal/skip-preseed boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"

sudo apt-get -qqy install composer mariadb-client phpmyadmin
 
sudo sh -c "cp /usr/share/phpmyadmin/config.sample.inc.php /etc/phpmyadmin/config.inc.php"
sudo sed -i "s/.*blowfish_secret.*/\$cfg['blowfish_secret'] = '${parameter["BLOWFISH"]}';/" /etc/phpmyadmin/config.inc.php
sudo sed -i "s/localhost/${parameter["DATABASE_ENDPOINT"]}/" /etc/phpmyadmin/config.inc.php
sudo sed -i "s/PHPMYADMIN_PLACEHOLDER/${parameter["MYSQL_PATH"]}/g" /etc/nginx/conf.d/phpmyadmin.conf
sudo sed -i "s,#include conf.d/phpmyadmin.conf;,include conf.d/phpmyadmin.conf;," /etc/nginx/sites-available/magento.conf
 
sudo sh -c "cat > /etc/logrotate.d/magento <<END
${parameter["WEB_ROOT_PATH"]}/var/log/*.log
{
su ${parameter["BRAND"]} ${parameter["PHP_USER"]}
create 660 ${parameter["BRAND"]} ${parameter["PHP_USER"]}
daily
rotate 7
notifempty
missingok
compress
}
END
"
fi

sudo mkdir -p /etc/nginx/sites-enabled
sudo ln -s /etc/nginx/sites-available/magento.conf /etc/nginx/sites-enabled/magento.conf
 
sudo sed -i "s,CIDR,${parameter["CIDR"]}," /etc/nginx/nginx.conf
sudo sed -i "s/HEALTH_CHECK_LOCATION/${parameter["HEALTH_CHECK_LOCATION"]}/" /etc/nginx/sites-available/magento.conf
sudo sed -i "s,/var/www/html,${parameter["WEB_ROOT_PATH"]},g" /etc/nginx/conf.d/maps.conf
sudo sed -i "s/PROFILER_PLACEHOLDER/${parameter["PROFILER"]}/" /etc/nginx/conf.d/maps.conf
sudo sh -c "echo '' > /etc/nginx/conf.d/default.conf"
 
sudo sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/sites-available/magento.conf
sudo sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/nginx.conf

fi

# # ---------------------------------------------------------------------------------------------------------------------#
# Varnish instance configuration
# # ---------------------------------------------------------------------------------------------------------------------#

if [ "${INSTANCE_NAME}" == "varnish" ]; then
## install nginx
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list'
sudo apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/nginx.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

sudo apt-get -qqy install varnish nginx nginx-module-geoip

sudo systemctl stop nginx varnish

cd /etc/varnish
sudo git init
sudo git remote add origin ${parameter["CODECOMMIT_SERVICES_REPO"]}
sudo git fetch
sudo git reset --hard origin/varnish
sudo git checkout -t origin/varnish

sudo uuidgen > /etc/varnish/secret

cd /etc/systemd/system/
sudo git init
sudo git remote add origin ${parameter["CODECOMMIT_SERVICES_REPO"]}
sudo git fetch
sudo git reset --hard origin/systemd_varnish
sudo git checkout -t origin/systemd_varnish

cd /etc/nginx
sudo git init
sudo git remote add origin ${parameter["CODECOMMIT_SERVICES_REPO"]}
sudo git fetch
sudo git reset --hard origin/nginx_varnish
sudo git checkout -t origin/nginx_varnish

sudo sed -i "s,CIDR,${parameter["CIDR"]}," /etc/nginx/nginx.conf
sudo sed -i "s/RESOLVER/${parameter["RESOLVER"]}/" /etc/nginx/nginx.conf
sudo sed -i "s/DOMAIN/${parameter["DOMAIN"]} ${parameter["STAGING_DOMAIN"]}/" /etc/nginx/nginx.conf
sudo sed -i "s/MAGENX_HEADER/${parameter["MAGENX_HEADER"]}/" /etc/nginx/nginx.conf
sudo sed -i "s/HEALTH_CHECK_LOCATION/${parameter["HEALTH_CHECK_LOCATION"]}/" /etc/nginx/nginx.conf
sudo sed -i "s/ALB_DNS_NAME/${parameter["ALB_DNS_NAME"]}/" /etc/nginx/conf.d/alb.conf
sudo sed -i "s/example.com/${parameter["DOMAIN"]}/" /etc/nginx/conf.d/maps.conf

fi

sudo timedatectl set-timezone ${parameter["TIMEZONE"]}
 
cd /tmp
sudo wget https://aws-codedeploy-${parameter["AWS_DEFAULT_REGION"]}.s3.amazonaws.com/latest/install
sudo chmod +x ./install
sudo ./install auto
 
sudo wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazon-ssm-${parameter["AWS_DEFAULT_REGION"]}/latest/debian_arm64/amazon-ssm-agent.deb
sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent

sudo wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazoncloudwatch-agent-${parameter["AWS_DEFAULT_REGION"]}/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${INSTANCE_NAME}.json

sudo apt-get remove --purge -y \
    awscli* \
    apache2* \
    bind9* \
    samba* \
    avahi-daemon \
    cups* \
    exim4* \
    postfix* \
    telnet \
    aptitude \
    unzip \
    xserver-xorg* \
    x11-common \
    gnome* \
    kde* \
    xfce* \
    lxqt*

sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove --purge -y
