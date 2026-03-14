#!/bin/bash
# get-stars.sh - GitHub 사용자 스타 저장소 URL만 가져와서 USER-stars.list 생성
# 사용: ./get-stars.sh [GitHub_username]
# 요구: curl, jq(권장), GITHUB_TOKEN(선택)

set -e

USER="${1:-WisemanLim}"
API_URL="https://api.github.com/users/${USER}/starred"
PER_PAGE=100
OUT_FILE="${USER}-stars.list"

get_starred_urls() {
  local page=1
  while true; do
    local json
    if [ -n "$GITHUB_TOKEN" ]; then
      json=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "${API_URL}?per_page=${PER_PAGE}&page=${page}")
    else
      json=$(curl -s "${API_URL}?per_page=${PER_PAGE}&page=${page}")
    fi

    if command -v jq >/dev/null 2>&1; then
      local len
      len=$(echo "$json" | jq 'length' 2>/dev/null || echo 0)
      echo "$json" | jq -r '.[].html_url' 2>/dev/null
      [ "$len" -lt "$PER_PAGE" ] && break
    else
      echo "$json" | grep -oE '"html_url"\s*:\s*"https://[^"]+"' | sed 's/.*"\(https:\/\/[^\"]\+\)"/\1/'
      [ "$(echo "$json" | grep -c '"html_url"' 2>/dev/null || echo 0)" -lt "$PER_PAGE" ] && break
    fi

    page=$((page + 1))
  done
}

echo "=== GitHub 스타 저장소 URL 가져오기: ${USER} ==="
rm -f "$OUT_FILE"
count=0
while IFS= read -r url; do
  [ -n "$url" ] || continue
  echo "$url" >> "$OUT_FILE"
  count=$((count + 1))
done < <(get_starred_urls)

echo "완료: ${count}개 URL을 ${OUT_FILE}에 저장했습니다."
