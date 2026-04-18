#!/bin/bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALEXA_DIR="${SCRIPT_DIR}/../alexa"
INFRA_DIR="${SCRIPT_DIR}/../infra"
TFVARS="${INFRA_DIR}/terraform.tfvars"

# Obtener Lambda ARN desde terraform
LAMBDA_NAME=$(cd "$INFRA_DIR" && terraform output -raw skill_function_name)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}"

echo "==> Lambda ARN: ${LAMBDA_ARN}"

# Inyectar ARN en skill.json
SKILL_JSON="${ALEXA_DIR}/skill-package/skill.json"
TMP=$(mktemp)
jq --arg arn "$LAMBDA_ARN" \
  '.manifest.apis.custom.endpoint = {uri: $arn}' \
  "$SKILL_JSON" > "$TMP" && mv "$TMP" "$SKILL_JSON"

echo "==> skill.json actualizado"

# Desplegar skill al Alexa Developer Console
cd "$ALEXA_DIR"
echo "==> subiendo skill al Alexa Developer Console"
npx ask-cli deploy

# Extraer Skill ID
SKILL_ID=$(jq -r '.profiles.default.skillId' .ask/ask-states.json)
echo "==> Skill ID: ${SKILL_ID}"

# Persistir Skill ID en terraform.tfvars
if grep -q "alexa_skill_id" "$TFVARS" 2>/dev/null; then
  sed -i '' "s|alexa_skill_id.*|alexa_skill_id = \"${SKILL_ID}\"|" "$TFVARS"
else
  echo "alexa_skill_id = \"${SKILL_ID}\"" >> "$TFVARS"
fi
echo "==> terraform.tfvars actualizado"

# Aplicar solo el permission (terraform.tfvars se carga automáticamente)
cd "$INFRA_DIR"
terraform apply -auto-approve -target=aws_lambda_permission.alexa

echo ""
echo "==> deploy completo. Skill ID: ${SKILL_ID}"
