#!/bin/bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
cd "$(cd "$(dirname "$0")" && pwd)/../infra"

read -r -p "¿Seguro que quieres destruir toda la infraestructura? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Cancelado."
  exit 0
fi

# The Bedrock API requires functionSchema when updating action groups, so
# update-agent-action-group --action-group-state DISABLED doesn't work without it.
# Instead, delete the agent directly (cascades to action groups), then remove
# those resources from TF state so destroy doesn't try to delete them again.
echo "==> deleting bedrock agent (cascades to action groups)"
AGENT_ID=$(terraform output -raw agent_id 2>/dev/null || echo "")
if [[ -n "$AGENT_ID" ]]; then
  aws bedrock-agent delete-agent \
    --agent-id "$AGENT_ID" \
    --skip-resource-in-use-check \
    --region "$AWS_REGION" > /dev/null 2>&1 || true
  echo "  agent $AGENT_ID deleted (or already deleting)"

  for STATE_ADDR in \
    "module.bedrock_agent.aws_bedrockagent_agent.main" \
    "module.bedrock_agent.aws_bedrockagent_agent_action_group.reservar" \
    "module.bedrock_agent.aws_bedrockagent_agent_action_group.consultar" \
    "module.bedrock_agent.aws_bedrockagent_agent_action_group.clima" \
    "module.bedrock_agent.aws_bedrockagent_agent_alias.live"; do
    terraform state rm "$STATE_ADDR" 2>/dev/null || true
  done
fi

# S3 versioning is enabled. Delete markers have VersionId="null" (string, not
# JSON null) for pre-versioning uploads; aws s3 rb --force and JMESPath-based
# delete-objects both fail on these. Build the payload with Python and loop
# until list-object-versions returns nothing, then delete the bucket.
echo "==> deleting versioned s3 bucket"
KB_BUCKET=$(terraform output -raw kb_bucket_name 2>/dev/null || echo "")
if [[ -n "$KB_BUCKET" ]]; then
  while true; do
    PAYLOAD=$(aws s3api list-object-versions \
      --bucket "$KB_BUCKET" --region "$AWS_REGION" --output json 2>/dev/null \
      | python3 -c "
import json,sys
d=json.load(sys.stdin)
objs=[{'Key':o['Key'],'VersionId':o['VersionId']}
      for src in [d.get('Versions') or [],d.get('DeleteMarkers') or []]
      for o in src]
print(json.dumps({'Objects':objs,'Quiet':True}) if objs else '')
" 2>/dev/null || echo "")
    [[ -z "$PAYLOAD" ]] && break
    aws s3api delete-objects \
      --bucket "$KB_BUCKET" --region "$AWS_REGION" \
      --delete "$PAYLOAD" > /dev/null
  done
  aws s3api delete-bucket \
    --bucket "$KB_BUCKET" --region "$AWS_REGION" 2>/dev/null || true
  terraform state rm "aws_s3_bucket.kb_docs" 2>/dev/null || true
  echo "  bucket $KB_BUCKET deleted"
fi

echo "==> terraform destroy"
terraform destroy -auto-approve \
  -var="aws_region=${AWS_REGION}"

echo "==> done"
