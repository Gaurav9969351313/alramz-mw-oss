#!/bin/bash
set -euo pipefail
INPUT=$(cat)
eval "$(printf '%s' "$INPUT" | jq -r '@sh "PRINCIPAL_ID=\(.var_identity_principal_id) SCOPE=\(.var_scope) ROLE=\(.var_role)"')"
EXISTS=$(az role assignment list \
  --assignee "$PRINCIPAL_ID" \
  --scope "$SCOPE" \
  --role "$ROLE" \
  --query "[?principalId=='$PRINCIPAL_ID'].id|[0]" \
  -o tsv 2>/dev/null || true)
if [ -n "$EXISTS" ]; then
  echo '{"exists":"true"}'
else
  echo '{"exists":"false"}'
fi