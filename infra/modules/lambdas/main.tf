data "archive_file" "mcp_weather_server" {
  type        = "zip"
  source_file = "${path.root}/../lambdas/mcp-weather-server/handler.py"
  output_path = "${path.module}/dist/mcp-weather-server.zip"
}

resource "aws_lambda_function" "mcp_weather_server" {
  function_name    = "${var.name_prefix}-mcp-weather-server"
  role             = var.lambda_role_arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.mcp_weather_server.output_path
  source_code_hash = data.archive_file.mcp_weather_server.output_base64sha256
  timeout          = 10
  tags             = merge(var.common_tags, { Name = "${var.name_prefix}-mcp-weather-server" })
}

resource "aws_lambda_function_url" "mcp_weather_server" {
  function_name      = aws_lambda_function.mcp_weather_server.function_name
  authorization_type = "NONE"
}

data "archive_file" "consultar_clima" {
  type        = "zip"
  source_file = "${path.root}/../lambdas/consultar-clima/handler.py"
  output_path = "${path.module}/dist/consultar-clima.zip"
}

resource "aws_lambda_function" "consultar_clima" {
  function_name    = "${var.name_prefix}-consultar-clima"
  role             = var.lambda_role_arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.consultar_clima.output_path
  source_code_hash = data.archive_file.consultar_clima.output_base64sha256
  timeout          = 10
  tags             = merge(var.common_tags, { Name = "${var.name_prefix}-consultar-clima" })

  environment {
    variables = {
      MCP_SERVER_URL = aws_lambda_function_url.mcp_weather_server.function_url
    }
  }
}

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
