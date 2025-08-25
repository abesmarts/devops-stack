#!/usr/bin/env bash
set -euo pipefail

cd infra/tofu/

echo "🔹 Initializing tofu/terraform..."
tofu init

echo "🔹 Planning the VM deployment..."
tofu plan -out=tfplan

echo "🔹 Applying the VM deployment..."
tofu apply -auto-approve tfplan

echo "✅ VM deployment complete!"

# Optional: Show outputs
echo "🔹 Terraform outputs:"
tofu output
