#!/bin/bash
# review_all.sh - WisemanLim 스타 저장소 목록을 가져와 각 repo에 대해 review_source 실행 (자동 G 선택)
# 사용: ./review_all.sh [GitHub_username]
# 요구: review_source (PATH), curl, jq(권장). GITHUB_TOKEN(선택, 비인증 시 60회/시간 제한)
# 2026-02, Wiseman Lim

set -e

USER="${1:-WisemanLim}"
API_URL="https://api.github.com/users/${USER}/starred"
PER_PAGE=100

command -v review_source >/dev/null 2>&1 || {
  echo "오류: review_source를 찾을 수 없습니다. setup_vibe 설치 후 source ~/.zshrc 를 실행하세요."
  exit 1
}

if command -v jq >/dev/null 2>&1; then
  get_starred_urls() {
    local page=1
    while true; do
      local json
      if [ -n "$GITHUB_TOKEN" ]; then
        json=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "${API_URL}?per_page=${PER_PAGE}&page=${page}")
      else
        json=$(curl -s "${API_URL}?per_page=${PER_PAGE}&page=${page}")
      fi
      local len
      len=$(echo "$json" | jq 'length' 2>/dev/null || echo 0)
      echo "$json" | jq -r '.[].clone_url' 2>/dev/null | grep -E '^https://' || true
      [ "$len" -lt "$PER_PAGE" ] && break
      page=$((page + 1))
    done
  }
else
  echo "jq가 없습니다. 설치 권장: brew install jq (또는 GITHUB_TOKEN 없이 간단 파싱 시도)"
  get_starred_urls() {
    local page=1
    while true; do
      local raw
      if [ -n "$GITHUB_TOKEN" ]; then
        raw=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "${API_URL}?per_page=${PER_PAGE}&page=${page}")
      else
        raw=$(curl -s "${API_URL}?per_page=${PER_PAGE}&page=${page}")
      fi
      echo "$raw" | grep -oE '"clone_url"[[:space:]]*:[[:space:]]*"https://[^"]+"' | sed 's/.*"https:\/\//https:\/\//;s/"$//'
      echo "$raw" | grep -q '"clone_url"' || break
      [ "$(echo "$raw" | grep -c '"clone_url"' 2>/dev/null || echo 0)" -lt "$PER_PAGE" ] && break
      page=$((page + 1))
    done
  }
fi

echo "=== $USER 스타 저장소 리뷰 ==="
urls=()
LIST_FILE="${USER}-stars.list"
if [ -f "$LIST_FILE" ]; then
  echo "목록 파일 사용: $LIST_FILE (API 조회 생략)"
  while IFS= read -r u; do
    u="${u%%#*}"
    u="$(echo "$u" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$u" ] && urls+=("$u")
  done < "$LIST_FILE"
else
  while IFS= read -r u; do
    [ -n "$u" ] && urls+=("$u")
  done < <(get_starred_urls)
fi
total=${#urls[@]}
[ "$total" -eq 0 ] && { echo "저장소 URL이 없습니다. (API 조회 또는 $LIST_FILE 내용 확인)"; exit 1; }
echo "전체 스타 저장소: ${total}개 (1 ~ ${total})"
read -p "시작 번호 (0 또는 비우면 전체): " start_input
read -p "끝 번호 (비우면 마지막까지): " end_input
start_num=${start_input:-0}
end_num=${end_input:-$total}
if [ -z "$start_input" ] || [ "$start_num" -eq 0 ]; then
  start=1
  end=$total
  echo "범위: 1 ~ ${total} (전체)"
else
  start=$start_num
  end=${end_num:-$total}
  [ "$end" -lt "$start" ] && end=$start
  echo "범위: ${start} ~ ${end}"
fi

echo ""
echo "G) Gemini  C) Claude  B) Both  S) SKIP (clone만)"
read -p "선택 (G/C/B/S) [기본: G]: " ai_choice
ai_choice=${ai_choice:-G}

SOURCES_DIR="_sources"
mkdir -p "$SOURCES_DIR"
count=0
skipped=0
for i in "${!urls[@]}"; do
  num=$((i + 1))
  [ "$num" -lt "$start" ] || [ "$num" -gt "$end" ] && continue
  url="${urls[$i]}"
  repo_name=$(basename "$url" .git)
  if [ -d "$SOURCES_DIR/$repo_name" ] && [ -f "$SOURCES_DIR/$repo_name/REVIEW.md" ]; then
    echo "[skip] #${num} $repo_name (클론·REVIEW.md 있음)"
    skipped=$((skipped + 1))
    continue
  fi
  count=$((count + 1))
  echo ""
  echo "[#${num}/${total}] $url"
  ( cd "$SOURCES_DIR" && printf '%s\n' "$ai_choice" | review_source "$url" ) || true
done

echo ""
echo "완료: ${count}개 리뷰 진행, ${skipped}개 스킵 (이미 REVIEW.md 있음)"
