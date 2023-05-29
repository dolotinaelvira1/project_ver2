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
        flow_comparison_output=$(python scripts/flow_comparison_table.py "$old_flow_file" "$new_flow_file" "$file")
        echo -e "::set-output name=output::$flow_comparison_output"
        rm "$old_flow_file"
    done
}

# Проверка наличия зависимостей и запуск скрипта
main() {
    check_dependencies
    check_flow_changes
}

main
