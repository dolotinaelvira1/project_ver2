#!/bin/bash

export GITHUB_TOKEN='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'
export SOURCE_PATH='C:/Users/dolot/IdeaProjects/project_ver2/force-app/main/default'
export SCRATCH_ORG_DEFINITION='C:/Users/dolot/IdeaProjects/project_ver2/config/project-scratch-def.json'
export GITHUB_REPOSITORY="dolotinaelvira1/project_ver2"
export TARGET_BRANCH="master"

#set testUser credentials
PASSWORD="password123"
ORG_USERNAME="testuser@example.com"

# Get the commit hash for the latest commit
COMMIT_HASH=$(git rev-parse --abbrev-ref HEAD | awk -F'/' '{print $2}')
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

# Open the scratch org
sfdx force:org:open -u $RANDOM_STRING

FLOW_FILES=$(git diff-tree --no-commit-id --name-only -r COMMIT_HASH | grep -E '^[^.]+\.(flow-meta\.xml)$')
if [ -z "$FLOW_FILES" ]; then
  echo "No changes found in commit."
else
  echo "flow files: $FLOW_FILES"


fi


