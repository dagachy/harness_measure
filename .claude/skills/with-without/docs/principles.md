# with-without 원칙 (ex-05-11 기반)

이 스킬은 책 *Harness Engineering with Claude Code* ex-05-11 "With/Without 비교" 1사이클을 범용 fixture 포맷으로 추상화한 것이다.

## 5대 원칙 (책 번호 F1~F5)

| 번호 | 원칙 | 본 구현에서의 반영 |
|------|------|----------------------|
| F1 | **동시 실행** — 순차 시 캐시·파일 상태 오염 | `run.sh` 가 `&` 로 두 환경을 띄우고 `wait`. `WW_PARALLEL=0` 는 디버깅 전용 경고 발생 |
| F2 | 같은 프롬프트 / 다른 스킬 구성 / **다른 출력 경로** | `result/with/`, `result/without/` 로 완전 격리. 러너가 재실행 시 지우고 재생성 |
| F3 | **변별력 없는 단언**("출력 존재")은 라벨링해서 노이즈 제거 | grader 가 `non_discriminating_both_pass` / `non_discriminating_both_fail` 라벨 자동 부여 |
| F4 | **변별력 있는 단언** >= 1건 (with PASS / without FAIL) | `discriminating_count = 0` 이면 Verdict `NO_POWER` + 상단 경고 |
| F5 | 비교 표 컬럼 = **pass_rate / duration_ms / total_tokens** (품질·속도·비용 3축) | `comparison.md` 상단에 고정 테이블 |

## estimated 토큰 추정 공식

실제 API 호출 비용을 모르는 환경(stub, 로컬 fixture)에서는 **산출물 바이트 수 / 4** 를 추정치로 사용한다 (영문 1 토큰 ≒ 4 바이트 가정).

- 상대 비교 (with vs without)에만 유의미.
- 절대 비용 산정에는 부적합 — API 측정값 기반 `measured` 모드가 있을 때만 사용.
- 각 환경 `run.sh` 가 직접 `metrics.json` 에 `total_tokens` 를 쓰면 `WW_TOKENS_MODE=measured` 로 신뢰.

## inverted 라벨

with 환경이 오히려 품질을 떨어뜨리는 경우 (`with=FAIL / without=PASS`) — **의심 신호**. 다음을 점검:

1. with 환경이 올바르게 로드되었는가 (스킬 경로/권한).
2. 단언이 with 환경의 산출물 포맷을 전제로 짠 것은 아닌가.
3. with 환경에서 외부 의존성(네트워크/파일)이 깨지지 않았는가.

inverted 1건 이상 → Verdict `SUSPECT`. 전건 재검토 전까지 결론 보류.

## 책 수치와의 관계

책 ex-05-11 표의 수치(pass_rate 0.83, total_tokens 18,500 등)는 저자 실측값이다. 본 fixture 수치는 **방법론 일치**가 본질이지 정량 일치가 아니다 — 각 환경에서 실제로 측정하라.
