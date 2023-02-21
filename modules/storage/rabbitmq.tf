


/////////////////////////////////////////////////[ AMAZON RABBITMQ BROKER ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create RabbitMQ - queue message broker
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_mq_broker" "this" {
  broker_name        = "${local.project}-rabbitmq"
  engine_type        = "RabbitMQ"
  engine_version     = var.rabbitmq["engine_version"]
  host_instance_type = var.rabbitmq["host_instance_type"]
  security_groups    = [aws_security_group.rabbitmq.id]
  deployment_mode    = var.rabbitmq["deployment_mode"]
  subnet_ids         = values(aws_subnet.this).*.id
  user {
    username         = var.app["brand"]
    password         = random_password.this["rabbitmq"].result
  }
  tags = {
    Name   = "${local.project}-rabbitmq"
  }
}


