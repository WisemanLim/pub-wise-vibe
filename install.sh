#!/bin/bash
# install.sh - Wise Vibe 설치 (2026 v1.2)
# 설치: curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main/install.sh | bash
# 설치 후 setup_vibe 명령은 로컬 ~/.wise_vibe/share/setup_vibe.sh 를 실행 (터미널 stdin 정상 동작)
# Wiseman Lim (Seoul, bio-healthcare)

set -e

BASE_URL="https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main"
VIBE_DIR="${HOME}/.wise_vibe"

echo "🔧 Wise Vibe v1.2 설치: $VIBE_DIR"
mkdir -p "$VIBE_DIR"/bin "$VIBE_DIR"/share

curl -fsSL "$BASE_URL/.env.example" -o "$VIBE_DIR/share/.env.example"
curl -fsSL "$BASE_URL/review_source.sh" -o "$VIBE_DIR/share/review_source.sh"
curl -fsSL "$BASE_URL/setup_vibe.sh" -o "$VIBE_DIR/share/setup_vibe.sh"
chmod +x "$VIBE_DIR/share/review_source.sh"
chmod +x "$VIBE_DIR/share/setup_vibe.sh"

# setup_vibe: 로컬 setup_vibe.sh 실행 (파이프 없이 실행되어 read 입력 정상 동작)
ln -sf "$VIBE_DIR/share/setup_vibe.sh" "$VIBE_DIR/bin/setup_vibe"
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

echo "✅ 설치 완료. 로컬 보관: .env.example, setup_vibe.sh, review_source.sh"
echo "다음: source ~/.zshrc && setup_vibe"
