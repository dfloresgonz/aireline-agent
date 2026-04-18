#!/bin/bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
cd "$(dirname "$0")/../infra"

echo "==> terraform init"
terraform init

echo "==> terraform apply"
terraform apply -auto-approve -var="aws_region=${AWS_REGION}"

echo "==> outputs"
terraform output
