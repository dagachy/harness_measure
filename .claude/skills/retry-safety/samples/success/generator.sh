#!/usr/bin/env bash
# success fixture generator — attempt>=2 에서 'good' 포함 산출물
set -euo pipefail
N="${1:?attempt required}"
OUT="${2:?out_file required}"
if (( N >= 2 )); then
  echo "artifact_v${N}_good" > "$OUT"
else
  echo "artifact_v${N}_bad" > "$OUT"
fi
