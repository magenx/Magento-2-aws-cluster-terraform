
###################################################################################
###                                  FINAL CLEANUP                              ###
###################################################################################

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
