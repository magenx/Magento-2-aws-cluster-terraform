


# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document runShellScript to install magento, push to codecommit, init git
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "install_magento" {
  name          = "${var.app["brand"]}-install-magento-push-codecommit"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Configure git, install magento, push to codecommit"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "${var.app["brand"]}InstallMagentoPushCodecommit"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      cd /home/${var.app["brand"]}/public_html
      su ${var.app["brand"]} -s /bin/bash -c "echo 007 > magento_umask"
      su ${var.app["brand"]} -s /bin/bash -c "echo -e '/pub/media/*\n/var/*'" > .gitignore
      su ${var.app["brand"]} -s /bin/bash -c "composer -n -q config -g http-basic.repo.magento.com ${var.app["composer_user"]} ${var.app["composer_pass"]}"
      su ${var.app["brand"]} -s /bin/bash -c "composer install -n"
      chmod +x bin/magento
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:install \
      --base-url=https://${var.app["domain"]}/ \
      --base-url-secure=https://${var.app["domain"]}/ \
      --db-host=${aws_db_instance.this.endpoint} \
      --db-name=${aws_db_instance.this.name} \
      --db-user=${aws_db_instance.this.username} \
      --db-password='${random_password.this["rds"].result}' \
      --admin-firstname=${var.app["brand"]} \
      --admin-lastname=${var.app["brand"]} \
      --admin-email=${var.app["admin_email"]} \
      --admin-user=admin \
      --admin-password='${random_password.this["app"].result}' \
      --backend-frontname='admin_${random_string.this["admin_path"].result}' \
      --language=${var.app["language"]} \
      --currency=${var.app["currency"]} \
      --timezone=${var.app["timezone"]} \
      --cleanup-database \
      --session-save=files \
      --use-rewrites=1 \
      --use-secure=1 \
      --use-secure-admin=1 \
      --consumers-wait-for-messages=0 \
      --amqp-host=${trimsuffix(trimprefix("${aws_mq_broker.this.instances.0.endpoints.0}", "amqps://"), ":5671")} \
      --amqp-port=5671 \
      --amqp-user=${var.app["brand"]} \
      --amqp-password='${random_password.this["rabbitmq"].result}' \
      --amqp-virtualhost='/' \
      --amqp-ssl=true \
      --search-engine=elasticsearch7 \
      --elasticsearch-host="https://${aws_elasticsearch_domain.this.endpoint}" \
      --elasticsearch-port=443 \
      --elasticsearch-index-prefix=${var.app["brand"]} \
      --elasticsearch-enable-auth=0"
      ## installation check
      if [[ $? -ne 0 ]]; then
      echo
      echo "Installation error - check command output log"
      exit 1
      fi
      if [ ! -f /home/${var.app["brand"]}/public_html/app/etc/env.php ]; then
      echo "Installation error - env.php not available"
      exit 1
      fi
      ## cache backend
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set \
      --cache-id-prefix="${random_string.this["id_prefix"].result}_" \
      --cache-backend=redis \
      --cache-backend-redis-server=${aws_elasticache_replication_group.this["cache"].primary_endpoint_address} \
      --cache-backend-redis-port=6379 \
      --cache-backend-redis-db=0 \
      --cache-backend-redis-compress-data=1 \
      --cache-backend-redis-compression-lib=l4z \
      -n"
      ## session
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set \
      --session-save=redis \
      --session-save-redis-host=${aws_elasticache_replication_group.this["session"].primary_endpoint_address} \
      --session-save-redis-port=6379 \
      --session-save-redis-log-level=3 \
      --session-save-redis-db=0 \
      --session-save-redis-compression-lib=lz4 \
      --session-save-redis-persistent-id=${random_string.this["persistent"].result} \
      -n"
      ## add cache optimization
      sed -i "/${aws_elasticache_replication_group.this["cache"].primary_endpoint_address}/a\            'load_from_slave' => '${aws_elasticache_replication_group.this["cache"].reader_endpoint_address}:6379', \\
            'master_write_only' => '0', \\
            'retry_reads_on_master' => '1', \\
            'persistent' => '${random_string.this["persistent"].result}', \\
            'preload_keys' => [ \\
                    '${random_string.this["id_prefix"].result}_EAV_ENTITY_TYPES', \\
                    '${random_string.this["id_prefix"].result}_GLOBAL_PLUGIN_LIST', \\
                    '${random_string.this["id_prefix"].result}_DB_IS_UP_TO_DATE', \\
                    '${random_string.this["id_prefix"].result}_SYSTEM_DEFAULT', \\
                ],"  app/etc/env.php
      ## clean cache
      rm -rf var/cache var/page_cache
      ## enable s3 remote storage
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:config:set --remote-storage-driver=aws-s3 \
      --remote-storage-bucket=${aws_s3_bucket.this["media"].bucket} \
      --remote-storage-region=${data.aws_region.current.name} \
      --remote-storage-key=${aws_iam_access_key.s3.id} \
      --remote-storage-secret="${aws_iam_access_key.s3.secret}" \
      -n"
      ## sync to s3 remote storage
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento remote-storage:sync"
      ## install modules to properly test magento 2 production-ready functionality
      su ${var.app["brand"]} -s /bin/bash -c "composer -n require fooman/sameorderinvoicenumber-m2 fooman/emailattachments-m2 fooman/printorderpdf-m2 mageplaza/module-smtp magefan/module-blog stripe/stripe-payments"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento setup:upgrade -n --no-ansi"
      ## correct general contact name and email address
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set trans_email/ident_general/name ${var.app["brand"]}'
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set trans_email/ident_general/email ${var.app["admin_email"]}'
      ## configure smtp ses 
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/general/enabled 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/general/log_email 0"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/host email-smtp.${data.aws_region.current.name}.amazonaws.com"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/port 587"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/protocol tls"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/authentication login"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/username ${aws_iam_access_key.ses_smtp_user_access_key.id}"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/password ${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/configuration_option/test_email/from general"
      su ${var.app["brand"]} -s /bin/bash -c 'bin/magento config:set smtp/configuration_option/test_email/to ${var.app["admin_email"]}'
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set smtp/developer/developer_mode 0"
      ## explicitly set the new catalog media url format
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/url/catalog_media_url_format image_optimization_parameters"
      ## configure cloudfront media / static base url
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/unsecure/base_media_url https://${aws_cloudfront_distribution.this.domain_name}/media/"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/base_media_url https://${aws_cloudfront_distribution.this.domain_name}/media/"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/unsecure/base_static_url https://${aws_cloudfront_distribution.this.domain_name}/static/"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/base_static_url https://${aws_cloudfront_distribution.this.domain_name}/static/"
      ## minify js and css
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/css/minify_files 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/js/minify_files 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/js/move_script_to_bottom 1"
      ## enable hsts upgrade headers
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/enable_hsts 1"
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set web/secure/enable_upgrade_insecure 1"
      ## enable eav cache
      su ${var.app["brand"]} -s /bin/bash -c "bin/magento config:set dev/caching/cache_user_defined_attributes 1"
      ## git push to codecommit build branch to trigger codepipeline build
      git add . -A
      git commit -m ${var.app["brand"]}-init-$(date +'%y%m%d-%H%M%S')
      git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}
      git checkout -b build
      git push origin build
EOT
}
