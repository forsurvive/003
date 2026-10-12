# 서울 폴아웃 아트 작업 폴더

그래픽은 모두 Claude가 만든다. 규격 정본은 [SD-16 아트 디렉션](../docs/seoul-fallout/16_art-direction.md)이다.

| 폴더 | 내용 |
|---|---|
| `tools/` | 팔레트 모듈(`palette.py`), 텍스트 격자 렌더러·검사기(`grid.py`), 미리보기(`preview.py`), 타일·소품 생성기(`tiles_r01.py`, `props_r01.py`), 장면 합성(`scene_bongcheon.py`), 주인공 파츠 리그·걷기·달리기(`rig_pc.py`), 이동 시연(`locomotion_demo.py`), 모바일 HUD(`hud_mobile.py`), 핍-보이 화면(`pipboy.py`), 대표 그림(`keyart.py`), 볼트 S-07 실내(`tiles_s07.py`, `scene_s07.py`), 팔레트 시트(`make_palette_sheet.py`) |
| `src/` | 원화 소스. 스프라이트는 팔레트 인덱스 텍스트 격자(SD-16 §13.2) |
| `samples/` | 기준 샘플 출력(원본 크기 + 확대 미리보기) |
| `fonts/` | 갈무리(Galmuri) 도트 한글 글꼴, SIL OFL 1.1 (`OFL-Galmuri.md`) |

## 다시 만들기
```
python3 tools/make_palette_sheet.py
python3 tools/tiles_r01.py
python3 tools/scene_bongcheon.py
python3 tools/preview.py src/sprites/pc_s07_jumpsuit_S.txt samples/04_pc_s07_idle_x8.png 8 P19
python3 tools/rig_pc.py
python3 tools/locomotion_demo.py
python3 tools/hud_mobile.py
python3 tools/pipboy.py
python3 tools/keyart.py
python3 tools/tiles_s07.py
python3 tools/scene_s07.py
python3 tools/outfit_samples.py
python3 tools/head_samples.py
```

## 기준 샘플 진행 (SD-16 §12.3)
| # | 샘플 | 상태 |
|---|---|---|
| 1 | 팔레트 시트 | 1차 완료 |
| 2 | 볼트 S-07 실내 | 1차: 바닥 12·벽 9·문 2·벽걸이 7(성적 순위 게시판 앵커, 표어 CRT, 칠판, 배급과 창구)·바닥 소품 12·톱니 방폭문 192×192 8프레임(`10_*`), 아트리움 + 적성 평가 교실 장면(`11_*`) |
| 3 | 관악·봉천 외부 타일·소품 | 1차(타일 17종, 빌라·전신주·고무 대야 화분·간판·포스터) |
| 4·5 | 주인공 몸 + S-07 점프슈트 | 대기 5방향 원화 + 반전 = 8방향. 걷기·달리기 6프레임 × 8방향 2차: 디딤발 고정 IK(측면·대각선, 검사 0px, `04_pc_footlock.txt`), 실제 속도 이동 시연(`04_pc_locomotion_demo.gif`) |
| 5 | 몸통 4계열 | 1차: T01·T02(어깨 패드 +1px, 가슴 보호대, 무릎)·T03(스카프, 후드, 야전 코트 밑단)·T06(어깨 +2px, 판갑, 파우치, 장갑) + T06 PF-12 세력 교체. 리그가 장비 램프를 받아 걷기·달리기 8방향, 디딤발 검사 60구간 0px(`12_*`) |
| 6 | 머리 3슬롯 | 1차: 머리 4종(짧은 머리·단발·똥머리·짧게 민 머리) × 머리색 교체, 경비 헬멧, 야구모자, 안경. 모자 아래 상태(똥머리 숨김, 단발 끝 노출), N·NE 안경 숨김. 8조합 달리기 디딤발 96구간 0px(`13_*`) |
| 8 | 크리처 | 변이 바퀴벌레 측면 1차 |
| 11 | UI | PC HUD 1차(장면 합성 안). 모바일 터치 HUD 640·800폭 1차(`06_*`). 핍-보이 능력치·서술형 세력 탭 1차(`07_*`) |
| 13 | 픽처 | 대표 그림 '관악산 비탈에서 처음 내려다본 서울' 640×360 1차(`09_*`) |
| 합성 | 봉천 계단마을 장면 640×360 | 1차 |
