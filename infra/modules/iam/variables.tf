variable "name_prefix" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "dynamodb_table_arn" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "bedrock_model_id" {
  type = string
}
