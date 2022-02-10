


//////////////////////////////////////////////////////////[ ELASTICSEARCH ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElasticSearch service linked role if not exists
# # ---------------------------------------------------------------------------------------------------------------------#
resource "null_resource" "es" {
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          exit_code=$(aws iam get-role --role-name AWSServiceRoleForAmazonElasticsearchService > /dev/null 2>&1 ; echo $?)
          if [[ $exit_code -ne 0 ]]; then
          aws iam create-service-linked-role --aws-service-name es.amazonaws.com
          fi
EOF
 }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ElasticSearch domain
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_elasticsearch_domain" "this" {
  depends_on = [null_resource.es]
  domain_name           = "${local.project}-elk"
  elasticsearch_version = var.elk["elasticsearch_version"]
  cluster_config {
    instance_type  = var.elk["instance_type"]
    instance_count = var.elk["instance_count"]
  zone_awareness_enabled = var.elk["instance_count"] > 1 ? true : false
  dynamic "zone_awareness_config" {
     for_each = var.elk["instance_count"] > 1 ? [var.elk["instance_count"]] : []
     content {
        availability_zone_count = var.elk["instance_count"]
      }
    }
  }
  encrypt_at_rest {
    enabled = true
  }
  ebs_options {
    ebs_enabled = var.elk["ebs_enabled"]
    volume_type = var.elk["volume_type"]
    volume_size = var.elk["volume_size"]
  }
  vpc_options {
    subnet_ids = slice(values(aws_subnet.this).*.id, 0, var.elk["instance_count"])
    security_group_ids = [aws_security_group.elk.id]
  }
  tags = {
    Name = "${local.project}-elk"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.elk.arn
    log_type                 = var.elk["log_type"]
  }
  access_policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Action": [
        "es:*"
      ],
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.project}-elk/*"
    }
  ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch log group for ElasticSearch log stream
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "elk" {
  name = "${local.project}-elk"
}

resource "aws_cloudwatch_log_resource_policy" "elk" {
  policy_name = "${local.project}-elk"

  policy_document = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
EOF
}

  
