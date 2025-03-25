


/////////////////////////////////////////////////////[ AWS ECR REPOSITORY ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ecr repository
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ecr_repository" "this" {
  name         = "${local.project}-ecr"
  force_delete = var.ecr["force_delete"]
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    Name = "${local.project}-ecr"
  }
}
