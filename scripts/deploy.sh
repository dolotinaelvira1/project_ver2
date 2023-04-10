#!/bin/bash

export GITHUB_TOKEN='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'
export SOURCE_PATH='C:/Users/dolot/IdeaProjects/project_ver2/force-app/main/default'
export SCRATCH_ORG_DEFINITION='C:/Users/dolot/IdeaProjects/project_ver2/config/project-scratch-def.json'
export GITHUB_REPOSITORY="dolotinaelvira1/project_ver2"
export TARGET_BRANCH="master"

# Get the commit hash for the latest commit
COMMIT_HASH=$(git rev-parse HEAD)

USERNAME=$(git config --get remote.origin.url | awk -F'/' '{print $4}')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD="$USERNAME:$BRANCH"

FLOW_CHANGES=$(python -c "import os, subprocess, sys
                          from xml.etree import ElementTree as ET
                          import difflib
                          import tempfile

                          if len(sys.argv) < 2:
                              print('Error: Commit hash not provided.')
                              sys.exit(1)

                          commit_hash = sys.argv[1]

                          def get_commit_changes(commit_hash):
                              changes_list = []
                              try:
                                  output = subprocess.check_output(['git', 'diff', commit_hash + '^', commit_hash]).decode('utf-8')
                                  lines = output.splitlines()
                                  for line in lines:
                                      if line.startswith('---') or line.startswith('+++'):
                                          status = 'edited' if line.startswith('---') else 'added'
                                          if line.endswith('/dev/null'):
                                              status = 'deleted'
                                          change = line.split(' ')[1][2:]
                                          if not change in changes_list:
                                              changes_list.append((status, change))
                              except subprocess.CalledProcessError as e:
                                  print('Error: {}'.format(e.output.decode("utf-8")))
                                  sys.exit(1)
                              return changes_list

                          def get_flow_diff(file1, file2):
                              root1 = ET.parse(file1).getroot()
                              root2 = ET.parse(file2).getroot()

                              xml1 = ET.tostring(root1, encoding='unicode', method='xml')
                              xml2 = ET.tostring(root2, encoding='unicode', method='xml')

                              d = difflib.Differ()
                              diff = list(d.compare(xml1.splitlines(), xml2.splitlines()))

                              formatted_diff = []
                              for i, line in enumerate(diff):
                                  if line.startswith('+ ') or line.startswith('- '):
                                      tag = line[2:].strip()
                                      if not tag.startswith('<'):
                                          continue
                                      operation = 'added' if line.startswith('+ ') else 'removed'
                                      formatted_diff.append('{} flow element: {}'.format(operation, tag))

                              return formatted_diff

                          flow_changes = []
                          for status, change in get_commit_changes(commit_hash):
                              if change.endswith('.flow-meta.xml') and status == 'edited':
                                  old_file = tempfile.NamedTemporaryFile(delete=False).name
                                  new_file = tempfile.NamedTemporaryFile(delete=False).name
                                  os.system('git show {}^:{} > {}'.format(commit_hash, change, old_file))
                                  os.system('git show {}:{} > {}'.format(commit_hash, change, new_file))
                                  flow_changes += get_flow_diff(old_file, new_file)

                              formatted_flow_changes = "\n".join(flow_changes)
                              print(formatted_flow_changes)
                              ")

COMMENT="Please review the following flows in the scratch org at ... credentials to access:
Flow changes:$FORMATTED_FLOW_CHANGES"

ESC_COMMENT=$(echo -e "$COMMENT" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\//\\\//g' -e 's/$/\\n/g')
RESPONSE=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/pulls" \
  -d "{\"title\":\"Peer review for declarative changes\",\"body\":\"$ESC_COMMENT\",\"head\":\"$HEAD\",\"base\":\"$TARGET_BRANCH\"}")

echo "Response: $RESPONSE"

PR_URL=$(echo "$RESPONSE" | grep ""html_url":" | awk '{print $2}' | tr -d '",')
echo "Pull request created: $PR_URL "
