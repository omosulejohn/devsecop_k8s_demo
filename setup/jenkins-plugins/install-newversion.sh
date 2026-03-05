#!/bin/bash

set -euo pipefail

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_TOKEN="YOUR_API_TOKEN_HERE" #GET the token from Manage Jenkins → Users → admin → API Token

echo "Checking Jenkins availability..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -u ${JENKINS_USER}:${JENKINS_TOKEN} \
  ${JENKINS_URL}/login)

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Cannot authenticate to Jenkins. HTTP code: $HTTP_CODE"
  exit 1
fi

echo "✔ Jenkins reachable and authenticated"

echo "Getting CSRF crumb..."

CRUMB_RESPONSE=$(curl -s \
  -u ${JENKINS_USER}:${JENKINS_TOKEN} \
  ${JENKINS_URL}/crumbIssuer/api/json)

if ! echo "$CRUMB_RESPONSE" | jq . >/dev/null 2>&1; then
  echo "❌ Failed to retrieve crumb. Response:"
  echo "$CRUMB_RESPONSE"
  exit 1
fi

JENKINS_CRUMB=$(echo "$CRUMB_RESPONSE" | jq -r .crumb)

echo "✔ Crumb obtained"

echo "Installing plugins from plugins.txt..."

while read -r plugin; do
  [ -z "$plugin" ] && continue

  echo "Installing ${plugin}..."

  curl -s -X POST \
    -u "${JENKINS_USER}:${JENKINS_TOKEN}" \
    -H "Jenkins-Crumb:${JENKINS_CRUMB}" \
    -H "Content-Type: text/xml" \
    --data "<jenkins><install plugin='${plugin}' /></jenkins>" \
    "${JENKINS_URL}/pluginManager/installNecessaryPlugins"

done < plugins.txt

echo "✔ Plugin installation requests sent"

echo "Triggering safe restart..."

curl -s -X POST \
  -u "${JENKINS_USER}:${JENKINS_TOKEN}" \
  -H "Jenkins-Crumb:${JENKINS_CRUMB}" \
  "${JENKINS_URL}/safeRestart"

echo "🎉 Done."