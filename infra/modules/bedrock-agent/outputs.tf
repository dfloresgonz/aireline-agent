output "agent_id" {
  value = aws_bedrockagent_agent.main.agent_id
}

output "agent_alias_id" {
  value = aws_bedrockagent_agent_alias.live.agent_alias_id
}

output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.main.id
}

output "data_source_id" {
  value = aws_bedrockagent_data_source.s3.data_source_id
}
