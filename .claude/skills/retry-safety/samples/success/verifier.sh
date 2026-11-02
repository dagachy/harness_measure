#!/usr/bin/env bash
# verifier: 산출물에 'good' 포함 시 PASS
set -euo pipefail
OUT="${1:?out_file required}"
grep -q "good" "$OUT"
