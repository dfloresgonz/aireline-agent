variable "name_prefix" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "lambda_role_arn" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "agent_id" {
  type    = string
  default = ""
}

variable "agent_alias_id" {
  type    = string
  default = ""
}
