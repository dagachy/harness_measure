# measure

Claude Code 하네스 **런타임 측정(measure)** 스킬 번들.
"스킬·에이전트가 실제로 돌 때 **얼마나 잘/빠르게/안전하게** 동작하는지 측정한다" 는 목적으로 모은 플러그인.

자매 플러그인 [`condition`](https://github.com/dagachy/condition) 이 **초 단위 pre-flight 정적 점검**을 담당한다면, `measure` 는 **분~시간 단위 런타임 실행·측정**을 담당한다. 둘은 UX·실행 모델이 달라 저장소를 분리.

각 스킬은 책 *Harness Engineering with Claude Code* 의 특정 예제가 가르치는 원칙 하나를 **실제 실행 + 자동 측정**으로 변환한 것이다.

---

## 현재 포함된 스킬 (2종)

### A. A/B 비교 측정

- **with-without** — 동일 프롬프트를 두 환경(With/Without)에서 **동시** 실행하고 `pass_rate` · `duration_ms` · `total_tokens` 3축으로 비교. 변별력 있는/없는 단언 자동 라벨링 + Verdict (HAS_POWER / NO_POWER / SUSPECT). *(ex-05-11)*

### B. 재시도 안전장치

- **retry-safety** — generator + verifier 를 **MAX_RETRIES 상한** 루프로 감싸 성공 또는 `"escalated: N회 실패, 수동 개입 필요"` 로 종결. 무한 루프 안티패턴(ex-08-33) 차단. *(ex-08-15)*

---

## condition vs measure (실행 모델 비교)

| 구분 | condition | measure |
|------|-----------|---------|
| 실행 시간 | 초 단위 | 분~시간 단위 |
| 입력 | 파일/디렉토리 (정적) | 실행 가능한 fixture (generator/verifier/run.sh) |
| 결정론 | regex/bash 결정론 | fixture 자체는 결정론, 측정값(duration)은 환경 의존 |
| 호출 시점 | 프로젝트 kickoff 전 pre-flight | kickoff 이후 실제 run 과 함께 또는 회고 때 |
| Verdict | COMPLETE / INCOMPLETE 등 구조 판정 | HAS_POWER / NO_POWER / SUSPECT, success / escalated 등 실행 결과 판정 |

---

## 설치 (한 줄)

```bash
git clone https://github.com/dagachy/measure.git ~/measure-src
bash ~/measure-src/scripts/install.sh
```

옵션:

```bash
bash ~/measure-src/scripts/install.sh --target /path/to/.claude
bash ~/measure-src/scripts/install.sh --symlink
```

기존 파일은 `.bak.<timestamp>` 로 백업.

---

## 사용법

### A. With/Without 비교

```
<fixture_dir> with/without 비교해줘                        # 단일 fixture
<fixtures_root> 전체 with/without 측정                     # 배치
```

fixture 레이아웃:

```
<fixture>/
├── fixture.json              # {"name","timeout_ms","expected":{...}}
├── with/run.sh               # with 환경 실행기 (인자: out_dir)
├── without/run.sh            # without 환경 실행기
└── assertions/*.sh           # 단언. CWD=out_dir, exit 0 = PASS.
```

산출: `<fixture>/result/{with,without}/{output*,metrics.json}`, `grading.json`, `comparison.md`.

### B. retry-safety

```
<fixture_dir> retry-safety 실행                           # 단일 fixture
<fixtures_root> retry-safety 배치                         # 배치
```

fixture 레이아웃:

```
<fixture>/
├── fixture.json              # {"max_retries","expected":{"outcome","attempts"}}
├── generator.sh              # 인자: attempt(1-origin), out_file
└── verifier.sh               # 인자: out_file. exit 0 = PASS.
```

산출: `<fixture>/result/{attempt_N.txt, run.log, outcome.json, report.md}`.

### 임계값 override

세션 환경변수로 조정:

| 변수 | 스킬 | 기본값 | 의미 |
|------|------|--------|------|
| `WW_TIMEOUT_MS` | with-without | `60000` | 각 환경 실행 timeout (ms, 초 단위 반올림) |
| `WW_TOKENS_MODE` | with-without | `estimated` | `estimated` (바이트/4) 또는 `measured` (run.sh가 직접 기록) |
| `WW_PARALLEL` | with-without | `1` | `0` 지정 시 순차 실행 (F1 위반, 디버깅 전용) |
| `RS_MAX_RETRIES` | retry-safety | fixture.json 또는 3 | 상한 재지정 |
| `RS_ATTEMPT_TIMEOUT_MS` | retry-safety | `60000` | generator 1회 timeout |
| `RS_ESCALATE_MESSAGE` | retry-safety | `"escalated: {N}회 실패, 수동 개입 필요"` | 책 p140 문구 보존. `{N}` 치환 토큰 |

---

## 자가 검증 결과 (모든 스킬 2/2 PASS)

| 스킬 | 샘플 | 결과 |
|------|------|------|
| **with-without** | `samples/{discriminating,non-discriminating}/` | 2/2 (bash + python stdlib). HAS_POWER / NO_POWER Verdict 결정론 |
| **retry-safety** | `samples/{success,escalation}/` | 2/2 (bash + python stdlib). success(2회차 PASS) / escalated(3회 FAIL) 결정론 |

재검증:

```bash
# with-without
bash .claude/skills/with-without/bin/run.sh   <fixture>
bash .claude/skills/with-without/bin/grade.sh <fixture>/result

# retry-safety
bash .claude/skills/retry-safety/bin/run.sh   <fixture>
```

각 리포트 끝의 `[self-check] PASS` 라인으로 확인.

---

## 의존성

- `bash` 4+
- `python` 3+ (bin 스크립트의 집계 로직)
- `grep`, `find`, `date`, `awk`, `du` (POSIX)
- `timeout` (coreutils, 선택) — 없으면 timeout 캡 미적용
- Windows: Git for Windows 또는 WSL 권장. Windows App Alias로 `python3` 가 Microsoft Store로 리다이렉션되므로 bin 스크립트는 `python3 || python` fallback 포함.

---

## 업그레이드

```bash
cd ~/measure-src
git pull
bash scripts/install.sh
```

---

## 플러그인 확장 규약 (기여자용)

다른 "런타임 측정" 스킬을 이 번들에 추가하려면:

1. `.claude/skills/<new-skill>/SKILL.md` 폴더로 신규 스킬 추가 (라우터 패턴).
2. 전용 에이전트 1~2개를 `.claude/agents/<new-agent>.md` 로 추가.
3. 실제 측정 로직은 `bin/*.sh` + python stdlib 로 자체 포함.
4. `samples/` 는 결정론적 fixture 로 자가검증 2건 이상 (expected 키 필수).
5. `install.sh` 는 glob 기반이라 수정 불필요.
6. README "현재 포함된 스킬" 목록 + 자가 검증 표만 갱신.
7. docs/USAGE-SCENARIO.md 에 새 스킬 시나리오 1건 추가.

**새 스킬이 condition 의 "초 단위 정적 점검" 성격이면 `measure` 가 아니라 `condition` 에 추가할 것.**

---

## 더 자세한 사용 흐름

실제 커맨드와 예상 출력이 포함된 시나리오는 [`docs/USAGE-SCENARIO.md`](./docs/USAGE-SCENARIO.md) 참조.

각 스킬의 상세 원칙·공식·제한은 각 스킬 폴더의 `docs/principles.md` 에 분산되어 있다:

```
.claude/skills/<skill>/docs/principles.md
```

---

## 라이선스

[MIT](./LICENSE)
