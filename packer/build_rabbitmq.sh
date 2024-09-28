#!/bin/bash

. /tmp/build_header.sh

###################################################################################
###                               RABBITMQ CONFIGURATION                        ###
###################################################################################

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

cat <<END > /etc/systemd/system/rabbitmq-route.service
[Unit]
Description=Configure rabbitmq instance IP address
Requires=network-online.target
After=network-online.target

[Service]
Type=oneshot
KillMode=process
RemainAfterExit=no

ExecStart=/usr/local/bin/rabbitmq-route

[Install]
WantedBy=multi-user.target
END

cat <<END > /usr/local/bin/rabbitmq-route
#!/bin/bash
. /usr/local/bin/metadata
iptables -t nat -A PREROUTING -d \${INSTANCE_IP} -p tcp --dport 5672 -j DNAT --to-destination 127.0.0.1:5672
iptables -t nat -A POSTROUTING -j MASQUERADE
END

fi

###################################################################################

. /tmp/build_footer.sh
