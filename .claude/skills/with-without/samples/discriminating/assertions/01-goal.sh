#!/usr/bin/env bash
# 변별력 있는 단언: "goal achieved" 마커가 산출물에 있어야 PASS.
set -euo pipefail
grep -q "goal achieved" output.txt
