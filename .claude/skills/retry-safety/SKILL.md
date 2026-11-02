---
name: retry-safety
description: generator + verifier 를 MAX_RETRIES 상한 루프로 감싸 성공 또는 "escalated: N회 실패, 수동 개입 필요" 로 종결시키는 런타임 안전장치 진입점. 단일 fixture 또는 fixtures 디렉토리를 retry-safety-executor 에이전트로 실행하고 outcome.json + report.md 를 반환한다. 사용자가 "retry 상한", "무한 루프 방지", "max retries", "에스컬레이트 안전장치" 등을 요청할 때 사용.
---

# retry-safety

MAX_RETRIES 상한 재시도 안전장치 라우터.
단일 fixture / 다중 fixture 두 가지를 지원한다.

---

## 입력 fixture 규약

```
<fixture>/
├── fixture.json       # {"name","max_retries","expected":{"outcome","attempts"}}
├── generator.sh       # 호출: bash generator.sh <attempt> <out_file>. attempt는 1-origin.
└── verifier.sh        # 호출: bash verifier.sh <out_file>. exit 0 = PASS.
```

- generator 는 매 attempt 마다 `<out_file>` 를 새로 쓴다. 품질은 attempt 와 무관하거나 attempt 가 늘수록 좋아질 수 있다.
- verifier 는 산출물 1건의 PASS/FAIL 만 판정. 로그는 stdout/stderr 에.

---

## 모드 결정

- 사용자가 fixture 디렉토리 1개를 주면 **단일 모드**.
- 상위 디렉토리를 주면서 "전체" 또는 "batch" 를 요청하면 **배치 모드** (`fixture.json` 을 가진 하위 디렉토리 전수 수집).

---

## 단일 모드

입력: fixture 디렉토리 절대 경로 1개.

1. `retry-safety-executor` 에이전트를 1회 호출. 프롬프트에 `FIXTURE=<absolute path>` 전달.
2. executor 리포트와 산출물 경로(`<fixture>/result/{outcome.json,report.md,run.log,attempt_*.txt}`) 를 그대로 노출.
3. outcome 이 `escalated` 이면 "수동 개입 필요" 안내 1~2줄 재강조.

---

## 배치 모드

입력: 상위 디렉토리 (`samples/`, `fixtures/` 등).

1. 각 fixture 마다 executor 를 **직렬 호출** (상한 루프끼리 리소스 경합 방지).
2. 집계 표:

```
| Fixture | outcome    | attempts/max | duration_ms | self-check |
|---------|------------|--------------|-------------|------------|
```

3. 표 끝에 `escalated N / success M / 전체 K` 요약 1줄.

---

## 임계값 override

- `RS_MAX_RETRIES` (기본: fixture.json 의 `max_retries`, 없으면 3): 상한 재지정. 디버깅용. 운영에서는 fixture.json 값을 신뢰할 것.
- `RS_ATTEMPT_TIMEOUT_MS` (기본 `60000`): generator 1회 실행 최대 허용 시간. 초과 시 해당 attempt FAIL + run.log 에 `timed_out=true`.
- `RS_ESCALATE_MESSAGE` (기본 `"escalated: {N}회 실패, 수동 개입 필요"` — 책 p140 문구): 조직 템플릿으로 교체 가능. `{N}` 은 치환 토큰.

---

## 자가 검증

플러그인 내장 샘플 fixture 2건:

```
<플러그인 루트>/.claude/skills/retry-safety/samples/
├── success/      # 2회차에 PASS → outcome=success, attempts=2
└── escalation/   # 3회 전부 FAIL → outcome=escalated, attempts=3
```

executor 가 `fixture.json.expected` 와 비교해 `[self-check] PASS|FAIL` 을 report.md 끝에 1줄 추가한다. 2/2 PASS 가 정상.

---

## 범용 적용 메모

이 스킬은 "measure" 플러그인의 런타임 안전장치다. **무한 재시도** 는 이 책의 안티패턴 #2 (ex-08-33) — 생성·검증 루프를 짤 때 반드시 상한을 둘 것.

- 상한 소진 후 **반드시 사람에게 넘기는 문구** 가 로그 끝에 남는다 (관측·에스컬레이션 가능성 확보).
- 상한 자체는 fixture 당 결정 — 책 기본 3 은 "짧은 피드백 사이클" 전제. 비용/시간이 큰 작업은 더 낮게.
- generator 가 **매번 같은 산출물** 을 내면 재시도는 무의미 — 입력(spec/seed/noise)에 변화를 주거나, 상한을 1로 두고 즉시 escalate.
