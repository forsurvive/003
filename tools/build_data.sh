#!/usr/bin/env bash
# 데이터 파이프라인 한 줄 실행 (SD-19 §6.12): 기획서 표 → game/data, 대사 원고 → game/data/dialogue, 맵 원고 → game/data/maps,
# 식 대조 사례, 심리스 월드 청크(1-1).
# 오류가 하나라도 있으면 종료 코드 1(빌드 중단). 그림 가져오기(art_import)는 그림이 바뀔 때만 따로 돌린다.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/pipeline/places_extract.py                # 장소 425(1-2): SD-09a~f 개요 표 → places.json(이야기 추출이 쓴다)
python3 tools/pipeline/encounter_extract.py             # 인카운터(1-3): SD-08 §14.3 위협도 격자 · SD-05 §6.5 EP → encounters.json
python3 tools/pipeline/extract.py
python3 tools/pipeline/unique_weapons.py               # 고유 무기(1-12a, D-027): SD-13 §3.9 → 기반 무기 사본 + 바뀐 값
python3 tools/pipeline/encounter_table.py             # 인카운터 표(1-E, SD-22): RE 행·범주 가중 → encounters.json(적 자료 뒤에)
python3 tools/pipeline/extract_story.py
python3 tools/pipeline/extract_docs.py
python3 tools/pipeline/script_variants.py               # 원고 변형판(1-12f — FQ-SB-02 대리 반장 판)
python3 tools/pipeline/script_compile.py
python3 tools/pipeline/note_compile.py                  # 종이 기록물(1-5): script/notes → notes.json
python3 tools/pipeline/term_compile.py                  # 단말(1-4): script/terms → terminals.json
python3 tools/pipeline/hack_words.py                    # 해킹 단어 풀(1-4)
python3 tools/pipeline/prop_export.py
python3 tools/pipeline/ui_export.py
python3 tools/pipeline/fx_export.py
python3 tools/pipeline/token_export.py                   # 세력 계급 증표(1-8b, SD-13 §7.4.2 · M-136 정착지 차분)
python3 tools/pipeline/craft_export.py                   # 제작(1-8c, SD-13 §3.10 · §7.9): 제작 무기 · 설계도 · 폭발물 · 조리 · 레시피
python3 tools/pipeline/loot_export.py
python3 tools/pipeline/merchant_export.py
python3 tools/pipeline/map_compile.py
python3 tools/pipeline/dungeon_compile.py                 # 던전 표(1-D0): script/world/dungeons.txt → dungeons.json(맵 뒤에)
python3 tools/pipeline/rumor_compile.py                  # 소문(1-4f): script/world/rumors.txt → rumors.json
python3 tools/pipeline/turf_export.py                    # 판도(1-12m): SD-08 §15.2 격자 · 거점 · turf.txt · factions.txt → turf.json(시작 상태 검사)
python3 tools/pipeline/struct_bake.py
python3 tools/pipeline/world_extract.py                 # 월드(1-1): SD-08 표 → source.json
python3 tools/pipeline/rad_zones.py                    # 방사능 구역(1-9d): source.json → rad.json(굽기가 고리 안에 웅덩이·드럼·표지판)
python3 tools/pipeline/world_chunks.py                  # 월드 굽기 → world.bin(손 맵·타일셋 뒤에)
python3 tools/pipeline/convoy_route.py                  # FQ-SB-02 운송 행렬 경로 굽기(1-12f — 구운 월드 뒤에)
python3 tools/pipeline/expr_cases.py
python3 tools/pipeline/ko_lint.py                      # 번역투 후보(SD-24 · 사용자 지시 2026-10-23): 판정은 다듬이 — 새 후보는 고치거나 허용 목록에 이유
python3 tools/pipeline/portrait_export.py
python3 tools/pipeline/story_sprites.py
python3 tools/pipeline/quest_cross.py                   # 퀘스트 교차 정합 표(1-X, SD-20 §10) — 새 경고는 단위 시험이 막는다
