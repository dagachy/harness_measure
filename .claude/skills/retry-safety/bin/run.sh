#!/usr/bin/env bash
# retry-safety executor — MAX_RETRIES 상한 재시도 루프
# 사용: bash run.sh <fixture_dir>
#
# 환경변수:
#   RS_MAX_RETRIES          (default: fixture.json.max_retries 또는 3)
#   RS_ATTEMPT_TIMEOUT_MS   (default 60000)
#   RS_ESCALATE_MESSAGE     (default "escalated: {N}회 실패, 수동 개입 필요")
#
# 산출:
#   <fixture>/result/attempt_<N>.txt
#   <fixture>/result/run.log
#   <fixture>/result/outcome.json
#   <fixture>/result/report.md

set -euo pipefail

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
[[ -d "$FIXTURE" ]]              || { echo "error: fixture not found: $FIXTURE" >&2; exit 1; }
[[ -f "$FIXTURE/generator.sh" ]] || { echo "error: $FIXTURE/generator.sh missing" >&2; exit 1; }
[[ -f "$FIXTURE/verifier.sh"  ]] || { echo "error: $FIXTURE/verifier.sh missing"  >&2; exit 1; }

# MAX_RETRIES 결정 우선순위: 환경변수 > fixture.json > 기본 3
DEFAULT_MAX=3
FIXTURE_MAX=""
if [[ -f "$FIXTURE/fixture.json" ]]; then
  FIXTURE_MAX=$($PY - "$FIXTURE/fixture.json" <<'PY' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        d = json.load(f)
    v = d.get("max_retries")
    if isinstance(v, int) and v > 0:
        print(v)
except Exception:
    pass
PY
)
fi
MAX_RETRIES="${RS_MAX_RETRIES:-${FIXTURE_MAX:-$DEFAULT_MAX}}"
if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || (( MAX_RETRIES < 1 )); then
  echo "error: invalid MAX_RETRIES: $MAX_RETRIES" >&2
  exit 1
fi

ATTEMPT_TIMEOUT_MS="${RS_ATTEMPT_TIMEOUT_MS:-60000}"
ATTEMPT_TIMEOUT_SEC=$(( (ATTEMPT_TIMEOUT_MS + 999) / 1000 ))
(( ATTEMPT_TIMEOUT_SEC < 1 )) && ATTEMPT_TIMEOUT_SEC=1

if [[ -z "${RS_ESCALATE_MESSAGE:-}" ]]; then
  # 책 p140 원문 보존. default 안에 '}' 가 있으면 `${VAR:-...}` 를 조기 종결시키므로 if-else로 할당.
  ESCALATE_MESSAGE_TEMPLATE="escalated: {N}회 실패, 수동 개입 필요"
else
  ESCALATE_MESSAGE_TEMPLATE="$RS_ESCALATE_MESSAGE"
fi
ESCALATE_MESSAGE="${ESCALATE_MESSAGE_TEMPLATE//'{N}'/$MAX_RETRIES}"

RESULT="$FIXTURE/result"
rm -rf "$RESULT"
mkdir -p "$RESULT"
LOG="$RESULT/run.log"
: > "$LOG"
DETAIL_TSV="$RESULT/.attempts.tsv"
: > "$DETAIL_TSV"

START_NS=$(date +%s%N)

OUTCOME="escalated"
FINAL_ATTEMPT=0
FINAL_ARTIFACT=""

run_attempt() {
  local n="$1"
  local out="$RESULT/attempt_${n}.txt"
  local a_start a_end a_dur exit_gen=0 exit_ver=0 timed_out=false

  a_start=$(date +%s%N)
  if command -v timeout >/dev/null 2>&1; then
    if ! timeout --preserve-status "${ATTEMPT_TIMEOUT_SEC}s" bash "$FIXTURE/generator.sh" "$n" "$out" >>"$LOG" 2>&1; then
      exit_gen=$?
      if (( exit_gen == 124 )); then timed_out=true; fi
    fi
  else
    if ! bash "$FIXTURE/generator.sh" "$n" "$out" >>"$LOG" 2>&1; then
      exit_gen=$?
    fi
  fi

  # verifier 실행 (generator 가 실패해도 책 의사코드는 verifier 를 호출 — 산출물 FFFD/부재 시 자연히 FAIL)
  if bash "$FIXTURE/verifier.sh" "$out" >>"$LOG" 2>&1; then
    exit_ver=0
  else
    exit_ver=$?
  fi

  a_end=$(date +%s%N)
  a_dur=$(( (a_end - a_start) / 1000000 ))
  if $timed_out; then
    a_dur=$ATTEMPT_TIMEOUT_MS
  fi

  printf "%d\t%d\t%d\t%d\t%s\n" "$n" "$exit_gen" "$exit_ver" "$a_dur" "$timed_out" >> "$DETAIL_TSV"
  printf "[attempt %d/%d] exit_gen=%d exit_ver=%d duration_ms=%d timed_out=%s\n" \
    "$n" "$MAX_RETRIES" "$exit_gen" "$exit_ver" "$a_dur" "$timed_out" >> "$LOG"

  if (( exit_ver == 0 )); then
    OUTCOME="success"
    FINAL_ATTEMPT="$n"
    FINAL_ARTIFACT="$out"
    return 0
  fi
  return 1
}

for (( n=1; n<=MAX_RETRIES; n++ )); do
  if run_attempt "$n"; then
    break
  fi
done

if [[ "$OUTCOME" != "success" ]]; then
  FINAL_ATTEMPT=$MAX_RETRIES
  echo "$ESCALATE_MESSAGE" >> "$LOG"
fi

END_NS=$(date +%s%N)
DURATION_TOTAL_MS=$(( (END_NS - START_NS) / 1000000 ))

# outcome.json + report.md 생성
$PY - "$FIXTURE" "$RESULT" "$MAX_RETRIES" "$OUTCOME" "$FINAL_ATTEMPT" "$FINAL_ARTIFACT" "$ESCALATE_MESSAGE" "$DURATION_TOTAL_MS" "$DETAIL_TSV" <<'PY'
import json, os, sys
fixture_dir, result_dir, max_r, outcome, final_attempt, final_artifact, escalate_msg, dur_total, tsv = sys.argv[1:10]
max_r = int(max_r); final_attempt = int(final_attempt); dur_total = int(dur_total)

details = []
with open(tsv, encoding="utf-8") as f:
    for line in f:
        p = line.rstrip("\n").split("\t")
        if len(p) != 5: continue
        details.append({
            "n": int(p[0]),
            "exit_gen": int(p[1]),
            "exit_ver": int(p[2]),
            "duration_ms": int(p[3]),
            "timed_out": p[4] == "true",
        })

outcome_obj = {
    "outcome": outcome,
    "attempts": final_attempt,
    "max_retries": max_r,
    "final_artifact": (final_artifact or None) if outcome == "success" else None,
    "escalate_message": escalate_msg if outcome == "escalated" else None,
    "duration_ms_total": dur_total,
    "attempts_detail": details,
}
with open(os.path.join(result_dir, "outcome.json"), "w", encoding="utf-8") as f:
    json.dump(outcome_obj, f, indent=2, ensure_ascii=False)

# self-check
self_check = None
fx_path = os.path.join(fixture_dir, "fixture.json")
if os.path.isfile(fx_path):
    try:
        with open(fx_path, encoding="utf-8") as f: fx = json.load(f)
        exp = fx.get("expected") or {}
        if exp:
            ok = True
            if "outcome"  in exp and exp["outcome"]  != outcome:        ok = False
            if "attempts" in exp and exp["attempts"] != final_attempt:  ok = False
            self_check = ("PASS" if ok else "FAIL", exp)
    except Exception as e:
        self_check = ("SKIP", {"error": str(e)})

lines = []
lines.append("# retry-safety report")
lines.append("")
lines.append(f"- Fixture: {fixture_dir}")
lines.append(f"- max_retries: {max_r}")
lines.append(f"- outcome: {outcome}")
lines.append(f"- attempts: {final_attempt}/{max_r}")
lines.append(f"- final_artifact: {outcome_obj['final_artifact'] or '--'}")
lines.append(f"- duration_ms_total: {dur_total}")
lines.append("")
lines.append("## attempts")
lines.append("")
lines.append("| attempt | exit_gen | exit_ver | duration_ms | timed_out |")
lines.append("|:-------:|:--------:|:--------:|:-----------:|:---------:|")
for d in details:
    lines.append(f"| {d['n']} | {d['exit_gen']} | {d['exit_ver']} | {d['duration_ms']} | {str(d['timed_out']).lower()} |")
lines.append("")
lines.append("## escalation")
lines.append(escalate_msg if outcome == "escalated" else "없음 (성공 종료)")
if self_check:
    status, exp = self_check
    lines.append("")
    lines.append(f"[self-check] {status} vs expected={exp}")

with open(os.path.join(result_dir, "report.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

print(f"outcome={outcome} attempts={final_attempt}/{max_r} duration_ms_total={dur_total}")
if outcome == "escalated":
    print(f"escalate_message={escalate_msg}")
print(f"wrote {os.path.join(result_dir, 'outcome.json')}")
print(f"wrote {os.path.join(result_dir, 'report.md')}")
PY

echo "result_dir=$RESULT"
