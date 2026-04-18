output "table_name" {
  value = aws_dynamodb_table.reservations.name
}

output "table_arn" {
  value = aws_dynamodb_table.reservations.arn
}
