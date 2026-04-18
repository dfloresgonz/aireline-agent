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
  default = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "alexa_skill_id" {
  type    = string
  default = ""
}
