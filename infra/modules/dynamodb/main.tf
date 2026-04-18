resource "aws_dynamodb_table" "reservations" {
  name         = "${var.name_prefix}-reservations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "reservation_id"

  attribute {
    name = "reservation_id"
    type = "S"
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-reservations" })
}
