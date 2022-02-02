



///////////////////////////////////////////////////[ TERRAFORM STATE LOCK ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create S3 backend to keep terraform state lock
# # ---------------------------------------------------------------------------------------------------------------------#
terraform {
  backend "s3" {
    bucket         = "state"
    key            = "${var.app["brand"]}/${data.aws_region.current.name}/terraform.tfstate"
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.lock.id
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create DynamoDB table to check terraform lock state
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_dynamodb_table" "lock" {
    name           = "${var.app["brand"]}-terraform-state-lock"
    read_capacity  = 10
    write_capacity = 10
    hash_key       = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
    tags = {
        Name = "${local.project} terraform state lock"
    }
}
