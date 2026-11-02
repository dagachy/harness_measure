# retry-safety report

- Fixture: .claude/skills/retry-safety/samples/escalation
- max_retries: 3
- outcome: escalated
- attempts: 3/3
- final_artifact: --
- duration_ms_total: 829

## attempts

| attempt | exit_gen | exit_ver | duration_ms | timed_out |
|:-------:|:--------:|:--------:|:-----------:|:---------:|
| 1 | 0 | 1 | 235 | false |
| 2 | 0 | 1 | 213 | false |
| 3 | 0 | 1 | 201 | false |

## escalation
escalated: 3회 실패, 수동 개입 필요

[self-check] PASS vs expected={'outcome': 'escalated', 'attempts': 3}
