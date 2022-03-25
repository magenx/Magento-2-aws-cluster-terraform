


////////////////////////////////////////////////////[ AWS IMAGE BUILDER ]/////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_image" "this" {
  for_each                         = var.ec2
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn

  depends_on = [
    data.aws_iam_policy_document.image_builder
  ]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image component
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_component" "build" {
  name         = "${local.project}-imagebuilder-component"
  description  = "ImageBuilder component for ${local.project}"
  data = yamlencode("${abspath(path.root)}/imagebuilder/build.yml")
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
  name         = "${local.project}-imagebuilder-recipe"
  description  = "ImageBuilder recipe for ${local.project} using debian-11-arm64"
  parent_image = data.aws_ami.distro.id
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
      name        = "Parameter1"
      value       = "Value1"
    }

    parameter {
      name        = "Parameter2"
      value       = "Value2"
    }
  }
  
  user_data_base64        = filebase64("${abspath(path.root)}/imagebuilder/ssm.sh")

  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name = "${local.project}-imagebuilder-recipe"
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
  instance_types        = ["c6g.xlarge"]
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

  tags = {
    Name = "${local.project}-${each.key}-imagebuilder-infrastructure"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ImageBuilder image pipeline
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = "${local.project}-${each.key}-imagebuilder-pipeline"
  description                      = "ImageBuilder pipeline for ${each.key} in ${local.project}"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn

  schedule []
  
  tags = {
    Name = "${local.project}-${each.key}-imagebuilder-pipeline"
  }
}
