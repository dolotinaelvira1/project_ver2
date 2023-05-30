# Выполняем аутентификацию с использованием ключевого файла JWT
auth_result=$(sfdx force:auth:jwt:grant --client-id=3MVG9t0sl2P.pBypyUQ9QtrDHltVGOGkJTU5Zjv_F8c22JCzQS2P8ZVqlmUgcbkTqh5UyJt..B2Er9OUeDZGZ --jwt-key-file=C:/Users/dolot/JWT/server.key --username=dolotinaelvira@empathetic-badger-rllf1u.com --set-default-dev-hub  --alias=DevHub)

# Извлекаем ACCESS_TOKEN из вывода команды
access_token=$(echo "$auth_result" | awk '/access token:/ {print $3}')

# Проверяем, что ACCESS_TOKEN был успешно получен
if [ -n "$access_token" ]; then
  echo "Access token: $access_token"

  # Далее можно использовать полученный ACCESS_TOKEN в запросах к Salesforce API
  # Например:
  INSTANCE_URL="https://empathetic-badger-rllf1u-dev-ed.trailblaze.lightning.force.com"
  LABEL="flaoopppw"
  QUERY=$(printf "SELECT+Id,MasterLabel+FROM+Flow__Flow+WHERE+Status+=+'Active'+AND+MasterLabel+=+'%s'" "$LABEL")
  echo "QUERY: $QUERY"
  response=$(curl -s "$INSTANCE_URL/services/data/v52.0/tooling/query/?q=$QUERY" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -H "X-PrettyPrint:1")

  echo "$response"
else
  echo "Failed to obtain access token."
fi
