# 새 세션 이어받기 — 서울 폴아웃(SESSION_HANDOFF)

새 세션 첫 메시지: **"docs/seoul-fallout/_plans/SESSION_HANDOFF.md 읽고 따라 해"**.

이 파일은 늘 지금 상태에 맞아야 한다. 아래 셋이 바뀌면 같은 커밋에서 이 파일도 고친다(CLAUDE.md 작업 습관):
- 단계를 열거나 닫을 때
- 필수 문서 · 도구 · 명령 · 검수 절차가 바뀔 때
- 다음 작업 후보가 바뀔 때

---

서울 폴아웃(Fallout 3를 2277년 서울로 옮긴 한국어 팬게임) 개발을 이어서 한다. 브랜치는 `claude/clever-mayer-yddxqv`다.
작업에 들어가기 전에 아래 문서를 순서대로 읽고 숙지한다. 다 읽으면 **'숙지 보고'를 먼저 하고, 사용자 확인을 받은 뒤** 작업을 시작한다.

## 1단계 — 지침(반드시 전부)
- `CLAUDE.md`(저장소 맨 위): 사용자 고정 지침 · 기획서 리마인드 · 서사 정합 · 교차 정합 · 작업 습관
- `.claude/agents/`의 `korean-editor.md` · `balance-auditor.md` · `openworld-player.md`: 검수 에이전트 셋의 역할과 쓰는 때

## 2단계 — 기획서 색인과 검수 기준
- `docs/seoul-fallout/_digest/00_INDEX.md`: 기획서 SD-00~SD-22 색인. 요약마다 규칙 · 수치 · ID · 원문 줄 번호가 있다
- `docs/seoul-fallout/20_narrative-consistency.md`(SD-20 서사 정합): §2 · §6 · §7 점검표 · §10 교차 점검. 요약 `_digest/20_narrative-consistency.md`도 같이 읽는다
- `docs/seoul-fallout/23_fun-review.md`(SD-23 재미 검수 F1~F12)
- `docs/seoul-fallout/24_korean-style.md`(SD-24 번역투 기준)
- `docs/seoul-fallout/25_balance-audit.md`(SD-25 밸런스 B1~B13, 특히 §2 · §6 B4 받은 피해)
- 위 셋(SD-23 · 24 · 25)은 요약이 없으니 원문을 읽는다

## 3단계 — 지금 단계에 걸린 기획서 요약
- `_digest/`의 05(퀘스트 · 인카운터) · 06(세력 · 판도) · 14(크리처 · 적) · 19(개발 로드맵 · 완료 기준) · 22(월드 채우기 · 인카운터) · 15(경제) · 11(전투)
- 구현할 규칙은 요약의 줄 번호를 따라 원문 해당 절을 직접 연다

## 4단계 — 개발 기록과 장부
- `game/STAGE_1.md`: 1막 단계 기록. 특히 '1-13' 절들(1-13a~1-13i · D-380 · 1-13h · 1-13i)을 끝까지
- `game/DEFERRED.md`: 미뤄둔 과제 장부. '열림' 줄, 특히 D-380 · D-384 · D-394 · D-399~D-405
- `docs/seoul-fallout/_plans/1-13_closing_plan.md`(1막 완료 기준 ↔ 검사 표) · `_plans/1-13i_patrol_plan.md`
- `game/STAGE_0.md`는 구현 정합 기록이 필요할 때만 찾아본다

## 5단계 — 도구와 명령(CLAUDE.md '작업 습관')
- 자료 빌드: `bash tools/build_data.sh`
  - 원고 변환 · 교차 표 · 번역투 · 밸런스 · 배치 대조 · 분기 검증이 다 들어 있다
  - 새 그림 · 새 `class_name`을 넣은 뒤에는 `cd game && godot --headless --path . --import`를 먼저 돌린다(안 하면 시험이 시트 · 클래스를 못 읽는다)
- 시험
  - 전체: `cd game && timeout 1500 godot --headless -s res://tests/run_tests.gd`
  - 파일만: `TEST_FILES=이름조각` / 함수만: `TEST_ONLY=이름조각`
- 봇: `godot --headless res://scenes/bench/jm_bot.tscn -- <갈래>`(bw · rq · rqb · s8 · gs02 · sb_raid 등)
- 보스 벤치: `scenes/bench/boss_fight_check.tscn`(`BF_STAND` · `BF_PLV` · `BF_LOG`)
- 1막 완료 기준 묶음 실행기: `python3 tools/pipeline/act1_done.py`(초안 — 아직 돌려 보지 않았다)
- 적 그림: `python3 art/tools/pack.py` → `python3 tools/pipeline/art_import.py` → Godot 가져오기

## 숙지 보고 — 이렇게 정리해 먼저 보여 준다
1. 사용자 고정 지침 가운데 지금 작업에 걸리는 것
2. 1-13 단계에서 끝난 것과 남은 것(1막 완료 기준 표 ①~⑪ 기준)
3. DEFERRED 열린 과제 가운데 다음에 집을 후보 셋과, 각각 고르는 이유
4. 검수 절차(다듬이 · 밸런스 · 재미 · 교차 표 · SD-20 §7 · 예상 밖 행동 목록)를 어느 때 돌리는지

## 작업 방식 — 반응 속도를 위해(사용자 요청 2026-10-24)
- 작은 수정: 바뀐 파일의 시험(`TEST_FILES`)만 돌린다
- 전체 시험 · 회귀 봇 · 벤치: 단계를 닫는 커밋 때 한 번
- 재미 검수 · 밸런스 조율사: 새 체계나 새 요소를 넣을 때 계획 때와 구현 뒤에 한 번씩
- 다듬이: 게임 안 글을 새로 쓸 때마다(지침 그대로)
- 오래 걸리는 시험 · 봇은 백그라운드로 돌리고, 그동안 game/ 밖 일(원고 · 도구 · 문서)을 한다
- 모든 응답과 작업 과정은 한국어로 쓴다. 커밋 메시지에 모델 ID를 넣지 않는다. PR은 요청할 때만 만든다

## 지금 상태(이 절은 단계를 닫을 때마다 고친다)
- 마지막 갱신: 2026-10-24 — 1-13i 정기 순찰 둘(봉천 감시조 RE-X08 · 계약 경호단 RE-X09)을 닫음
- 마지막 전체 시험: 866 · 실패 0(1-13i 첫 구현 뒤)
  - 그 뒤 순찰 손질 커밋은 `test_patrol` 5개(확인 64)만 돌렸다 — 다음 단계를 닫을 때 전체 시험을 한 번 돌린다
- 1-13에서 끝난 것
  - a 배치 대조 · a2 빠진 인물 · 장소 · a3 깡철이 보스전
  - b 분기 자동 검증 · c 경제 곡선 v1 · d 추적대 빈도 시뮬
  - e 기본 RE 30종(지금 32) · f 밀집 성능 v1 · g A27
  - h 짐승 전투 손질(외눈 3국면 · B4 받은 피해) · i 정기 순찰 둘
- 다음 후보
  - 1막 완료 기준 ① · ② · ④를 `act1_done.py`로 실제로 돌려 보고 막히는 갈래 고치기
  - D-380 배수구 어미를 실전 맵(J-10)에서 벤치
  - D-399 경제 곡선 v2(보통 플레이어 봇) → D-384 Lv3 시점
  - D-404 새벽인력 낮 순찰 판 · D-405 순찰 표식 · 진돗개 · 판도 경계
  - D-402 떼 도약 토큰 · D-403 교전 중 맵 경계(확인 필요)
