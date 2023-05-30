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





     # Use the access token for further API requests
     # Example: Make a Tooling API query request
     INSTANCE_URL=$(sfdx force:org:display --json | jq -r '.result.instanceUrl')
     API_VERSION=$(sfdx force:org:display --json | jq -r '.result.defaultApiVersion')
     SOQL_QUERY="YOUR_SOQL_QUERY"

     QUERY_URL="${INSTANCE_URL}/services/data/${API_VERSION}/tooling/query?q=${SOQL_QUERY}"

     RESPONSE=$(curl -X GET -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "X-PrettyPrint: 1" "${QUERY_URL}")

     echo "Query response:"
     echo "${RESPONSE}"


    JWT_KEY_FILE=$(mktemp)
        echo "$JWT_KEY" > "$JWT_KEY_FILE"
        RANDOM_STRING=$(openssl rand -hex 5)
        SCRATCH_ORG_DEFINITION="config/project-scratch-def.json"
        echo "Scratch org alias: $RANDOM_STRING"

        # Аутентификация с использованием ключевого файла
        sfdx force:auth:jwt:grant --clientid "$CLIENT_ID" --jwtkeyfile "$JWT_KEY_FILE" --username "$USERNAME" --setdefaultdevhubusername


        echo "Access granted"

     # Step 1: Run the sfdx force:auth:jwt:grant command
     RESULT=$(sfdx force:auth:jwt:grant --clientid "$CLIENT_ID" --jwtkeyfile "$JWT_KEY_FILE" --username "$USERNAME" --setdefaultdevhubusername)

     # Check the command result
     if [[ $RESULT =~ "Successfully authorized" ]]; then
       echo "Authentication successful!"
     else
       echo "Authentication failed. Please check your client ID, JWT key file, and username."
       exit 1
     fi
     echo "RESULT $RESULT"
      # Extract the access token from the command result
          ACCESS_TOKEN=$(echo "$RESULT" | grep -oP '(?<=access token=)[^&]+')
           echo "ACCESS_TOKEN $ACCESS_TOKEN"
        # Установка алиаса для Dev Hub
        sfdx force:config:set defaultdevhubusername="$USERNAME" --global

        # Создание новой Scratch org
        sfdx force:org:create -f "$SCRATCH_ORG_DEFINITION" --setalias "$RANDOM_STRING" --durationdays 7 -a "$RANDOM_STRING"
        echo "org created"

        SCRATCH_ORG_URL=$(sfdx force:org:open -u "$RANDOM_STRING" --urlonly)
        echo "SCRATCH_ORG_URL: $SCRATCH_ORG_URL"



    sfdx force:source:push -u "$RANDOM_STRING"



LABEL="flaoopppw"
INSTANCE_URL=$(sfdx force:org:display --json | jq -r '.result.instanceUrl')
API_VERSION=$(sfdx force:org:display --json | jq -r '.result.defaultApiVersion')
echo "INSTANCE_URL $INSTANCE_URL"
echo "API_VERSION $API_VERSION"
SOQL_QUERY="YOUR_SOQL_QUERY"

QUERY_URL="${INSTANCE_URL}/services/data/${API_VERSION}/tooling/query?q=${SOQL_QUERY}"

RESPONSE=$(curl -X GET -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "X-PrettyPrint: 1" "${QUERY_URL}")

echo "Query response:"
echo "${RESPONSE}"

        FLOW_LINK="https://$SCRATCH_ORG_URL/lightning/r/Flow/$FLOW_ID/view"

        echo "Flow Link: $FLOW_LINK"
    rm "$JWT_KEY_FILE"
}

# Проверка наличия зависимостей и запуск скрипта
main() {
    check_dependencies
    check_flow_changes
}

main
