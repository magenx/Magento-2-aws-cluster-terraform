

//////////////////////////////////////////////////////////[ OPENSEARCH ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create OpenSearch service linked role if not exists
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
# Create OpenSearch domain
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_opensearch_domain" "this" {
  depends_on = [null_resource.es]
  domain_name           = "${local.project}-opensearch"
  engine_version = var.opensearch["engine_version"]
  cluster_config {
    instance_type  = var.opensearch["instance_type"]
    instance_count = var.opensearch["instance_count"]
  zone_awareness_enabled = var.opensearch["instance_count"] > 1 ? true : false
  dynamic "zone_awareness_config" {
     for_each = var.opensearch["instance_count"] > 1 ? [var.opensearch["instance_count"]] : []
     content {
        availability_zone_count = var.opensearch["instance_count"]
      }
    }
  }
  encrypt_at_rest {
    enabled = true
  }
  ebs_options {
    ebs_enabled = var.opensearch["ebs_enabled"]
    volume_type = var.opensearch["volume_type"]
    volume_size = var.opensearch["volume_size"]
  }
  vpc_options {
    subnet_ids = slice(values(aws_subnet.this).*.id, 0, var.opensearch["instance_count"])
    security_group_ids = [aws_security_group.opensearch.id]
  }
  tags = {
    Name = "${local.project}-opensearch"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch.arn
    log_type                 = var.opensearch["log_type"]
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
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.project}-opensearch/*"
    }
  ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch log group for OpenSearch log stream
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "opensearch" {
  name = "${local.project}-opensearch"
}

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "${local.project}-opensearch"

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
