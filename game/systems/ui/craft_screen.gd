## 작업대·조리 창(단계 1-8c, SD-12 §11.3 · SD-13 §7.9): 왼쪽 레시피 목록(설계도는 가진 것만) → 오른쪽 결과물·만든 직후 상태·
## 필요 재료(보유/필요, 모자라면 붉은 숫자 + [부족])·캡 → 아래 수량(◀▶)·[만들기]·[닫기]. 작업대면 [제작]/[조리] 탭, 불(화덕·버너)이면 조리만.
## 핍-보이 녹색 화면 틀. 키: ▲▼ 칸 · ◀▶ 수량 · 결정 · 취소(Esc/Tab). 마우스·터치: 줄을 누르면 고르고, 단추를 누르면 만든다.
class_name CraftScreen
extends DocScreen

signal crafted(rid: String, result: Dictionary)

const ROWS := 11
var title := ""
var station := true            ## 작업대·화덕 앞(조리에 불이 있다)
var bench := true              ## 작업대(제작 탭이 있다) — 아니면 조리만
var cook := false              ## 지금 탭: 조리
var db := {}                   ## 아이템 ID → 이름·수치(호스트 items_db)
var sel := ""                  ## 고른 레시피
var qty := 1
var top := 0                   ## 목록 맨 위 줄
var flash := ""                ## 방금 만든 결과 한 줄
var flash_t := 0.0


func setup(state: StoryState, items_db: Dictionary, name: String, is_bench: bool, at_station: bool) -> CraftScreen:
	st = state
	db = items_db
	title = name
	bench = is_bench
	station = at_station
	cook = not is_bench
	cancel_ok = true
	Craft.load_data()
	_pick_first()
	return self


func _pick_first() -> void:
	var l := Craft.listing(st, cook)
	sel = str(l[0]) if not l.is_empty() else ""
	qty = 1
	top = 0


## 글 한 줄(Godot 기준선 방식: p = 기준선 왼쪽, w = 정렬 폭)
func _s(p: Vector2, s: String, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	view.draw_string(font, p, s, align, w, size, col)


func _nm(id: String) -> String:
	return str(db.get(id, db.get(Gear.base(id), {})).get("name", id))


func _tick(dt: float) -> void:
	if flash_t > 0.0:
		flash_t -= dt


func _adjust(id: String, d: int) -> void:
	if id == "qty":
		qty = clampi(qty + d, 1, maxi(1, Craft.max_sets(st, sel, station)))
	elif id.begins_with("tab"):
		_set_tab(not cook)


func _set_tab(c: bool) -> void:
	if not bench or c == cook:
		return
	cook = c
	_pick_first()


func _press(id: String) -> void:
	if id == "close":
		close(true)
	elif id == "tab_craft":
		_set_tab(false)
	elif id == "tab_cook":
		_set_tab(true)
	elif id.begins_with("r:"):
		sel = id.substr(2)
		qty = 1
		focus_on("make")
	elif id == "make":
		var r := Craft.make(st, sel, qty, station)
		if bool(r.get("ok", false)):
			var parts: Array = []
			for k in r["made"]:
				parts.append("%s ×%d" % [_nm(str(k)), int(r["made"][k])])
			flash = "만들었다 — " + ", ".join(parts)
			crafted.emit(sel, r)
		else:
			flash = str(r.get("why", "만들 수 없다"))
		flash_t = 3.0
		qty = clampi(qty, 1, maxi(1, Craft.max_sets(st, sel, station)))


func _focus_changed(_by_mouse: bool) -> void:
	var id := focused_id()
	if id.begins_with("r:") and id.substr(2) != sel:
		sel = id.substr(2)
		qty = 1


func _draw_doc() -> void:
	var g := GREEN
	view.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.6))
	var r := Rect2(36, 24, 568, 312)
	view.draw_rect(r, g[0])
	view.draw_rect(r, g[4], false, 2.0)
	view.draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), g[2], false, 1.0)
	_s(r.position + Vector2(14, 22), title, f12b, 12, g[6])
	# 탭(작업대만)
	if bench:
		for k in 2:
			var tr := Rect2(r.position.x + 300 + k * 96, r.position.y + 8, 88, 18)
			var on_tab := (k == 1) == cook
			var f := item("tab_cook" if k == 1 else "tab_craft", tr, true, true, tr, tr)
			view.draw_rect(tr, g[3] if on_tab else g[1])
			view.draw_rect(tr, g[5] if f else g[3], false, 1.0)
			_s(tr.position + Vector2(0, 13), "조리" if k == 1 else "제작", f10, 10, g[7] if on_tab else g[4], HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
	hline(r.position.x + 10, r.end.x - 10, r.position.y + 32, g[3])
	# 왼쪽 목록
	var l := Craft.listing(st, cook)
	var fid := focused_id()
	if fid.begins_with("r:"):
		var fi := l.find(fid.substr(2))
		if fi >= 0:
			if fi < top:
				top = fi
			elif fi >= top + ROWS:
				top = fi - ROWS + 1
	var lx := r.position.x + 12
	var ly := r.position.y + 40
	if l.is_empty():
		_s(Vector2(lx, ly + 14), "만들 수 있는 것이 없다." if not cook else "조리법이 없다.", f10, 10, g[4])
		_s(Vector2(lx, ly + 30), "설계도는 상인·금고·보상에서 얻는다." if not cook else "", f8, 8, g[3])
	for i in range(top, mini(l.size(), top + ROWS)):
		var rid: String = l[i]
		var rr := Rect2(lx, ly + (i - top) * 21, 246, 19)
		var rec: Dictionary = Craft.recipes[rid]
		var n := Craft.max_sets(st, rid, station)
		var f := item("r:" + rid, rr)
		var chosen := rid == sel
		view.draw_rect(rr, g[2] if chosen else (g[1] if f else g[0]))
		if f:
			view.draw_rect(rr, g[5], false, 1.0)
		var nm := _nm(rid)
		if rid == "건설용 대못" or rid == "마취 다트":
			nm = rid
		_s(rr.position + Vector2(6, 13), nm, f10, 10, g[7] if n > 0 else g[4], HORIZONTAL_ALIGNMENT_LEFT, 160)
		var tag := ""
		var tcol: Color = g[5]
		if not Craft.perk_ok(st, rec):
			tag = "[퍽: %s]" % str(Craft.PERK_NAMES.get(str(rec["perk"]), rec["perk"]))
			tcol = RED.lightened(0.25)
		elif bool(rec.get("cook", false)) and not Craft.heat_ok(st, station):
			tag = "[불 없음]"
			tcol = RED.lightened(0.25)
		elif n <= 0:
			tag = "[부족]"
			tcol = RED.lightened(0.25)
		else:
			tag = "%d번" % n
		_s(rr.position + Vector2(0, 13), tag, f8, 8, tcol, HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x - 6)
	if l.size() > ROWS:
		_s(Vector2(lx, r.end.y - 52), "▲▼ %d/%d" % [mini(top + ROWS, l.size()), l.size()], f8, 8, g[3])
	# 오른쪽 자세히
	view.draw_line(Vector2(r.position.x + 266, r.position.y + 38), Vector2(r.position.x + 266, r.end.y - 46), g[3])
	if sel != "" and Craft.recipes.has(sel):
		_detail(Rect2(r.position.x + 276, r.position.y + 40, 280, 220))
	# 아래: 수량 · 만들기 · 닫기
	var by := r.end.y - 38
	var mx := Craft.max_sets(st, sel, station) if sel != "" else 0
	var ql := Rect2(r.position.x + 276, by, 18, 24)
	var qr := Rect2(r.position.x + 352, by, 18, 24)
	var qf := item("qty", Rect2(r.position.x + 276, by, 94, 24), mx > 1, true, ql, qr)
	view.draw_rect(Rect2(r.position.x + 276, by, 94, 24), g[1])
	if qf:
		view.draw_rect(Rect2(r.position.x + 276, by, 94, 24), g[5], false, 1.0)
	_s(ql.position + Vector2(4, 16), "◀", f10, 10, g[6] if mx > 1 else g[3])
	_s(qr.position + Vector2(4, 16), "▶", f10, 10, g[6] if mx > 1 else g[3])
	_s(Vector2(r.position.x + 294, by + 16), "%d세트" % qty, f10, 10, g[7], HORIZONTAL_ALIGNMENT_CENTER, 58)
	var mb := Rect2(r.position.x + 380, by, 100, 24)
	var cb := Rect2(r.position.x + 488, by, 72, 24)
	var ms := item("make", mb, mx > 0)
	view.draw_rect(mb, g[4] if ms else (g[2] if mx > 0 else g[1]))
	view.draw_rect(mb, g[5], false, 1.0)
	_s(mb.position + Vector2(0, 16), "조리하기" if cook else "만들기", f12, 12, g[0] if ms else (g[7] if mx > 0 else g[3]), HORIZONTAL_ALIGNMENT_CENTER, mb.size.x)
	var cs := item("close", cb)
	view.draw_rect(cb, g[4] if cs else g[1])
	view.draw_rect(cb, g[5], false, 1.0)
	_s(cb.position + Vector2(0, 16), "닫기", f12, 12, g[0] if cs else g[6], HORIZONTAL_ALIGNMENT_CENTER, cb.size.x)
	if flash_t > 0.0:
		_s(Vector2(r.position.x + 14, r.end.y - 12), flash, f10, 10, g[7], HORIZONTAL_ALIGNMENT_LEFT, 540)
	else:
		_s(Vector2(r.position.x + 14, r.end.y - 12), "캡 %d" % int(st.vars.get_v("PC_CAPS")), f10, 10, g[5])


func _detail(a: Rect2) -> void:
	var g := GREEN
	var rec: Dictionary = Craft.recipes[sel]
	var kind := str(rec.get("kind", ""))
	var y := a.position.y + 12
	var key := Craft.out_key(st, sel)
	var nm := _nm(key) if kind != "ammo" else sel
	var per := Craft.per_set(st, sel)
	_s(Vector2(a.position.x, y), nm + ("  ×%d" % per if per > 1 else ""), f12b, 12, g[7], HORIZONTAL_ALIGNMENT_LEFT, a.size.x)
	y += 16
	var info: Dictionary = db.get(Gear.base(key), {})
	var line := ""
	match kind:
		"weapon":
			line = "만든 직후: %s  (설계도 %d장 · 수리 %d)" % [Gear.NAMES[Craft.quality(st, sel)], Craft.copies(st, rec), st.skill("REPAIR")]
		"explosive":
			line = "재료 1세트당 %d개  (설계도 %d장)" % [per, Craft.copies(st, rec)]
		"food":
			line = str(db.get(key, {}).get("desc", info.get("desc", "")))
		_:
			line = str(info.get("desc", ""))
	_s(Vector2(a.position.x, y), line, f8, 8, g[5], HORIZONTAL_ALIGNMENT_LEFT, a.size.x)
	y += 12
	if kind == "weapon":
		_s(Vector2(a.position.x, y), str(info.get("desc", "")), f8, 8, g[4], HORIZONTAL_ALIGNMENT_LEFT, a.size.x)
		y += 12
	if Craft.copies(st, rec) >= 4:
		_s(Vector2(a.position.x, y), "설계도 4장째부터는 더 나아지지 않는다(팔 수 있다).", f8, 8, g[3], HORIZONTAL_ALIGNMENT_LEFT, a.size.x)
		y += 12
	y += 6
	_s(Vector2(a.position.x, y), "필요 재료", f10, 10, g[6])
	_s(Vector2(a.position.x, y), "보유 / 필요", f8, 8, g[4], HORIZONTAL_ALIGNMENT_RIGHT, a.size.x)
	y += 4
	hline(a.position.x, a.end.x, y, g[3])
	y += 13
	for slot in rec["needs"]:
		var have := Craft.have(st, slot)
		var need := int(slot["n"]) * qty
		var names: Array = []
		for id in slot["any"]:
			names.append(_nm(str(id)))
		var label := str(names[0]) if names.size() == 1 else ("물(아무거나, 맑은 것부터)" if slot["any"] == Craft.WATER else " 또는 ".join(names))
		var short := have < need
		_s(Vector2(a.position.x + 4, y), label, f10, 10, g[6] if not short else g[4], HORIZONTAL_ALIGNMENT_LEFT, a.size.x - 70)
		_s(Vector2(a.position.x, y), ("[부족] " if short else "") + "%d / %d" % [have, need], f10, 10,
			RED.lightened(0.3) if short else g[6], HORIZONTAL_ALIGNMENT_RIGHT, a.size.x)
		y += 15
	if int(rec.get("caps", 0)) > 0:
		var need_c := int(rec["caps"]) * qty
		var short_c := int(st.vars.get_v("PC_CAPS")) < need_c
		_s(Vector2(a.position.x + 4, y), "캡(녹여 쓴다)", f10, 10, g[6])
		_s(Vector2(a.position.x, y), ("[부족] " if short_c else "") + "%d / %d" % [int(st.vars.get_v("PC_CAPS")), need_c], f10, 10,
			RED.lightened(0.3) if short_c else g[6], HORIZONTAL_ALIGNMENT_RIGHT, a.size.x)
		y += 15
	if not Craft.perk_ok(st, rec):
		y += 4
		_s(Vector2(a.position.x, y), "퍽 '%s'이 있어야 만든다." % str(Craft.PERK_NAMES.get(str(rec["perk"]), rec["perk"])), f8, 8, RED.lightened(0.3))
	elif bool(rec.get("cook", false)) and not Craft.heat_ok(st, station):
		y += 4
		_s(Vector2(a.position.x, y), "불이 없다 — 작업대·화덕 앞이거나 휴대용 버너가 있어야 한다.", f8, 8, RED.lightened(0.3))
