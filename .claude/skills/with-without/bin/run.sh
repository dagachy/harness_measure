#!/usr/bin/env bash
# with-without runner — fixture 1건 실행
# 사용: bash run.sh <fixture_dir>
#
# 환경변수:
#   WW_TIMEOUT_MS (default 60000)
#   WW_TOKENS_MODE (default "estimated")  : "estimated" | "measured"
#   WW_PARALLEL   (default 1)             : 0 지정 시 순차
#
# 산출:
#   <fixture>/result/with/*         (환경 산출물)
#   <fixture>/result/without/*
#   <fixture>/result/with/metrics.json
#   <fixture>/result/without/metrics.json

set -euo pipefail

# Windows: python3 가 Store alias로 리다이렉션되는 환경 대응
PY=""
if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  PY="python3"
elif command -v python >/dev/null 2>&1 && python -c "import sys" >/dev/null 2>&1; then
  PY="python"
else
  echo "error: python3/python not available" >&2
  exit 1
fi

FIXTURE="${1:?fixture dir required}"
[[ -d "$FIXTURE" ]] || { echo "error: fixture dir not found: $FIXTURE" >&2; exit 1; }
[[ -f "$FIXTURE/with/run.sh"    ]] || { echo "error: $FIXTURE/with/run.sh missing" >&2; exit 1; }
[[ -f "$FIXTURE/without/run.sh" ]] || { echo "error: $FIXTURE/without/run.sh missing" >&2; exit 1; }

WW_TIMEOUT_MS="${WW_TIMEOUT_MS:-60000}"
WW_TOKENS_MODE="${WW_TOKENS_MODE:-estimated}"
WW_PARALLEL="${WW_PARALLEL:-1}"

# ms → 초 반올림 (최소 1초, 정수)
TIMEOUT_SEC=$(( (WW_TIMEOUT_MS + 999) / 1000 ))
(( TIMEOUT_SEC < 1 )) && TIMEOUT_SEC=1

RESULT="$FIXTURE/result"
rm -rf "$RESULT"
mkdir -p "$RESULT/with" "$RESULT/without"

# 환경 1건 실행 함수. 반환: metrics.json 작성.
run_env() {
  local env_name="$1"            # "with" | "without"
  local script="$FIXTURE/$env_name/run.sh"
  local out_dir="$RESULT/$env_name"
  local metrics="$out_dir/metrics.json"
  local log="$out_dir/_run.log"

  local start_ns end_ns duration_ms exit_code=0 timed_out=false

  start_ns=$(date +%s%N)
  # timeout 유틸은 Git Bash/Linux/macOS(coreutils) 공통. 없으면 그대로 실행.
  if command -v timeout >/dev/null 2>&1; then
    if ! timeout --preserve-status "${TIMEOUT_SEC}s" bash "$script" "$out_dir" >"$log" 2>&1; then
      exit_code=$?
      # 124 = timeout 발생 (preserve-status 라도 자식이 종료되지 않으면 124 유지되는 환경 존재)
      if (( exit_code == 124 )); then timed_out=true; fi
    fi
  else
    if ! bash "$script" "$out_dir" >"$log" 2>&1; then
      exit_code=$?
    fi
  fi
  end_ns=$(date +%s%N)
  duration_ms=$(( (end_ns - start_ns) / 1000000 ))

  if $timed_out; then
    duration_ms=$WW_TIMEOUT_MS
  fi

  # 토큰 추정/수집
  local tokens="null" mode="$WW_TOKENS_MODE"
  if [[ "$mode" == "measured" && -f "$metrics" ]]; then
    # run.sh가 metrics.json을 미리 썼다면 total_tokens 추출
    tokens=$($PY - "$metrics" <<'PY' 2>/dev/null || echo null
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    v = d.get("total_tokens")
    print(v if isinstance(v, int) else "null")
except Exception:
    print("null")
PY
)
  else
    # estimated: 산출물 바이트 합계 / 4
    local bytes
    bytes=$(find "$out_dir" -type f ! -name "metrics.json" ! -name "_run.log" -printf "%s\n" 2>/dev/null \
      | awk 'BEGIN{s=0} {s+=$1} END{print s+0}')
    tokens=$(( bytes / 4 ))
    mode="estimated"
  fi

  # metrics.json 덮어쓰기 (최종본)
  cat > "$metrics" <<JSON
{
  "env": "$env_name",
  "duration_ms": $duration_ms,
  "total_tokens": $tokens,
  "tokens_mode": "$mode",
  "timed_out": $timed_out,
  "exit_code": $exit_code
}
JSON
}

# 동시 실행 (F1: 순차 금지가 기본)
if [[ "$WW_PARALLEL" == "1" ]]; then
  run_env with    & PID_W=$!
  run_env without & PID_WO=$!
  wait "$PID_W"
  wait "$PID_WO"
else
  echo "warning: WW_PARALLEL=0 — 순차 실행 중 (F1 위반, 디버깅 전용)" >&2
  run_env with
  run_env without
fi

# 요약을 stdout 으로 (호출 에이전트가 리포트에 넣기 용이하도록)
$PY - "$RESULT/with/metrics.json" "$RESULT/without/metrics.json" <<'PY'
import json, sys
w = json.load(open(sys.argv[1]))
wo = json.load(open(sys.argv[2]))
def row(e, m): return f"{e:7s} duration_ms={m['duration_ms']:>6}  tokens={m['total_tokens']}  mode={m['tokens_mode']}  exit={m['exit_code']}  timed_out={str(m['timed_out']).lower()}"
print(row("with",    w))
print(row("without", wo))
PY

echo "result_dir=$RESULT"
