#!/bin/bash



# Check for modified files and process them
check_and_process_modified_files() {
  local file_extension=$1
  local detected_modified_files
  detected_modified_files=$(git diff origin/master...origin/"$BRANCH_NAME" --name-only | grep -i "$file_extension")

  if [[ -z "$detected_modified_files" ]]; then
    echo "No changes found with suffix $file_extension."
    return
  fi

  local filenames
  filenames=($(echo "$detected_modified_files" | grep -E '^[^.]+\.'"$file_extension" | xargs -r basename))

  if [[ -z "$filenames" ]]; then
    echo "No changes found with suffix $file_extension."
    return
  fi

  process_modified_files "$filenames" "$file_extension" "$detected_modified_files"
}

process_modified_files() {
  local filenames=$1
  local file_extension=$2
  local detected_modified_files=$3
  local master_branch="master"

  local jwt_key_temp_file=$(mktemp)
  echo "$JWT_KEY" >"$jwt_key_temp_file"
  local random_string=$(openssl rand -hex 5)
  local scratch_org_definition="config/project-scratch-def.json"
  echo "Scratch org alias: $random_string"
  sfdx force:auth:jwt:grant --clientid "$CLIENT_ID" --jwtkeyfile "$jwt_key_temp_file" --username "$USERNAME" --setdefaultdevhubusername
  echo "Access granted"
  sfdx force:config:set defaultdevhubusername="$USERNAME" --global
  sfdx force:org:create -f "$scratch_org_definition" --setalias "$random_string" --durationdays 7 -a "$random_string"
  echo "org created"

  local instance_url=$(sfdx force:org:display -u $random_string --json | jq -r '.result.instanceUrl')
  echo "INSTANCE_URL : $instance_url"

  SID=$(sfdx force:org:display -u $random_string --json | jq -r '.result.accessToken' )
    echo "SID : $SID"

  sfdx force:source:push -u "$random_string"

  rm "$jwt_key_temp_file"

  for file in "${filenames[@]}"; do
    local file_path_without_extension="${file%.$file_extension}"
    local old_version_file="old_$file_path_without_extension.xml"

    git show "origin/$master_branch:$detected_modified_files" >"$old_version_file"
    local new_version_file="$detected_modified_files"
    local comparison_output=$(python scripts/flow_comparison_table.py "$old_version_file" "$new_version_file" "$file")
    comparison_output="${comparison_output//$'\n'/'%0A'}" # Replace newline characters with %0A
    local file_link=$(generate_link_to_file "$file_path_without_extension" "$file_extension" "$detected_modified_files")
    local combined_output="${comparison_output} Link to File: $file_link"
    echo -e "::set-output name=output::$combined_output"
  done
}

generate_link_to_file() {
  local file_path_without_extension=$1
  local file_extension=$2
  local detected_modified_files=$3

  if [[ $file_extension == "object-meta.xml" ]]; then
    IFS="/" read -ra path_components <<< "$detected_modified_files"
    local object_name="${path_components[4]}"
  elif [[ $file_extension == "validationRule-meta.xml" ]]; then
    IFS="/" read -ra path_components <<< "$detected_modified_files"
    local object_name="${path_components[4]}"
  elif [[ $file_extension == "field-meta.xml" ]]; then
    IFS="/" read -ra path_components <<< "$detected_modified_files"
    local object_name="${path_components[4]}"
  fi

  if [[ $file_suffix == "flow-meta.xml" ]]; then
    local FLOW=$(sfdx force:data:record:get -s FlowDefinition -w "DeveloperName=$file_path" -t -u $RANDOM_STRING --json)
    local FLOW_ID=$(echo "$FLOW" | jq -r '.result.ActiveVersionId')
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/builder_platform_interaction/flowBuilder.app?flowId=${FLOW_ID}"

  elif [[ $file_suffix == "flexipage-meta.xml" ]]; then
    local appBuilder=$(sfdx force:data:record:get -s FlexiPage -w "DeveloperName=$file_path" -t -u $RANDOM_STRING --json)
    local appBuilder_ID=$(echo "$appBuilder" | jq -r '.result.ActiveVersionId')
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/visualEditor/appBuilder.app?id=${appBuilder_ID}"

  elif [[ $file_suffix == "object-meta.xml" ]]; then
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${objectName}/Details/view"

  elif [[ $file_suffix == "field-meta.xml" ]]; then
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${objectName}/FieldsAndRelationships/${file_path}/view"

  elif [[ $file_suffix == "validationRule-meta.xml" ]]; then
    local VALIDATION_RULE=$(sfdx force:data:record:get -s ValidationRule -w "ValidationName=$file_path" -t -u $RANDOM_STRING --json)
    local VALIDATION_RULE_ID=$(echo "$VALIDATION_RULE" | jq -r '.result.Id')
    echo "${INSTANCE_URL}/secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${objectName}/ValidationRules/${VALIDATION_RULE_ID}/view"
  else
    echo "Unknown file type : $file_suffix"
  fi
}


main() {
  check_and_process_modified_files "field-meta.xml"
  check_and_process_modified_files "flow-meta.xml"
  check_and_process_modified_files "flexipage-meta.xml"
  check_and_process_modified_files "object-meta.xml"
  check_and_process_modified_files "validationRule-meta.xml"
}

main
