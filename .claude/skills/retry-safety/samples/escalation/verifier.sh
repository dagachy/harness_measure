#!/usr/bin/env bash
# verifier: 'good' 포함 시 PASS. escalation 샘플은 항상 FAIL이 나와야 함.
set -euo pipefail
OUT="${1:?out_file required}"
grep -q "good" "$OUT"
