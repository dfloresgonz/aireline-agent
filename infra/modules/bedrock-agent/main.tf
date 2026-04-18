data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ── S3 Vectors (vector store) ─────────────────────────────────────────────────

resource "aws_s3vectors_vector_bucket" "kb" {
  vector_bucket_name = "${var.name_prefix}-kb-vectors"
}

resource "aws_s3vectors_index" "kb" {
  vector_bucket_name = aws_s3vectors_vector_bucket.kb.vector_bucket_name
  index_name         = "${var.name_prefix}-kb-index"
  data_type          = "float32"
  dimension          = 1024 # amazon.titan-embed-text-v2:0
  distance_metric    = "cosine"
}

# ── IAM role para Knowledge Base ──────────────────────────────────────────────

resource "aws_iam_role" "kb" {
  name = "${var.name_prefix}-bedrock-kb-role"
  tags = var.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "kb" {
  name = "kb-permissions"
  role = aws_iam_role.kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDocuments"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          var.kb_bucket_arn,
          "${var.kb_bucket_arn}/*",
        ]
      },
      {
        Sid      = "EmbeddingModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Sid    = "S3VectorsAccess"
        Effect = "Allow"
        Action = [
          "s3vectors:GetIndex",
          "s3vectors:PutVectors",
          "s3vectors:GetVectors",
          "s3vectors:DeleteVectors",
          "s3vectors:QueryVectors",
          "s3vectors:ListVectors",
        ]
        Resource = [
          aws_s3vectors_vector_bucket.kb.vector_bucket_arn,
          aws_s3vectors_index.kb.index_arn,
        ]
      },
    ]
  })
}

# ── Knowledge Base ────────────────────────────────────────────────────────────

resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.name_prefix}-kb"
  role_arn = aws_iam_role.kb.arn
  tags     = var.common_tags

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${local.region}::foundation-model/amazon.titan-embed-text-v2:0"
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = 1024
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.kb.index_arn
    }
  }

  depends_on = [aws_iam_role_policy.kb]
}

resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "${var.name_prefix}-s3-docs"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.kb_bucket_arn
    }
  }

  # Chunking fijo para respetar el límite de 2048 bytes de metadata en S3 Vectors.
  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 150
        overlap_percentage = 10
      }
    }
  }
}

# ── Bedrock Agent ─────────────────────────────────────────────────────────────

resource "aws_bedrockagent_agent" "main" {
  agent_name                  = "${var.name_prefix}-agent"
  agent_resource_role_arn     = var.agent_role_arn
  foundation_model            = var.bedrock_model_id
  idle_session_ttl_in_seconds = 600

  instruction = <<-EOT
    You are a helpful airline assistant. Respond in the same language the customer uses. Be concise and polite.

    You can:
    - Book flights with reservar_vuelo (needs: passenger_name, flight_number, departure_date, seat_class).
    - Look up reservations with consultar_reserva.
    - Answer policy questions using the knowledge base.

    IMPORTANT - reservation rule: you MUST ask a confirmation question before calling reservar_vuelo.
    List all details and end with "¿Confirmas?" (or equivalent in the customer's language).
    Call reservar_vuelo ONLY after the customer answers yes.
    If the customer says no, cancel and ask what else you can help with.
  EOT

  tags = var.common_tags
}

resource "aws_bedrockagent_agent_knowledge_base_association" "main" {
  agent_id             = aws_bedrockagent_agent.main.agent_id
  description          = "Airline policies: baggage, cancellations, pets"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.main.id
  knowledge_base_state = "ENABLED"
}

# ── Action Groups ─────────────────────────────────────────────────────────────

resource "aws_lambda_permission" "bedrock_reserva" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.reserva_lambda_arn
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/${aws_bedrockagent_agent.main.agent_id}"
}

resource "aws_lambda_permission" "bedrock_consultar_reserva" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.consultar_reserva_lambda_arn
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/${aws_bedrockagent_agent.main.agent_id}"
}

resource "aws_bedrockagent_agent_action_group" "reservar" {
  agent_id          = aws_bedrockagent_agent.main.agent_id
  agent_version     = "DRAFT"
  action_group_name = "reservar-vuelo"
  description       = "Book a new flight reservation"

  action_group_executor {
    lambda = var.reserva_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "reservar_vuelo"
        description = "Creates a new flight reservation for a passenger"
        parameters {
          map_block_key = "passenger_name"
          type          = "string"
          description   = "Full name of the passenger"
          required      = true
        }
        parameters {
          map_block_key = "flight_number"
          type          = "string"
          description   = "Flight number"
          required      = true
        }
        parameters {
          map_block_key = "departure_date"
          type          = "string"
          description   = "Departure date in YYYY-MM-DD format"
          required      = true
        }
        parameters {
          map_block_key = "seat_class"
          type          = "string"
          description   = "Seat class: economy, business, or first"
          required      = false
        }
      }
    }
  }

  depends_on = [aws_lambda_permission.bedrock_reserva]
}

resource "aws_bedrockagent_agent_action_group" "consultar" {
  agent_id          = aws_bedrockagent_agent.main.agent_id
  agent_version     = "DRAFT"
  action_group_name = "consultar-reserva"
  description       = "Look up an existing reservation"

  action_group_executor {
    lambda = var.consultar_reserva_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "consultar_reserva"
        description = "Retrieves details of an existing reservation by ID"
        parameters {
          map_block_key = "reservation_id"
          type          = "string"
          description   = "The reservation ID to look up"
          required      = true
        }
      }
    }
  }

  depends_on = [aws_lambda_permission.bedrock_consultar_reserva]
}

resource "aws_lambda_permission" "bedrock_consultar_clima" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.consultar_clima_lambda_arn
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/${aws_bedrockagent_agent.main.agent_id}"
}

resource "aws_bedrockagent_agent_action_group" "clima" {
  agent_id          = aws_bedrockagent_agent.main.agent_id
  agent_version     = "DRAFT"
  action_group_name = "consultar-clima"
  description       = "Get current weather for a city"

  action_group_executor {
    lambda = var.consultar_clima_lambda_arn
  }

  function_schema {
    member_functions {
      functions {
        name        = "consultar_clima"
        description = "Returns current temperature and weather condition for a given city"
        parameters {
          map_block_key = "city"
          type          = "string"
          description   = "City name (e.g. Mexico City, Miami, Madrid)"
          required      = true
        }
      }
    }
  }

  depends_on = [aws_lambda_permission.bedrock_consultar_clima]
}

# ── Agent Alias ───────────────────────────────────────────────────────────────

resource "aws_bedrockagent_agent_alias" "live" {
  agent_alias_name = "live"
  agent_id         = aws_bedrockagent_agent.main.agent_id
  tags             = var.common_tags

  depends_on = [
    aws_bedrockagent_agent_action_group.reservar,
    aws_bedrockagent_agent_action_group.consultar,
    aws_bedrockagent_agent_action_group.clima,
    aws_bedrockagent_agent_knowledge_base_association.main,
  ]
}
