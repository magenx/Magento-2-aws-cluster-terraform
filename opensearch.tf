

//////////////////////////////////////////////////////////[ OPENSEARCH ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create OpenSearch service linked role if not exists
# # ---------------------------------------------------------------------------------------------------------------------#
resource "null_resource" "es" {
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          exit_code=$(aws iam get-role --role-name AWSServiceRoleForAmazonOpenSearchService > /dev/null 2>&1 ; echo $?)
          if [[ $exit_code -ne 0 ]]; then
          aws iam create-service-linked-role --aws-service-name opensearchservice.amazonaws.com
          fi
EOF
 }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create OpenSearch domain access policy
# # ---------------------------------------------------------------------------------------------------------------------#
data "aws_iam_policy_document" "opensearch_access" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["es:*"]
    resources = ["arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.project}-opensearch/*"]
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
  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = random_string.this["opensearch"].result
      master_user_password = random_password.this["opensearch"].result
    }
  }
  encrypt_at_rest {
    enabled = true
  }
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  node_to_node_encryption {
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
  access_policies = data.aws_iam_policy_document.opensearch_access.json
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudWatch log group for OpenSearch log stream
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "opensearch" {
  name = "${local.project}-opensearch"
}

data "aws_iam_policy_document" "opensearch-log-publishing-policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]
    resources = ["arn:aws:logs:*"]
    principals {
      identifiers = ["es.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "${local.project}-opensearch"
  policy_document = data.aws_iam_policy_document.opensearch-log-publishing-policy.json
}
