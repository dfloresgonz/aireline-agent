#!/bin/bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
cd "$(cd "$(dirname "$0")" && pwd)/../infra"

read -r -p "¿Seguro que quieres destruir toda la infraestructura? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Cancelado."
  exit 0
fi

echo "==> terraform destroy"
terraform destroy -auto-approve \
  -var="aws_region=${AWS_REGION}"

echo "==> done"
