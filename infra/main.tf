terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# Pass 1: action lambdas (sin agent_id — aún no existe)
module "lambdas" {
  source              = "./modules/lambdas"
  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  lambda_role_arn     = module.iam.lambda_role_arn
  dynamodb_table_name = module.dynamodb.table_name
  agent_id            = ""
  agent_alias_id      = ""
}

module "bedrock_agent" {
  source                       = "./modules/bedrock-agent"
  name_prefix                  = local.name_prefix
  common_tags                  = local.common_tags
  bedrock_model_id             = var.bedrock_model_id
  agent_role_arn               = module.iam.bedrock_agent_role_arn
  reserva_lambda_arn           = module.lambdas.reserva_arn
  consultar_reserva_lambda_arn = module.lambdas.consultar_reserva_arn
  kb_bucket_arn                = aws_s3_bucket.kb_docs.arn
}

# Pass 2: inyectar agent_id en la skill lambda vía AWS CLI
resource "terraform_data" "skill_env" {
  depends_on = [module.lambdas, module.bedrock_agent]

  triggers_replace = [
    module.bedrock_agent.agent_id,
    module.bedrock_agent.agent_alias_id,
  ]

  provisioner "local-exec" {
    command = <<-EOF
      aws lambda update-function-configuration \
        --function-name ${module.lambdas.skill_function_name} \
        --environment "Variables={AGENT_ID=${module.bedrock_agent.agent_id},AGENT_ALIAS_ID=${module.bedrock_agent.agent_alias_id}}" \
        --region ${var.aws_region}
    EOF
  }
}
