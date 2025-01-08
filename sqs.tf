


/////////////////////////////////////////////////////[ SQS DEAD LETTER QUEUE ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create SQS queue to collect failed events debug messages
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_sqs_queue" "dead_letter_queue" {
  name                      = "${local.project}-dead-letter-queue"
  delay_seconds             = 5
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 5
  tags = {
    Name = "${local.project}-dead-letter-queue"
  }
}
