# retry-safety report

- Fixture: .claude/skills/retry-safety/samples/success
- max_retries: 3
- outcome: success
- attempts: 2/3
- final_artifact: .claude/skills/retry-safety/samples/success/result/attempt_2.txt
- duration_ms_total: 514

## attempts

| attempt | exit_gen | exit_ver | duration_ms | timed_out |
|:-------:|:--------:|:--------:|:-----------:|:---------:|
| 1 | 0 | 1 | 183 | false |
| 2 | 0 | 0 | 197 | false |

## escalation
없음 (성공 종료)

[self-check] PASS vs expected={'outcome': 'success', 'attempts': 2}
