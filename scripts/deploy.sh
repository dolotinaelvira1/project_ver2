#!/bin/bash

export GITHUB_TOKEN='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'



# Get the commit hash for the latest commit
COMMIT_HASH=$(git rev-parse --abbrev-ref HEAD | awk -F'/' '{print $2}')


FLOW_FILES=$(git diff-tree --no-commit-id --name-only -r COMMIT_HASH | grep -E '^[^.]+\.(flow-meta\.xml)$')
if [ -z "$FLOW_FILES" ]; then
  echo "No changes found in commit."
else
  echo "flow files: $FLOW_FILES"

fi


