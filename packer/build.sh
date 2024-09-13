#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#
SELF=$(basename $0)
MAGENX_VERSION=$(curl -s https://api.github.com/repos/magenx/Magento-2-server-installation/tags 2>&1 | head -3 | grep -oP '(?<=")\d.*(?=")')
MAGENX_BASE="https://magenx.sh"

###################################################################################
###                              REPOSITORY AND PACKAGES                        ###
###################################################################################

# Github installation repository raw url
MAGENX_INSTALL_GITHUB_REPO="https://raw.githubusercontent.com/magenx/Magento-2-server-installation/master"

## Version lock
COMPOSER_VERSION="2.4"
RABBITMQ_VERSION="3.12*"
MARIADB_VERSION="10.11"
OPENSEARCH_VERSION="2.x"
VARNISH_VERSION="73"
REDIS_VERSION="7"

# Repositories
MARIADB_REPO_CONFIG="https://downloads.mariadb.com/MariaDB/mariadb_repo_setup"

# Nginx configuration
NGINX_VERSION=$(curl -s http://nginx.org/en/download.html | grep -oP '(?<=gz">nginx-).*?(?=</a>)' | head -1)
MAGENX_NGINX_GITHUB_REPO="https://raw.githubusercontent.com/magenx/Magento-nginx-config/master/"
MAGENX_NGINX_GITHUB_REPO_API="https://api.github.com/repos/magenx/Magento-nginx-config/contents/magento2"

# WebStack Packages .deb
WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* ufw varnish* certbot* redis* webmin"

###################################################################################
###                              CLEANUP AND SET TIMEZONE                       ###
###################################################################################
## Debian

# check if web stack is clean and clean it
installed_packages="$(apt -qq list --installed ${WEB_STACK_CHECK} 2> /dev/null | cut -d'/' -f1 | tr '\n' ' ')"
if [ ! -z "$installed_packages" ]; then
apt -qq -y remove --purge "${installed_packages}"
fi

###################################################################################
###                               GET PARAMETERSTORE                            ###
###################################################################################

# get parameters
apt-get -qqy update
apt-get -qqy install jq

PARAMETER=$(aws ssm get-parameter --name "${PARAMETERSTORE}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$key"]="$value"; done < <(echo ${PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')

###################################################################################
###                              VARIABLES CONSTRUCTOR                          ###
###################################################################################

OPENSEARCH_ENDPOINT="opensearch.${parameter["BRAND"]}.internal"
REDIS_ENDPOINT="redis.${parameter["BRAND"]}.internal"
RABBITMQ_ENDPOINT="rabbitmq.${parameter["BRAND"]}.internal"
DATABASE_ENDPOINT="mariadb.${parameter["BRAND"]}.internal"

cat <<END > /usr/local/bin/metadata
#!/bin/bash
# Fetch metadata
AWSTOKEN=\$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 600")
INSTANCE_ID=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-type)
INSTANCE_IP=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/local-ipv4)

# Export variables
export INSTANCE_ID="\${INSTANCE_ID}"
export INSTANCE_TYPE="\${INSTANCE_TYPE}"
export INSTANCE_IP="\${INSTANCE_IP}"
END
chmod +x /usr/local/bin/metadata

###################################################################################
###                          LEMP WEB STACK INSTALLATION                        ###
###################################################################################

# configure system/magento timezone
ln -fs /usr/share/zoneinfo/${parameter["TIMEZONE"]} /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

if [ "${INSTANCE_NAME}" == "mariadb" ]; then
# ATTACH VOLUME
. /usr/local/bin/metadata
aws ec2 attach-volume --volume-id ${MARIADB_DATA_VOLUME} --instance-id ${INSTANCE_ID} --device /dev/xvdb
aws ec2 wait volume-in-use --volume-ids ${MARIADB_DATA_VOLUME}
sleep 5
FSTYPE=$(blkid -o value -s TYPE /dev/xvdb)
if [ -z "${FSTYPE}" ] || [ "${FSTYPE}" != "ext4" ]; then
mkfs.ext4 /dev/xvdb
fi
while [ ! -e /dev/xvdb ]; do sleep 1; done && mkdir -p /var/lib/mysql && mount /dev/xvdb /var/lib/mysql
UUID=$(blkid -s UUID -o value /dev/xvdb)
if [ -z "$UUID" ]; then
    echo "UUID is empty. ERROR."
    exit 1
fi
echo "UUID=${UUID} /var/lib/mysql ext4 defaults,nofail 0 2" >> /etc/fstab
# MARIADB INSTALLATION
curl -sS ${MARIADB_REPO_CONFIG} | bash -s -- --mariadb-server-version="mariadb-${MARIADB_VERSION}" --skip-maxscale --skip-verify --skip-eol-check
apt -qq update
apt -qq -y install mariadb-server bc
systemctl enable mariadb
curl -sSo /etc/my.cnf https://raw.githubusercontent.com/magenx/magento-mysql/master/my.cnf/my.cnf
INNODB_BUFFER_POOL_SIZE=$(echo "0.90*$(awk '/MemTotal/ { print $2 / (1024*1024)}' /proc/meminfo | cut -d'.' -f1)" | bc | xargs printf "%1.0f")
if [ "${INNODB_BUFFER_POOL_SIZE}" == "0" ]; then INNODB_BUFFER_POOL_SIZE=1; fi
sed -i "s/innodb_buffer_pool_size = 4G/innodb_buffer_pool_size = ${INNODB_BUFFER_POOL_SIZE}G/" /etc/my.cnf
systemctl restart mariadb
sleep 5
mariadb --connect-expired-password  <<EOMYSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY "${parameter["DATABASE_ROOT_PASSWORD"]}";
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
exit
EOMYSQL

cat > /root/.my.cnf <<END
[client]
user=root
password="${parameter["DATABASE_ROOT_PASSWORD"]}"
END

cat > /root/.mytop <<END
user=root
pass=${parameter["DATABASE_ROOT_PASSWORD"]}
db=mysql
END

chmod 600 /root/.my.cnf /root/.mytop

mariadb <<EOMYSQL
CREATE USER '${parameter["DATABASE_USER"]}'@'${parameter["CIDR"]/0.0\/16/%}' IDENTIFIED BY '${parameter["DATABASE_PASSWORD"]}';
CREATE DATABASE IF NOT EXISTS ${parameter["DATABASE_NAME"]};
GRANT ALL PRIVILEGES ON ${parameter["DATABASE_NAME"]}.* TO '${parameter["DATABASE_USER"]}'@'${parameter["CIDR"]/0.0\/16/%}' WITH GRANT OPTION;
exit
EOMYSQL

sed -i "s/bind-address = 127.0.0.1/bind-address = ${DATABASE_ENDPOINT}/" /etc/my.cnf

cat <<END > /etc/systemd/system/attach-ebs-volume.service
[Unit]
Description=Attach EBS Volume for MariaDB
Before=mariadb.service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'aws ec2 attach-volume --volume-id ${MARIADB_DATA_VOLUME} --instance-id \${INSTANCE_ID} --device /dev/xvdb && while [ ! -e /dev/xvdb ]; do sleep 1; done && mount /dev/xvdb /var/lib/mysql'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
END

cat <<END > /etc/systemd/system/detach-ebs-volume.service
[Unit]
Description=Detach EBS volume on shutdown
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'aws ec2 detach-volume --volume-id ${MARIADB_DATA_VOLUME}'

[Install]
WantedBy=halt.target reboot.target shutdown.target
END

systemctl enable attach-ebs-volume.service
systemctl enable detach-ebs-volume.service

fi


if [ "${INSTANCE_NAME}" == "redis" ]; then
# REDIS INSTALLATION
curl -fL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/redis.list

apt -qq update
apt -qq -y install redis   

systemctl stop redis-server
systemctl disable redis-server

# Create Redis config
cat > /etc/systemd/system/redis@.service <<END
[Unit]
Description=Advanced key-value store for %i
After=network.target

[Service]
Type=notify
User=redis
Group=redis

# Security options
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadOnlyPaths=/

# Resource limits
LimitNOFILE=65535

# Directories to create and permissions
RuntimeDirectory=redis
RuntimeDirectoryMode=2755
UMask=007

# Directories and files that Redis can read and write
ReadWritePaths=-/var/lib/redis
ReadWritePaths=-/var/log/redis
ReadWritePaths=-/run/redis

# Command-line options
PIDFile=/run/redis/%i.pid
ExecStartPre=/usr/bin/test -f /etc/redis/%i.conf
ExecStart=/usr/bin/redis-server /etc/redis/%i.conf --daemonize yes --supervised systemd

# Timeouts
Restart=on-failure
TimeoutStartSec=5s
TimeoutStopSec=5s

[Install]
WantedBy=multi-user.target

END

mkdir -p /var/lib/redis
chmod 750 /var/lib/redis
chown redis /var/lib/redis
mkdir -p /etc/redis/
rm /etc/redis/redis.conf

PORT=6379

for SERVICE in session cache
do
if [ "${SERVICE}" = "session" ]; then
# Perfect options for sessions
CONFIG_OPTIONS="
save 900 1
save 300 10
save 60 10000

appendonly yes
appendfsync everysec"
else
# Default options for cache
CONFIG_OPTIONS="save \"\""
fi

cat > /etc/redis/${SERVICE}.conf<<END

bind ${REDIS_ENDPOINT}
port ${PORT}

daemonize yes
supervised auto
protected-mode yes
timeout 0

requirepass ${parameter["REDIS_PASSWORD"]}

dir /var/lib/redis
logfile /var/log/redis/${SERVICE}.log
pidfile /run/redis/${SERVICE}.pid

${CONFIG_OPTIONS}

maxmemory 1024mb
maxmemory-policy allkeys-lru

lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
lazyfree-lazy-user-del yes

rename-command SLAVEOF ""
rename-command CONFIG ""
rename-command PUBLISH ""
rename-command SAVE ""
rename-command SHUTDOWN ""
rename-command DEBUG ""
rename-command BGSAVE ""
rename-command BGREWRITEAOF ""
END

((PORT++))

chown redis /etc/redis/${SERVICE}.conf
chmod 640 /etc/redis/${SERVICE}.conf

systemctl daemon-reload
systemctl enable redis@${SERVICE}
done

fi


if [ "${INSTANCE_NAME}" == "rabbitmq" ]; then
# RABBITMQ INSTALLATION
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/setup.deb.sh' | bash
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/setup.deb.sh' | bash
apt -qq -y install rabbitmq-server=${RABBITMQ_VERSION}

systemctl stop rabbitmq-server
systemctl stop epmd*
epmd -kill

cat > /etc/rabbitmq/rabbitmq-env.conf <<END
NODENAME=rabbit@localhost
NODE_IP_ADDRESS=127.0.0.1
ERL_EPMD_ADDRESS=127.0.0.1
PID_FILE=/var/lib/rabbitmq/mnesia/rabbitmq_pid
END

echo '[{kernel, [{inet_dist_use_interface, {127,0,0,1}}]},{rabbit, [{tcp_listeners, [{"127.0.0.1", 5672}]}]}].' > /etc/rabbitmq/rabbitmq.config

cat >> /etc/sysctl.conf <<END
net.ipv6.conf.lo.disable_ipv6 = 0
END

sysctl -q -p

cat > /etc/systemd/system/epmd.service <<END
[Unit]
Description=Erlang Port Mapper Daemon
After=network.target
Requires=epmd.socket

[Service]
ExecStart=/usr/bin/epmd -address 127.0.0.1 -daemon
Type=simple
StandardOutput=journal
StandardError=journal
User=epmd
Group=epmd

[Install]
Also=epmd.socket
WantedBy=multi-user.target
END

cat > /etc/systemd/system/epmd.socket <<END
[Unit]
Description=Erlang Port Mapper Daemon Activation Socket

[Socket]
ListenStream=4369
BindIPv6Only=both
Accept=no

[Install]
WantedBy=sockets.target
END

systemctl daemon-reload
systemctl start rabbitmq-server
rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbitmq_pid
sleep 5

# delete guest user
rabbitmqctl delete_user guest

# generate rabbitmq user permissions
rabbitmqctl add_user ${parameter["BRAND"]} ${parameter["RABBITMQ_PASSWORD"]}
rabbitmqctl set_permissions -p / ${parameter["BRAND"]} ".*" ".*" ".*"

apt-mark hold erlang rabbitmq-server

fi


if [ "${INSTANCE_NAME}" == "opensearch" ]; then
# OPENSEARCH INSTALLATION
curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring
echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch/${OPENSEARCH_VERSION}/apt stable main" > /etc/apt/sources.list.d/opensearch-${OPENSEARCH_VERSION}.list
apt -qq -y update
env OPENSEARCH_INITIAL_ADMIN_PASSWORD=${parameter["OPENSEARCH_PASSWORD"]} apt -qq -y install opensearch

echo "${INSTANCE_IP} ${OPENSEARCH_ENDPOINT}" >> /etc/hosts

## opensearch settings
cp /etc/opensearch/opensearch.yml /etc/opensearch/opensearch.yml_default
cat > /etc/opensearch/opensearch.yml <<END
#--------------------------------------------------------------------#
#----------------------- MAGENX CONFIGURATION -----------------------#
# -------------------------------------------------------------------#
# original config saved: /etc/opensearch/opensearch.yml_default

cluster.name: ${parameter["BRAND"]}
node.name: ${parameter["BRAND"]}-node1
node.attr.rack: r1
node.max_local_storage_nodes: 1

discovery.type: single-node

path.data: /var/lib/opensearch
path.logs: /var/log/opensearch

network.host: ${OPENSEARCH_ENDPOINT}
http.port: 9200

# WARNING: revise all the lines below before you go into production
plugins.security.ssl.transport.pemcert_filepath: esnode.pem
plugins.security.ssl.transport.pemkey_filepath: esnode-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: root-ca.pem

plugins.security.ssl.transport.enforce_hostname_verification: false
plugins.security.ssl.http.enabled: false
plugins.security.allow_unsafe_democertificates: true
plugins.security.allow_default_init_securityindex: true

plugins.security.audit.type: internal_opensearch
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.restapi.roles_enabled: ["all_access", "security_rest_api_access"]
plugins.security.system_indices.enabled: true
plugins.security.system_indices.indices: [".plugins-ml-config", ".plugins-ml-connector", ".plugins-ml-model-group", ".plugins-ml-model", ".plugins-ml-task", ".plugins-ml-conversation-meta", ".plugins-ml-conversation-interactions", ".opendistro-alerting-config", ".opendistro-alerting-alert*", ".opendistro-anomaly-results*", ".opendistro-anomaly-detector*", ".opendistro-anomaly-checkpoints", ".opendistro-anomaly-detection-state", ".opendistro-reports-*", ".opensearch-notifications-*", ".opensearch-notebooks", ".opensearch-observability", ".ql-datasources", ".opendistro-asynchronous-search-response*", ".replication-metadata-store", ".opensearch-knn-models", ".geospatial-ip2geo-data*"]

END

## OpenSearch settings
sed -i "s/.*-Xms.*/-Xms512m/" /etc/opensearch/jvm.options
sed -i "s/.*-Xmx.*/-Xmx1024m/" /etc/opensearch/jvm.options

chown -R :opensearch /etc/opensearch/*
systemctl daemon-reload
systemctl enable opensearch.service
systemctl restart opensearch.service

# create opensearch indexer role/user
timeout 10 sh -c 'until nc -z $0 $1; do sleep 1; done' ${OPENSEARCH_ENDPOINT} 9200
grep -m 1 '\[GREEN\].*security' <(tail -f /var/log/opensearch/${parameter["BRAND"]}.log)
sleep 5

# Create role
curl -u ${parameter["OPENSEARCH_ADMIN"]}:${parameter["OPENSEARCH_PASSWORD"]} -XPUT "http://${OPENSEARCH_ENDPOINT}:9200/_plugins/_security/api/roles/indexer_${parameter["BRAND"]}" \
-H "Content-Type: application/json" \
-d "$(cat <<EOF
{
"cluster_permissions": [
"cluster_composite_ops_monitor",
"cluster:monitor/main",
"cluster:monitor/state",
"cluster:monitor/health"
],
"index_permissions": [
{
"index_patterns": ["indexer_${parameter["BRAND"]}*"],
"fls": [],
"masked_fields": [],
"allowed_actions": ["*"]
},
{
"index_patterns": ["*"],
"fls": [],
"masked_fields": [],
"allowed_actions": [
"indices:admin/aliases/get",
"indices:data/read/search",
"indices:admin/get"]
}
],
"tenant_permissions": []
}
EOF
)"

# Create user
curl -u  ${parameter["OPENSEARCH_ADMIN"]}:${parameter["OPENSEARCH_PASSWORD"]} -XPUT "http://${OPENSEARCH_ENDPOINT}:9200/_plugins/_security/api/internalusers/indexer_${parameter["BRAND"]}" \
-H "Content-Type: application/json" \
-d "$(cat <<EOF
{
"password": "${parameter["INDEXER_PASSWORD"]}",
"opendistro_security_roles": ["indexer_${parameter["BRAND"]}", "own_index"]
}
EOF
)"

/usr/share/opensearch/bin/opensearch-plugin install --batch \
analysis-icu \
analysis-phonetic

apt-mark hold opensearch

sed -i "/${OPENSEARCH_ENDPOINT}/d" /etc/hosts

fi


###################################################################################
###                           FRONTEND ADMIN  CONFIGURATION                     ###
###################################################################################

if [[ "${INSTANCE_NAME}" =~ (frontend|admin) ]]; then
apt -qqy update
apt -qq -y install ${parameter["LINUX_PACKAGES"]}

# BUILD EFS UTILS
cd /tmp
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
apt-get -y install ./build/amazon-efs-utils*deb
rm -rf ~/.cargo ~/.rustup

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

_PHP_PACKAGES+=(${parameter["PHP_PACKAGES"]})
apt -qq -y install php${parameter["PHP_VERSION"]} ${_PHP_PACKAGES[@]/#/php${parameter["PHP_VERSION"]}-} php-pear

# COMPOSER INSTALLATION
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --${COMPOSER_VERSION} --install-dir=/usr/bin --filename=composer
php -r "unlink('composer-setup.php');"

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

# MAGENTO FOLDERS PERMISSIONS
mkdir -p ${parameter["WEB_ROOT_PATH"]}
chmod 711 /home/${parameter["BRAND"]}
chown -R ${parameter["BRAND"]}:php-${parameter["BRAND"]} ${parameter["WEB_ROOT_PATH"]}
chmod 2750 ${parameter["WEB_ROOT_PATH"]}
setfacl -R -m m:r-X,u:${parameter["BRAND"]}:rwX,g:php-${parameter["BRAND"]}:r-X,o::-,d:u:${parameter["BRAND"]}:rwX,d:g:php-${parameter["BRAND"]}:r-X,d:o::- ${parameter["WEB_ROOT_PATH"]}
setfacl -R -m u:nginx:r-X,d:u:nginx:r-X ${parameter["WEB_ROOT_PATH"]}

echo '${parameter["EFS_SYSTEM_ID"]}:/ ${parameter["WEB_ROOT_PATH"]}/var efs _netdev,noresvport,tls,iam,accesspoint=${parameter["EFS_ACCESS_POINT_VAR"]} 0 0' >> /etc/fstab
echo '${parameter["EFS_SYSTEM_ID"]}:/ ${parameter["WEB_ROOT_PATH"]}/pub/media efs _netdev,noresvport,tls,iam,accesspoint=${parameter["EFS_ACCESS_POINT_MEDIA"]} 0 0' >> /etc/fstab

mkdir -p ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}
chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} ${parameter["WEB_ROOT_PATH"]}/
chmod 2770 ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}

# DOWNLOADING NGINX CONFIG FILES
curl -o /etc/nginx/fastcgi_params  ${MAGENX_NGINX_GITHUB_REPO}magento2/fastcgi_params
curl -o /etc/nginx/nginx.conf  ${MAGENX_NGINX_GITHUB_REPO}magento2/nginx.conf
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/sites-available && cd $_
curl ${MAGENX_NGINX_GITHUB_REPO_API}/sites-available 2>&1 | awk -F'"' '/download_url/ {print $4 ; system("curl -O "$4)}' >/dev/null
ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf
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
END


# TIMESTAMP TO BASH HISTORY
cat <<END >> ~/.bashrc
export HISTTIMEFORMAT="%d/%m/%y %T "
END

if [ "${INSTANCE_NAME}" == "admin" ]; then
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

systemctl daemon-reload
systemctl restart nginx.service
systemctl restart php*fpm.service
systemctl restart varnish.service

fi

###################################################################################

cat <<END > /usr/local/bin/cloudmap-register
#! /bin/bash
. /usr/local/bin/metadata
aws servicediscovery register-instance \
  --region ${parameter["AWS_DEFAULT_REGION"]} \
  --service-id ${SERVICE_ID} \
  --instance-id \${INSTANCE_ID} \
  --attributes AWS_INSTANCE_IPV4=\${INSTANCE_IP}
END

cat <<END > /usr/local/bin/cloudmap-deregister
#! /bin/bash
. /usr/local/bin/metadata
aws servicediscovery deregister-instance \
  --region ${parameter["AWS_DEFAULT_REGION"]} \
  --service-id ${SERVICE_ID} \
  --instance-id \${INSTANCE_ID}
END

cat <<END > /etc/systemd/system/cloudmap.service
[Unit]
Description=Run AWS CloudMap service
Requires=network-online.target network.target
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
KillMode=none
RemainAfterExit=yes

ExecStart=/usr/local/bin/cloudmap-register
ExecStop=/usr/local/bin/cloudmap-deregister

[Install]
WantedBy=multi-user.target
END

systemctl enable cloudmap.service

###################################################################################

cd /tmp
wget https://aws-codedeploy-${parameter["AWS_DEFAULT_REGION"]}.s3.amazonaws.com/latest/install
chmod +x ./install
./install auto

wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazon-ssm-${parameter["AWS_DEFAULT_REGION"]}/latest/debian_arm64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent

wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazoncloudwatch-agent-${parameter["AWS_DEFAULT_REGION"]}/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${INSTANCE_NAME}.json

apt-get remove --purge -y \
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

apt-get clean
apt-get autoclean
apt-get autoremove --purge -y

echo "PS1='\[\e[37m\][\[\e[m\]\[\e[32m\]\u\[\e[m\]\[\e[37m\]@\[\e[m\]\[\e[35m\]\h\[\e[m\]\[\e[37m\]:\[\e[m\]\[\e[36m\]\W\[\e[m\]\[\e[37m\]]\[\e[m\]$ '" >> /etc/bashrc
chmod +x /usr/local/bin/*
chmod 700 /usr/bin/aws

## simple installation stats
curl --silent -X POST https://www.magenx.com/ping_back_id_${INSTANCE_NAME}_domain_${parameter["DOMAIN"]}_geo_${parameter["TIMEZONE"]}_keep_30d >/dev/null 2>&1
