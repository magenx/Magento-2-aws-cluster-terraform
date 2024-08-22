


/////////////////////////////////////////////[ SYSTEM MANAGER DOCUMENT USER DATA ]////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document to configure EC2 instances in Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_document" "user_data" {
  for_each      = var.ec2
  name          = "BootstrappingEC2WithUserData${each.key}"
  document_format = "YAML"
  document_type = "Command"
  content = <<EOF
schemaVersion: "2.2"
description: "Bootstrapping EC2 ${each.key} instance With UserData"
mainSteps:
  - name: "BootstrappingEC2${each.key}"
    action: "aws:runShellScript"
    inputs:
      runCommand: <<EOF
        - |-
          AWSTOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
          INSTANCE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $${AWSTOKEN}" http://169.254.169.254/latest/meta-data/local-ipv4)
        - |-
          echo "$${INSTANCE_IP}  ${each.key}.${var.magento["brand"]}.internal ${each.key}" >> /etc/hosts
        - |-
          if [ -d /home/${var.magento["brand"]}/public_html/ ]; then
          cd /home/${var.magento["brand"]}/public_html/
          su ${var.magento["brand"]} -s /bin/bash -c "git init -b main"
          su ${var.magento["brand"]} -s /bin/bash -c "git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}"
          su ${var.magento["brand"]} -s /bin/bash -c "git fetch origin main"
          su ${var.magento["brand"]} -s /bin/bash -c "git reset origin/main --hard"
          sed -i "s/listen 80;/listen $${INSTANCE_IP} 80;/" /etc/nginx/sites-available/${var.magento["domain"]}.conf
          sed -i "s/localhost/$${INSTANCE_IP}/g" /etc/varnish/default.vcl
          systemctl restart varnish nginx php${var.magento["php_version"]}-fpm
          fi
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create SSM Document association with Auto Scaling Group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ssm_association" "user_data" {
  for_each = var.ec2
  name     = aws_ssm_document.user_data[each.key].name
  targets {
    key    = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.this[each.key].name]
  }
  output_location {
    s3_bucket_name = aws_s3_bucket.this["system"].bucket
    s3_key_prefix  = "user_data_${each.key}"
    s3_region      = data.aws_region.current.name
  }
  association_name = "User-Data-for-EC2-instances-in-${aws_autoscaling_group.this[each.key].name}"
  document_version = "$LATEST"
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule for EC2 Instance Launch
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_rule" "instance_launch" {
  for_each    = var.ec2
  name        = "${local.project}-${each.key}-instance-launch"
  description = "Trigger on ASG launch EC2 instance success"
  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance Launch Successful"]
  })
}
# # ---------------------------------------------------------------------------------------------------------------------#
# EventBridge Rule Target for SSM Document
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_event_target" "instance_launch" {
  for_each  = var.ec2
  rule      = aws_cloudwatch_event_rule.instance_launch.name
  target_id = "${local.project}-${each.key}-instance-launch"
  arn       =  aws_ssm_document.user_data.arn
  
  run_command_targets {
    key    = "tag:Name"
    values = ["${local.project}-${each.key}-ec2"]
  }
}
