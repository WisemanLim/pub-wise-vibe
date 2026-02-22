#!/bin/bash
# review_source.sh - Multi-Repo AI Review (Dynamic REPO_DIR, G/C/B, Advanced Addon)
# Usage: ./review_source.sh <github_url1> [url2 ...]
# Requires: setup_vibe.sh, tree (brew install tree), git
# 2026-02-22, Wiseman Lim

set -e

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
  read -p "선택 (G/C/B): " ai_choice

  case "$ai_choice" in
    [Gg]*) AI_TOOLS=(gemini) ;;
    [Cc]*) AI_TOOLS=(claude) ;;
    [Bb]*) AI_TOOLS=(gemini claude) ;;
    *) AI_TOOLS=(gemini) ;;
  esac

  common_structure() {
    local f="$1"
    echo "# $REPO_NAME 리뷰 [$(date)]" > "$f"
    echo "## 1. 구조 다이어그램" >> "$f"
    tree -L 3 -I 'node_modules|.git|review_*' >> "$f" 2>/dev/null || find . -maxdepth 3 -not -path '*/node_modules/*' -not -path '*/.git/*' | head -80 >> "$f"
    echo "## 구성 요소" >> "$f"
    echo "- FE: $(find . \( -name "*.jsx" -o -name "*.tsx" -o -name "*.vue" -o -name "*.html" \) 2>/dev/null | wc -l | tr -d ' ') 파일" >> "$f"
    echo "- BE: $(find . \( -name "*.py" -o -name "*.js" -o -name "*.go" \) -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ') 파일" >> "$f"
    echo "- DB/설치: $(find . -name "*.sql" -o -name "Dockerfile" -o -name "package*.json" 2>/dev/null | wc -l | tr -d ' ') 파일" >> "$f"
  }

  run_ai_review() {
    local ai_tool=$1
    local md_file="REVIEW_${ai_tool}.md"
    common_structure "$md_file"
    echo "## 2. $ai_tool 상세 분석" >> "$md_file"
    local prompt="분석: $(pwd)
1. 구조 요약 (FE/BE/DB 관계 텍스트 다이어그램).
2. 디렉토리별: 파일/기능/호출 관계.
3. BE API: curl 예제.
4. 총론: 개요/부족점(보안/HTTPS/Docker)/개선 코드.
한국어 Markdown."
    echo "[$ai_tool] 분석 중..."
    $ai_tool "$prompt" >> "$md_file" 2>/dev/null || echo "(AI CLI 미설치 또는 오류 - 수동 분석 권장)" >> "$md_file"
    echo "[$ai_tool] 완료: $md_file"
  }

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

    echo "## 3. 개선 addon ($addon)" >> "$rfile"

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

  cd "$START_DIR" || cd ..
done

echo "전체 완료. 예: cd <repo_name> && ./review_addon/security_audit.sh"
