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

    process_flow_files "$flow_files"
}
create_scratch_org() {
    RANDOM_STRING=$(openssl rand -hex 5)
    echo "Scratch org alias: $RANDOM_STRING"
    # Authenticate with Salesforce using JWT flow
    sfdx force:auth:jwt:grant --client-id=3MVG9t0sl2P.pBypyUQ9QtrDHltVGOGkJTU5Zjv_F8c22JCzQS2P8ZVqlmUgcbkTqh5UyJt..B2Er9OUeDZGZ --jwt-key-file=C:/Users/dolot/JWT/server.key --username=dolotinaelvira@empathetic-badger-rllf1u.com --set-default-dev-hub  --alias=DevHub
     echo "Access granted"
    # Create a new scratch org
    sfdx force:org:create -f "$SCRATCH_ORG_DEFINITION" --setalias $RANDOM_STRING --durationdays 7 -a $RANDOM_STRING
     echo "org created"
    SCRATCH_ORG_URL=$(sfdx force:org:open -u $RANDOM_STRING --urlonly)
    echo "SCRATCH_ORG_URL : $SCRATCH_ORG_URL"
    local scratch_org_url="https://example.com/scratch-org"

    echo "$scratch_org_url"
}

# Обработка файлов Flow
process_flow_files() {
    local flow_files=$1
    local target_branch="master"
    local source_path="force-app/main/default"

    for file in $flow_files; do
        local file_path="${file%.flow-meta.xml}"
        local old_flow_file="old_$file_path.xml"
        git show "origin/$target_branch:$source_path/flows/$file_path.flow-meta.xml" > "$old_flow_file"
        local new_flow_file="$source_path/flows/$file_path.flow-meta.xml"
        echo "elvira $old_flow_file"
        echo "elvira  $new_flow_file"
        flow_comparison_output=$(python scripts/flow_comparison_table.py "$old_flow_file" "$new_flow_file" "$file")
        flow_comparison_output="${flow_comparison_output//$'\n'/'%0A'}"  # Заменить символы новой строки на %0A
        echo -e "::set-output name=output::$flow_comparison_output"
    done
}

# Проверка наличия зависимостей и запуск скрипта
main() {
    check_dependencies
    check_flow_changes
}

main
