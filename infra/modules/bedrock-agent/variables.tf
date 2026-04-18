variable "name_prefix" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "bedrock_model_id" {
  type = string
}

variable "agent_role_arn" {
  type = string
}

variable "reserva_lambda_arn" {
  type = string
}

variable "consultar_reserva_lambda_arn" {
  type = string
}

variable "kb_bucket_arn" {
  type = string
}
