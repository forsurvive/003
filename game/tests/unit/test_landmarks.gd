## 원경 표식(1-12k, SD-08 §5.2 · §12.2, SD-12 §4.3): 반경 · 등록 비트 · 전망 S 둘 · 링에 보일 것(가까운 3 + S 2)
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	return st


func test_landmarks_radius_and_register(t) -> void:
	var st := _st()
	t.eq(Landmarks.ROWS.size(), 21, "랜드마크 21(SD-08 §5.2)")
	var ns := Landmarks.index("NAMSAN")
	var gold := Landmarks.index("GOLD")
	var nanji := Landmarks.index("NANJI")
	var dome := Landmarks.index("DOME")
	t.ok(is_inf(Landmarks.radius(ns, false)), "S = 전역")
	t.eq(int(Landmarks.radius(gold, false)), 640, "A = 16청크 = 640타일")
	t.eq(int(Landmarks.radius(dome, true)), 280, "B 7청크 — 빛나지 않는 돔은 밤에도 같다")
	t.eq(int(Landmarks.radius(nanji, true)), 420, "난지도 메탄 불꽃은 밤 ×1.5")
	t.ok(not Landmarks.seen(st, ns), "처음엔 등록 없음")
	t.ok(Landmarks.register(st, gold), "등록")
	t.ok(not Landmarks.register(st, gold), "두 번째는 false")
	t.eq(int(st.vars.get_v("LM_SEEN")), 1 << gold, "비트 한 곳(P1)")
	var names: Array = Landmarks.vista(st)
	t.eq(names, ["남산 송신탑", "세진전자 타워"], "전망 픽처 → S 둘 등록")
	t.eq(Landmarks.vista(st).size(), 0, "다시 봐도 새 등록 없음")


func test_landmarks_tick_and_visible(t) -> void:
	var st := _st()
	var rock := Vector2i(980, 1515)                                        # 관악산 전망바위
	var got: Array = Landmarks.tick(st, rock, false)
	t.ok("여의도 금탑" in got, "전망바위에서 금탑(A, 9.7청크) 반경 안 → 등록")
	t.ok("관악 레이더 돔" in got, "레이더 돔(A, 1.2청크)")
	t.ok(not ("남산 송신탑" in got), "S는 tick이 아니라 vista로만")
	t.ok(not ("무너진 국회 돔" in got), "국회 돔(B 7청크)은 12청크 밖")
	var vis: Array = Landmarks.visible(st, rock, false)
	t.ok(vis.size() >= 2 and vis.size() <= 3, "링: 등록된 것 중 반경 안 — 가까운 순 셋까지(S 아직 없음)")
	Landmarks.vista(st)
	vis = Landmarks.visible(st, rock, false)
	var names: Array = vis.map(func(r): return r["name"])
	t.ok("남산 송신탑" in names and "세진전자 타워" in names, "S 둘은 늘")
	t.ok(vis.size() <= 5, "가까운 3 + S 2까지")
	var far := Vector2i(100, 100)                                          # 북서 끝: 금탑 반경 밖
	vis = Landmarks.visible(st, far, false)
	names = vis.map(func(r): return r["name"])
	t.ok(not ("여의도 금탑" in names) and "남산 송신탑" in names, "반경 밖이면 안 보이고 S는 보인다")
	for r in vis:
		t.ok(absf((r["dir"] as Vector2).length() - 1.0) < 0.01, "방향은 단위 벡터")
