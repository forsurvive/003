"""소장소(mini-site) 생성기(단계 1-W, SD-22 §5): 넓은 맵에 '들를 이유'를 깐다.

청크 결·지형 태그(chunk_tags)에 맞는 템플릿을 골라 소품 묶음 · 용기 1~3 · 사연(조사 글·쪽지) · 사람/크리처 자리(sites.json — 인카운터가
가까이 오면 그 RE를 세운다) 가운데 셋 이상을 갖춘 장면을 놓는다(§5.2 '상자 하나 덩그러니는 소장소가 아니다').
밀도(§5.1): 장소 청크 0~1 · 시가지 1~2 · 업무 1 · 황무지·강변 1~2(서로 25칸) · 산지 0~1. 소장소끼리 20칸, 장소 중심에서 18칸 이상.
사슬(§5.3): 사연 쪽지의 30%가 다른 곳을 가리킨다 — ① 아직 표시 안 된 가까운 장소를 지도에 표시(fx reveal_near) ② 15~40칸 떨어진
숨겨 둔 상자(방위·걸음 수를 글로 — 상자는 쪽지와 상관없이 늘 있다, SD-20 순서 무관).
"""
import json
import math
import os
import random

DIR8 = ["동", "남동", "남", "남서", "서", "북서", "북", "북동"]

# 템플릿: 무대 태그 · 결 · 가중 · 조각[(소품, dx, dy, {box, text})] · 사연 글 · 사람/크리처 자리
# box = (종류, 이름, 잠금 확률, 잠금 등급) · text = 조사 글(사연 풀에서 고르면 "@story")
T = {
    "jam": {"name": "사고 정체 줄", "tags": ["큰길"], "w": 6, "road": True,
            "parts": [("car_wreck", 0, 0, {"box": ("car", "차량 잔해 트렁크", 0.2, 25)}), ("car_wreck2", 4, 1, {}),
                      ("car_wreck", 8, 0, {"box": ("car", "차량 잔해 트렁크", 0.2, 25)}), ("bus_wreck", 12, -1, {"opt": 0.5}),
                      ("remains", 3, 3, {"box": ("corpse_scav", "운전자의 유해", 0, 0), "text": "@story"})],
            "story": ["운전석 유해의 무릎에 2077년 10월 23일자 출근 표. 경적을 누른 채 굳은 손.",
                      "트렁크마다 짐이 반쯤 꺼내져 있다. 다들 내려서 걸어갔다. 차를 가지러 온 사람은 아무도 없었다.",
                      "앞유리에 립스틱으로 쓴 글씨. '엄마 먼저 봉천 가. 나 따라갈게.'"]},
    "checkpoint": {"name": "버려진 검문소", "tags": ["큰길", "고가", "업무"], "w": 5,
                   "parts": [("jersey", 0, 0, {}), ("jersey", 3, 0, {}), ("sandbags", 6, 0, {}), ("sandbags", 7, 1, {}),
                             ("guard_booth", 1, -3, {"text": "@story"}), ("crate_army", 5, -3, {"box": ("ammo", "검문소 보급 상자", 0.35, 25)})],
                   "story": ["초소 근무 일지 마지막 줄. '22:40 하늘이 밝음. 교대 오지 않음. 계속 근무함.'",
                             "검문 명부. '통행 허가: 관리 후보 등록증 소지자에 한함.' 그 아래 손글씨로 '전부 통과시킴.'",
                             "초소 안 무전기. 다이얼이 비상 채널에 맞춰진 채 녹슬었다."],
                   "site": [("RE-002", "S2", 0.35), ("RE-061", "S1", 0.25)]},
    "under_camp": {"name": "고가 밑 노숙 야영", "tags": ["고가"], "w": 7,
                   "parts": [("tent", 0, 0, {}), ("drum_fire", 3, 1, {}), ("bedroll", 0, 2, {}), ("bedroll2", 5, 2, {}),
                             ("pallet_sacks", 5, 0, {"box": ("camp", "야영지 보급 자루", 0, 0)}), ("note_ground", 2, 3, {"text": "@story"})],
                   "story": ["불 꺼진 드럼통 옆 쪽지. '비 오면 기둥 3번 밑. 패거리 오면 기둥 7번 쪽으로 흩어질 것.'",
                             "깡통에 새긴 이름 다섯. 둘에는 줄이 그어져 있다.",
                             "골판지에 숯으로 그린 지도. 고가 기둥마다 '물'·'개'·'안 됨'."],
                   "site": [("RE-036", "S4", 0.3), ("RE-002", "S4", 0.3)]},
    "barricade": {"name": "골목 바리케이드 초소", "tags": ["구도심", "시장"], "w": 6,
                  "parts": [("scrap_pile", 0, 0, {}), ("sandbags", 3, 0, {}), ("jersey", 5, 0, {}), ("drum", 0, -2, {}),
                            ("crate_o", 3, -2, {"box": ("crate", "초소 나무 상자", 0.2, 25)}), ("warn_board", 7, -2, {"text": "@story"})],
                  "story": ["손글씨 경고판. '여기부터 우리 골목. 물 값 안 내면 못 지나감.'",
                            "경고판 뒤에 붙인 순번표. 밤 보초 이름 넷, 마지막 칸은 비었다.",
                            "판자에 못으로 박은 표. '패거리 출입 금지 — 들어오면 개 푼다.'"],
                  "site": [("RE-002", "S4", 0.4), ("RE-012", "S4", 0.3)]},
    "moving_pile": {"name": "피난 이삿짐 더미", "tags": ["구도심", "아파트", "언덕"], "w": 3,
                    "parts": [("sofa_home", 0, 0, {}), ("wardrobe", 3, 0, {"box": ("apartment", "옷장", 0, 0)}), ("dresser", 6, 0, {}),
                              ("crate_o", 1, 2, {"box": ("pantry", "이삿짐 상자", 0, 0)}), ("plant_pot", 4, 2, {}),
                              ("note_ground", 6, 2, {"text": "@story"})],
                    "story": ["이삿짐 상자에 매직으로 쓴 주소. '관악 S-07 볼트 배정 — 가구 반입 불가.' 그래서 여기 두고 갔다.",
                              "소파 쿠션 밑 가족사진. 뒷면에 '10/23 밤 9시, 볼트 앞에서 만나.'",
                              "장롱 문에 붙은 쪽지. '다시 올게. 문 잠가 두지 마.'"]},
    "clinic": {"name": "골목 임시 진료소", "tags": ["구도심", "시장"], "w": 5,
               "parts": [("cot", 0, 0, {}), ("cot", 2, 0, {}), ("iv_pole", 4, 0, {}), ("folding_chair", 5, 1, {}),
                         ("crate_o", 0, 3, {"box": ("pharmacy", "구급 약상자", 0.3, 25)}), ("info_board", 3, 3, {"text": "@story"})],
               "story": ["진료소 칠판. '방사능 — 요오드 없음. 화상 — 붕대 없음. 기도는 무료.'",
                         "환자 명단. 이름 옆 동그라미와 가위표. 마지막 줄은 이름이 지워졌다."],
               "site": [("RE-046", "S6", 0.15)]},
    "memorial": {"name": "골목 추모 자리", "tags": ["구도심", "언덕"], "w": 4,
                 "parts": [("gravestone", 0, 0, {"text": "@story"}), ("gravestone2", 2, 0, {}), ("plant_pot", 1, 2, {}),
                           ("bucket", 3, 2, {}), ("crate_o", 4, 0, {"box": ("trash", "제물 바구니", 0, 0)})],
                 "story": ["널판 비석. '박씨네 셋 — 물 먹고 감. 우물 조심.'", "돌에 새긴 이름 줄. 2077년 것은 하나도 없고, 다 그 뒤다.",
                           "비석 앞 깡통에 마른 꽃과 캡 셋. 누가 아직 다녀간다."]},
    # 바꿈 상자(1-L 계획 §4.2 · §9.2): 큰길 갈림목 · 시장 골목 · 구도심 — 하나 두고 하나 가져가는 판자 함. 더 가져가면 표시가 남는다(진행기)
    "swap": {"name": "바꿈 상자", "tags": ["큰길", "시장", "구도심"], "w": 3,
             "parts": [("swap_box_lt", 0, 0, {"box": ("swap", "바꿈 상자", 0, 0)}), ("folding_chair", 2, 0, {}),
                       ("note_ground", 1, 2, {"text": "@story"})],
             "story": ["상자 옆 판자에 분필. '하나 두고 하나. 더 가져가면 다음 사람이 빈 상자를 연다.'",
                       "상자 뚜껑 안쪽에 칼로 새긴 줄. 누가 무엇을 두고 갔는지 — '통조림 → 붕대', '라디오 → 신발 한 켤레'.",
                       "의자 다리에 묶인 쪽지. '여기 물건은 길 가는 사람 거다. 주인은 없다. 그러니 다들 주인이다.'"]},
    "laundry_yard": {"name": "빨랫줄 마당", "tags": ["언덕", "구도심"], "w": 4,
                     "parts": [("laundry_line", 0, 0, {}), ("laundry_rack", 3, 0, {}), ("water_jug", 0, 2, {}), ("wash_basin", 2, 2, {"text": "@story"}),
                               ("crate_o", 4, 2, {"box": ("apartment", "마당 창고 상자", 0.2, 25)})],
                     "story": ["빨랫줄에 아이 옷 셋, 어른 옷 하나. 옷핀마다 이름표.", "대야 바닥에 긁어 쓴 글. '빨래는 흐린 날. 맑은 날엔 재가 내린다.'"]},
    "stall_ruin": {"name": "무너진 노점 줄", "tags": ["시장"], "w": 6,
                   "parts": [("stall_food", 0, 0, {}), ("stall_parts", 3, 0, {"box": ("stall", "노점 창고 상자", 0, 0)}),
                             ("umbrella_pile", 6, 0, {}), ("rubble", 1, 2, {}), ("note_ground", 4, 2, {"text": "@story"})],
                   "story": ["좌판 장부. '10/23 떡볶이 41그릇 외상 7.' 외상은 끝내 받지 못했다.",
                             "천막 기둥에 매단 가격표. 쌀 한 되 3,200원. 그 밑에 누가 '캡 2'라고 덧썼다."]},
    "landing_camp": {"name": "계단참 야영", "tags": ["언덕"], "w": 6,
                     "parts": [("straw_mat", 0, 0, {}), ("bedroll", 1, 0, {}), ("drum_fire", 3, 0, {}), ("water_jug", 5, 0, {}),
                               ("garden_box", 0, -2, {}), ("crate_o", 4, -2, {"box": ("pantry", "식료품 상자", 0, 0)}),
                               ("note_ground", 2, 2, {"text": "@story"})],
                     "story": ["계단 난간에 매단 빨래집게 쪽지. '312계단 위는 물 있음. 아래는 없음.'",
                               "텃밭 상자 팻말. '상추 — 남의 것. 뜯지 마시오. 뜯었으면 물이라도.'"]},
    "water_house": {"name": "옥상 물탱크 집", "tags": ["언덕", "구도심"], "w": 4,
                    "parts": [("water_tank", 0, 0, {"text": "@story"}), ("garden_box", 3, 0, {}), ("laundry_line", 0, 2, {}),
                              ("crate_o", 3, 2, {"box": ("pantry", "물탱크 집 찬장 상자", 0.3, 25)})],
                    "story": ["물탱크 옆구리에 페인트로 쓴 글. '정수 안 됨. 끓여서.'",
                              "물탱크 밸브에 감은 자물쇠 줄과 이름표. '302호 몫.'"]},
    "well": {"name": "공동 우물", "tags": ["언덕", "황무지"], "w": 4,
             "parts": [("well", 0, 0, {"text": "@story"}), ("bucket", 2, 0, {}), ("bench_o", -1, 2, {}),
                       ("crate_o", 3, 2, {"box": ("pantry", "우물가 상자", 0, 0)})],
             "story": ["우물 돌에 새긴 줄. 해마다 한 줄. 2210년대부터 줄이 뜸해진다.",
                       "두레박 줄에 묶인 표. '하루 두 번. 먼저 온 사람 먼저.'"]},
    "yard": {"name": "하역장 컨테이너 더미", "tags": ["공단"], "w": 7,
             "parts": [("container", 0, 0, {"box": ("crate", "컨테이너 안 화물", 0.3, 50)}), ("container2", 4, 0, {}),
                       ("forklift", 8, 1, {}), ("drum", 1, 3, {}), ("tool_chest", 4, 3, {"box": ("toolbox", "공구함", 0, 0)}),
                       ("note_ground", 6, 3, {"text": "@story"})],
             "story": ["하역 지시서. '세진 물류 → 여의도 원자력 연구동. 10/24 06:00 도착 예정.' 화물은 도착하지 않았다.",
                       "컨테이너 문에 분필로 쓴 숫자 셈. 마지막 숫자는 112."]},
    "spill": {"name": "화학 드럼 누출", "tags": ["공단"], "w": 3,
              "parts": [("chem_leak", 0, 0, {}), ("drum", 2, 0, {}), ("drum", 2, 1, {}), ("chem_leak", -1, 2, {}),
                        ("tool_chest", 4, 1, {"box": ("toolbox", "방제 공구함", 0, 0)}), ("warn_board", 4, -1, {"text": "@story"})],
              "story": ["손글씨 경고판. '녹색 물 밟지 마. 신발 녹는다.'", "뒤집힌 드럼 옆 작업 장갑 한 짝. 손가락 끝이 녹아 있다."]},
    "playground": {"name": "놀이터 야영", "tags": ["아파트"], "w": 6,
                   "parts": [("slide", 0, 0, {}), ("bench_o", 3, 1, {}), ("drum_fire", 0, 3, {}), ("bedroll", 2, 3, {}),
                             ("backpack", 5, 3, {"box": ("bag", "버려진 배낭", 0, 0)}), ("note_ground", 4, -1, {"text": "@story"})],
                   "story": ["미끄럼틀 밑에 분필 그림. 집 네 채, 사람 다섯, 그중 하나는 크다.",
                             "놀이터 게시판. '단지 주민 외 출입 금지.' 단지 주민은 남지 않았다."]},
    "guardhouse": {"name": "경비실 기록", "tags": ["아파트"], "w": 4,
                   "parts": [("guard_booth", 0, 0, {"text": "@story"}), ("guard_chair", 2, 0, {}),
                             ("crate_o", 2, 2, {"box": ("cabinet", "경비실 서류함", 0.3, 25)})],
                   "story": ["경비 일지. '10/23 23:10 102동 지하 주차장 대피 인원 340. 문 닫음. 문 다시 안 열기로 함.'",
                             "택배 보관 대장. 찾아가지 않은 물건 1,412개."]},
    "lobby": {"name": "무너진 로비", "tags": ["업무"], "w": 6,
              "parts": [("rubble", 0, 0, {}), ("rubble2", 2, 1, {}), ("office_desk", 4, 0, {"text": "@story"}),
                        ("safe_big", 7, 0, {"box": ("safe", "로비 금고", 1.0, 50)}), ("wait_chairs", 1, 3, {}), ("rubble", 6, 3, {})],
              "story": ["안내 데스크 방문 기록. 마지막 방문객 이름 칸에 '정부 관계자(3)'.",
                        "명함 꽂이에 세진 전자 영업부 명함 한 줌. 뒷면마다 '연락 바람'."]},
    "greenhouse": {"name": "비닐하우스 폐허", "tags": ["황무지"], "w": 6,
                   "parts": [("greenhouse", 0, 0, {"text": "@story"}), ("garden_box", 4, 3, {}), ("water_jug", 0, 3, {}),
                             ("crate_o", 2, 3, {"box": ("pantry", "씨앗·식량 상자", 0, 0)})],
                   "story": ["비닐하우스 기둥의 영농 일지. '고추 3년째 됨. 땅은 아직 산다.'",
                             "씨앗 봉투 묶음. 봉투마다 해가 다르다. 가장 늦은 해는 2241."]},
    "junkyard": {"name": "고물상 야적장", "tags": ["황무지", "공단"], "w": 6,
                 "parts": [("scrap_pile", 0, 0, {"box": ("trash", "고물 더미", 0, 0)}), ("scrap_pile2", 3, 0, {}), ("car_wreck2", 6, 0, {}),
                           ("kennel", 0, 3, {}), ("crate_o", 4, 3, {"box": ("toolbox", "고물상 공구함", 0.2, 25)}), ("warn_board", 7, 3, {"text": "@story"})],
                 "story": ["고물상 간판. '고철 kg당 캡 1. 개 조심 — 진짜임.'", "개집 옆 밥그릇 셋. 하나만 깨끗하다."],
                 "site": [("RE-X01", "S3", 0.35)]},
    "heli": {"name": "추락 헬기 잔해", "tags": ["황무지", "산지"], "w": 2,
             "parts": [("heli_wreck", 0, 0, {"text": "@story"}), ("remains", 5, 2, {"box": ("corpse_scav", "조종사의 유해", 0, 0)}),
                       ("crate_army", 5, 0, {"box": ("us_ammo", "기내 탄약 상자", 0.3, 50)}), ("rubble", -1, 3, {})],
             "story": ["비행 일지. '10/23 22:51 관악 상공. 계기 전부 죽음. 강 쪽으로 미끄러져 내려간다.'",
                       "조종석 계기판에 붙은 사진. 아이 둘, 바다."]},
    "pit": {"name": "패인 구덩이", "tags": ["황무지"], "w": 3,
            "parts": [("rubble", 0, 0, {}), ("rubble2", 2, 0, {}), ("bone_pile", 1, 2, {"text": "@story"}),
                      ("backpack", 3, 2, {"box": ("bag", "떨어진 배낭", 0, 0)}), ("tree_dead", 5, 0, {})],
            "story": ["구덩이 바닥의 뼈 무더기. 모두 같은 방향을 보고 누웠다.", "구덩이 가장자리에 박힌 측량 말뚝. '2133 매립 예정지'."],
            "site": [("RE-001", "S3", 0.3)]},
    "kiosk": {"name": "한강공원 매점 폐허", "tags": ["강변"], "w": 5,
              "parts": [("kiosk_ruin", 0, 0, {"text": "@story"}), ("bench_o", 3, 1, {}), ("umbrella_pile", 0, 2, {}),
                        ("crate_o", 3, 3, {"box": ("conv", "매점 창고 상자", 0, 0)})],
              "story": ["매점 창구에 붙은 안내. '라면 물 셀프. 그릇 반납.'", "매점 냉장고에 붙은 자석 메모. '사장님 대피함 — 알바'."]},
    "fisher": {"name": "낚시꾼 야영", "tags": ["강변"], "w": 5,
               "parts": [("tent2", 0, 0, {}), ("fishing_gear", 3, 0, {}), ("drum_fire", 3, 2, {}), ("bedroll", 0, 2, {}),
                         ("crate_o", 5, 2, {"box": ("camp", "낚시꾼 짐", 0, 0)}), ("note_ground", 1, 4, {"text": "@story"})],
               "story": ["낚시 수첩. '참게 많음. 집게 두 개짜리만 먹을 것.'", "천막 기둥에 걸린 수건. 이름 대신 '셋째 주 일요일'."],
               "site": [("RE-004", "S3", 0.25)]},
    "boat": {"name": "떠밀려 온 보트", "tags": ["강변"], "w": 4,
             "parts": [("boat_wreck", 0, 0, {"box": ("crate", "보트 사물함", 0.6, 25), "text": "@story"}), ("rubble", 4, 2, {}),
                       ("fishing_gear", -1, 2, {})],
             "story": ["보트 옆구리 글씨 '한강 순찰 3호'. 순찰 일지는 물에 불어 한 줄만 읽힌다. '하류로'.",
                       "보트 바닥의 방수 지도. 한강 다리마다 X 표."]},
    "rest": {"name": "등산로 쉼터", "tags": ["산지"], "w": 5,
             "parts": [("bench_o", 0, 0, {}), ("info_board", 3, 0, {"text": "@story"}), ("backpack", 0, 2, {"box": ("bag", "쉼터에 두고 간 배낭", 0, 0)}),
                       ("stump", 4, 2, {})],
             "story": ["등산로 안내판. 누군가 매직으로 덧그린 길이 능선 너머로 이어진다.",
                       "안내판 '현재 위치' 화살표 옆에 칼로 새긴 글. '여기서 사흘 기다림. 아무도 안 옴.'"]},
    "ridge": {"name": "능선 캠프", "tags": ["산지"], "w": 4,
              "parts": [("tent", 0, 0, {}), ("drum_fire", 3, 0, {}), ("bedroll2", 0, 2, {}),
                        ("crate_army", 4, 2, {"box": ("ammo", "사냥꾼 탄약 상자", 0.2, 25)}), ("note_ground", 2, 3, {"text": "@story"})],
              "story": ["사냥 기록. '들개 셋. 멧돼지 하나 — 놓침. 곰 발자국.'", "모닥불 재 속 탄피 몇 개. 같은 총에서 나왔다."],
              "site": [("RE-001", "S4", 0.3)]},
    "waste_spill": {"name": "폐기물 유출 현장", "tags": ["공단", "강변", "황무지", "큰길"], "w": 3,   # 1-9d 방사능: 드럼 Z2 · 웅덩이 Z1 · 표지판
                    "parts": [("waste_drum", 0, 0, {}), ("waste_drum", 2, 1, {"opt": 0.7}), ("rad_puddle", 1, 2, {}),
                              ("rad_puddle2", 3, -1, {"opt": 0.6}), ("rad_sign", -3, 1, {"text": "@story"}),
                              ("crate_army", 5, 2, {"box": ("pharmacy", "방호 장비 함", 0.3, 25)}),
                              ("remains", 4, 4, {"box": ("corpse_scav", "작업복 차림의 유해", 0, 0), "opt": 0.6})],
                    "story": ["표지판 기둥에 묶인 운송장. '세진 원자력 — 저준위 폐기물 12통. 수신 관악 매립장.' 도착 칸은 비어 있다.",
                              "표지판 밑에 긁어 쓴 글씨. '선량계 바늘이 끝까지 감. 장갑 벗지 말 것. 물 마시지 말 것.'",
                              "표지판에 분필로 덧쓴 줄. '여기서 자고 간 놈들 다 머리 빠짐 — 봉천 사람이.'"]},
}

# 결·지형별 밀도(§5.1): (최소, 최대, 간격)
DENSITY = {"구도심": (1, 2, 20), "언덕": (1, 2, 20), "공단": (1, 2, 20), "아파트": (1, 2, 20), "시장": (1, 2, 20),
           "업무": (1, 1, 20), "황무지": (1, 2, 25), "강변": (1, 2, 25), "산지": (0, 1, 22)}
CHAIN_P = 0.3
STASH_TEXT = ["쪽지 끝에 덧쓴 줄. '남은 건 {d}쪽으로 {n}걸음, {m} 밑에 묻었다.'",
              "구겨진 약도. 이 자리에서 {d}쪽으로 {n}걸음에 X. 옆에 '{m}'.",
              "쪽지 뒷면. '못 가져가면 누구든 써라 — {d}쪽 {n}걸음, {m}.'"]
STASH_MARK = {"tarp_pile": "방수포", "rubble": "돌무더기", "rubble2": "돌무더기", "stump": "그루터기"}
REVEAL_TEXT = " 지도 조각이 끼워져 있다 — 근처 한 곳에 동그라미."


def place(api):
    """api: put(name,x,y)·free(x,y)·cells(cx,cy,rng)·boxes·texts·cnt·places·chunks(태그)·play_chunks·W·H·CS·kind
    돌려줌: {"sites": [...사람/크리처 자리], "n": 개수, "by_tpl": {템플릿: 수}}"""
    put, free, cells = api["put"], api["free"], api["cells"]
    boxes, texts, cnt = api["boxes"], api["texts"], api["cnt"]
    CS, W, H = api["CS"], api["W"], api["H"]
    kind = api["kind"]
    centers = [(p["tx"], p["ty"]) for p in api["places"].values()]
    center_chunks = {(int(x) // CS, int(y) // CS) for (x, y) in centers}
    chunks = api["chunks"]
    placed_sites = []                                                      # (x, y, 간격)
    sites = []
    by_tpl = {}
    stash_n = 0
    first = {}

    # 정해진 행렬 길(FQ-SB-02 운송 — convoy_sb02.json, 지난 굽기의 경로) 둘레 5칸은 비운다: 소장소가 길을 막으면 행렬이 선다(1-12l — 고가 북 램프 끝에 비석 둘이 놓여 굽기가 멈춤)
    lane = set()
    cpath = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "game", "data", "world", "convoy_sb02.json")
    if os.path.exists(cpath):
        cj = json.load(open(cpath, encoding="utf-8"))
        for seq in (cj.get("route", []), cj.get("detour", [])):
            for a, b in zip(seq, seq[1:]):
                n = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
                for k in range(n + 1):
                    px, py = round(a[0] + (b[0] - a[0]) * k / n), round(a[1] + (b[1] - a[1]) * k / n)
                    for dy in range(-5, 6):
                        for dx in range(-5, 6):
                            lane.add((px + dx, py + dy))

    def far_enough(x, y, gap):
        if (x, y) in lane:
            return False
        for (sx, sy, sg) in placed_sites:
            if (sx - x) ** 2 + (sy - y) ** 2 < max(gap, sg) ** 2:
                return False
        for (px, py) in centers:
            if (px - x) ** 2 + (py - y) ** 2 < 18 ** 2:
                return False
        return True

    def build(tid, x0, y0, rng):
        tpl = T[tid]
        got = {"props": 0, "box": 0, "story": 0}
        story_at = None
        for pi, (name, dx, dy, opt) in enumerate(tpl["parts"]):
            if "opt" in opt and rng.random() >= opt["opt"]:
                continue
            ok = None
            jit = ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1), (1, 1))
            if pi == 0:                                                       # 중심 소품(헬기 · 보트 · 비닐하우스 …)은 더 넓게 찾고, 그래도 안 들어가면 자리 자체를 버린다
                jit = jit + ((-1, -1), (2, 0), (0, 2), (-2, 0), (0, -2), (2, 1), (1, 2), (-2, 1), (-1, 2))
            for (jx, jy) in jit:
                x, y = x0 + dx + jx, y0 + dy + jy
                if 0 <= x < W and 0 <= y < H and put(name, x, y):
                    ok = (x, y)
                    break
            if ok is None:
                if pi == 0:                                                   # 유해 · 상자만 남고 헬기가 없는 자리를 만들지 않는다(사용자 지적 2026-10-22 헬기 견본에서 발견)
                    return None
                continue
            got["props"] += 1
            if "box" in opt:
                k, nm, lp, lv = opt["box"]
                fw, fh = api["foot"](name)
                boxes.append({"x": ok[0], "y": ok[1], "w": max(1, fw), "h": max(1, fh), "kind": k, "name": nm, "owner": "",
                              "lock": lv if rng.random() < lp else 0})
                got["box"] += 1
            if opt.get("text") == "@story" and story_at is None:
                story_at = ok
        if got["props"] < 2:
            return None
        if story_at is not None:
            txt = rng.choice(tpl["story"])
            fx = ""
            if rng.random() < CHAIN_P:                                        # 사슬: 숨겨 둔 상자 또는 지도 조각
                link = stash(story_at, rng) if rng.random() < 0.6 else None
                if link:
                    txt += " " + link
                else:
                    txt += REVEAL_TEXT
                    fx = "reveal_near"
            t = {"x": story_at[0], "y": story_at[1], "text": txt}
            if fx:
                t["fx"] = fx
            texts.append(t)
            got["story"] = 1
        site = None
        for (re, st, p) in tpl.get("site", []):
            if rng.random() < p:
                site = {"x": x0, "y": y0, "re": re, "state": st, "tpl": tid}
                break
        elems = (1 if got["props"] >= 2 else 0) + (1 if got["box"] else 0) + got["story"] + (1 if site else 0)
        if elems < 3 and site is None and tpl.get("site"):                   # 셋을 못 채우면 그 템플릿의 사람·크리처 자리로 채운다
            re, st, p = tpl["site"][0]
            site = {"x": x0, "y": y0, "re": re, "state": st, "tpl": tid}
            elems += 1
        if site:
            sites.append(site)
        return elems

    def stash(at, rng):
        nonlocal stash_n
        for _ in range(12):
            ang = rng.random() * math.tau
            r = rng.randint(15, 40)
            x, y = int(at[0] + math.cos(ang) * r), int(at[1] + math.sin(ang) * r)
            if not (2 <= x < W - 2 and 2 <= y < H - 2) or not free(x, y):
                continue
            mark = rng.choice(list(STASH_MARK))
            if not put(mark, x, y):
                continue
            mname = STASH_MARK[mark]
            boxes.append({"x": x, "y": y, "w": 1, "h": 1, "kind": "stash", "name": "숨겨 둔 상자", "owner": "", "lock": 0})
            stash_n += 1
            d = DIR8[int((math.degrees(math.atan2(y - at[1], x - at[0])) % 360 + 22.5) // 45) % 8]
            n = int(round(math.hypot(x - at[0], y - at[1]) * 1.4 / 5.0) * 5)       # 한 칸 ≈ 1.4걸음, 5걸음 단위로 어림
            return rng.choice(STASH_TEXT).format(d=d, n=n, m=mname)
        return None

    for key in sorted(chunks, key=lambda k: (int(k.split(",")[1]), int(k.split(",")[0]))):
        info = chunks[key]
        tags = info["tags"]
        cx, cy = map(int, key.split(","))
        if (cx, cy) not in api["play_chunks"]:
            continue
        rng = random.Random(cx * 104723 + cy * 7907 + 1201)
        dens = [DENSITY[t] for t in tags if t in DENSITY]
        if not dens:
            continue
        lo = max(d[0] for d in dens)
        hi = max(d[1] for d in dens)
        gap = max(d[2] for d in dens)
        if (cx, cy) in center_chunks:                                       # 장소 청크: 장소가 우선(0~1)
            lo, hi = 0, 1
        want = rng.randint(lo, hi)
        if want <= 0:
            continue
        cand = [tid for tid, tp in T.items() if any(t in tags for t in tp["tags"])]
        if not cand:
            continue
        cl = cells(cx, cy, rng)
        made = 0
        tries = 0
        for (x, y) in cl[::5]:
            if made >= want or tries > 14:
                break
            if not far_enough(x, y, gap):
                continue
            tries += 1
            ws = [T[c]["w"] for c in cand]
            tid = rng.choices(cand, ws)[0]
            if T[tid].get("road") and kind[y, x] != 7:                       # 정체 줄은 찻길 위에서만
                alt = [c for c in cand if not T[c].get("road")]
                if not alt:
                    continue
                tid = rng.choices(alt, [T[c]["w"] for c in alt])[0]
            e = build(tid, x, y, rng)
            if e is None:
                continue
            placed_sites.append((x, y, gap))
            by_tpl[T[tid]["name"]] = by_tpl.get(T[tid]["name"], 0) + 1
            if 800 < x < 1000 and 1150 < y < 1550:                         # 견본 좌표(1막 권역 둘레 — 확인용)
                first.setdefault(tid, (x, y))
            made += 1
    cnt["소장소"] = sum(by_tpl.values())
    cnt["숨긴 상자"] = stash_n
    return {"sites": sites, "n": sum(by_tpl.values()), "by_tpl": by_tpl, "first": first}
