#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#

## Debian
# WebStack Packages .deb
WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* ufw varnish* certbot* redis* webmin"

# check if web stack is clean and clean it
INSTALLED_PACKAGES="$(apt -qq list --installed $${WEB_STACK_CHECK} 2> /dev/null | cut -d'/' -f1 | tr '\n' ' ')"
if [ ! -z "$${INSTALLED_PACKAGES}" ]; then
apt -qq -y remove --purge "$${INSTALLED_PACKAGES}"
fi

# stack update
apt -qqy update
apt -qqy install jq apt-transport-https lsb-release ca-certificates curl gnupg software-properties-common snmp syslog-ng

cat <<END > /usr/local/bin/parameterstore
#!/bin/bash
PARAMETER=$(aws ssm get-parameter --name "${AWS_ENVIRONMENT}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$${key}"]="$${value}"; done < <(echo $${PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')
END

# Make the script executable
chmod +x /usr/local/bin/parameterstore

