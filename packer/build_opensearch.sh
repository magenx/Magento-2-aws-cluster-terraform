#!/bin/bash

. /tmp/build_header.sh

###################################################################################
###                              OPENSEARCH CONFIGURATION                       ###
###################################################################################

if [ "${INSTANCE_NAME}" == "opensearch" ]; then
# OPENSEARCH INSTALLATION
curl -o- https://artifacts.opensearch.org/publickeys/opensearch.pgp | gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring
echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch/${OPENSEARCH_VERSION}/apt stable main" > /etc/apt/sources.list.d/opensearch-${OPENSEARCH_VERSION}.list
apt -qq -y update
env OPENSEARCH_INITIAL_ADMIN_PASSWORD=${parameter["OPENSEARCH_PASSWORD"]} apt -qq -y install netcat-traditional opensearch

echo "127.0.0.1 ${OPENSEARCH_ENDPOINT}" >> /etc/hosts

# opensearch settings
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
curl -XGET -u ${parameter["OPENSEARCH_ADMIN"]}:${parameter["OPENSEARCH_PASSWORD"]} "http://${OPENSEARCH_ENDPOINT}:9200/_cluster/health?wait_for_status=green&timeout=60s"
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

/usr/share/opensearch/bin/opensearch-plugin install --batch analysis-icu analysis-phonetic

apt-mark hold opensearch

sed -i "/${OPENSEARCH_ENDPOINT}/d" /etc/hosts

fi

###################################################################################

. /tmp/build_footer.sh

