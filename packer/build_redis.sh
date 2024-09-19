#!/bin/bash

. /tmp/build_header.sh

###################################################################################
###                                REDIS CONFIGURATION                          ###
###################################################################################

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

###################################################################################

. /tmp/build_footer.sh
