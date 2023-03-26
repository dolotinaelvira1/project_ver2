#!/bin/bash

export GITHUB_TOKEN='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'
export SOURCE_PATH='C:/Users/dolot/IdeaProjects/project_ver2/force-app/main/default'
export SCRATCH_ORG_DEFINITION='C:/Users/dolot/IdeaProjects/project_ver2/config/project-scratch-def.json'
export GITHUB_REPOSITORY="dolotinaelvira1/project_ver2"
export TARGET_BRANCH="master"

# Get the commit hash for the latest commit
COMMIT_HASH=$(git rev-parse HEAD)

FLOW_FILES=$(git diff-tree --no-commit-id --name-only -r $COMMIT_HASH | grep -E '^[^.]+\.(flow-meta\.xml)$' | xargs basename)

if [ -z "$FLOW_FILES" ]; then
  echo "No changes found in commit."
else
  echo "flow files: $FLOW_FILES"



USERNAME=$(git config --get remote.origin.url | awk -F'/' '{print $4}')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD="$USERNAME:$BRANCH"


# Generate a random string for the scratch org alias
RANDOM_STRING=$(openssl rand -hex 5)
echo "Scratch org alias: $RANDOM_STRING"

# Authenticate with Salesforce using JWT flow
sfdx force:auth:jwt:grant --client-id=3MVG9t0sl2P.pBypyUQ9QtrDHltVGOGkJTU5Zjv_F8c22JCzQS2P8ZVqlmUgcbkTqh5UyJt..B2Er9OUeDZGZ --jwt-key-file=C:/Users/dolot/JWT/server.key --username=dolotinaelvira@empathetic-badger-rllf1u.com --set-default-dev-hub  --alias=DevHub



# Create a new scratch org
sfdx force:org:create -f "$SCRATCH_ORG_DEFINITION" --setalias $RANDOM_STRING --durationdays 7 -a $RANDOM_STRING


sfdx force:source:push -u $RANDOM_STRING



# Open the flows in the scratch org and retrieve their URLs
FLOW_URLS=""
for FILE in $FLOW_FILES; do
   FLOW_NAME=$(grep -oP '(?<=<label>)[^<]+' "$SOURCE_PATH/flows/$FILE")
  FLOW_URL=$(sfdx force:org:open -p "lightning/flow/$FLOW_NAME" -u $RANDOM_STRING  --urlonly)
  FLOW_URLS+="\n$FLOW_NAME: $FLOW_URL"
done

echo "flow name: $FLOW_NAME"
echo "flow url : $FLOW_URL"
SCRATCH_ORG_URL=$(sfdx force:org:open -u $RANDOM_STRING --urlonly)
echo "SCRATCH_ORG_URL : $SCRATCH_ORG_URL"
# Create a pull request with links to the flows in the scratch org
...
# Create a pull request with links to the flows in the scratch org
COMMENT="Please review the following flows in the scratch org at $SCRATCH_ORG_URL:$FLOW_URLS
credentials to access: "

# Replace the following line with the new one below
# COMMENT=${COMMENT//$'\n'/\\n}
COMMENT=$(echo -e "$COMMENT")

echo "Comment: $COMMENT"
echo "Head: $HEAD"
RESPONSE=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$GITHUB_REPOSITORY/pulls \
  -d "{\"title\":\"Peer review for declarative changes\",\"body\":\"$COMMENT\",\"head\":\"$HEAD\",\"base\":\"$TARGET_BRANCH\"}")
echo "Response: $RESPONSE"

PR_URL=$(echo "$RESPONSE" | grep "\"html_url\":" | awk '{print $2}' | tr -d '",')
echo "Pull request created: $PR_URL"
fi






