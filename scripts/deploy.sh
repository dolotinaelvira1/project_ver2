#!/bin/bash

# Проверка наличия необходимых утилит
check_dependencies() {
  local dependencies=("git" "grep" "xargs" "basename")
  for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "Požadovaný nástroj $dep nebyl nalezen. Nainstalujte ho a zkuste to znovu."
      exit 1
    fi
  done
}

# Проверка наличия измененных файлов Flow
check_and_process_files() {
  local file_suffix=$1
  local modified_files_path
  modified_files_path=$(git diff origin/master...origin/"$BRANCH_NAME" --name-only | grep -i "$file_suffix")

  if [[ -z "$modified_files_path" ]]; then
    echo "no changes  found with suffix $file_suffix."
    return
  fi

  local files
  files=($(echo "$modified_files_path" | grep -E '^[^.]+\.'"$file_suffix" | xargs -r basename))

  if [[ -z "$files" ]]; then
    echo "no changes found with suffix $file_suffix."
    return
  fi


  process_files "$files"  "$file_suffix" "$modified_files_path"
}

process_files() {
  local files=$1
  local file_suffix=$3
  local modified_files_path=$4
  local target_branch="master"

JWT_KEY_FILE=$(mktemp)
  echo "$JWT_KEY" >"$JWT_KEY_FILE"
  RANDOM_STRING=$(openssl rand -hex 5)
  SCRATCH_ORG_DEFINITION="config/project-scratch-def.json"
  echo "Scratch org alias: $RANDOM_STRING"
  sfdx force:auth:jwt:grant --clientid "$CLIENT_ID" --jwtkeyfile "$JWT_KEY_FILE" --username "$USERNAME" --setdefaultdevhubusername
  echo "Access granted"
  sfdx force:config:set defaultdevhubusername="$USERNAME" --global
  sfdx force:org:create -f "$SCRATCH_ORG_DEFINITION" --setalias "$RANDOM_STRING" --durationdays 7 -a "$RANDOM_STRING"
  echo "org created"
  SCRATCH_ORG_URL=$(sfdx force:org:open -u $RANDOM_STRING --urlonly)
  echo "SCRATCH_ORG_URL : $SCRATCH_ORG_URL"
  INSTANCE_URL=$(sfdx force:org:display -u $RANDOM_STRING --json | jq -r '.result.instanceUrl')
  echo "INSTANCE_URL : $INSTANCE_URL"

  SID=$(sfdx force:org:display -u $RANDOM_STRING --json | jq -r '.result.accessToken' )
  echo "SID : $SID"

  sfdx force:source:push -u "$RANDOM_STRING"

  rm "$JWT_KEY_FILE"



  for file in "${files[@]}"; do
    local file_dev_name="${file%.$file_suffix}"
    local old_file="old_$file_dev_name.xml"
    local object_path=""

    git show "origin/$target_branch:$modified_files_path" >"$old_file"
    local new_file="$modified_files_path"
    local comparison_output=$(python scripts/flow_comparison_table.py "$old_file" "$new_file" "$file")
    comparison_output="${comparison_output//$'\n'/'%0A'}" # Replace newline characters with %0A
    local LINK_TO_FILE=$(generate_link "$file_dev_name" "$file_suffix" "$modified_files_path")
    local combined_output="${comparison_output} Link to File: $LINK_TO_FILE"
    echo -e "::set-output name=output::$combined_output"
  done
}

generate_link() {
  local file_dev_name=$2
  local file_suffix=$3
  local modified_files_path=$4

  if [[ $file_suffix == "object-meta.xml" ]]; then
     IFS="/" read -ra path_components <<< "$modified_files_path"
     objectName="${path_components[4]}"
  elif [[ $file_suffix == "validationRule-meta.xml" ]]; then
     IFS="/" read -ra path_components <<< "$modified_files_path"
     objectName="${path_components[4]}"
  elif [[ $file_suffix == "field-meta.xml" ]]; then
     IFS="/" read -ra path_components <<< "$modified_files_path"
     objectName="${path_components[4]}"
  fi

  if [[ $file_suffix == "flow-meta.xml" ]]; then
    local FLOW=$(sfdx force:data:record:get -s FlowDefinition -w "DeveloperName=$file_dev_name" -t -u $RANDOM_STRING --json)
    local FLOW_ID=$(echo "$FLOW" | jq -r '.result.ActiveVersionId')
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/builder_platform_interaction/flowBuilder.app?flowId=${FLOW_ID}"

  elif [[ $file_suffix == "flexipage-meta.xml" ]]; then
    local appBuilder=$(sfdx force:data:record:get -s FlexiPage -w "DeveloperName=$file_dev_name" -t -u $RANDOM_STRING --json)
    local appBuilder_ID=$(echo "$appBuilder" | jq -r '.result.ActiveVersionId')
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/visualEditor/appBuilder.app?id=${appBuilder_ID}"

  elif [[ $file_suffix == "object-meta.xml" ]]; then
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${objectName}/Details/view"

  elif [[ $file_suffix == "field-meta.xml" ]]; then
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${objectName}/FieldsAndRelationships/${file_dev_name}/view"

  elif [[ $file_suffix == "validationRule-meta.xml" ]]; then
    local VALIDATION_RULE=$(sfdx force:data:record:get -s ValidationRule -w "ValidationName=$file_dev_name" -t -u $RANDOM_STRING --json)
    local VALIDATION_RULE_ID=$(echo "$VALIDATION_RULE" | jq -r '.result.Id')
    echo "${INSTANCE_URL}/secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${objectName}/ValidationRules/${VALIDATION_RULE_ID}/view"
  else
    echo "Unknown file type: $file_suffix"
  fi
}


main() {
  check_and_process_files "field-meta.xml"
  check_and_process_files "flow-meta.xml"
  check_and_process_files "flexipage-meta.xml"
  check_and_process_files "object-meta.xml"
  check_and_process_files "validationRule-meta.xml"
}

main
