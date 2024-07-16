


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
      runCommand: 
${each.key == "varnish" ? local.varnish_user_data : local.frontend_user_data}
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

locals {

frontend_user_data = <<EOF
        - |-
          AWSTOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
          INSTANCE_LOCAL_IP=$(curl -s -H "X-aws-ec2-metadata-token: $${AWSTOKEN}" http://169.254.169.254/latest/meta-data/local-ipv4)
        - |-
          cd /home/${var.app["brand"]}/public_html/
          su ${var.app["brand"]} -s /bin/bash -c "git init -b main"
          su ${var.app["brand"]} -s /bin/bash -c "git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}"
          su ${var.app["brand"]} -s /bin/bash -c "git fetch origin main"
          su ${var.app["brand"]} -s /bin/bash -c "git reset origin/main --hard"
        - |-
          sed -i "s/INSTANCE_LOCAL_IP/$${INSTANCE_LOCAL_IP}/" /etc/nginx/sites-available/magento.conf
          systemctl restart nginx php${var.app["php_version"]}-fpm
EOF


varnish_user_data = <<EOF
        - |-
          AWSTOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
          INSTANCE_LOCAL_IP=$(curl -s -H "X-aws-ec2-metadata-token: $${AWSTOKEN}" http://169.254.169.254/latest/meta-data/local-ipv4)
        - |-
          sed -i "s/INSTANCE_LOCAL_IP/$${INSTANCE_LOCAL_IP}/" /etc/varnish/default.vcl
          sed -i "s/INSTANCE_LOCAL_IP/$${INSTANCE_LOCAL_IP}/" /etc/varnish/varnish.params
          sed -i "s/INSTANCE_LOCAL_IP/$${INSTANCE_LOCAL_IP}/" /etc/nginx/nginx.conf
        - |-
          systemctl restart nginx varnish
EOF
}
