


///////////////////////////////////////////////[ SYSTEMS MANAGER - PARAMETERSTORE ]///////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for aws env
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "aws_env" {
  name        = "/${local.project}/${local.environment}/aws/env"
  description = "AWS environment for ${local.project} in ${data.aws_region.current.name}"
  type        = "String"
  value       = <<EOF
{
"PROJECT" : "${local.project}",
"AWS_DEFAULT_REGION" : "${data.aws_region.current.name}",
"VPC_ID" : "${aws_vpc.this.id}",
"CIDR" : "${aws_vpc.this.cidr_block}",
"SUBNET_ID" : "${values(aws_subnet.this).0.id}",
"SOURCE_AMI" : "${data.aws_ami.distro.id}",
"EFS_SYSTEM_ID" : "${aws_efs_file_system.this.id}",
"EFS_ACCESS_POINT_VAR" : "${aws_efs_access_point.this["var"].id}",
"EFS_ACCESS_POINT_MEDIA" : "${aws_efs_access_point.this["media"].id}",
"SNS_TOPIC_ARN" : "${aws_sns_topic.default.arn}",
"RABBITMQ_USER" : "${var.magento["brand"]}",
"RABBITMQ_PASSWORD" : "${random_password.this["rabbitmq"].result}",
"OPENSEARCH_ADMIN" : "${random_string.this["opensearch"].result}",
"OPENSEARCH_PASSWORD" : "${random_password.this["opensearch"].result}",
"INDEXER_PASSWORD" : "${random_password.this["indexer"].result}",
"REDIS_PASSWORD" : "${random_password.this["redis"].result}",
"S3_MEDIA_BUCKET" : "${aws_s3_bucket.this["media"].bucket}",
"S3_MEDIA_BUCKET_URL" : "${aws_s3_bucket.this["media"].bucket_regional_domain_name}",
"ALB_DNS_NAME" : "${aws_lb.this.dns_name}",
"CLOUDFRONT_DOMAIN" : "${aws_cloudfront_distribution.this.domain_name}",
"SES_KEY" : "${aws_iam_access_key.ses_smtp_user_access_key.id}",
"SES_SECRET" : "${aws_iam_access_key.ses_smtp_user_access_key.secret}",
"SES_PASSWORD" : "${aws_iam_access_key.ses_smtp_user_access_key.ses_smtp_password_v4}",
"SES_ENDPOINT" : "email-smtp.${data.aws_region.current.name}.amazonaws.com",
"DATABASE_NAME" : "${var.magento["brand"]}",
"DATABASE_USER" : "${var.magento["brand"]}",
"DATABASE_PASSWORD" : "${random_password.this["mariadb"].result}",
"DATABASE_ROOT_PASSWORD" : "${random_password.this["mariadb_root"].result}",
"ADMIN_PATH" : "admin_${random_string.this["admin_path"].result}",
"DOMAIN" : "${var.magento["domain"]}",
"BRAND" : "${var.magento["brand"]}",
"PHP_USER" : "php-${var.magento["brand"]}",
"ADMIN_EMAIL" : "${var.magento["admin_email"]}",
"WEB_ROOT_PATH" : "/home/${var.magento["brand"]}/public_html",
"TIMEZONE" : "${var.magento["timezone"]}",
"SECURITY_HEADER" : "${random_uuid.this.result}",
"HEALTH_CHECK_LOCATION" : "${random_string.this["health_check"].result}",
"PHPMYADMIN" : "${random_string.this["phpmyadmin"].result}",
"BLOWFISH" : "${random_password.this["blowfish"].result}",
"PROFILER" : "${random_string.this["profiler"].result}",
"RESOLVER" : "${cidrhost(aws_vpc.this.cidr_block, 2)}",
"CRYPT_KEY" : "${var.magento["crypt_key"]}",
"GRAPHQL_ID_SALT" : "${var.magento["graphql_id_salt"]}",
"PHP_VERSION" : "${var.magento["php_version"]}",
"PHP_INI" : "/etc/php/${var.magento["php_version"]}/fpm/php.ini",
"PHP_FPM_POOL" : "/etc/php/${var.magento["php_version"]}/fpm/pool.d/www.conf",
"HTTP_X_HEADER" : "${random_uuid.this.result}",
"LINUX_PACKAGES" : "${var.magento["linux_packages"]}",
"PHP_PACKAGES" : "${var.magento["php_packages"]}",
"EXCLUDE_LINUX_PACKAGES" : "${var.magento["exclude_linux_packages"]}"
}
EOF
  tags = {
    Name = "${local.project}-${local.environment}-env"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for magento env.php
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "magento_env" {
  name        = "/${local.project}/${local.environment}/magento/env"
  description = "Magento env.php for ${local.project} in ${data.aws_region.current.name}"
  type        = "String"
  tier        = "Advanced"
  value       = <<EOF
<?php
return [
    'backend' => [
        'frontName' => getenv('ADMIN_PATH')
    ],
    'remote_storage' => [
        'driver' => 'file'
    ],
    'queue' => [
        'amqp' => [
            'host' => 'rabbitmq.' . getenv('BRAND') . '.internal',
            'port' => '5672',
            'user' => 'rabbitmq_' . getenv('BRAND'),
            'password' => getenv('RABBITMQ_PASSWORD'),
            'virtualhost' => '/'
        ],
        'consumers_wait_for_messages' => 0
    ],
    'crypt' => [
        'key' => getenv('CRYPT_KEY')
    ],
    'db' => [
        'table_prefix' => '',
        'connection' => [
            'default' => [
                'host' => 'mariadb.' . getenv('BRAND') . '.internal',
                'dbname' => getenv('DATABASE_NAME'),
                'username' => getenv('DATABASE_USER'),
                'password' => getenv('DATABASE_PASSWORD'),
                'model' => 'mysql4',
                'engine' => 'innodb',
                'initStatements' => 'SET NAMES utf8;',
                'active' => '1',
                'driver_options' => [
                    1014 => false
                ]
            ]
        ]
    ],
    'resource' => [
        'default_setup' => [
            'connection' => 'default'
        ]
    ],
    'x-frame-options' => 'SAMEORIGIN',
    'MAGE_MODE' => 'production',
    'session' => [
        'save' => 'redis',
        'redis' => [
            'host' => 'redis.' . getenv('BRAND') . '.internal',
            'port' => '6379',
            'password' => getenv('REDIS_PASSWORD'),
            'timeout' => '2.5',
            'persistent_identifier' => 'session',
            'database' => '0',
            'compression_threshold' => '2048',
            'compression_library' => 'lzf',
            'log_level' => '3',
            'max_concurrency' => '6',
            'break_after_frontend' => '5',
            'break_after_adminhtml' => '30',
            'first_lifetime' => '600',
            'bot_first_lifetime' => '60',
            'bot_lifetime' => '7200',
            'disable_locking' => '0',
            'min_lifetime' => '60',
            'max_lifetime' => '2592000',
            'sentinel_master' => '',
            'sentinel_servers' => '',
            'sentinel_connect_retries' => '5',
            'sentinel_verify_master' => '0'
        ]
    ],
    'cache' => [
        'frontend' => [
            'default' => [
                'id_prefix' => '71f_',
                'backend' => 'Magento\\Framework\\Cache\\Backend\\Redis',
                'backend_options' => [
                    'server' => 'redis.' . getenv('BRAND') . '.internal',
                    'persistent' => 'cache',
                    'database' => '0',
                    'port' => '6380',
                    'password' => getenv('REDIS_PASSWORD'),
                    'compress_data' => '1',
                    'compression_lib' => 'l4z'
                ]
            ]
        ],
        'allow_parallel_generation' => false
    ],
    'lock' => [
        'provider' => 'db',
        'config' => [
            'prefix' => ''
        ]
    ],
    'directories' => [
        'document_root_is_pub' => true
    ],
    'cache_types' => [
        'config' => 1,
        'layout' => 1,
        'block_html' => 1,
        'collections' => 1,
        'reflection' => 1,
        'db_ddl' => 1,
        'compiled_config' => 1,
        'eav' => 1,
        'customer_notification' => 1,
        'full_page' => 1,
        'config_integration' => 1,
        'config_integration_api' => 1,
        'translate' => 1,
        'config_webservice' => 1
    ],
    'downloadable_domains' => [
        getenv('DOMAIN')
    ],
    'install' => [
        'date' => 'Sun, 19 Jun 2022 18:45:26 +0000'
    ],
    'http_cache_hosts' => [
        [
            'host' => '127.0.0.1',
            'port' => '8081'
        ]
    ],
	  'deployment' => [
        'blue_green' => [
             'enabled' => true
        ]
    ],
    'system' => [
        'default' => [
            'catalog' => [
                'search' => [
                    'engine' => 'opensearch',
                    'opensearch_server_hostname' => 'opensearch.' . getenv('BRAND') . '.internal',
                    'opensearch_enable_auth' => '1',
                    'opensearch_server_port' => '9200',
                    'opensearch_index_prefix' => 'indexer_' . getenv('BRAND'),
                    'opensearch_username' => 'indexer_' . getenv('BRAND'),
                    'opensearch_password' => getenv('INDEXER_PASSWORD')
                ]
            ]
        ]
    ],
    'indexer' => [
        'batch_size' => [
            'cataloginventory_stock' => [
                'simple' => 250
            ],
            'catalog_category_product' => 1000,
            'catalogsearch_fulltext' => [
                'partial_reindex' => 250,
                'mysql_get' => 550,
                'elastic_save' => 550
            ],
            'catalog_product_price' => [
                'simple' => 250,
                'default' => 550,
                'configurable' => 1000
            ],
            'catalogpermissions_category' => 1000,
            'inventory' => [
                'simple' => 250,
                'default' => 550,
                'configurable' => 650
            ]
        ]
    ]
];
EOF
  tags = {
    Name = "${local.project}-${local.environment}-magento-envphp"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for appspec Codedeploy config
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "codedeploy_appspec" {
  name        = "/${local.project}/${local.environment}/codedeploy/appspec"
  description = "Codedeploy appspec.yml for ${local.project} in ${data.aws_region.current.name}"
  type        = "String"
  value       = <<EOF
version: 0.0
os: linux
files:
  - source: /
    destination: /home/${var.magento["brand"]}/public_html
file_exists_behavior: OVERWRITE
permissions:
  - object: /home/${var.magento["brand"]}/public_html
    pattern: "**"
    owner: ${var.magento["brand"]}
    group: php-${var.magento["brand"]}
    mode: 660
    type:
      - file
  - object: /home/${var.magento["brand"]}/public_html
    pattern: "**"
    owner: ${var.magento["brand"]}
    group: php-${var.magento["brand"]}
    mode: 2770
    type:
      - directory
hooks:
  BeforeInstall:
    - location: cleanup.sh
      timeout: 60
      runas: root
  AfterInstall:
    - location: setup.sh
      timeout: 60
      runas: ${var.magento["brand"]}
EOF
  tags = {
    Name = "${local.project}-${local.environment}-codedeploy-appspec"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter store for composer auth file
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "composer_auth" {
  name        = "/${local.project}/${local.environment}/composer/auth"
  description = "Composer auth.json for ${local.project} in ${data.aws_region.current.name}"
  type        = "String"
  value       = <<EOF
{
    "http-basic": {
        "repo.magento.com": {
            "username": "${var.magento["composer_user"]}",
            "password": "${var.magento["composer_pass"]}"
        }
    }
}
EOF
  tags = {
    Name = "${local.project}-${local.environment}-composer-auth"
  }
}
