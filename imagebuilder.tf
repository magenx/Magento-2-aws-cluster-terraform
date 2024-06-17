


////////////////////////////////////////////////////[ AWS IMAGE BUILDER ]/////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Upload ImageBuilder build script to s3 bucket
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_object" "imagebuilder_build" {
  bucket = aws_s3_bucket.this["system"].id
  key    = "imagebuilder/build.sh"
  source = "${abspath(path.root)}/imagebuilder/build.sh"
  etag = filemd5("${abspath(path.root)}/imagebuilder/build.sh")
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Upload ImageBuilder test script to s3 bucket
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_s3_object" "imagebuilder_test" {
  bucket = aws_s3_bucket.this["system"].id
  key    = "imagebuilder/test.sh"
  source = "${abspath(path.root)}/imagebuilder/test.sh"
  etag = filemd5("${abspath(path.root)}/imagebuilder/test.sh")
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_image" "this" {
  depends_on                       = [aws_ssm_parameter.env]
  for_each                         = var.ec2
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this[each.key].arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this[each.key].arn
  
  tags = {
    Name = "${local.project}-${each.key}-image"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image component
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_component" "build" {
  name         = "${local.project}-imagebuilder-component"
  description  = "ImageBuilder component for ${local.project}"
  data = file("${abspath(path.root)}/imagebuilder/build.yml")
  platform = "Linux"
  version  = "1.0.0"
  
  tags = {
    Name = "${local.project}-imagebuilder-recipe"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image recipe
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_image_recipe" "this" {
  for_each     = var.ec2
  name         = "${local.project}-${each.key}-imagebuilder-recipe"
  description  = "ImageBuilder recipe for ${each.key} in ${local.project} using ${data.aws_ami.this.name}"
  parent_image = data.aws_ami.this.id
  version      = "1.0.0"
  
  block_device_mapping {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = "alias/aws/ebs"
      volume_size           = var.asg["volume_size"]
      volume_type           = "gp3"
    }
  }
  
  component {
    component_arn = aws_imagebuilder_component.build.arn
    parameter {
      name        = "PARAMETERSTORE_NAME"
      value       = "${aws_ssm_parameter.env.name}"
    }

    parameter {
      name        = "INSTANCE_NAME"
      value       = "${each.key}"
    }
    
    parameter {
      name        = "S3_SYSTEM_BUCKET"
      value       = "${aws_s3_bucket.this["system"].id}"
    }
  }
  
  user_data_base64        = filebase64("${abspath(path.root)}/imagebuilder/ssm.sh")

  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name = "${local.project}-${each.key}-imagebuilder-recipe"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder infrastructure configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_infrastructure_configuration" "this" {
  for_each              = var.ec2
  name                  = "${local.project}-${each.key}-imagebuilder-infrastructure"
  description           = "ImageBuilder infrastructure for ${each.key} in ${local.project}"
  instance_profile_name = aws_iam_instance_profile.ec2[each.key].name
  instance_types        = each.value
  security_group_ids    = [aws_security_group.ec2.id]
  sns_topic_arn         = aws_sns_topic.default.arn
  subnet_id             = values(aws_subnet.this).0.id
  
  terminate_instance_on_failure = true

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.this["system"].id
      s3_key_prefix  = "imagebuilder"
    }
  }

  resource_tags = {
    Resource = "${local.project}-${each.key}-image"
  }
  
  tags = {
    Name = "${local.project}-${each.key}-imagebuilder-infrastructure"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image pipeline
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_image_pipeline" "this" {
  depends_on                       = [aws_ssm_parameter.env]
  for_each                         = var.ec2
  name                             = "${local.project}-${each.key}-imagebuilder-pipeline"
  description                      = "ImageBuilder pipeline for ${each.key} in ${local.project}"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this[each.key].arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this[each.key].arn
  
  tags = {
    Name = "${local.project}-${each.key}-imagebuilder-pipeline"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image distribution configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_distribution_configuration" "this" {
  for_each     = var.ec2
  name         = "${local.project}-${each.key}-imagebuilder-distribution-configuration"
  description  = "ImageBuilder distribution configuration for ${each.key} in ${local.project}"
  distribution {
    ami_distribution_configuration {
      name         = "${local.project}-${each.key}-{{ imagebuilder:buildDate }}"
      description  = "AMI for ${each.key} in ${local.project} - {{ imagebuilder:buildDate }}"
      ami_tags = {
        Name = "${local.project}-${each.key}-{{ imagebuilder:buildDate }}"
      }
      launch_permission {
        user_ids = [data.aws_caller_identity.current.account_id]
      }
    }
    
    launch_template_configuration {
      launch_template_id = aws_launch_template.this[each.key].id
    }

    region = data.aws_region.current.name
  }
  
  tags = {
    Name = "${local.project}-${each.key}-imagebuilder-distribution-configuration"
  }
}
