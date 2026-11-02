#!/usr/bin/env bash
# with 환경: 산출물에 "goal achieved" 포함
set -euo pipefail
OUT_DIR="${1:?out_dir required}"
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/output.txt" <<'EOF'
# summary
goal achieved: 요구 조건 모두 충족.
details: with-skill 활성화 상태에서 생성됨.
EOF
