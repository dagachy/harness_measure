# With/Without 비교

## 3축 요약

| 지표         | With | Without |
|-------------|------|---------|
| pass_rate   | 1.0 | 0.5 |
| duration_ms | 183 | 177 |
| total_tokens| 27 | 27 |

(토큰 모드: estimated)

## 단언별 결과

| ID | With | Without | 라벨 |
|----|:----:|:-------:|------|
| 01-goal.sh | PASS | FAIL | discriminating |
| 02-exists.sh | PASS | PASS | non_discriminating_both_pass |

## 변별력 요약
- 변별력 있는 단언: 1건
- 변별력 없는 단언: 1건
- Verdict: HAS_POWER

[self-check] PASS vs expected={'pass_rate_with': 1.0, 'pass_rate_without': 0.5, 'discriminating_count': 1}
