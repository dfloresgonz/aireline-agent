output "reserva_arn" {
  value = aws_lambda_function.reserva.arn
}

output "consultar_reserva_arn" {
  value = aws_lambda_function.consultar_reserva.arn
}

output "reserva_function_name" {
  value = aws_lambda_function.reserva.function_name
}

output "consultar_reserva_function_name" {
  value = aws_lambda_function.consultar_reserva.function_name
}
