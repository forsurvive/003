#!/usr/bin/env bash
# 데이터 파이프라인 한 줄 실행 (SD-19 §6.12): 기획서 표 → game/data, 대사 원고 → game/data/dialogue, 맵 원고 → game/data/maps,
# 식 대조 사례, 심리스 월드 청크(1-1).
# 오류가 하나라도 있으면 종료 코드 1(빌드 중단). 그림 가져오기(art_import)는 그림이 바뀔 때만 따로 돌린다.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/pipeline/places_extract.py                # 장소 425(1-2): SD-09a~f 개요 표 → places.json(이야기 추출이 쓴다)
python3 tools/pipeline/encounter_extract.py             # 인카운터(1-3): SD-08 §14.3 위협도 격자 · SD-05 §6.5 EP → encounters.json
python3 tools/pipeline/extract.py
python3 tools/pipeline/extract_story.py
python3 tools/pipeline/extract_docs.py
python3 tools/pipeline/script_compile.py
python3 tools/pipeline/term_compile.py                  # 단말(1-4): script/terms → terminals.json
python3 tools/pipeline/hack_words.py                    # 해킹 단어 풀(1-4)
python3 tools/pipeline/prop_export.py
python3 tools/pipeline/ui_export.py
python3 tools/pipeline/fx_export.py
python3 tools/pipeline/loot_export.py
python3 tools/pipeline/merchant_export.py
python3 tools/pipeline/map_compile.py
python3 tools/pipeline/struct_bake.py
python3 tools/pipeline/world_extract.py                 # 월드(1-1): SD-08 표 → source.json
python3 tools/pipeline/world_chunks.py                  # 월드 굽기 → world.bin(손 맵·타일셋 뒤에)
python3 tools/pipeline/expr_cases.py
python3 tools/pipeline/portrait_export.py
python3 tools/pipeline/story_sprites.py
