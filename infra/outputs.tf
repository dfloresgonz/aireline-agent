output "agent_id" {
  value = module.bedrock_agent.agent_id
}

output "agent_alias_id" {
  value = module.bedrock_agent.agent_alias_id
}

output "knowledge_base_id" {
  value = module.bedrock_agent.knowledge_base_id
}

output "data_source_id" {
  value = module.bedrock_agent.data_source_id
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "kb_bucket_name" {
  value = aws_s3_bucket.kb_docs.bucket
}

output "skill_function_name" {
  value = module.skill.function_name
}

output "skill_function_url" {
  value = module.skill.function_url
}

output "reserva_function_name" {
  value = module.lambdas.reserva_function_name
}

output "consultar_reserva_function_name" {
  value = module.lambdas.consultar_reserva_function_name
}
