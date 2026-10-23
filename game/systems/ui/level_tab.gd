## 핍-보이 능력치 > 퍽(단계 1-12p, SD-10 §4.2 · §5 · SD-12 §3): 가진 퍽 목록 + 미배분 레벨업이 있으면 맨 위 '▲ 레벨업' 줄.
##   그 줄을 고르면 레벨업 화면(시간 정지 — 핍-보이를 연 동안): 1 스킬 나누기 → 2 퍽 고르기(→ 인텐스 트레이닝이면 능력치) → 3 확인 · 확정.
##   핍-보이를 열 때마다 끌고 가지 않는다(재미 검수 질문 2) — HUD ▲ · 하위 탭 '퍽 ▲'만 남긴다. 넣던 것은 앱이 켜진 동안만 기억(StoryState.lv_draft, 저장 안 함 — P10).
##   퍽 카드 = 이름 · 맛 한 줄 · 효과 한 줄(script/world/perks.txt — 다듬이 검수). 못 고르는 퍽은 흐리게 + 모자란 조건.
class_name LevelTab
extends RefCounted

const ROWS := 14


## 퍽 칸 목록 줄
static func perk_rows(pb) -> Array:
	var st = pb.st
	var out: Array = []
	var pend := Perks.pending(st)
	if pend > 0 and st.quests.cur_act() >= 0:
		out.append({"text": "▲ 레벨업 — Lv %d" % (maxi(1, int(st.vars.get_v("PC_LV_DONE"))) + 1), "id": "lvup", "right": ("×%d" % pend) if pend > 1 else ""})
	if int(st.vars.get_v("V_REGCARD")) >= 1:                             # 특별 퍽 관리 후보 1순위(PK-103, SD-10): 결과 통지서를 받으면 자동
		out.append({"text": "관리 후보 1순위", "id": "PK-103", "right": "특별"})
	for id in Perks.owned(st):
		if id == "PK-103":
			continue
		var p: Dictionary = Perks.db.get(id, {})
		var mx := int(p.get("ranks", 1))
		out.append({"text": str(p.get("name", id)), "id": id, "right": ("%d/%d" % [Perks.rank(st, id), mx]) if mx > 1 else ""})
	return out


## 퍽 칸 오른쪽(가진 퍽 상세 · 레벨업 줄 안내)
static func perk_page(pb, id: String) -> void:
	var U: Array = PipBoy.U
	if id == "lvup":
		pb.text(Vector2(264, 78), "레벨업", pb.f12b, 12, U[6])
		var y: float = pb._para(Vector2(264, 98), "스킬 포인트 %d점을 나누고 퍽을 하나 고른다. 다 나눠야 퍽으로 넘어간다." % Perks.skill_points(pb.st), U[5])
		y = pb._para(Vector2(264, y + 4), "핍-보이를 닫아도 나누던 것은 다시 열면 이어진다. 확정하기 전까지는 아무것도 바뀌지 않는다.", U[4])
		pb._para(Vector2(264, y + 8), "[Enter] 시작", U[6])
		return
	if id == "PK-103":
		pb.text(Vector2(264, 78), "관리 후보 1순위", pb.f12b, 12, U[6])
		pb.text(Vector2(264, 96), "특별 퍽 · 적성 평가 결과 통지서(2274)", pb.f10, 10, U[4])
		var y2: float = pb._para(Vector2(264, 114), "결과 통지서 맨 아래 칸에 처음부터 인쇄되어 있던 순위. 누가 무엇을 답해도 같다고 한다.", U[5])
		pb._para(Vector2(264, y2 + 4), "뜻을 알 수 없는 순위.", U[6])
		return
	_card(pb, id, 78.0, Perks.rank(pb.st, id))


## 퍽 카드: 이름 · 구분 · 랭크 · 맛 한 줄 · 효과 한 줄. 돌려줌 = 다음 y
static func _card(pb, id: String, y0: float, r: int) -> float:
	var U: Array = PipBoy.U
	var p: Dictionary = Perks.db.get(id, {})
	pb.text(Vector2(264, y0), str(p.get("name", id)), pb.f12b, 12, U[6])
	var mx := int(p.get("ranks", 1))
	var sub := "Lv %d" % int(p.get("lv", 2)) + ((" · 랭크 %d/%d" % [r, mx]) if mx > 1 else "")
	pb.text(Vector2(588, y0 + 2), sub, pb.f10, 10, U[4], HORIZONTAL_ALIGNMENT_RIGHT)
	var y: float = pb._para(Vector2(264, y0 + 20), "\"%s\"" % str(p.get("line", "")), U[4]) if str(p.get("line", "")) != "" else y0 + 20
	y = pb._para(Vector2(264, y + 4), str(p.get("card", p.get("effect", ""))), U[6])
	return y


# ---------------------------------------------------------------- 레벨업 화면
static func start(pb) -> void:
	var st = pb.st
	if st.lv_draft == null or not (st.lv_draft as LevelDraft).fresh():
		st.lv_draft = LevelDraft.begin(st)
	pb.lv_on = true
	pb.sel = 0


static func draft(pb) -> LevelDraft:
	return pb.st.lv_draft as LevelDraft


## 그 단계의 왼쪽 줄 id들
static func ids(pb) -> Array:
	var d := draft(pb)
	match d.step:
		0:
			return StoryState.SKILL_ORDER.duplicate()
		1:
			var ok: Array = []
			var no: Array = []
			for id in Perks.choices():
				if Perks.rank(pb.st, id) >= int(Perks.db.get(id, {}).get("ranks", 1)):
					continue                                             # 랭크를 다 올린 퍽은 목록에서 빠진다
				(ok if d.pick_ok(id) else no).append(id)
			return ok + no                                               # 고를 수 있는 것 먼저(레벨 순), 그다음 흐린 것
		2:
			return Perks.STAT_NAMES.keys()
		3:
			return StoryState.SKILL_ORDER.filter(func(k): return int(d.add.get(k, 0)) + d.bonus(k) > 0)   # 확인: 이번에 오른 스킬만
	return []


static func draw(pb) -> void:
	var U: Array = PipBoy.U
	var d := draft(pb)
	if d == null or not d.fresh():
		pb.lv_on = false
		return
	var list := ids(pb)
	pb.sel = clampi(pb.sel, 0, maxi(0, list.size() - 1))
	var top := clampi(pb.sel - ROWS / 2, 0, maxi(0, list.size() - ROWS))
	for i in range(top, mini(list.size(), top + ROWS)):
		var y := 74.0 + (i - top) * 15.0
		var rr := Rect2(48, y - 1, 199, 14)
		pb.item("lvrow%d" % i, rr)
		var id: String = list[i]
		var txt := ""
		var right := ""
		var dim := false
		match d.step:
			0, 3:
				txt = StoryState.SKILLS[id][0] + (" [태그]" if pb.st.tagged(id) else "")
				var a := int(d.add.get(id, 0)) + d.bonus(id)
				right = str(d.shown(id)) + ((" +%d" % a) if a > 0 else "")
				dim = d.shown(id) >= 100
			1:
				txt = Perks.perk_name(id)
				var mx := int(Perks.db[id].get("ranks", 1))
				right = ("%d/%d" % [Perks.rank(pb.st, id), mx]) if mx > 1 else "Lv %d" % int(Perks.db[id].get("lv", 2))
				dim = not d.pick_ok(id)
			2:
				txt = Perks.STAT_NAMES[id]
				right = str(pb.st.stat_base(id)) + (" → %d" % mini(10, pb.st.stat_base(id) + 1) if id == pb_sel_id(pb) else "")
		var col: Color = U[3] if dim else U[5]
		if i == pb.sel:
			pb.view.draw_rect(rr, U[6])
			col = U[0]
		pb.text(Vector2(52, y), pb._fit(txt, 150.0), pb.f12, 12, col)
		pb.text(Vector2(242, y), right, pb.f12, 12, col, HORIZONTAL_ALIGNMENT_RIGHT)
	if top > 0:
		pb.text(Vector2(242, 64), "▲", pb.f10, 10, U[4], HORIZONTAL_ALIGNMENT_RIGHT)
	if top + ROWS < list.size():
		pb.text(Vector2(242, 282), "▼", pb.f10, 10, U[4], HORIZONTAL_ALIGNMENT_RIGHT)
	pb.view.draw_line(Vector2(250.5, 70), Vector2(250.5, 290), U[2])
	match d.step:
		0:
			_skill_side(pb, d, list)
		1:
			_perk_side(pb, d, list)
		2:
			pb.text(Vector2(264, 78), "인텐스 트레이닝 — 능력치 하나", pb.f12b, 12, U[6])
			var y: float = pb._para(Vector2(264, 98), "고른 능력치가 영구히 1 오른다. 10을 넘으면 안쪽 기록에만 쌓인다(표시는 10).", U[5])
			pb._para(Vector2(264, y + 6), "[Enter] 이 능력치로   [Backspace] 퍽 다시 고르기", U[4])
		3:
			_confirm_side(pb, d)
	_buttons(pb, d)


static func pb_sel_id(pb) -> String:
	var list := ids(pb)
	return str(list[pb.sel]) if pb.sel < list.size() else ""


static func _skill_side(pb, d: LevelDraft, list: Array) -> void:
	var U: Array = PipBoy.U
	pb.text(Vector2(264, 78), "레벨 %d — 스킬 나누기" % d.lv, pb.f12b, 12, U[6])
	pb.text(Vector2(588, 80), "남은 포인트 %d / %d" % [d.left(), d.pts], pb.f10, 10, U[6] if d.left() > 0 else U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	var k: String = list[pb.sel] if pb.sel < list.size() else ""
	var y := 100.0
	if k != "":
		var nm: String = StoryState.SKILLS[k][0]
		pb.text(Vector2(264, y), "%s  %d → %d" % [nm, pb.st.skill(k), d.shown(k)], pb.f12, 12, U[5])
		y += 18.0
		if d.bonus(k) > 0:
			pb.text(Vector2(264, y), "선행 학습 덤 +%d" % d.bonus(k), pb.f10, 10, U[4])
			y += 14.0
		var tx: Dictionary = pb.skills_text.get(nm, {})
		y = pb._para(Vector2(264, y), str(tx.get("uses", tx.get("desc", ""))), U[4])
	var th := d.thresholds()
	if not th.is_empty():
		y += 4.0
		for line in th.slice(0, 3):
			y = pb._para(Vector2(264, y), str(line), U[6])


static func _perk_side(pb, d: LevelDraft, list: Array) -> void:
	var U: Array = PipBoy.U
	var id: String = list[pb.sel] if pb.sel < list.size() else ""
	if id == "":
		pb.text(Vector2(264, 78), "고를 수 있는 퍽이 없다.", pb.f12, 12, U[3])
		return
	var y := _card(pb, id, 78.0, Perks.rank(pb.st, id))
	var lk := Perks.lacks(pb.st, id, d.lv)
	if lk.is_empty():
		pb._para(Vector2(264, y + 8), "[Enter] 이 퍽으로   [Backspace] 스킬 다시 나누기", U[4])
	else:
		pb._para(Vector2(264, y + 8), "조건: " + " · ".join(lk), U[3])


static func _confirm_side(pb, d: LevelDraft) -> void:
	var U: Array = PipBoy.U
	pb.text(Vector2(264, 78), "레벨 %d — 이대로 할까?" % d.lv, pb.f12b, 12, U[6])
	var parts: Array = []
	for k in StoryState.SKILL_ORDER:
		var a := int(d.add.get(k, 0)) + d.bonus(k)
		if a > 0:
			parts.append("%s +%d" % [StoryState.SKILLS[k][0], a])
	var y: float = pb._para(Vector2(264, 100), "스킬: " + (" · ".join(parts) if not parts.is_empty() else "없음"), U[5])
	var pn: String = Perks.perk_name(d.perk) + ((" — " + Perks.STAT_NAMES[d.stat_pick] + " +1") if d.perk == "PK-004" and d.stat_pick != "" else "")
	y = pb._para(Vector2(264, y + 4), "퍽: " + pn, U[5])
	for line in d.thresholds().slice(0, 2):
		y = pb._para(Vector2(264, y + 2), str(line), U[6])
	pb._para(Vector2(264, y + 8), "[Enter] 확정   [Backspace] 되돌리기", U[4])


## 터치 단추(아래 줄 위 — 모바일에서 13줄 숫자를 하나씩 누르지 않게 '태그에 고루')
static func _buttons(pb, d: LevelDraft) -> void:
	var U: Array = PipBoy.U
	var bs: Array = []
	match d.step:
		0:
			bs = [["lv_dec", "−"], ["lv_inc", "+"], ["lv_tags", "태그에 고루"], ["lv_next", "퍽 고르기 ▶"]]
		1, 2:
			bs = [["lv_back", "◀ 뒤로"], ["lv_ok", "고르기"]]
		3:
			bs = [["lv_back", "◀ 되돌리기"], ["lv_ok", "확정"]]
	var x := 588.0
	for i in range(bs.size() - 1, -1, -1):
		var w: float = pb.tw(str(bs[i][1]), pb.f10, 10) + 14.0
		var r := Rect2(x - w, 268, w, 16)
		pb.item(str(bs[i][0]), r)
		var off: bool = (str(bs[i][0]) == "lv_next" and d.left() > 0) or (str(bs[i][0]) == "lv_ok" and d.step == 1 and not d.pick_ok(pb_sel_id(pb)))
		pb.box(r, U[3] if off else U[5], false)
		pb.text(Vector2(r.position.x + w / 2.0, 270), str(bs[i][1]), pb.f10, 10, U[3] if off else U[6], HORIZONTAL_ALIGNMENT_CENTER)
		x -= w + 6.0


static func hint(pb) -> String:
	match draft(pb).step:
		0:
			return "[↑↓] 스킬   [←→] 빼기 · 넣기   [T] 태그에 고루   [Enter] 퍽 고르기   [Tab] 닫기(이어서 가능)"
		1:
			return "[↑↓] 퍽   [Enter] 고르기   [Backspace] 스킬로   [Tab] 닫기"
		2:
			return "[↑↓] 능력치   [Enter] 고르기   [Backspace] 퍽으로"
	return "[Enter] 확정   [Backspace] 되돌리기   [Tab] 닫기"


## 키. 처리했으면 true
static func key(pb, e: InputEvent) -> bool:
	var d := draft(pb)
	if d == null:
		return false
	var k: int = e.keycode if e is InputEventKey and e.pressed and not e.echo else -1
	if e.is_action_pressed("ui_up", true):
		pb.sel = maxi(0, pb.sel - 1)
	elif e.is_action_pressed("ui_down", true):
		pb.sel = mini(ids(pb).size() - 1, pb.sel + 1)
	elif d.step == 0 and e.is_action_pressed("ui_left", true):
		d.inc(pb_sel_id(pb), -1)
	elif d.step == 0 and e.is_action_pressed("ui_right", true):
		d.inc(pb_sel_id(pb), 1)
	elif d.step == 0 and k == KEY_T:
		d.spread_tags()
	elif e.is_action_pressed("ui_accept"):
		_ok(pb)
	elif k == KEY_BACKSPACE:
		_back(pb)
	elif e is InputEventKey and e.pressed and e.keycode in [KEY_LEFT, KEY_RIGHT, KEY_T, KEY_BACKSPACE]:
		pass
	else:
		return false
	return true


static func press(pb, id: String) -> bool:
	var d := draft(pb)
	if d == null:
		return false
	if id.begins_with("lvrow"):
		var i := int(id.substr(5))
		if i == pb.sel and d.step > 0:
			_ok(pb)
		pb.sel = i
		return true
	match id:
		"lv_dec":
			d.inc(pb_sel_id(pb), -1)
		"lv_inc":
			d.inc(pb_sel_id(pb), 1)
		"lv_tags":
			d.spread_tags()
		"lv_next", "lv_ok":
			_ok(pb)
		"lv_back":
			_back(pb)
		_:
			return false
	return true


static func _ok(pb) -> void:
	var d := draft(pb)
	match d.step:
		0:
			if d.left() > 0:
				pb.say("포인트를 다 나눠야 퍽으로 넘어간다 — 남은 %d점." % d.left())
				return
			d.step = 1
			pb.sel = 0
		1:
			var id := pb_sel_id(pb)
			if id == "" or not d.pick_ok(id):
				pb.say("아직 고를 수 없는 퍽이다.")
				return
			d.perk = id
			d.step = 2 if id == "PK-004" else 3
			pb.sel = 0
		2:
			var c := pb_sel_id(pb)
			d.stat_pick = c
			d.step = 3
		3:
			var notes := d.confirm()
			if notes.is_empty():
				return
			pb.action.emit("levelup", str(d.lv))
			pb.say(" · ".join(notes.slice(0, 2)))
			pb.st.lv_draft = null
			if Perks.pending(pb.st) > 0:                               # 여러 레벨: 레벨 차례대로 이어서(§4.2)
				pb.st.lv_draft = LevelDraft.begin(pb.st)
				pb.sel = 0
			else:
				pb.lv_on = false
				pb.sel = 0


static func _back(pb) -> void:
	var d := draft(pb)
	match d.step:
		1:
			d.step = 0
		2:
			d.step = 1
			d.perk = ""
		3:
			d.step = 2 if d.perk == "PK-004" else 1
			d.stat_pick = ""
			if d.step == 1:
				d.perk = ""
	pb.sel = 0
