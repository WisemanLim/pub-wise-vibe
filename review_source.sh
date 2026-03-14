#!/bin/bash
# review_source.sh - Multi-Repo AI Review (Dynamic REPO_DIR, G/C/B, Advanced Addon)
# Usage: ./review_source.sh <github_url1> [url2 ...]
# Requires: setup_vibe.sh, tree (brew install tree), git
# 2026-02-22, Wiseman Lim

set -e

# 프로젝트 .env 로드 후 자식 프로세스(AI CLI)에 전달되도록 export
[ -f ".env" ] && source .env 2>/dev/null || true
[ -f "$HOME/.wise_vibe/share/.env.example" ] && source "$HOME/.wise_vibe/share/.env.example" 2>/dev/null || true
export GEMINI_API_KEY GEMINI_MODEL ANTHROPIC_API_KEY CLAUDE_MODEL 2>/dev/null || true

if [ $# -lt 1 ]; then
  echo "사용: $0 <github_url1> [url2 ...]"
  exit 1
fi

START_DIR=$(pwd)
command -v tree >/dev/null 2>&1 || { command -v brew >/dev/null 2>&1 && brew install tree; }

for REPO_URL in "$@"; do
  REPO_NAME=$(basename "$REPO_URL" .git)
  REPO_DIR="$REPO_NAME"
  ADDON_DIR="review_addon"

  echo "=== 리뷰 시작: $REPO_URL -> $REPO_DIR ==="

  if [ -d "$REPO_DIR" ]; then
    echo "기존 $REPO_DIR 업데이트"
    (cd "$REPO_DIR" && git pull) || true
  else
    git clone "$REPO_URL" "$REPO_DIR"
  fi

  cd "$REPO_DIR" || exit 1

  echo "=== AI 리뷰 서비스 선택 ==="
  command -v gemini >/dev/null 2>&1 && echo "G) Gemini CLI ✓" || echo "G) Gemini CLI ✗"
  command -v claude >/dev/null 2>&1 && echo "C) Claude Code ✓" || echo "C) Claude Code ✗"
  echo "B) Both (비교)"
  echo "S) SKIP (clone만)"
  read -p "선택 (G/C/B/S) [기본: G]: " ai_choice
  ai_choice=${ai_choice:-G}

  CLONE_ONLY=""
  case "$ai_choice" in
    [Gg]*) AI_TOOLS=(gemini) ;;
    [Cc]*) AI_TOOLS=(claude) ;;
    [Bb]*) AI_TOOLS=(gemini claude) ;;
    [Ss]*) CLONE_ONLY=1; AI_TOOLS=() ;;
    *) AI_TOOLS=(gemini) ;;
  esac

  common_structure() {
    local f="$1"
    echo "# $REPO_NAME 리뷰 [$(date)]" > "$f"
    echo "" >> "$f"
    echo "**저장소:** $REPO_URL" >> "$f"
    echo "" >> "$f"

    # 1. 개요: README.md 있으면 내용 정리하여 추가
    readme_file=""
    for r in README.md README Readme.md readme.md; do
      [ -f "$r" ] && { readme_file="$r"; break; }
    done
    if [ -n "$readme_file" ]; then
      echo "## 1. 개요" >> "$f"
      echo "" >> "$f"
      # README 본문만 (앞쪽 200줄 제한, 과도한 양 방지)
      head -200 "$readme_file" >> "$f" 2>/dev/null || cat "$readme_file" >> "$f"
      echo "" >> "$f"
    fi

    echo "## 2. 구조 다이어그램" >> "$f"
    tree -L 3 -I 'node_modules|.git|review_*' >> "$f" 2>/dev/null || find . -maxdepth 3 -not -path '*/node_modules/*' -not -path '*/.git/*' | head -80 >> "$f"
    echo "" >> "$f"
    echo "### 주요 경로 설명" >> "$f"
    for src in $(find . \( -name "*.py" -o -name "*.js" -o -name "*.html" -o -name "*.go" -o -name "Dockerfile" -o -name "setup.sh" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | sort | head -50); do
      [ -f "$src" ] || continue
      desc=$(file_one_line_desc "$src")
      if [ -n "$desc" ]; then
        echo "- **\`${src#./}\`** — $desc" >> "$f"
      else
        echo "- **\`${src#./}\`**" >> "$f"
      fi
    done
    echo "" >> "$f"
    echo "## 구성 요소" >> "$f"
    echo "- FE: $(find . \( -name "*.jsx" -o -name "*.tsx" -o -name "*.vue" -o -name "*.html" \) 2>/dev/null | wc -l | tr -d ' ') 파일" >> "$f"
    echo "- BE: $(find . \( -name "*.py" -o -name "*.js" -o -name "*.go" \) -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ') 파일" >> "$f"
    echo "- DB/설치: $(find . -name "*.sql" -o -name "Dockerfile" -o -name "package*.json" 2>/dev/null | wc -l | tr -d ' ') 파일" >> "$f"
  }

  # 파일 첫 주석/독스트링에서 한 줄 설명 추출 (최대 80자)
  file_one_line_desc() {
    local path="$1"
    [ ! -f "$path" ] && return
    local line=""
    case "$path" in
      *.py)
        line=$(head -25 "$path" 2>/dev/null | grep -m1 -E '^#|^"""' | sed 's/^# *//;s/^""" *//;s/ *"""$//')
        ;;
      *.js|*.jsx|*.ts|*.tsx|*.vue)
        line=$(head -25 "$path" 2>/dev/null | grep -m1 -E '^[[:space:]]*//' | sed 's/^[[:space:]]*\/\/[[:space:]]*//')
        ;;
      *.go)
        line=$(head -20 "$path" 2>/dev/null | grep -m1 -E '^//' | sed 's/^\/\/ *//')
        ;;
      *.html)
        line=$(grep -m1 -oE '<title>[^<]+</title>' "$path" 2>/dev/null | sed 's/<[^>]*>//g;s/^[[:space:]]*//;s/[[:space:]]*$//')
        ;;
      Dockerfile|*.sh)
        line=$(head -10 "$path" 2>/dev/null | grep -m1 -E '^#' | sed 's/^# *//')
        ;;
    esac
    if [ -n "$line" ]; then
      echo "$line" | tr -d '\n\r' | head -c 80
    fi
  }

  # 구조 문자열 생성 (AI 프롬프트·로컬 분석용)
  build_structure_context() {
    echo "=== 저장소 트리 ==="
    tree -L 3 -I 'node_modules|.git|review_*' 2>/dev/null || find . -maxdepth 3 -not -path '*/node_modules/*' -not -path '*/.git/*' | head -80
    echo ""
    echo "=== FE 파일 ==="
    find . \( -name "*.jsx" -o -name "*.tsx" -o -name "*.vue" -o -name "*.html" \) -not -path "*/.git/*" 2>/dev/null | sed 's|^\./||'
    echo ""
    echo "=== BE 파일 ==="
    find . \( -name "*.py" -o -name "*.js" -o -name "*.go" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | sed 's|^\./||'
    echo ""
    echo "=== DB/설치 관련 ==="
    find . \( -name "*.sql" -o -name "Dockerfile" -o -name "package*.json" -o -name "requirements*.txt" -o -name "setup.sh" \) -not -path "*/.git/*" 2>/dev/null | sed 's|^\./||'
  }

  # 구성요소별·파일별 상세 분석 (함수/클래스 목록 등) — AI 실패 시 또는 보강용
  local_detail_analysis() {
    local md_file="$1"
    echo "" >> "$md_file"
    echo "### 구성요소별 파일·기능 목록" >> "$md_file"
    echo "" >> "$md_file"

    # FE
    echo "#### FE (프론트엔드)" >> "$md_file"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      echo "- **\`$f\`**" >> "$md_file"
      desc=$(file_one_line_desc "$f"); [ -n "$desc" ] && echo "  - 설명: $desc" >> "$md_file"
      case "$f" in
        *.html)
          grep -nE '<script|</script>|router\.|path\(|route\(' "$f" 2>/dev/null | head -15 | sed 's/^/  - /' >> "$md_file" || true
          ;;
        *.js|*.jsx|*.tsx|*.vue)
          grep -nE '^(export )?(function |const |class )|^  (async )?[a-zA-Z]+ *\(' "$f" 2>/dev/null | head -25 | sed 's/^/  - /' >> "$md_file" || true
          ;;
        *) echo "  - (파일)" >> "$md_file" ;;
      esac
      echo "" >> "$md_file"
    done < <(find . \( -name "*.html" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.vue" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | sort)
    echo "" >> "$md_file"

    # BE
    echo "#### BE (백엔드)" >> "$md_file"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      echo "- **\`$f\`**" >> "$md_file"
      desc=$(file_one_line_desc "$f"); [ -n "$desc" ] && echo "  - 설명: $desc" >> "$md_file"
      case "$f" in
        *.py)
          grep -nE '^(def |class |async def )' "$f" 2>/dev/null | sed 's/^/  - /' >> "$md_file" || true
          ;;
        *.js)
          grep -nE '^(export )?(function |const |class )|(get|post|put|delete)\s*\(' "$f" 2>/dev/null | head -25 | sed 's/^/  - /' >> "$md_file" || true
          ;;
        *.go)
          grep -nE '^func |^type .* struct' "$f" 2>/dev/null | sed 's/^/  - /' >> "$md_file" || true
          ;;
        *) echo "  - (파일)" >> "$md_file" ;;
      esac
      echo "" >> "$md_file"
    done < <(find . \( -name "*.py" -o -name "*.js" -o -name "*.go" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | sort)
    echo "" >> "$md_file"

    # DB/설치
    echo "#### DB/설치" >> "$md_file"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      echo "- **\`$f\`** ($(wc -l < "$f" 2>/dev/null | tr -d ' ') 줄)" >> "$md_file"
      desc=$(file_one_line_desc "$f"); [ -n "$desc" ] && echo "  - 설명: $desc" >> "$md_file"
    done < <(find . \( -name "*.sql" -o -name "Dockerfile" -o -name "package*.json" -o -name "requirements*.txt" -o -name "setup.sh" \) -not -path "*/.git/*" 2>/dev/null | sort)
    echo "" >> "$md_file"

    echo "### BE API·엔드포인트 후보" >> "$md_file"
    grep -rnE "(@app\.(route|get|post|put|delete)|app\.(get|post|put|delete)|router\.(get|post)|path\s*=\s*['\"]|url_for|/api/)" . --include="*.py" --include="*.js" --include="*.go" 2>/dev/null | grep -v node_modules | head -40 | sed 's/^/  - /' >> "$md_file" || true
    echo "" >> "$md_file"
  }

  run_ai_review() {
    local ai_tool=$1
    local md_file="REVIEW_${ai_tool}.md"
    common_structure "$md_file"
    echo "## 3. $ai_tool 상세 분석" >> "$md_file"
    # 항상 로컬 상세 분석 먼저 추가 (구성요소별·파일별 기능 목록)
    local_detail_analysis "$md_file"

    local structure_ctx
    structure_ctx=$(build_structure_context)
    local prompt="다음은 저장소 구조와 파일 목록입니다:

$structure_ctx

위 구조를 바탕으로 아래를 한국어 Markdown으로 작성해 주세요.
1. 구조 요약: FE/BE/DB 관계 텍스트 다이어그램.
2. 디렉토리별: 파일 역할, 기능, 호출 관계.
3. BE API: curl 호출 예제.
4. 총론: 개요, 부족점(보안/HTTPS/Docker), 개선 권고."

    echo "[$ai_tool] AI 분석 중..."
    local err_log
    err_log=$(mktemp 2>/dev/null || echo "/tmp/review_$$.err")
    if [ "$ai_tool" = "gemini" ]; then
      # 긴 프롬프트는 파일로 전달(인자/파이프 한계 회피), 헤드리스로 실행
      local prompt_file
      prompt_file=$(mktemp 2>/dev/null || echo "/tmp/review_prompt_$$.txt")
      printf '%s' "$prompt" > "$prompt_file"
      if ( gemini --model "${GEMINI_MODEL:-gemini-2.5-flash}" < "$prompt_file" 2>"$err_log" ) >> "$md_file"; then
        :
      else
        echo "" >> "$md_file"
        echo "(Gemini CLI 오류: $(head -1 "$err_log" 2>/dev/null | sed 's/^[[:space:]]*//' | head -c 120))" >> "$md_file"
      fi
      rm -f "$prompt_file"
    elif [ "$ai_tool" = "claude" ]; then
      # Claude: 긴 내용은 stdin, 지시문만 -p (명령줄 길이 한계 회피)
      local prompt_file
      prompt_file=$(mktemp 2>/dev/null || echo "/tmp/review_prompt_$$.txt")
      printf '%s' "$prompt" > "$prompt_file"
      local claude_instruction="위 stdin의 저장소 구조를 분석해 주세요. 1. 구조 요약(FE/BE/DB) 2. 디렉토리별 파일/기능/호출관계 3. BE API curl 예제 4. 총론(부족점/개선). 한국어 Markdown."
      if ( cat "$prompt_file" | claude -p "$claude_instruction" 2>"$err_log" ) >> "$md_file"; then
        :
      else
        echo "" >> "$md_file"
        echo "(Claude CLI 오류: $(head -1 "$err_log" 2>/dev/null | sed 's/^[[:space:]]*//' | head -c 120))" >> "$md_file"
      fi
      rm -f "$prompt_file"
    else
      if ( printf '%s' "$prompt" | $ai_tool 2>"$err_log" ) >> "$md_file"; then
        :
      else
        echo "" >> "$md_file"
        echo "(AI CLI 오류: $(head -1 "$err_log" 2>/dev/null | sed 's/^[[:space:]]*//' | head -c 120))" >> "$md_file"
      fi
    fi
    rm -f "$err_log"
    echo "[$ai_tool] 완료: $md_file"
  }

  if [ -n "$CLONE_ONLY" ]; then
    echo "✅ clone만 완료: $(pwd)"
  else
  REVIEW_FILE="REVIEW.md"
  if [ ${#AI_TOOLS[@]} -eq 1 ]; then
    run_ai_review "${AI_TOOLS[0]}"
    mv "REVIEW_${AI_TOOLS[0]}.md" "REVIEW.md"
  else
    for tool in "${AI_TOOLS[@]}"; do
      run_ai_review "$tool"
    done
    common_structure "REVIEW.md"
    echo "## AI 비교 분석" >> "REVIEW.md"
    echo "- Gemini: $(wc -l < "REVIEW_gemini.md" 2>/dev/null || echo 0)줄 | Claude: $(wc -l < "REVIEW_claude.md" 2>/dev/null || echo 0)줄" >> "REVIEW.md"
    diff -u "REVIEW_gemini.md" "REVIEW_claude.md" 2>/dev/null | head -30 >> "REVIEW.md" || true
    echo "전체: Gemini/Claude 공통 권고 따름" >> "REVIEW.md"
  fi

  create_addons() {
    local rfile="${1:-REVIEW.md}"
    local addon="${2:-review_addon}"
    mkdir -p "$addon"/dist "$addon"/security "$addon"/ci-cd "$addon"/monitoring "$addon"/docs

    echo "## 4. 개선 addon ($addon)" >> "$rfile"

    if [ ! -f docker-compose.yml ]; then
      cat > "$addon/dist/docker-compose.prod.yml" << 'DOCPROD'
version: '3.9'
services:
  frontend:
    build: ./frontend
    ports: ["3000:3000"]
    environment: { REACT_APP_API_URL: "http://nginx" }
  backend:
    build: ./backend
    ports: ["8000:8000"]
    environment:
      DB_URL: postgresql://user:pass@db/mydb
      REDIS_URL: redis://redis:6379
    depends_on: [db, redis]
  db:
    image: postgres:16-alpine
    volumes: ["./data/pg:/var/lib/postgresql/data"]
    environment: { POSTGRES_DB: mydb, POSTGRES_USER: user, POSTGRES_PASSWORD: "${DB_PASS}" }
  redis:
    image: redis:7-alpine
    volumes: ["./data/redis:/data"]
  nginx:
    image: nginx:alpine
    ports: ["80:80", "443:443"]
    volumes: ["./nginx.conf:/etc/nginx/nginx.conf:ro"]
    depends_on: [frontend, backend]
DOCPROD
      echo "- **배포**: docker-compose.prod.yml (Postgres/Redis/Nginx)" >> "$rfile"
    fi

    cat > "$addon/nginx.conf" << 'NGINX'
events { worker_connections 1024; }
http {
  server {
    listen 80; return 301 https://$host$request_uri;
    listen 443 ssl http2;
    ssl_protocols TLSv1.3;
    ssl_certificate /etc/ssl/cert.pem;
    ssl_certificate_key /etc/ssl/key.pem;
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    location /api/ { proxy_pass http://backend:8000; proxy_set_header Host $host; }
    location / { proxy_pass http://frontend:3000; }
  }
}
NGINX
    echo "- **보안**: nginx.conf (HSTS/HTTPS TLS1.3)" >> "$rfile"

    cat > "$addon/security_audit.sh" << 'SECAUDIT'
#!/bin/bash
echo "=== OWASP 2026 보안 감사 ==="
echo "1. 하드코딩 시크릿: $(grep -rE 'password|secret|api_key' . --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null | wc -l | tr -d ' ')"
echo "2. HTTPS: $(grep -r 'http://' . --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null | wc -l | tr -d ' ') 건 확인 권고"
find . -name "*.env*" -exec chmod 600 {} \; 2>/dev/null || true
echo "3. .env 권한 600 적용"
SECAUDIT
    chmod +x "$addon/security_audit.sh"
    echo "- **감사**: security_audit.sh (OWASP/시크릿)" >> "$rfile"

    mkdir -p "$addon/ci-cd"
    cat > "$addon/ci-cd/github-actions.yml" << 'CIYML'
name: CI/CD Pipeline
on: [push, pull_request]
jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Docker build
        run: |
          docker build -t app-backend ./backend 2>/dev/null || echo "backend Dockerfile 없음"
          docker build -t app-frontend ./frontend 2>/dev/null || echo "frontend Dockerfile 없음"
CIYML
    echo "- **CI/CD**: ci-cd/github-actions.yml" >> "$rfile"

    cat > "$addon/prometheus.yml" << 'PROM'
global: scrape_interval: 15s
scrape_configs:
  - job_name: backend
    static_configs: [{ targets: ['backend:8000'] }]
PROM
    echo "- **모니터링**: prometheus.yml" >> "$rfile"

    cat > "$addon/.env.example" << 'ENVEX'
DB_PASS=strong_random_pass
JWT_SECRET=your_jwt_secret_base64
REDIS_PASS=redis_secure
ENVEX
    cat > "$addon/SECURITY.md" << 'SECDOC'
# 보안 체크리스트
- Input Validation (no SQLi/XSS)
- Rate Limiting
- MFA/JWT Rotation
- Secrets: Vault/SSM (no .env commit)
SECDOC
    echo "- **문서**: SECURITY.md / .env.example" >> "$rfile"
  }

  create_addons "$REVIEW_FILE" "$ADDON_DIR"

  echo "## 리뷰 완료" >> "$REVIEW_FILE"
  echo "✅ $(pwd)/REVIEW.md 생성 | addon: $ADDON_DIR"
  fi

  cd "$START_DIR" || cd ..
done

echo "전체 완료. 예: cd <repo_name> && ./review_addon/security_audit.sh"
