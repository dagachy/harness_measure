#!/usr/bin/env bash
# 변별력 없는 단언: 파일 존재/비공백만 확인. 두 환경 모두 PASS 할 것으로 기대.
set -euo pipefail
test -s output.txt
