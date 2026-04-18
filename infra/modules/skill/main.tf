data "archive_file" "skill" {
  type        = "zip"
  source_file = "${path.root}/../lambdas/skill/handler.py"
  output_path = "${path.module}/dist/skill.zip"
}

resource "aws_lambda_function" "skill" {
  function_name    = "${var.name_prefix}-skill"
  role             = var.lambda_role_arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.skill.output_path
  source_code_hash = data.archive_file.skill.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      AGENT_ID       = var.agent_id
      AGENT_ALIAS_ID = var.agent_alias_id
    }
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-skill" })
}

resource "aws_lambda_function_url" "skill" {
  function_name      = aws_lambda_function.skill.function_name
  authorization_type = "NONE"
}
