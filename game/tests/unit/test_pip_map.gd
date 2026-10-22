## 핍-보이 지도의 순수 판정(1-12k): 지도를 보고 하는 단서 2 추론(D-046) · 교역로 쌍 열림(D-048) · 시간 글 · 등록 카드 코드 줄
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("V_ACT", 1)
	return st


func test_pip_map_infer(t) -> void:
	var st := _st()
	var at := Vector2(806.5, 1091.5)                                       # 여의도 지하 벙커 = 청크 (20, 27)
	t.ok(not PipMap.infer_hit(st, at, 2), "카드 단계 2 전엔 숫자가 없다")
	st.vars.set_v("V_REGCARD", 2)
	t.ok(not PipMap.infer_hit(st, at, 0), "전도 단계에선 청크를 짚지 못한다")
	t.ok(PipMap.infer_hit(st, at, 1), "권역 단계 · 카드 2 · MQ-102 전이어도 된다(허브는 clue가 연다)")
	t.ok(PipMap.infer_hit(st, Vector2(839, 1119), 3), "같은 청크 안 어디든")
	t.ok(not PipMap.infer_hit(st, Vector2(840, 1091), 3), "옆 청크 (21, 27)는 아니다")
	st.vars.set_v("MQ102_C2", 1)
	t.ok(not PipMap.infer_hit(st, at, 2), "단서 2가 서면 줄이 사라진다(P2)")
	st.vars.set_v("MQ102_C2", 0)
	st.vars.set_v("V_ACT", 0)
	t.ok(not PipMap.infer_hit(st, at, 2), "프롤로그(볼트 안)에선 아니다")
	t.eq(PipBoy.CARD_CHUNK, PipMap.INFER_CHUNK, "카드 숫자와 지도 판정은 같은 청크")
	var code := PipBoy.card_code(0.0)
	t.ok(code.ends_with("-20 27"), "카드 코드 줄 끝 숫자 둘: " + code)
	t.ok(code.length() == 15, "####-####-## 꼴(깨진 글자 8 + 붙임표 2 + 숫자 둘)")


func test_pip_map_trade_link(t) -> void:
	var st := _st()
	t.ok(not PipMap.trade_link_open(st), "처음엔 닫힘")
	st.vars.set_v("SQ_S05_SOL", 1)
	t.ok(not PipMap.trade_link_open(st), "해법만으론 아니다 — 두 끝 발견")
	st.places.raise("L-R01-18", PlaceLog.FOUND)
	st.places.raise("L-UG-02", PlaceLog.FOUND)
	t.ok(PipMap.trade_link_open(st), "해법 A + 두 끝 발견 → 열림")
	st.vars.set_v("SQ_S05_SOL", 4)
	t.ok(not PipMap.trade_link_open(st), "가면 통과(4)는 통과이지 해결이 아니다")
	st.vars.set_v("SQ_S05_SOL", 3)
	t.ok(PipMap.trade_link_open(st), "구울의 말(3)도 개통")
	t.eq(PipMap.hours_text(1.0), "1시간", "1시간")
	t.eq(PipMap.hours_text(0.5), "30분", "30분")
	t.eq(PipMap.hours_text(2.0), "2시간", "2시간")
