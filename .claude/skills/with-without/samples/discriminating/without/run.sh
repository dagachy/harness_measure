#!/usr/bin/env bash
# without 환경: 산출물에 "goal achieved" 미포함 (파일만 생성)
set -euo pipefail
OUT_DIR="${1:?out_dir required}"
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/output.txt" <<'EOF'
# summary
작업 수행함. 결과: 임의 출력.
details: without-skill 상태 — goal 마커 미기재.
EOF
