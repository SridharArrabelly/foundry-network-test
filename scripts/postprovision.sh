#!/usr/bin/env bash
# postprovision hook: invoke the indexer ON THE JUMPBOX VM via
# `az vm run-command`, since Cloud Shell / local machines cannot reach the
# private endpoints.

set -euo pipefail

echo "=== postprovision: running indexer on jumpbox via az vm run-command ==="

: "${AZURE_RESOURCE_GROUP:?AZURE_RESOURCE_GROUP must be set by azd}"
: "${JUMPBOX_VM_NAME:?JUMPBOX_VM_NAME must be set by azd}"
: "${AI_SEARCH_ENDPOINT:?AI_SEARCH_ENDPOINT must be set by azd}"
: "${AI_FOUNDRY_ENDPOINT:?AI_FOUNDRY_ENDPOINT must be set by azd}"

# Determine repo URL + branch (this hook runs from inside the user's clone).
REPO_URL="$(git config --get remote.origin.url)"
REPO_BRANCH="${REPO_BRANCH:-$(git symbolic-ref --quiet --short HEAD || echo master)}"
INDEX_NAME="${AI_SEARCH_INDEX_NAME:-documents-index}"
EMBED_MODEL="${EMBEDDING_MODEL:-text-embedding-3-large}"
EMBED_DIMS="${EMBEDDING_DIMENSIONS:-3072}"

echo "  Repo:     $REPO_URL @ $REPO_BRANCH"
echo "  VM:      $JUMPBOX_VM_NAME (rg: $AZURE_RESOURCE_GROUP)"
echo "  Search:  $AI_SEARCH_ENDPOINT"
echo "  Foundry: $AI_FOUNDRY_ENDPOINT"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jumpbox-bootstrap.ps1"

echo "==> Invoking jumpbox bootstrap (this can take 5-10 min on first run)..."
az vm run-command invoke \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$JUMPBOX_VM_NAME" \
  --command-id RunPowerShellScript \
  --scripts "@${SCRIPT_PATH}" \
  --parameters \
      "RepoUrl=$REPO_URL" \
      "RepoBranch=$REPO_BRANCH" \
      "AiSearchEndpoint=$AI_SEARCH_ENDPOINT" \
      "AiFoundryEndpoint=$AI_FOUNDRY_ENDPOINT" \
      "AiSearchIndexName=$INDEX_NAME" \
      "EmbeddingModel=$EMBED_MODEL" \
      "EmbeddingDimensions=$EMBED_DIMS" \
  --output json
