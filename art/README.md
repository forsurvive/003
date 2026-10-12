# 서울 폴아웃 아트 작업 폴더

그래픽은 모두 Claude가 만든다. 규격 정본은 [SD-16 아트 디렉션](../docs/seoul-fallout/16_art-direction.md)이다.

| 폴더 | 내용 |
|---|---|
| `tools/` | 팔레트 모듈(`palette.py`), 텍스트 격자 렌더러·검사기(`grid.py`), 미리보기(`preview.py`), 타일·소품 생성기(`tiles_r01.py`, `props_r01.py`), 장면 합성(`scene_bongcheon.py`), 팔레트 시트(`make_palette_sheet.py`) |
| `src/` | 원화 소스. 스프라이트는 팔레트 인덱스 텍스트 격자(SD-16 §13.2) |
| `samples/` | 기준 샘플 출력(원본 크기 + 확대 미리보기) |
| `fonts/` | 갈무리(Galmuri) 도트 한글 글꼴, SIL OFL 1.1 (`OFL-Galmuri.md`) |

## 다시 만들기
```
python3 tools/make_palette_sheet.py
python3 tools/tiles_r01.py
python3 tools/scene_bongcheon.py
python3 tools/preview.py src/sprites/pc_s07_jumpsuit_S.txt samples/04_pc_s07_idle_x8.png 8 P19
```

## 기준 샘플 진행 (SD-16 §12.3)
| # | 샘플 | 상태 |
|---|---|---|
| 1 | 팔레트 시트 | 1차 완료 |
| 3 | 관악·봉천 외부 타일·소품 | 1차(타일 17종, 빌라·전신주·고무 대야 화분·간판·포스터) |
| 4·5 | 주인공 몸 + S-07 점프슈트 | 대기 3방향(S·E·N) 1차. 걷기·나머지 방향·모션은 다음 |
| 8 | 크리처 | 변이 바퀴벌레 측면 1차 |
| 11 | UI | PC HUD 1차(장면 합성 안) |
| 합성 | 봉천 계단마을 장면 640×360 | 1차 |
