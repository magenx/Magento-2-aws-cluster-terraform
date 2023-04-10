#!/bin/bash

## debug
if [ -z "${_PARAMETERSTORE_NAME}" ]; then
echo "_PARAMETERSTORE_NAME is empty"
exit 1
fi

## remove old aws cli v1
apt-get -y remove awscli
apt-get update
apt-get -qqy install jq unzip

## get latest aws cli v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip -d /root/
rm awscliv2.zip
/root/aws/install --bin-dir /usr/bin --install-dir /root/aws --update
rm -rf /root/aws/{dist,install}

## get environment variables from aws parameter store
_PARAMETER=$(aws ssm get-parameter --name "${_PARAMETERSTORE_NAME}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$key"]="$value"; done < <(echo ${_PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')

## installation
apt-get -qqy install ${parameter["LINUX_PACKAGES"]}
pip3 install git-remote-codecommit

## create user
useradd -d /home/${parameter["BRAND"]} -s /sbin/nologin ${parameter["BRAND"]}
## create root php user
useradd -M -s /sbin/nologin -d /home/${parameter["BRAND"]} ${parameter["PHP_USER"]}
usermod -g ${parameter["PHP_USER"]} ${parameter["BRAND"]}
 
mkdir -p ${parameter["WEB_ROOT_PATH"]}
chmod 711 /home/${parameter["BRAND"]}
chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} ${parameter["WEB_ROOT_PATH"]}
chmod 2750 ${parameter["WEB_ROOT_PATH"]} /home/${parameter["BRAND"]}/{.config,.cache,.local,.composer}
setfacl -R -m m:rx,u:${parameter["BRAND"]}:rwX,g:${parameter["PHP_USER"]}:r-X,o::-,d:u:${parameter["BRAND"]}:rwX,d:g:${parameter["PHP_USER"]}:r-X,d:o::- ${parameter["WEB_ROOT_PATH"]}

## add EFS mount
mkdir -p /mnt/efs
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${parameter["EFS_DNS_TARGET"]}:/ /mnt/efs
mkdir -p /mnt/efs/data/{var,pub/media}
chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} /mnt/efs/
find /mnt/efs -type d -exec chmod 2770 {} \;
umount /mnt/efs

echo "${parameter["EFS_DNS_TARGET"]}:/data/var ${parameter["WEB_ROOT_PATH"]}/var nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
echo "${parameter["EFS_DNS_TARGET"]}:/data/pub/media ${parameter["WEB_ROOT_PATH"]}/pub/media nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab

mkdir -p ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}
chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} ${parameter["WEB_ROOT_PATH"]}/
chmod 2770 ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}

## install nginx
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list

## install php + phpmyadmin
wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/nginx.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/php.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

_PHP_PACKAGES+=(${parameter["PHP_PACKAGES"]})
apt-get -qqy install nginx php-pear php${parameter["PHP_VERSION"]} ${_PHP_PACKAGES[@]/#/php${parameter["PHP_VERSION"]}-}

setfacl -R -m u:nginx:r-X,d:u:nginx:r-X ${parameter["WEB_ROOT_PATH"]}

cat > /etc/sysctl.conf <<END
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

for dir in cli fpm
do
cat > /etc/php/${parameter["PHP_VERSION"]}/$dir/conf.d/zz-magenx-overrides.ini <<END
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

cat >> ${parameter["PHP_FPM_POOL"]} <<END
;;
;; Custom pool settings
[${parameter["BRAND"]}]

;;
;; Pool user
user = php-\$pool
group = php-\$pool

listen = /var/run/\$pool.sock
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
php_admin_value[date.timezone] = "${TIMEZONE}"
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
END

if [ "${parameter["FASTLY"]}" == "disabled" ] && [ "${_INSTANCE_NAME}" != "admin" ]; then

apt-get -qqy install varnish

cd /etc/varnish

git init
git remote add origin ${parameter["GITHUB_SERVICES_REPO"]}
git fetch
git reset --hard origin/varnish
git checkout -t origin/varnish

cp varnish.service /etc/systemd/system/

fi

cd /etc/nginx
git init
git remote add origin ${parameter["GITHUB_SERVICES_REPO"]}
git fetch
git reset --hard origin/nginx_${_INSTANCE_NAME}
git checkout -t origin/nginx_${_INSTANCE_NAME}

if [ "${_INSTANCE_NAME}" == "admin" ]; then
debconf-set-selections <<< "phpmyadmin phpmyadmin/internal/skip-preseed boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"

apt-get -qqy install composer mariadb-client phpmyadmin
 
cp /usr/share/phpmyadmin/config.sample.inc.php /etc/phpmyadmin/config.inc.php
sed -i "s/.*blowfish_secret.*/\$cfg['blowfish_secret'] = '${parameter["BLOWFISH"]}';/" /etc/phpmyadmin/config.inc.php
sed -i "s/localhost/${parameter["DATABASE_ENDPOINT"]}/" /etc/phpmyadmin/config.inc.php
sed -i "s/PHPMYADMIN_PLACEHOLDER/${parameter["MYSQL_PATH"]}/g" /etc/nginx/conf.d/phpmyadmin.conf
sed -i "s,#include conf.d/phpmyadmin.conf;,include conf.d/phpmyadmin.conf;," /etc/nginx/sites-available/magento.conf
 
cat > /etc/logrotate.d/magento <<END
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
fi

mkdir -p /etc/nginx/sites-enabled
ln -s /etc/nginx/sites-available/magento.conf /etc/nginx/sites-enabled/magento.conf
 
sed -i "s,VPC_CIDR,${parameter["VPC_CIDR"]}," /etc/nginx/nginx.conf
sed -i "s/HEALTH_CHECK_LOCATION/${parameter["HEALTH_CHECK_LOCATION"]}/" /etc/nginx/sites-available/magento.conf
sed -i "s,/var/www/html,${parameter["WEB_ROOT_PATH"]},g" /etc/nginx/conf.d/maps.conf
sed -i "s/PROFILER_PLACEHOLDER/${parameter["PROFILER"]}/" /etc/nginx/conf.d/maps.conf
echo '' > /etc/nginx/conf.d/default.conf
 
sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/sites-available/magento.conf
sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/nginx.conf
 
timedatectl set-timezone ${parameter["TIMEZONE"]}
 
cd /tmp

wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazoncloudwatch-agent-${parameter["AWS_DEFAULT_REGION"]}/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${_INSTANCE_NAME}.json

chmod 750 /usr/bin/aws /root/aws
apt-get clean

