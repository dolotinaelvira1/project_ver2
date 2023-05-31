#!/bin/bash

# Проверка наличия необходимых утилит
check_dependencies() {
  local dependencies=("git" "grep" "xargs" "basename")
  for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "Необходимая утилита $dep не найдена. Установите ее и повторите попытку."
      exit 1
    fi
  done
}

# Проверка наличия измененных файлов Flow
check_flow_changes() {
  local modified_files
  modified_files=$(git diff origin/master...origin/$BRANCH_NAME --name-only | grep -i "flow-meta.xml")
  if [[ -z "$modified_files" ]]; then
    echo "Нет изменений в файлах Flow."
    exit 0
  fi

  local flow_files
  flow_files=$(echo "$modified_files" | grep -E '^[^.]+\.(flow-meta\.xml)$' | xargs -r basename)

  if [[ -z "$flow_files" ]]; then
    echo "Нет изменений в файлах Flow."
    exit 0
  fi

  for filename in "${flow_files[@]}"; do
    flow_name=${filename%.flow-meta.xml}
    flow_names+=("$flow_name")
  done

  process_flow_files "$flow_files" "${flow_names[@]}"
}

# Обработка файлов Flow
process_flow_files() {
  local flow_files=$1
  local target_branch="master"
  local source_path="force-app/main/default"

  echo "Processing flow files: $flow_files"
  # shellcheck disable=SC2145
  echo "Flow names: ${flow_names[@]}"

  JWT_KEY_FILE=$(mktemp)
  echo "$JWT_KEY" >"$JWT_KEY_FILE"
  RANDOM_STRING=$(openssl rand -hex 5)
  SCRATCH_ORG_DEFINITION="config/project-scratch-def.json"
  echo "Scratch org alias: $RANDOM_STRING"

  # Аутентификация с использованием ключевого файла
  sfdx force:auth:jwt:grant --clientid "$CLIENT_ID" --jwtkeyfile "$JWT_KEY_FILE" --username "$USERNAME" --setdefaultdevhubusername

  echo "Access granted"

  # Установка алиаса для Dev Hub
  sfdx force:config:set defaultdevhubusername="$USERNAME" --global

  # Создание новой Scratch org
  sfdx force:org:create -f "$SCRATCH_ORG_DEFINITION" --setalias "$RANDOM_STRING" --durationdays 7 -a "$RANDOM_STRING"
  echo "org created"
  SCRATCH_ORG_URL=$(sfdx force:org:open -u $RANDOM_STRING --urlonly)
  echo "SCRATCH_ORG_URL : $SCRATCH_ORG_URL"
  INSTANCE_URL=$(sfdx force:org:display -u $RANDOM_STRING --json | jq -r '.result.instanceUrl')
  echo "INSTANCE_URL : $INSTANCE_URL"

  SID_WITH_PARAM=$(echo $SCRATCH_ORG_URL | awk -F '?' '{print $2}')
  SID=$(echo $SID_WITH_PARAM | awk -F '=' '{print $2}')
  echo "SID : $SID"

  sfdx force:source:push -u "$RANDOM_STRING"

  rm "$JWT_KEY_FILE"

  for file in $flow_files; do
    local file_path="${file%.flow-meta.xml}"
    local old_flow_file="old_$file_path.xml"
    FLOWS_IN_ORG=$(sfdx force:data:record:get  -s FlowDefinition -w "DeveloperName=$file_path" -t -u $RANDOM_STRING --json)
    echo "FLOWS_IN_ORG: $FLOWS_IN_ORG"
    FLOW_ID=$(echo "$FLOWS_IN_ORG" | jq -r '.result.Id')
    echo "FLOW_ID: $FLOW_ID"
    LINK_TO_FLOW="${INSTANCE_URL}secur/frontdoor.jsp?sid=${SID}&retURL=/builder_platform_interaction/flowBuilder.app?flowId=${FLOW_ID}"
    git show "origin/$target_branch:$source_path/flows/$file_path.flow-meta.xml" >"$old_flow_file"
    local new_flow_file="$source_path/flows/$file_path.flow-meta.xml"
    flow_comparison_output=$(python scripts/flow_comparison_table.py "$old_flow_file" "$new_flow_file" "$file")
    flow_comparison_output="${flow_comparison_output//$'\n'/'%0A'}" # Replace newline characters with %0A
    combined_output="${flow_comparison_output}
        Link to Flow: $LINK_TO_FLOW"
    echo -e "::set-output name=output::$combined_output"
  done
}

# Проверка наличия зависимостей и запуск скрипта
main() {
  check_dependencies
  check_flow_changes
}

main
