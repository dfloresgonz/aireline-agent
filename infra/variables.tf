variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "airlines-app"
}

variable "owner" {
  type    = string
  default = "dfloresgonz"
}

variable "bedrock_model_id" {
  type    = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "alexa_skill_id" {
  type    = string
  default = ""
}
