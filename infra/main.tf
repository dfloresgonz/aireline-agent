terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "kb_docs" {
  bucket = "${local.name_prefix}-kb-docs-${data.aws_caller_identity.current.account_id}"
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-kb-docs" })
}

resource "aws_s3_bucket_versioning" "kb_docs" {
  bucket = aws_s3_bucket.kb_docs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb_docs" {
  bucket = aws_s3_bucket.kb_docs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "kb_docs" {
  bucket                  = aws_s3_bucket.kb_docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "dynamodb" {
  source      = "./modules/dynamodb"
  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "iam" {
  source             = "./modules/iam"
  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  dynamodb_table_arn = module.dynamodb.table_arn
  aws_region         = var.aws_region
  account_id         = data.aws_caller_identity.current.account_id
  bedrock_model_id   = var.bedrock_model_id
}

module "lambdas" {
  source              = "./modules/lambdas"
  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  lambda_role_arn     = module.iam.lambda_role_arn
  dynamodb_table_name = module.dynamodb.table_name
}

module "bedrock_agent" {
  source                       = "./modules/bedrock-agent"
  name_prefix                  = local.name_prefix
  common_tags                  = local.common_tags
  bedrock_model_id             = var.bedrock_model_id
  agent_role_arn               = module.iam.bedrock_agent_role_arn
  reserva_lambda_arn           = module.lambdas.reserva_arn
  consultar_reserva_lambda_arn = module.lambdas.consultar_reserva_arn
  consultar_clima_lambda_arn   = module.lambdas.consultar_clima_arn
  kb_bucket_arn                = aws_s3_bucket.kb_docs.arn
}

module "skill" {
  source          = "./modules/skill"
  name_prefix     = local.name_prefix
  common_tags     = local.common_tags
  lambda_role_arn = module.iam.lambda_role_arn
  agent_id        = module.bedrock_agent.agent_id
  agent_alias_id  = module.bedrock_agent.agent_alias_id
}

resource "aws_lambda_permission" "alexa" {
  statement_id       = "AllowAlexaInvoke"
  action             = "lambda:InvokeFunction"
  function_name      = module.skill.function_name
  principal          = "alexa-appkit.amazon.com"
  event_source_token = var.alexa_skill_id != "" ? var.alexa_skill_id : null
}
