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
