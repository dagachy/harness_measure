---
name: retry-safety-executor
description: fixture 1건의 generator + verifier 를 MAX_RETRIES 상한 루프로 실행하고 outcome.json / report.md / run.log / attempt_*.txt 를 생성한다. retry-safety 런타임 안전장치의 "실행자" 역할. 호출자: retry-safety 스킬.
model: sonnet
tools: Read, Bash, Write
---

# retry-safety-executor

MAX_RETRIES 상한 재시도 실행 에이전트.
입력 1건(fixture 디렉토리) → `result/` 생성 + 고정 스키마 리포트.

---

## 1. 입력 계약

- `FIXTURE` (필수): fixture 디렉토리 **절대 경로**. 하위에 `generator.sh`, `verifier.sh`, `fixture.json` 이 있어야 한다.
- `RS_MAX_RETRIES` (선택, 환경변수): 상한 재지정. 기본은 `fixture.json.max_retries` 또는 3.
- `RS_ATTEMPT_TIMEOUT_MS` (선택, 환경변수): generator 1회 실행 timeout(ms). 기본 `60000`.
- `RS_ESCALATE_MESSAGE` (선택, 환경변수): 에스컬레이션 문구 템플릿. `{N}` 토큰은 상한값으로 치환. 기본 `"escalated: {N}회 실패, 수동 개입 필요"` (책 p140 문구 보존).

파일 유효성 실패 시 **종료 코드 1 + 한 줄 에러**.

---

## 2. 실행 로직

내장 러너 `bin/run.sh` 를 호출. bash + python3 표준 라이브러리만 사용.

```bash
bash "<플러그인 루트>/.claude/skills/retry-safety/bin/run.sh" "$FIXTURE"
```

### 2.1 루프 (책 p140 의사코드 보존)

```
for attempt in 1..MAX_RETRIES:
    out = attempt_<N>.txt
    generator.sh <attempt> <out>              # timeout 적용
    if verifier.sh <out>: outcome=success → return out
done
outcome=escalated
```

- 각 attempt 마다 `run.log` 에 `[attempt N/M] exit_gen=... exit_ver=... duration_ms=... timed_out=...` 라인 추가.
- generator timeout 또는 비정상 종료는 **그 attempt 를 FAIL 로 간주**하고 루프 지속 (책 의사코드 보존).
- 성공 시: `outcome=success`, `attempts=N`, `final_artifact=attempt_<N>.txt`.
- 소진 시: `outcome=escalated`, `attempts=MAX_RETRIES`, `final_artifact=null`, run.log 마지막 줄에 치환된 `RS_ESCALATE_MESSAGE`.

### 2.2 outcome.json 스키마 (고정)

```json
{
  "outcome": "success|escalated",
  "attempts": <int>,
  "max_retries": <int>,
  "final_artifact": "<path|null>",
  "escalate_message": "<string|null>",
  "duration_ms_total": <int>,
  "attempts_detail": [
    {"n": 1, "exit_gen": 0, "exit_ver": 1, "duration_ms": 42, "timed_out": false}
  ]
}
```

---

## 3. report.md (고정 스키마)

```
# retry-safety report

- Fixture: <absolute path>
- max_retries: <N>
- outcome: <success|escalated>
- attempts: <N>/<MAX>
- final_artifact: <path|-->
- duration_ms_total: <int>

## attempts

| attempt | exit_gen | exit_ver | duration_ms | timed_out |
|:-------:|:--------:|:--------:|:-----------:|:---------:|
| 1 | 0 | 1 | 42 | false |
| 2 | 0 | 0 | 44 | false |

## escalation
<escalate_message 또는 "없음 (성공 종료)">

[self-check] <PASS|FAIL> vs expected={outcome,attempts}  ← fixture.json.expected 가 있을 때만
```

---

## 4. 실행 순서

1. `FIXTURE` 유효성 확인 + 환경변수 로드.
2. `bin/run.sh` 호출.
3. `report.md` + `outcome.json` 경로를 보고. outcome 이 `escalated` 이면 "수동 개입 필요" 1줄 재강조.

---

## 5. 제한 사항

- generator 가 **같은 산출물을 매번** 만들면 재시도는 의미 없음 — fixture 설계 시 attempt 에 따른 변화 또는 외부 noise 를 반영할 것.
- verifier 는 종료 코드만 신뢰. 비결정적 verifier(네트워크 의존)는 timeout 이슈가 번져 outcome 왜곡 가능.
- MAX_RETRIES 는 **상한** 이지 목표가 아님 — "매번 3회 돌리고 평균을 낸다" 는 다른 스킬(A/B 반복 측정) 영역.
