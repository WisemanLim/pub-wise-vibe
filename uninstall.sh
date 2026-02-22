#!/bin/bash
# uninstall.sh - Wise Vibe 설치 환경 초기화
# 실행: curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main/uninstall.sh | bash
# Wiseman Lim (Seoul, bio-healthcare)

set -e

VIBE_DIR="${HOME}/.wise_vibe"

echo "=== Wise Vibe 환경 초기화 (uninstall) ==="
echo "다음 항목이 제거됩니다:"
echo "  - $VIBE_DIR (전체 디렉터리)"
echo "  - 셸 프로파일(.zshrc, .bash_profile, .bashrc) 내 wise_vibe PATH 한 줄"
echo ""
echo "※ Homebrew, Node, tree, Gemini/Claude CLI 등은 제거하지 않습니다."
read -p "계속하시겠습니까? (y/N): " confirm

case "$confirm" in
  [yY]|[yY][eE][sS])
    ;;
  *)
    echo "취소되었습니다."
    exit 0
    ;;
esac

# 1. ~/.wise_vibe 삭제
if [ -d "$VIBE_DIR" ]; then
  rm -rf "$VIBE_DIR"
  echo "✅ $VIBE_DIR 제거됨"
else
  echo "  (이미 없음: $VIBE_DIR)"
fi

# 2. 셸 프로파일에서 wise_vibe PATH 라인 제거
for profile in .zshrc .bash_profile .bashrc; do
  path_file="$HOME/$profile"
  if [ -f "$path_file" ]; then
    if grep -q "wise_vibe" "$path_file" 2>/dev/null; then
      if sed --version 2>/dev/null | head -1 | grep -q GNU; then
        sed -i '/wise_vibe/d' "$path_file"
      else
        sed -i '' '/wise_vibe/d' "$path_file"
      fi
      echo "✅ $profile 에서 wise_vibe PATH 제거됨"
    fi
  fi
done

echo ""
echo "초기화 완료. 변경 사항 반영을 위해 새 터미널을 열거나 다음을 실행하세요:"
echo "  source ~/.zshrc   # 또는 source ~/.bash_profile"
