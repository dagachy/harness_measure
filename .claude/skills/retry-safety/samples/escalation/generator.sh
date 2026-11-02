#!/usr/bin/env bash
# escalation fixture generator — 항상 'bad' 산출물
set -euo pipefail
N="${1:?attempt required}"
OUT="${2:?out_file required}"
echo "artifact_v${N}_bad" > "$OUT"
