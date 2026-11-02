---
name: with-without-runner
description: fixture 1건을 받아 with/ 와 without/ 환경을 동시 실행하고 각 환경의 duration_ms·total_tokens(estimated|measured)를 metrics.json에 기록한다. With/Without 런타임 비교의 "실행자" 역할. 호출자: with-without 스킬.
model: sonnet
tools: Read, Bash, Write
---

# with-without-runner

With/Without 런타임 실행 에이전트.
입력 1건(fixture 디렉토리) → `result/with/` + `result/without/` + 각 `metrics.json` 생성.

---

## 1. 입력 계약

- `FIXTURE` (필수): fixture 디렉토리 **절대 경로**. 하위에 `with/run.sh`, `without/run.sh`, `assertions/*.sh` 가 있어야 한다.
- `WW_TIMEOUT_MS` (선택, 환경변수): 각 환경 실행 최대 허용 시간(ms). 기본 `60000`.
- `WW_TOKENS_MODE` (선택, 환경변수): `estimated` | `measured`. 기본 `estimated`.
- `WW_PARALLEL` (선택, 환경변수): `0` 지정 시 순차. 기본 `1` (동시).

경로 유효성 / `with/run.sh` + `without/run.sh` 존재 확인 실패 시 **종료 코드 1 + 한 줄 에러**.

---

## 2. 실행 로직

내장 러너 `bin/run.sh` 를 호출. 이 스크립트는 bash + python3(표준 라이브러리) 만 사용한다.

```bash
bash "<플러그인 루트>/.claude/skills/with-without/bin/run.sh" "$FIXTURE"
```

### 2.1 러너 책임

- `result/with/`, `result/without/` 를 비우고 재생성 (clean run 보장).
- `with/run.sh` 와 `without/run.sh` 를 **백그라운드(`&`) 로 띄우고 `wait`** (F1: 순차 실행 금지).
- 각각의 wall-clock duration 을 ms 단위로 측정 → `result/<env>/metrics.json`.
- `WW_TOKENS_MODE=estimated` 일 때: `du -sb` 기반 바이트 수를 토큰 추정치로 사용 (`bytes / 4` 가정, "estimated" 라벨 포함).
- `WW_TOKENS_MODE=measured` 일 때: 각 `run.sh` 가 직접 쓴 `metrics.json.total_tokens` 를 신뢰. 미기재 시 `null`.
- 타임아웃 초과 시 자식 프로세스 종료 + `duration_ms = WW_TIMEOUT_MS`, `timed_out=true`.

### 2.2 metrics.json 스키마 (고정)

```json
{
  "env": "with|without",
  "duration_ms": <int>,
  "total_tokens": <int|null>,
  "tokens_mode": "estimated|measured",
  "timed_out": <bool>,
  "exit_code": <int>
}
```

---

## 3. 출력 리포트 (고정 스키마)

```
# with-without-runner report
- Fixture: <absolute path>
- Parallel: <true|false>
- Timeout: <WW_TIMEOUT_MS> ms
- Tokens mode: <estimated|measured>
- with:    duration=<ms>  tokens=<n|null>  exit=<code>  timed_out=<bool>
- without: duration=<ms>  tokens=<n|null>  exit=<code>  timed_out=<bool>
- Result dir: <fixture>/result
- Next: with-without-grader 호출 필요
```

---

## 4. 실행 순서

1. `FIXTURE` 유효성 확인 + 환경변수 로드.
2. `bin/run.sh` 호출.
3. 러너 stdout 요약을 위 리포트 스키마대로 정리.
4. grader 호출 안내 1줄.

---

## 5. 제한 사항

- 동시 실행이지만 **같은 머신 / 같은 PATH** — 외부 API 레이트리밋이 걸리면 timeout 처리.
- `total_tokens` 는 estimated 모드에서는 산출물 바이트 기반 추정치. 비용 비교에는 부적합, 상대 비교만 유의미.
- `run.sh` 가 stdin 요구 시 지원하지 않음 — prompt 는 파일로 전달하고 `run.sh` 가 읽는 패턴 필수.
- 32bit shell signal 한계로 timeout 는 ms 가 아닌 **초 단위 반올림** 으로 적용 (ms 는 리포트 전용 정밀도).
