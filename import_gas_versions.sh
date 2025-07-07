#!/bin/bash

set -e
set -u

SCRIPT_ID="$1"
AUTHOR_NAME="$2"
AUTHOR_EMAIL="$3"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

echo '{"scriptId":"'"$SCRIPT_ID"'"}' > .clasp.json
echo ".clasp.json" >> .gitignore
git add .gitignore

if git ls-files --error-unmatch ".clasp.json" > /dev/null 2>&1; then
  git rm --cached ".clasp.json"
fi

RC_FILE_PATH="$HOME/.clasprc.json"
REFRESH_TOKEN=$(jq -r '.tokens.default.refresh_token' "$RC_FILE_PATH")
CLIENT_ID=$(jq -r '.tokens.default.client_id' "$RC_FILE_PATH")
CLIENT_SECRET=$(jq -r '.tokens.default.client_secret' "$RC_FILE_PATH")
TOKEN_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
     --data-urlencode "client_id=$CLIENT_ID" \
     --data-urlencode "client_secret=$CLIENT_SECRET" \
     --data-urlencode "refresh_token=$REFRESH_TOKEN" \
     --data-urlencode "grant_type=refresh_token")
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
    echo "Error: Failed to get access token from Google."
    exit 1
fi
echo "Successfully obtained access token."

API_URL_BASE="https://script.googleapis.com/v1/projects/$SCRIPT_ID/versions"
ALL_VERSIONS_FILE=$(mktemp)
PAGE_TOKEN=""

while true; do
  API_URL="$API_URL_BASE"
  [ -n "$PAGE_TOKEN" ] && API_URL="$API_URL_BASE?pageToken=$PAGE_TOKEN"
  CURRENT_PAGE_JSON=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL")
  if echo "$CURRENT_PAGE_JSON" | jq -e 'has("error")' > /dev/null; then
    echo "Error fetching versions from API"
    exit 1
  fi
  echo "$CURRENT_PAGE_JSON" | jq -c '.versions[]' >> "$ALL_VERSIONS_FILE"
  PAGE_TOKEN=$(echo "$CURRENT_PAGE_JSON" | jq -r '.nextPageToken // ""')
  [ -z "$PAGE_TOKEN" ] || [ "$PAGE_TOKEN" == "null" ] && break
done

VERSIONS_JSON=$(jq -s '.' "$ALL_VERSIONS_FILE")
rm "$ALL_VERSIONS_FILE"

echo "$VERSIONS_JSON" | jq -c 'reverse | .[]' | while read -r version_info; do
  VERSION_NUMBER=$(echo "$version_info" | jq -r '.versionNumber')
  CREATE_TIME=$(echo "$version_info" | jq -r '.createTime')
  DESCRIPTION=$(echo "$version_info" | jq -r '.description // "No description"')
  ESCAPED_DESCRIPTION=$(echo "$DESCRIPTION" | tr '\n' ' ' | sed 's/"/\\"/g')

  echo "Processing Version: $VERSION_NUMBER"

  # Check if this version has already been committed
  if [ -n "$(git log --oneline --grep="^Version $VERSION_NUMBER:")" ]; then
    echo "  - Version $VERSION_NUMBER already committed. Skipping."
    continue
  fi
  
  # Clean up GAS files
  find . -maxdepth 1 -type f \( -name "*.js" -o -name "*.html" -o -name "*.gs" -o -name "appsscript.json" \) -delete

  if ! npx clasp pull --versionNumber "$VERSION_NUMBER" > /dev/null; then
      echo "  - WARNING: Failed to pull version $VERSION_NUMBER. Skipping."
      continue
  fi

  git add -A
  
  AUTHOR_OPTION=""
  if [ -n "$AUTHOR_NAME" ] && [ -n "$AUTHOR_EMAIL" ]; then
    AUTHOR_OPTION="--author='$AUTHOR_NAME <$AUTHOR_EMAIL>'"
  fi

  GIT_COMMITTER_DATE="$CREATE_TIME" git commit --allow-empty -m "Version $VERSION_NUMBER: $ESCAPED_DESCRIPTION" --date="$CREATE_TIME" $AUTHOR_OPTION
done

