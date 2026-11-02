#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="${1:?out_dir required}"
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/output.txt" <<'EOF'
summary line.
another line.
EOF
