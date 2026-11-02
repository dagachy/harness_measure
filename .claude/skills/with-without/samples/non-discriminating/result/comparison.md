# With/Without 비교

## 3축 요약

| 지표         | With | Without |
|-------------|------|---------|
| pass_rate   | 1.0 | 1.0 |
| duration_ms | 172 | 173 |
| total_tokens| 7 | 7 |

(토큰 모드: estimated)

## 단언별 결과

| ID | With | Without | 라벨 |
|----|:----:|:-------:|------|
| 01-exists.sh | PASS | PASS | non_discriminating_both_pass |
| 02-nonempty-line.sh | PASS | PASS | non_discriminating_both_pass |

## 변별력 요약
- 변별력 있는 단언: 0건
- 변별력 없는 단언: 2건
- Verdict: NO_POWER

[self-check] PASS vs expected={'pass_rate_with': 1.0, 'pass_rate_without': 1.0, 'discriminating_count': 0}
