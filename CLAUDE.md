# Seoul Fallout — 작업 지침 (세션마다 먼저 읽는다)

Fallout 3를 2277년 서울로 옮긴 한국어 비상업 팬게임.
- 기획서 세트: `docs/seoul-fallout/` (SD-00~SD-20, 조사 SR-01~05).
- 정밀 요약: `docs/seoul-fallout/_digest/` — 문서마다 규칙·수치·ID·결정·절 줄 번호를 담았다. 색인은 `_digest/00_INDEX.md`.
- 게임: `game/` (Godot 4.7.2). 단계 계획·진행 기록: `game/STAGE_0.md`(완료) · `game/STAGE_1.md`(진행 중).
- 그림: `art/`. 자료 빌드: `bash tools/build_data.sh`.

## 사용자 고정 지침 (어기지 말 것)
- 모든 응답과 작업 과정은 **한국어**로 쓴다.
- 예전에 사용자가 진행했던 다른 프로젝트는 참조하지 않는다.
- 그래픽은 Claude가 직접, 타협 없는 품질로 만든다. PC와 모바일을 모두 지원한다.
- 라디오 노래 없음 · 크리처 콘셉트 아트 없음 · 동료 시스템 없음.
- 캐릭터 미끄러짐·벽 비비기 절대 금지(발 고정 걸음, 막히면 선다).
- 컷신은 인게임 연출(RPG 메이커식). 캐릭터는 아이작풍 2등신, 타일은 RPG 메이커풍.
- 볼트 출구는 정문 방폭문 하나뿐이다. 프롤로그 볼트(평시)에서는 일반 볼트원을 죽일 수 없다.
- 바이옴은 점진적으로 바뀐다 — 자연 지형 사이에 경계선 금지(SD-08 §6 · SD-16 §6.10 구현 정합 1-7).

## 기획서 리마인드 지침 (사용자 지시 — 꼭 지킬 것)
대화가 길어지면 앞부분이 압축되어 기획서 세부를 잊는다. 잊을 것 같으면 **스스로 판단해서 주기적으로 기획서 내용을 다시 읽는다**.
- 새 단계·새 기능을 시작할 때: 관련 `_digest/` 요약을 먼저 읽고, 구현할 규칙은 원문 해당 절(요약의 줄 번호)을 직접 열어 확인한다.
- 대화가 압축된 직후(요약으로 이어받았을 때): `_digest/00_INDEX.md`와 지금 작업에 걸린 요약을 다시 읽는다.
- 긴 작업 중에도 수치·ID·이름·규칙을 기억에 기대어 쓰지 않는다 — 확신이 없으면 원문을 연다.
- 기획서와 구현이 어긋나면 '구현 정합' 블록(해당 SD 절)과 `game/STAGE_0.md`에 적는다.
- 기획서가 바뀌면 해당 `_digest/` 요약도 함께 고친다.

## 서사 정합 지침 (사용자 지시 — 매번 살필 것)
플레이어의 동선·예상 밖 행동·여러 퀘스트 동시 진행·저장/불러오기·생포·시간 도약 때문에 이야기가 모순되거나 시간선·인과가 꼬이면 안 된다.
- 기준 문서: **SD-20 `docs/seoul-fallout/20_narrative-consistency.md`** (요약 `_digest/20_narrative-consistency.md`).
- 퀘스트·장면·원고·진행기·강제 사건을 새로 만들거나 고칠 때마다 SD-20을 다시 읽고 **§7 점검표 10항목**을 통과시킨다. 결과는 그 SD 절 '구현 정합'과 STAGE 기록에 남긴다.
- 핵심: 사실은 변수 한 곳(P1) · 지식 장면은 '이미 앎' 판(P2) · 인물은 한 곳(P3) · 큰 사건은 서사 독점 + 안전한 순간까지 미룸(P4·P5) · 시간 도약은 날마다(P6) · 소문엔 출처(P7) · 끊겨도 반쯤 된 상태 없음(P10).
- 새로 찾은 모순 유형·사례는 SD-20 §2·§6에 더한다.

## 작업 습관
- 브랜치 `claude/clever-mayer-yddxqv`. PR은 요청이 있을 때만. 커밋 전 `__pycache__` 삭제. 커밋 메시지에 모델 ID를 넣지 않는다.
- 시험: `cd game && timeout 900 godot --headless -s res://tests/run_tests.gd` (`TEST_ONLY=부분이름`).
- 봇: `godot --headless --path game res://scenes/story/prologue.tscn -- --auto --from=p2|p3|p4|p4e|view|gate|box --log`.
- 월드(1-1): 굽기 `python3 tools/pipeline/world_chunks.py`(build_data에 포함, 그림 바꾸면 `art_import.py` 먼저) · 견본 `world_chunks.py --sample X Y W H 출력.png` · 1막까지 `--from=view --chain` · 벤치 `scenes/bench/world_bench.tscn`.
