


/////////////////////////////////////////////////////////[ SYSTEMS MANAGER ]//////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Parameter configuration file for CloudWatch Agent
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  for_each    = var.ec2
  name        = "/cloudwatch-agent/amazon-cloudwatch-agent-${each.key}.json"
  description = "Configuration file for CloudWatch agent at ${each.key} for ${local.project}"
  type        = "String"
  value       = <<EOF
{
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
            %{ if each.key == "frontend" ~}
            {
                "file_path": "/var/log/nginx/error.log",
                "log_group_name": "${local.project}_nginx_error_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            {
                "file_path": "/var/log/php/error.log",
                "log_group_name": "${local.project}_php_error_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            %{ endif ~}
            %{ if each.key == "mariadb" ~}
            {
                "file_path": "/var/log/mysql/error.log",
                "log_group_name": "${local.project}_mariadb_error_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            %{ endif ~}
            %{ if each.key == "opensearch" ~}
            {
                "file_path": "/var/log/opensearch/**.log",
                "log_group_name": "${local.project}_opensearch_error_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            %{ endif ~}
            %{ if each.key == "redis" ~}
            {
                "file_path": "/var/log/redis/**.log",
                "log_group_name": "${local.project}_redis_error_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            %{ endif ~}
            {
                "file_path": "/opt/${var.brand}/setup/log/**.log",
                "log_group_name": "${local.project}_instance_configuration",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            {
                "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
                "log_group_name": "${local.project}_cloudwatch_agent_log",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            {
                "file_path": "/var/log/apt/**.log",
                "log_group_name": "${local.project}_system_apt",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            },
            {
                "file_path": "/var/log/syslog",
                "log_group_name": "${local.project}_system_syslog",
                "log_stream_name": "${each.key}-{instance_id}-{ip_address}",
                "retention_in_days": 30
            }
            ]
          }
        },
        "log_stream_name": "${local.project}",
        "force_flush_interval" : 60
      },
  "metrics": {
    "namespace": "${local.project}",
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}",
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "disk": {
        "measurement": [
          "free",
          "total",
          "used",
          "used_percent",
          "inodes_free",
        ],
        "resources": ["*"],
        "ignore_file_system_types": ["sysfs", "tmpfs"]
      }
    }
  }
}
EOF
  tags = {
    Name = "amazon-cloudwatch-agent-${each.key}.json"
  }
}
