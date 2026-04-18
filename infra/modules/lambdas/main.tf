data "archive_file" "reserva" {
  type        = "zip"
  source_file = "${path.root}/../lambdas/reserva/handler.py"
  output_path = "${path.module}/dist/reserva.zip"
}

data "archive_file" "consultar_reserva" {
  type        = "zip"
  source_file = "${path.root}/../lambdas/consultar-reserva/handler.py"
  output_path = "${path.module}/dist/consultar-reserva.zip"
}

resource "aws_lambda_function" "reserva" {
  function_name    = "${var.name_prefix}-reserva"
  role             = var.lambda_role_arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.reserva.output_path
  source_code_hash = data.archive_file.reserva.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-reserva" })
}

resource "aws_lambda_function" "consultar_reserva" {
  function_name    = "${var.name_prefix}-consultar-reserva"
  role             = var.lambda_role_arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.consultar_reserva.output_path
  source_code_hash = data.archive_file.consultar_reserva.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-consultar-reserva" })
}
