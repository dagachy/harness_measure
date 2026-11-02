# retry-safety 원칙 (ex-08-15 기반)

이 스킬은 책 *Harness Engineering with Claude Code* p140 "MAX_RETRIES 안전장치" 의사코드를 범용 fixture 포맷으로 추상화한 것이다.

## 책 의사코드 (p140)

```python
MAX_RETRIES = 3

def generate_with_retries(spec, generator, verifier):
    for attempt in range(MAX_RETRIES):
        artifact = generator.run(spec)
        result = verifier.run(artifact)
        if result.passed:
            return artifact
    return f"escalated: {MAX_RETRIES}회 실패, 수동 개입 필요"
```

본 구현은 Python 대신 bash + shell fixture 로 동일 의사코드 시그니처를 보존한다:

| 책 요소 | 본 구현 |
|--------|---------|
| `MAX_RETRIES = 3` | fixture.json 의 `max_retries` (기본 3). 환경변수 `RS_MAX_RETRIES` 로 override |
| `for attempt in range(MAX_RETRIES)` | bash `for (( n=1; n<=MAX_RETRIES; n++ ))` 루프 |
| `if result.passed: return` | `exit_ver==0` 분기 → `OUTCOME="success"` + 루프 탈출 |
| 루프 탈출 후 escalate 문구 | `RS_ESCALATE_MESSAGE` 템플릿. 기본 `"escalated: {N}회 실패, 수동 개입 필요"` (책 문구 그대로) |

## 안티패턴 #2 와의 관계 (ex-08-33)

**무한 재시도**는 책이 꼽는 하네스 안티패턴 #2. 상한이 없는 `while True` 는:

1. 비용 폭주 (API 과금, CPU 시간).
2. 디버깅 신호 상실 (실패를 못 보고 지남).
3. 에스컬레이션 지점 상실 (사람 개입 trigger 없음).

본 스킬은 **상한을 강제**하는 것이 책임의 전부. 상한값 자체는 fixture 설계자가 결정 — 책 기본 3은 "짧은 피드백 사이클" 가정이고, 비용 큰 작업(장시간 생성/네트워크 호출)은 더 낮게 두는 것이 안전.

## 에스컬레이션 문구

`RS_ESCALATE_MESSAGE` 는 조직 템플릿으로 교체 가능하지만 **반드시 `{N}` 토큰과 "escalated" 라는 어휘** 를 포함할 것 — 상위 로그 수집기(Grafana, Linear, Slack bot)가 이 문자열로 알림을 띄우는 설계가 흔하다.

예:
- `"escalated: {N} attempts failed, needs human review"` (영문)
- `"[P1] escalated after {N} retries — paging oncall"` (알림용)

## generator 가 매번 같은 산출물을 낸다면

재시도는 의미 없음. 두 가지 중 선택:

1. generator 가 attempt 번호 / seed / noise 를 받아 **다른 산출물**을 내도록 수정.
2. `max_retries=1` 로 두고 즉시 escalate (= "한 번 실패하면 사람에게").

본 스킬은 generator 품질을 판정하지 않는다 — 러너는 "상한을 지킨다" 만 보장.

## verifier 가 비결정적일 때

verifier 가 네트워크/타이밍 의존이면 timeout 또는 간헐 실패가 outcome 을 왜곡한다. 그런 경우:

- verifier 자체를 더 짧은 timeout 안의 결정적 check 로 축소.
- 또는 verifier 재시도는 **retry-safety 바깥 레이어**로 분리 (verifier 안정화 → retry-safety 적용).

## cross-link

- 다이어그램: 책 ex-08-13
- 트레이드오프 (무한 루프 vs 상한): ex-08-16
- 안티패턴 전체 목록: ex-08-33
