#!/bin/bash
# install.sh - Wise Vibe 설치 + 바이브 환경 구성 (2026 v1.3 단일 파일)
# 설치: curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main/install.sh | bash
# --setup 전용: curl ... install.sh | bash -s -- --setup (또는 PATH의 setup_vibe 명령)
# Wiseman Lim (Seoul, bio-healthcare)

set -e

BASE_URL="https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main"
VIBE_DIR="${HOME}/.wise_vibe"
ENV_FILE="${ENV_FILE:-.env}"

# ---- setup 전용: 서비스 선택·API 키·.env 저장 (--setup 또는 설치 직후 호출) ----
run_setup_vibe() {
  safe_load_env() {
    local f="$1"
    [ ! -f "$f" ] && return 0
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%%#*}" ; line="${line%%$'\r'}" ; line="${line#"${line%%[![:space:]]*}"}" ; line="${line%"${line##*[![:space:]]}"}"
      [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && export "$line" || true
    done < "$f"
  }

  [ -f "$VIBE_DIR/share/.env.example" ] && safe_load_env "$VIBE_DIR/share/.env.example"
  [ -f "$ENV_FILE" ] && safe_load_env "$ENV_FILE" && echo ".env 로드됨"

  echo "=== 바이브 코딩 서비스 선택 (MacOS) ==="
  echo "1. Gemini CLI"
  echo "2. Claude Code"
  echo "3. Continue + Ollama"
  echo "4. Cursor (IDE)"
  echo "5. Cline"
  if [ ! -t 0 ]; then
    echo "이 스크립트는 대화형 터미널에서 실행하세요. (stdin이 TTY가 아님)"
    echo "다음 명령으로 서비스 선택을 진행하세요: source ~/.zshrc && setup_vibe"
    return 0
  fi
  read -p "선택 (1-5): " choice || true
  [ -z "$choice" ] && choice=4
  save_env=1
  additional_info=""
  service=""

  check_env_and_prompt() {
    local var_name=$1
    local prompt_msg=$2
    local default_value="${!var_name:-}"
    if [ -n "$default_value" ] && [[ "$default_value" != your_* ]]; then
      echo "$prompt_msg (현재: $default_value)"
      read -p "사용 (Y/N, 기본 Y)? " use_default
      if [ "$use_default" != "N" ] && [ "$use_default" != "n" ]; then
        export "$var_name=$default_value"
        echo "$var_name=\"$default_value\"" >> "$ENV_FILE.temp"
        return 0
      fi
    fi
    read -p "$prompt_msg: " value
    if [ -n "$value" ]; then
      export "$var_name=$value"
      echo "$var_name=\"$value\"" >> "$ENV_FILE.temp"
    fi
  }

  rm -f "$ENV_FILE.temp"

  case $choice in
    1)
      service="Gemini CLI"
      echo "# [Gemini CLI Block]" > "$ENV_FILE.temp"
      check_env_and_prompt "GEMINI_API_KEY" "Gemini API 키 (https://aistudio.google.com/apikey)"
      check_env_and_prompt "GEMINI_MODEL" "모델 (기본: gemini-2.0-pro-exp)"
      echo "추가 정보 (프록시 등):"
      read -r additional_info
      npm install -g @google/gemini-cli || echo "npm 에러: brew install node"
      echo "테스트: Hi"
      gemini "Hi" --model "${GEMINI_MODEL:-gemini-2.0-pro-exp}" || true
      ;;
    2)
      service="Claude Code"
      echo "# [Claude Code Block]" > "$ENV_FILE.temp"
      check_env_and_prompt "ANTHROPIC_API_KEY" "Anthropic API 키 (console.anthropic.com)"
      check_env_and_prompt "CLAUDE_MODEL" "모델 (기본: claude-3.7-sonnet-20250219)"
      echo "추가 정보:"
      read -r additional_info
      npm install -g @anthropic-ai/claude-code || echo "npm 에러"
      echo "테스트: Hi"
      claude "Hi" || true
      ;;
    3)
      service="Continue + Ollama"
      echo "# [Continue + Ollama Block]" > "$ENV_FILE.temp"
      check_env_and_prompt "OLLAMA_MODEL" "Ollama 모델 (deepseek-coder:6.7b-q4_K_M)"
      echo "Ollama 설치 (GPU: system_profiler SPDisplaysDataType)"
      command -v ollama >/dev/null 2>&1 || curl -fsSL https://ollama.com/install.sh | sh
      ollama pull "${OLLAMA_MODEL:-deepseek-coder:6.7b-q4_K_M}" || true
      echo "추가 모델:"
      read -r model
      [ -n "$model" ] && ollama pull "$model" || true
      echo "테스트: Hi"
      ollama run "${OLLAMA_MODEL:-deepseek-coder:6.7b-q4_K_M}" "Hi" || true
      echo "OLLAMA_BASE_URL=http://localhost:11434" >> "$ENV_FILE.temp"
      echo "VSCode Continue 설치 추천"
      ;;
    4)
      service="Cursor"
      echo "# [Cursor Block]" > "$ENV_FILE.temp"
      check_env_and_prompt "CURSOR_API_KEY" "Cursor API 키 (Settings > API)"
      check_env_and_prompt "CURSOR_PRIMARY_MODEL" "기본 모델 (예: GPT-4o, gemini-2.0-flash)"
      echo ""
      echo "========== Cursor (IDE) 설치 및 사용 가이드 =========="
      echo "【설치】"
      echo "  1. https://cursor.com 에서 다운로드 후 설치"
      echo "  2. 실행 후 Settings(Cmd+,) > Cursor Settings > API 에서 OpenAI/Gemini/Anthropic 등 연결"
      echo "  3. .cursor/rules/ 에 프로젝트 규칙(예: bio.md) 추가 권장"
      echo "【사용】"
      echo "  - Cmd+K: 인라인 편집 / Cmd+L: 채팅 / Agent: 멀티파일 작업"
      echo "  - 터미널: cursor-agent (CLI) 사용 가능"
      echo "【review_source 대안】 Cursor는 CLI 기반 review_source.sh를 사용하지 않습니다."
      echo "  → 저장소 클론: git clone <repo_url> && cd <repo_name>"
      echo "  → Cursor에서 해당 폴더 열기(File > Open Folder)"
      echo "  → 채팅에 아래 프롬프트로 리뷰 요청:"
      echo "    \"이 저장소를 분석해서 REVIEW.md를 만들어줘. 1) 구조 다이어그램(FE/BE/DB) 2) 디렉토리별 기능·호출 관계 3) BE API curl 예제 4) 총론(부족점·HTTPS·Docker 권고). 한국어 Markdown.\""
      echo "  → addon이 필요하면: review_source.sh를 Gemini/Claude로 한 번 실행해 addon만 생성하거나, 본 repo의 review_addon 템플릿 참고"
      echo "======================================================"
      open https://cursor.com 2>/dev/null || true
      ;;
    5)
      service="Cline"
      echo "# [Cline Block]" > "$ENV_FILE.temp"
      check_env_and_prompt "OPENAI_API_KEY" "OpenAI API 키 (또는 ANTHROPIC 사용 시 ANTHROPIC_API_KEY)"
      check_env_and_prompt "CLINE_PROVIDER" "Provider (openai / anthropic)"
      echo "추가 정보:"
      read -r additional_info
      echo ""
      echo "========== Cline 설치 및 사용 가이드 =========="
      echo "【설치】"
      echo "  1. VSCode 실행 후 Extensions(Cmd+Shift+X)에서 'Cline' 검색"
      echo "  2. cline-ai.cline 설치 후 VSCode 재시작"
      echo "  3. 설정: Ctrl+Shift+J 또는 사이드바 Cline 아이콘 > Settings > API Key (OpenAI 또는 Anthropic)"
      echo "  CLI 설치(선택): code --install-extension cline-ai.cline"
      echo "【사용】"
      echo "  - 사이드바 Cline 패널에서 채팅. Plan/Act 모드로 파일 생성·수정 가능"
      echo "  - @파일명, @폴더명으로 컨텍스트 지정"
      echo "【review_source 대안】 Cline은 CLI 기반 review_source.sh를 사용하지 않습니다."
      echo "  → 저장소 클론: git clone <repo_url> && cd <repo_name>"
      echo "  → VSCode에서 해당 폴더 열기(File > Open Folder)"
      echo "  → Cline 채팅에 아래 프롬프트로 리뷰 요청:"
      echo "    \"이 저장소를 분석해서 REVIEW.md를 만들어줘. 1) 구조 다이어그램(FE/BE/DB) 2) 디렉토리별 기능·호출 관계 3) BE API curl 예제 4) 총론(부족점·HTTPS·Docker 권고). 한국어 Markdown.\""
      echo "  → addon이 필요하면: review_source.sh를 Gemini/Claude로 한 번 실행해 review_addon만 생성하거나, 본 repo 문서의 addon 구조 참고"
      echo "======================================================"
      command -v code >/dev/null 2>&1 && code --install-extension cline-ai.cline 2>/dev/null || echo "VSCode code CLI 없음. 수동: Extensions에서 'Cline' 검색 후 설치"
      ;;
    *)
      echo "잘못된 선택"
      return 1
      ;;
  esac

  if [ "$save_env" -eq 1 ] && [ -f "$ENV_FILE.temp" ]; then
    if [ ! -f "$ENV_FILE" ]; then
      echo ".env 파일 생성됨"
      cat "$ENV_FILE.temp" >> "$ENV_FILE"
    else
      echo "기존 .env 업데이트용 내용 (수동 병합):"
      cat "$ENV_FILE.temp"
    fi
    rm -f "$ENV_FILE.temp"
  fi

  echo "완료: $service | 추가: $additional_info | 바이브 코딩 준비!"
  if [ "$service" = "Cursor" ] || [ "$service" = "Cline" ]; then
    echo "리뷰: review_source는 Gemini/Claude CLI 전용. 위 Cursor/Cline 가이드대로 저장소 열고 AI 채팅으로 REVIEW.md 요청하세요."
  else
    echo "리뷰: review_source https://github.com/user/repo"
  fi
}

# ---- --setup 인자: setup만 실행 후 종료 ----
if [ "$1" = "--setup" ]; then
  run_setup_vibe
  exit 0
fi

# ---- 설치: 다운로드, PATH, 의존성, setup 실행 ----
echo "🔧 Wise Vibe v1.3 설치: $VIBE_DIR"
mkdir -p "$VIBE_DIR"/bin "$VIBE_DIR"/share

curl -fsSL "$BASE_URL/.env.example" -o "$VIBE_DIR/share/.env.example"
curl -fsSL "$BASE_URL/review_source.sh" -o "$VIBE_DIR/share/review_source.sh"
curl -fsSL "$BASE_URL/install.sh" -o "$VIBE_DIR/share/install.sh"
chmod +x "$VIBE_DIR/share/review_source.sh"
chmod +x "$VIBE_DIR/share/install.sh"

# setup_vibe: 로컬 install.sh --setup 실행 (stdin이 TTY로 유지됨)
cat > "$VIBE_DIR/bin/setup_vibe" << SETUPWRAP
#!/bin/bash
V="\$HOME/.wise_vibe/share/install.sh"
if [ ! -f "\$V" ]; then
  echo "오류: 설치를 다시 실행하세요. curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main/install.sh | bash"
  exit 1
fi
exec bash "\$V" --setup
SETUPWRAP
chmod +x "$VIBE_DIR/bin/setup_vibe"
ln -sf "$VIBE_DIR/share/review_source.sh" "$VIBE_DIR/bin/review_source" 2>/dev/null || true

for profile in .zshrc .bash_profile .bashrc; do
  if [ -f "$HOME/$profile" ]; then
    if ! grep -q "wise_vibe" "$HOME/$profile" 2>/dev/null; then
      echo 'export PATH="$HOME/.wise_vibe/bin:$PATH"' >> "$HOME/$profile"
    fi
    break
  fi
done

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>/dev/null || true
fi
command -v node >/dev/null 2>&1 || (command -v brew >/dev/null 2>&1 && brew install node 2>/dev/null || true)
command -v tree >/dev/null 2>&1 || (command -v brew >/dev/null 2>&1 && brew install tree 2>/dev/null || true)

echo "✅ 설치 완료. 로컬 보관: .env.example, review_source.sh, install.sh"
run_setup_vibe || true
if [ ! -t 0 ]; then
  echo "바이브 환경 구성(서비스 선택 1~5)을 하려면: source ~/.zshrc && setup_vibe"
fi
