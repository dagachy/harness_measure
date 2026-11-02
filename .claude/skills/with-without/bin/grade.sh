#!/usr/bin/env bash
# with-without grader — result 디렉토리에 fixture assertions 적용
# 사용: bash grade.sh <result_dir>
#
# 산출:
#   <result>/grading.json
#   <result>/comparison.md

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

RESULT="${1:?result dir required}"
[[ -d "$RESULT/with"    ]] || { echo "error: $RESULT/with missing"    >&2; exit 1; }
[[ -d "$RESULT/without" ]] || { echo "error: $RESULT/without missing" >&2; exit 1; }
[[ -f "$RESULT/with/metrics.json"    ]] || { echo "error: with/metrics.json missing"    >&2; exit 1; }
[[ -f "$RESULT/without/metrics.json" ]] || { echo "error: without/metrics.json missing" >&2; exit 1; }

FIXTURE="$(cd "$RESULT/.." && pwd)"
ASSERT_DIR="$FIXTURE/assertions"
[[ -d "$ASSERT_DIR" ]] || { echo "error: $ASSERT_DIR missing" >&2; exit 1; }

# 단언 수집
mapfile -t ASSERTIONS < <(find "$ASSERT_DIR" -maxdepth 1 -type f -name "*.sh" | sort)
if (( ${#ASSERTIONS[@]} == 0 )); then
  echo "error: no assertions found in $ASSERT_DIR" >&2
  exit 1
fi

# 각 단언을 두 환경 CWD에서 실행
RESULTS_JSON="$RESULT/.assertion_results.tsv"
: > "$RESULTS_JSON"
for a in "${ASSERTIONS[@]}"; do
  id="$(basename "$a")"
  for env in with without; do
    env_dir="$RESULT/$env"
    if ( cd "$env_dir" && bash "$a" >/dev/null 2>&1 ); then
      verdict="PASS"
    else
      verdict="FAIL"
    fi
    printf "%s\t%s\t%s\n" "$id" "$env" "$verdict" >> "$RESULTS_JSON"
  done
done

# python 집계 + grading.json + comparison.md 생성
$PY - "$RESULT" "$RESULTS_JSON" "$FIXTURE/fixture.json" <<'PY'
import json, sys, os
from collections import defaultdict

result_dir = sys.argv[1]
tsv_path   = sys.argv[2]
fixture_js = sys.argv[3]

by_id = defaultdict(dict)  # id -> {"with": "PASS", "without": "FAIL"}
with open(tsv_path, encoding="utf-8") as f:
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 3: continue
        aid, env, v = parts
        by_id[aid][env] = v

def label(w, wo):
    if w == "PASS" and wo == "FAIL":    return "discriminating"
    if w == "FAIL" and wo == "PASS":    return "inverted"
    if w == "PASS" and wo == "PASS":    return "non_discriminating_both_pass"
    return "non_discriminating_both_fail"

ordered_ids = sorted(by_id.keys())
assertions = []
pass_w = pass_wo = 0
disc = inverted = 0
for aid in ordered_ids:
    w  = by_id[aid].get("with", "FAIL")
    wo = by_id[aid].get("without", "FAIL")
    lab = label(w, wo)
    assertions.append({"id": aid, "with": w, "without": wo, "label": lab})
    if w  == "PASS": pass_w  += 1
    if wo == "PASS": pass_wo += 1
    if lab == "discriminating": disc += 1
    if lab == "inverted":       inverted += 1

n = len(assertions)
rate_w  = round(pass_w  / n, 4) if n else 0.0
rate_wo = round(pass_wo / n, 4) if n else 0.0

grading = {
    "pass_rate_with":    rate_w,
    "pass_rate_without": rate_wo,
    "discriminating_count": disc,
    "inverted_count": inverted,
    "assertions": assertions,
}
with open(os.path.join(result_dir, "grading.json"), "w", encoding="utf-8") as f:
    json.dump(grading, f, indent=2, ensure_ascii=False)

# metrics
with open(os.path.join(result_dir, "with/metrics.json"),    encoding="utf-8") as f: mw  = json.load(f)
with open(os.path.join(result_dir, "without/metrics.json"), encoding="utf-8") as f: mwo = json.load(f)

def fmt_tokens(t):
    return "null" if t is None else str(t)

if disc >= 1 and inverted == 0:
    verdict = "HAS_POWER"
elif inverted >= 1:
    verdict = "SUSPECT"
else:
    verdict = "NO_POWER"

lines = []
lines.append("# With/Without 비교")
lines.append("")
lines.append("## 3축 요약")
lines.append("")
lines.append("| 지표         | With | Without |")
lines.append("|-------------|------|---------|")
lines.append(f"| pass_rate   | {rate_w} | {rate_wo} |")
lines.append(f"| duration_ms | {mw['duration_ms']} | {mwo['duration_ms']} |")
lines.append(f"| total_tokens| {fmt_tokens(mw['total_tokens'])} | {fmt_tokens(mwo['total_tokens'])} |")
lines.append("")
lines.append(f"(토큰 모드: {mw['tokens_mode']})")
lines.append("")
lines.append("## 단언별 결과")
lines.append("")
lines.append("| ID | With | Without | 라벨 |")
lines.append("|----|:----:|:-------:|------|")
for a in assertions:
    lines.append(f"| {a['id']} | {a['with']} | {a['without']} | {a['label']} |")
lines.append("")
lines.append("## 변별력 요약")
lines.append(f"- 변별력 있는 단언: {disc}건")
lines.append(f"- 변별력 없는 단언: {n - disc - inverted}건")
if inverted:
    lines.append(f"- inverted (의심): {inverted}건")
lines.append(f"- Verdict: {verdict}")

# self-check (optional)
if os.path.isfile(fixture_js):
    try:
        with open(fixture_js, encoding="utf-8") as f: fx = json.load(f)
        exp = fx.get("expected") or {}
        if exp:
            ok = True
            if "pass_rate_with" in exp and abs(exp["pass_rate_with"] - rate_w) > 0.001: ok = False
            if "pass_rate_without" in exp and abs(exp["pass_rate_without"] - rate_wo) > 0.001: ok = False
            if "discriminating_count" in exp and exp["discriminating_count"] != disc: ok = False
            lines.append("")
            lines.append(f"[self-check] {'PASS' if ok else 'FAIL'} vs expected={exp}")
    except Exception as e:
        lines.append(f"[self-check] skipped: {e}")

cmp_path = os.path.join(result_dir, "comparison.md")
with open(cmp_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

# stdout 요약
print(f"pass_rate: with={rate_w}  without={rate_wo}")
print(f"discriminating={disc}  inverted={inverted}  verdict={verdict}")
print(f"wrote {os.path.join(result_dir, 'grading.json')}")
print(f"wrote {cmp_path}")
PY
