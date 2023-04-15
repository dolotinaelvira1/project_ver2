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



for FILE in $FLOW_FILES; do
   # ... (your existing code)
   # Get the file path without the file extension and remove the .flow-meta part
   FILE_PATH="${FILE%.flow-meta.xml}"

   # Print debug info
   echo "Checking for old version in branch: $TARGET_BRANCH"
   echo "File path: $SOURCE_PATH/flows/$FILE_PATH.flow-meta.xml"

   # Check if the old version of the flow file exists in the target branch
   if git cat-file -e origin/$TARGET_BRANCH:$SOURCE_PATH/flows/$FILE_PATH.flow-meta.xml 2>/dev/null; then

      # Get the old version of the flow file from the target branch
      OLD_FLOW_FILE_CONTENT=$(git show origin/$TARGET_BRANCH:$SOURCE_PATH/flows/$FILE_PATH.flow-meta.xml)

      # Save the old version of the flow file to a temporary file
      OLD_FLOW_FILE="old_$FILE_PATH.xml"
      echo "$OLD_FLOW_FILE_CONTENT" > "$OLD_FLOW_FILE"

      # Get the new version of the flow file at the current commit
      NEW_FLOW_FILE="$SOURCE_PATH/flows/$FILE_PATH.flow-meta.xml"

      # Call the Python script for comparing flows
      flow_comparison_output=$(python scripts/flow_comparison_table.py "$OLD_FLOW_FILE" "$NEW_FLOW_FILE")

      # Echo the table
      echo "$flow_comparison_output"

      # Remove the temporary old flow file
      rm "$OLD_FLOW_FILE"
   else
      echo "Old version of $FILE not found in the target branch. Skipping comparison."
   fi

done

fi

