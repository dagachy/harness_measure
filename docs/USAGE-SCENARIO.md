# measure — 사용 시나리오

실제 명령·예상 출력 중심. 모든 산출물은 사용자 로컬에만 생성되며 외부 호출 없음.

---

## 공통 사전 준비

```bash
git clone https://github.com/dagachy/measure.git ~/measure-src
bash ~/measure-src/scripts/install.sh
```

설치 후 `~/.claude/{agents,skills}/` 에 다음이 들어온다:

```
agents/with-without-runner.md
agents/with-without-grader.md
agents/retry-safety-executor.md
skills/with-without/
skills/retry-safety/
```

---

## 시나리오 M.1 — 신규 스킬 효과를 With/Without 로 측정

**상황**: `csv-summary` 스킬을 새로 만들었다. 이 스킬이 **없을 때 vs 있을 때** 결과 품질이 실제로 좋아지는지 측정.

**준비** — fixture 디렉토리 1개:

```
my-exp/
├── fixture.json              # {"name":"csv-exp","timeout_ms":60000}
├── with/run.sh               # csv-summary 스킬을 사용해 요약 생성 → $1/output.md
├── without/run.sh            # 스킬 없이 LLM 직접 호출 → $1/output.md
└── assertions/
    ├── 01-dept-group.sh      # grep "부서별 평균 연봉" output.md  (변별력 있을 것 기대)
    └── 02-nonempty.sh        # test -s output.md                 (양쪽 PASS 기대, 변별력 없음)
```

**실행**:

```
~/exp/my-exp with/without 비교해줘
```

**예상 출력 (comparison.md 발췌)**:

```
| 지표         | With | Without |
|-------------|------|---------|
| pass_rate   | 1.0 | 0.5 |
| duration_ms | 12840 | 14210 |
| total_tokens| 1832 | 2104 |

- Verdict: HAS_POWER
- 변별력 있는 단언: 1건 (01-dept-group.sh)
```

**해석**: `HAS_POWER` → 스킬 효과가 변별력 있는 단언으로 검출됨. 운영 투입 가능.

---

## 시나리오 M.2 — 변별력 없는 실험 조기 탐지

**상황**: 비교해봤지만 두 환경 결과가 똑같다. 스킬이 효과가 없거나, 단언이 둔감하거나 둘 중 하나.

**실행**:

```
~/exp/my-exp with/without 비교해줘
```

**예상 출력**:

```
> 실험 변별력 없음 (NO_POWER): discriminating 단언 0건. 단언을 Why-first로 보강하거나 스킬 효과가 측정 범위를 벗어났을 가능성.

- Verdict: NO_POWER
- 변별력 있는 단언: 0건
- 변별력 없는 단언: 2건 (both_pass)
```

**다음 행동**:
1. 단언이 전부 "출력 존재" 수준이면 → Why-first 단언 추가 (예: 그룹별 집계가 들어 있는지).
2. 스킬이 영향 주는 범위가 다른 지표(duration/tokens)에 있으면 → 3축 요약 테이블로 확인.
3. 그래도 변별력 없으면 → 스킬 자체 재설계 또는 폐기.

---

## 시나리오 M.3 — With 가 오히려 품질 떨어뜨리는 "SUSPECT" 신호

**상황**: with 환경에서 어떤 단언이 FAIL 로 바뀌었다 (inverted).

**예상 출력**:

```
| 03-structured-output.sh | FAIL | PASS | inverted |

- Verdict: SUSPECT
- inverted (의심): 1건
```

**다음 행동**:
1. with 환경이 올바르게 로드되었는지 (스킬 경로/권한).
2. 03-structured-output.sh 가 **with 환경의 산출물 포맷** 을 전제로 짜여 있는지 (단언이 공정한가?).
3. with 환경에서 외부 의존성이 깨지지 않았는지.

**전건 재검토 전까지 결론 보류**.

---

## 시나리오 M.4 — retry-safety 로 생성·검증 루프 안전화

**상황**: 코드 생성 에이전트가 가끔 실패한다. 무한 재시도는 비용 폭주 — 상한을 두고 싶다.

**준비** — fixture:

```
code-gen-safe/
├── fixture.json              # {"max_retries":3}
├── generator.sh              # LLM 호출 → $2 에 코드 파일 작성
└── verifier.sh               # pytest / typecheck 돌려서 exit 0/1 반환
```

**실행**:

```
~/exp/code-gen-safe retry-safety 실행
```

**예상 출력 (성공 경로)**:

```
- outcome: success
- attempts: 2/3
- final_artifact: .../result/attempt_2.txt
```

**예상 출력 (상한 소진)**:

```
- outcome: escalated
- attempts: 3/3

## escalation
escalated: 3회 실패, 수동 개입 필요
```

**다음 행동**: `escalated` 라인을 Grafana/Linear/Slack bot 알림 규칙에 연결해 사람 개입 트리거.

---

## 시나리오 M.5 — 조직 템플릿 문구로 에스컬레이션 교체

**상황**: 사내 oncall 알림 봇이 특정 포맷을 요구한다.

**실행**:

```bash
export RS_ESCALATE_MESSAGE="[P1] escalated after {N} retries — paging oncall"
```

이후 retry-safety 를 실행하면 `{N}` 이 상한값으로 치환된 문구가 run.log 와 report.md 에 남는다.

---

## 시나리오 M.6 — 배치 모드로 여러 fixture 한 번에

**상황**: 10개 fixture 로 회귀 측정을 돌리고 집계 표만 보고 싶다.

**실행**:

```
~/exp/weekly-regression 전체 with/without 측정
```

**예상 출력**:

```
| Fixture       | pass_rate (W/WO) | duration_ms (W/WO) | discriminating | Verdict   |
|---------------|------------------|---------------------|----------------|-----------|
| csv-summary   | 1.00/0.50        | 12.8s/14.2s         | 1              | HAS_POWER |
| pr-review     | 0.83/0.67        | 24.1s/22.5s         | 2              | HAS_POWER |
| doc-outline   | 1.00/1.00        | 6.2s/6.1s           | 0              | NO_POWER  |
| ...           | ...              | ...                 | ...            | ...       |

변별력 있는 fixture: 7/10
```

**다음 행동**: NO_POWER 로 나온 fixture 의 단언을 Why-first 로 보강하거나, 해당 스킬이 실제로 효과 있는지 재검토.

---

## 시나리오 M.7 — 자가 검증 (설치 직후 또는 업그레이드 후)

**실행**:

```bash
cd ~/measure-src
# with-without
bash .claude/skills/with-without/bin/run.sh   .claude/skills/with-without/samples/discriminating
bash .claude/skills/with-without/bin/grade.sh .claude/skills/with-without/samples/discriminating/result
bash .claude/skills/with-without/bin/run.sh   .claude/skills/with-without/samples/non-discriminating
bash .claude/skills/with-without/bin/grade.sh .claude/skills/with-without/samples/non-discriminating/result

# retry-safety
bash .claude/skills/retry-safety/bin/run.sh .claude/skills/retry-safety/samples/success
bash .claude/skills/retry-safety/bin/run.sh .claude/skills/retry-safety/samples/escalation
```

각 result 디렉토리의 리포트 끝에 `[self-check] PASS` 가 있으면 OK. `FAIL` 이면 PR 리그레션 — 이슈로 보고.

---

## 트러블슈팅

### 결과 디렉토리에 이전 run 의 파일이 남아 있다

러너는 매 실행 시 `result/` 를 **지우고 재생성** 한다. 남아 있다면 러너가 실패해서 중간에 멈춘 것 — stderr 로그 확인.

### `python3` 가 Microsoft Store 설치 안내로 리다이렉션된다 (Windows)

bin 스크립트는 `python3 || python` fallback 을 포함한다. 둘 다 없으면 설치 필요.

### timeout 이 적용되지 않는다

`command -v timeout` 결과가 없으면 (coreutils 미설치) timeout 캡이 무시된다. 사용자 정의 timeout 이 중요한 환경이면 coreutils 설치.

### with-without 의 duration 이 매번 크게 흔들린다

환경 noise (CPU, 네트워크, 캐시). 중요한 측정은 **반복 수집 → 중앙값** 이 정석이지만 이 스킬 범위 밖. 같은 fixture 를 N번 돌려 수동 집계하거나, 전용 반복 측정 스킬을 별도로 추가할 것.

### with 와 without 이 같은 파일을 공유해서 오염된다

`run.sh` 가 `$1/` (전달받은 out_dir) 바깥에 쓰면 F1 오염 발생. **반드시 out_dir 안에만 쓸 것**. 전역 상태(홈 디렉토리, /tmp 공유 파일)는 금지.
