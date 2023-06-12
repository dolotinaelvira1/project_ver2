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

  local INSTANCE_URL=$(sfdx force:org:display -u $random_string --json | jq -r '.result.instanceUrl')
  echo "INSTANCE_URL : $INSTANCE_URL"

  SID=$(sfdx force:org:display -u $random_string --json | jq -r '.result.accessToken' )
    echo "SID : $SID"

  sfdx force:source:push -u "$random_string"

  rm "$jwt_key_temp_file"

  for file in "${filenames[@]}"; do
    local file_name="${file%.$file_extension}"
    local old_version_file="old_$file_name.xml"

    git show "origin/$master_branch:$detected_modified_files" >"$old_version_file"
    local new_version_file="$detected_modified_files"
    local comparison_output=$(python scripts/flow_comparison_table.py "$old_version_file" "$new_version_file" "$file")
    comparison_output="${comparison_output//$'\n'/'%0A'}" # Replace newline characters with %0A
    local file_link=$(generate_link_to_file "$file_name" "$file_extension" "$detected_modified_files")
    local combined_output="${comparison_output} Link to File: $file_link"
    echo -e "::set-output name=output::$combined_output"
  done
}

generate_link_to_file() {
  local file_name=$1
  local file_extension=$2
  local detected_modified_files=$3
  local object_name=""

  if [[ $file_extension == "object-meta.xml" ]]; then
    IFS="/" read -ra path_components <<< "$detected_modified_files"
    object_name="${path_components[4]}"
  elif [[ $file_extension == "validationRule-meta.xml" ]]; then
    IFS="/" read -ra path_components <<< "$detected_modified_files"
    object_name="${path_components[4]}"
  elif [[ $file_extension == "field-meta.xml" ]]; then
    IFS="/" read -ra path_components <<< "$detected_modified_files"
    object_name="${path_components[4]}"
  fi

  if [[ $file_extension == "flow-meta.xml" ]]; then
    local flow=$(sfdx force:data:record:get -s FlowDefinition -w "DeveloperName=$file_name" -t -u $random_string --json)
    local flow_id=$(echo "$flow" | jq -r '.result.ActiveVersionId')
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/builder_platform_interaction/flowBuilder.app?flowId=${flow_id}"

  elif [[ $file_extension == "flexipage-meta.xml" ]]; then
    local app_builder=$(sfdx force:data:record:get -s FlexiPage -w "DeveloperName=$file_name" -t -u $random_string --json)
    local app_builder_id=$(echo "$app_builder" | jq -r '.result.ActiveVersionId')
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/visualEditor/appBuilder.app?id=${app_builder_id}"

  elif [[ $file_extension == "object-meta.xml" ]]; then
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${object_name}/Details/view"

  elif [[ $file_extension == "field-meta.xml" ]]; then
    echo "${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${object_name}/FieldsAndRelationships/${file_name}/view"

  elif [[ $file_extension == "validationRule-meta.xml" ]]; then
    local validation_rule=$(sfdx force:data:record:get -s ValidationRule -w "ValidationName=$file_name" -t -u $random_string --json)
    local validation_rule_id=$(echo "$validation_rule" | jq -r '.result.Id')
    echo "${INSTANCE_URL}/secur/frontdoor.jsp?sid=${SID}&retURL=/lightning/setup/ObjectManager/${object_name}/ValidationRules/${validation_rule_id}/view"

  else
    echo "Unknown file type: $file_extension"
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
