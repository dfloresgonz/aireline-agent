#!/bin/bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
DOCS_DIR="$(dirname "$0")/../knowledge-base/docs"
cd "$(dirname "$0")/../infra"

BUCKET=$(terraform output -raw kb_bucket_name)
KB_ID=$(terraform output -raw knowledge_base_id)
DS_ID=$(terraform output -raw data_source_id)

echo "==> subiendo docs a s3://${BUCKET}/docs/"
aws s3 sync "${DOCS_DIR}" "s3://${BUCKET}/docs/" \
  --region "${AWS_REGION}" \
  --delete

echo "==> iniciando ingestion job"
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "${KB_ID}" \
  --data-source-id "${DS_ID}" \
  --region "${AWS_REGION}"

echo "==> seed completo"
