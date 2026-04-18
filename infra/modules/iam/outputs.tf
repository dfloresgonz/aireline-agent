output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "bedrock_agent_role_arn" {
  value = aws_iam_role.bedrock_agent.arn
}
