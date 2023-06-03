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
  local modified_files
  modified_files=$(git diff origin/master...origin/"$BRANCH_NAME" --name-only | grep -i "$file_suffix")

  if [[ -z "$modified_files" ]]; then
    echo "no changes  found with suffix $file_suffix."
    return
  fi

  local files
  files=($(echo "$modified_files" | grep -E '^[^.]+\.'"$file_suffix" | xargs -r basename))

  if [[ -z "$files" ]]; then
    echo "no changes found with suffix $file_suffix."
    return
  fi

  local names=()

  for filename in "${files[@]}"; do
    local name=${filename%.$file_suffix}
    names+=("$name")
  done

  process_files "$files" "${names[@]}" "$file_suffix"
}

process_files() {
  local files=$1
  local names=$2
  local file_suffix=$3
  local target_branch="master"

  echo "Processing files with suffix $file_suffix: $files"
  echo "File names: ${names[@]}"


  for file in "${files[@]}"; do
    local file_path="${file%.$file_suffix}"
    echo" file : $file"

    local old_file="old_$file_path.xml"
    local object_path=""

    if [[ $file_suffix == "flow-meta.xml" ]]; then
      source_path="force-app/main/default/flows"

    elif [[ $file_suffix == "flexipage-meta.xml" ]]; then
      source_path="force-app/main/default/flexipages"

    elif [[ $file_suffix == "object-meta.xml" ]]; then
      source_path="force-app/main/default/objects"
      object_path="$(basename "$file" ".$file_suffix" | cut -d'.' -f2)/"

    elif [[ $file_suffix == "field-meta.xml" ]]; then
      source_path="force-app/main/default/objects"
      object_path="$(basename "$file" ".$file_suffix" | cut -d'-' -f1)/fields"

    elif [[ $file_suffix == "validationRule-meta.xml" ]]; then

      objectName=$(echo "$file" | awk -F'/' '{print $(NF-2)}')
      source_path="force-app/main/default/objects/$objectName"
      echo "ObjectName: $objectName"

    fi

    git show "origin/$target_branch:$source_path/$objectName$file_path.$file_suffix" >"$old_file"
    local new_file="$source_path/$object_path$file_path.$file_suffix"
    local comparison_output=$(python scripts/flow_comparison_table.py "$old_file" "$new_file" "$file")
    comparison_output="${comparison_output//$'\n'/'%0A'}" # Replace newline characters with %0A
    local LINK_TO_FILE=$(generate_link "$file" "$file_path" "$file_suffix" "$objectName")
    local combined_output="${comparison_output} Link to File: $LINK_TO_FILE"
    echo -e "::set-output name=output::$combined_output"
  done
}

generate_link() {
  local file=$1
  local file_path=$2
  local file_suffix=$3
  local objectName=$4
  if [[ $file_suffix == "object-meta.xml" ]]; then
    objectName=$(basename "$file" ".$file_suffix" | cut -d'.' -f2)
  elif [[ $file_suffix == "field-meta.xml" ]]; then
    objectName=$(basename "$(dirname "$(dirname "$file")")")
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
    echo "Неизвестный тип файла: $file_suffix"
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
