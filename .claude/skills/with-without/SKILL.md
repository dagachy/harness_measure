---
name: with-without
description: 동일 프롬프트/작업을 두 환경(With/Without)에서 동시 실행하고 pass_rate·duration_ms·total_tokens 3축으로 비교하는 런타임 측정 진입점. 단일 fixture 또는 fixtures 디렉토리를 with-without-runner + with-without-grader 에이전트로 실행·채점하고 comparison.md 를 반환한다. 사용자가 "with/without 비교", "A/B 실험", "스킬 효과 측정", "with without compare" 등을 요청할 때 사용.
---

# with-without

With/Without 런타임 비교 라우터.
단일 fixture / 다중 fixture 두 가지를 지원한다.

---

## 입력 fixture 규약

하나의 fixture 디렉토리는 다음 레이아웃이어야 한다:

```
<fixture>/
├── fixture.json          # {"name","timeout_ms","expected": {...}}  (expected는 self-check용, 운영에선 생략 가능)
├── with/run.sh           # "with" 환경 실행기. 인자 1개: out_dir
├── without/run.sh        # "without" 환경 실행기. 인자 1개: out_dir
└── assertions/*.sh       # 각 파일 = 단언 1건. CWD는 out_dir. exit 0 = PASS.
```

각 `run.sh` 는 자유롭게 산출물을 `out_dir/` 밑에 쓰면 된다 (`output.txt` 가 관례).
각 `assertions/*.sh` 는 **두 환경 모두에 동일하게** 적용된다 (F4: 변별력 판정의 전제).

---

## 모드 결정

- 사용자가 fixture 디렉토리 1개를 주면 **단일 모드**.
- 디렉토리 상위를 주면서 "전체" 또는 "batch" 를 요청하면 **배치 모드** (하위의 각 `fixture.json` 보유 디렉토리를 독립 fixture로 간주).

---

## 단일 모드

입력: fixture 디렉토리 절대 경로 1개.

1. `with-without-runner` 에이전트를 1회 호출. 프롬프트에 `FIXTURE=<absolute path>` 전달.
2. runner 가 생성한 `result/` 가 완성되면 `with-without-grader` 에이전트를 1회 호출. 프롬프트에 `RESULT=<fixture>/result` 전달.
3. grader 리포트(`comparison.md` + 변별력 라벨)를 그대로 노출.
4. 변별력 있는 단언이 0건이면 "실험 변별력 없음" 경고를 상단 1~2줄에 재강조.

---

## 배치 모드

입력: 상위 디렉토리 (`samples/`, `fixtures/` 등).

1. 하위에서 `fixture.json` 을 가진 디렉토리를 전수 수집.
2. 각 fixture 마다 runner → grader 를 **직렬 호출** (각 fixture 내부는 with/without 동시 실행이지만, fixture 간에는 리소스 경합/오염을 피하기 위해 직렬).
3. 결과 집계 표:

```
| Fixture | pass_rate (W/WO) | duration_ms (W/WO) | total_tokens (W/WO) | discriminating | Verdict |
|---------|------------------|---------------------|---------------------|----------------|---------|
```

4. 표 끝에 "변별력 있는 fixture N/M" 요약 1줄.

---

## 임계값 override

호출자는 아래 환경변수로 조정 가능.

- `WW_TIMEOUT_MS` (기본 `60000`): 각 환경 실행의 최대 허용 시간. 초과 시 duration_ms 는 timeout 값으로 캡 + 해당 환경을 FAIL 처리.
- `WW_TOKENS_MODE` (기본 `estimated`): `estimated` | `measured`. measured 는 각 `run.sh` 가 `metrics.json` 에 `total_tokens` 를 직접 쓸 때만 사용. 기본은 산출물 바이트 수 기반 추정 (F5 메모 참조).
- `WW_PARALLEL` (기본 `1`): `0` 지정 시 with/without 를 **순차** 실행 (F1 위반 — 디버깅용 전용, 운영 금지).

---

## 자가 검증

플러그인에 내장된 샘플 fixture 2건:

```
<플러그인 루트>/.claude/skills/with-without/samples/
├── discriminating/      # with PASS 전건 / without 일부 FAIL → 변별력 있음
└── non-discriminating/  # 두 환경 모두 PASS → 변별력 없음, 경고 라벨
```

각 fixture 의 `fixture.json` 에 `expected.pass_rate_with` / `expected.pass_rate_without` / `expected.discriminating_count` 가 들어 있다. runner → grader 결과가 expected 와 일치하면 PASS.

---

## 범용 적용 메모

이 스킬은 "measure" 플러그인의 런타임 측정 1차 도구다. 실행 모델이 **분~시간 단위**라 condition 플러그인(초 단위 pre-flight)과 UX가 다르다.

- 각 환경에 **같은 프롬프트 / 다른 스킬 구성** 을 넣어야 공정 (F2).
- 각 환경의 출력 경로는 반드시 격리 (`result/with/`, `result/without/`) — 같은 디렉토리 공유 시 F1 오염.
- 단언이 전부 "출력 존재" 수준이면 변별력 없음 — Why-first 단언을 1건 이상 포함할 것 (F3/F4).
