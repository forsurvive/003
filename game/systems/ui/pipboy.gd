## 핍-보이 3000 (SD-12 §3, 견본 art/samples/07_pipboy_stat.png): 기기 틀 + 초록 CRT(U 팔레트), 주 탭 3개(능력치·아이템·데이터).
##   능력치: 상태(주민 그림·부위 막대·스팀팩) · S.P.E.C.I.A.L.(SD-10 §2.2 정의 + 생활기록부 문구) · 스킬 · 퍽 · 일반(카르마·등록 카드)
##   아이템: 무기 · 의복 · 구호품 · 잡화 · 탄약 (결정 = 장착/해제·사용, 1~8 = 단축키 지정)
##   데이터: 퀘스트 · 기록
##   프롤로그(단계 0)에서 뺀 하위 탭(정합): 세력(볼트 안에는 세력이 없다, SD-03a §7 서두), 지역·월드 지도·라디오(SD-19 §5.4 단계 1 시스템)
## 조작(SD-12 §3.2·§13.8): Tab·Esc 닫기, Q·E 주 탭, ←→ 하위 탭, ↑↓ 목록, Enter 사용, F1·F2·F3 주 탭 바로, J 퀘스트.
## 마우스·터치(마우스 흉내): 탭·하위 탭·줄을 누르고(고른 줄을 다시 누르면 사용), 아래 줄 [닫기]·오른쪽 위 전원 단추를 누르면 닫힌다.
## 열 때(§3.2): 기기가 아래에서 0.2초 올라오고 화면이 0.15초 켜진다(가로 주사선이 위아래로 벌어짐). 열어 둔 동안 시간이 멈춘다.
class_name PipBoy
extends DocScreen

signal action(kind: String, id: String)              ## "equip"·"unequip"·"use"·"hotkey:n" — 받는 쪽(전투·소지품)이 처리한다

const U := DocScreen.GREEN
const TABS := ["능력치", "아이템", "데이터"]
const SUBS := [["상태", "S.P.E.C.I.A.L.", "스킬", "퍽", "일반"], ["무기", "의복", "구호품", "잡화", "탄약"], ["퀘스트", "기록"]]
const CATS := ["weapon", "apparel", "aid", "misc", "ammo"]
const STAT_ORDER := ["ST", "PE", "EN", "CH", "IN", "AG", "LK"]
const OPEN_S := 0.2
const ON_S := 0.15

var tab := 0
var sub := [0, 0, 0]
var sel := 0
var info := {}                                       ## 위 줄·상세에 쓰는 수치(InteriorHost.status())
var db := {}                                         ## 아이템 ID -> {name, cat, desc, weight, value, ...}
var stats_text := {}
var skills_text := {}
var karma_titles := {}
var first := false                                   ## 처음 받았을 때: 조작 안내를 띄운다
var bezel: TextureRect
var crt: TextureRect
var fig: TextureRect
var rows: Array = []                                 ## 지금 목록 [{"text", "id", "right", "dim"}]
var t_open := 0.0


func setup(state: StoryState, items_db: Dictionary, status: Dictionary) -> PipBoy:
	st = state
	db = items_db
	info = status
	cancel_ok = true
	for kv in [["stats_text", "res://data/stats_text.json"], ["skills_text", "res://data/skills_text.json"],
			["karma_titles", "res://data/karma_titles.json"]]:
		if FileAccess.file_exists(kv[1]):
			set(kv[0], JSON.parse_string(FileAccess.get_file_as_string(kv[1])))
	return self


func _init() -> void:
	super._init()
	bezel = TextureRect.new()
	bezel.texture = load("res://assets/ui/pipboy_bezel.png")
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bezel)
	move_child(bezel, 0)
	fig = TextureRect.new()
	fig.texture = load("res://assets/ui/pipboy_figure.png")
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fig)
	crt = TextureRect.new()
	crt.texture = load("res://assets/ui/pipboy_crt.png")
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crt)


func _place() -> void:
	super._place()
	var k := clampf(t_open / OPEN_S, 0.0, 1.0)
	var vs := get_viewport().get_visible_rect().size
	view.position.y += roundf((1.0 - k) * (vs.y - view.position.y))      # 아래에서 올라온다
	bezel.position = view.position
	crt.position = view.position + Vector2(40, 28)


func _tick(dt: float) -> void:
	t_open += dt


func open_at(t: int, s: int = 0) -> void:
	tab = t
	sub[t] = s
	sel = 0


# ---------------------------------------------------------------- 목록
func _rows() -> Array:
	var out: Array = []
	match [tab, sub[tab]]:
		[0, 0]:
			out = [{"text": "신체", "id": "body"}, {"text": "방사능", "id": "rad"}, {"text": "효과", "id": "effects"}]
		[0, 1]:
			for c in STAT_ORDER:
				out.append({"text": StoryState.STATS[c], "id": c, "right": str(st.stat(c))})
		[0, 2]:
			for k in StoryState.SKILL_ORDER:
				out.append({"text": StoryState.SKILLS[k][0] + (" [태그]" if st.tagged(k) else ""), "id": k, "right": str(st.skill(k))})
		[0, 3]:                                                         # 특별 퍽 관리 후보 1순위(PK-103, SD-10): 결과 통지서를 받으면 자동
			out = [{"text": "관리 후보 1순위", "id": "PK-103", "right": "특별"}] if int(st.vars.get_v("V_REGCARD")) >= 1 else []
		[0, 4]:
			out = [{"text": "등록 카드", "id": "card"}, {"text": "카르마", "id": "karma"}, {"text": "통계", "id": "stats"}]
		[1, _]:
			var cat: String = CATS[sub[1]]
			var ids := st.items.keys()
			ids.sort()
			for id in ids:
				var it: Dictionary = db.get(id, {})
				var c: String = str(it.get("cat", "ammo" if str(id).ends_with("탄") else "misc"))
				if c != cat:
					continue
				var n := int(st.items[id])
				var on: bool = id == info.get("equipped", "") or id == info.get("worn", "")
				var hk := ""
				for k in info.get("hotkeys", {}):
					if info["hotkeys"][k] == id:
						hk = " (%d)" % int(k)
				out.append({"text": str(it.get("name", id)) + (" (%d)" % n if n > 1 and cat != "ammo" else "") + (" [장착]" if on else ""),
					"id": id, "right": (str(n) if cat == "ammo" else hk.strip_edges())})
		[2, 0]:
			for q in _quests():
				out.append({"text": ("" if q["active"] else "✓ ") + str(q["title"]), "id": q["id"], "dim": not q["active"]})
		[2, 1]:
			var ids := st.items.keys()
			ids.sort()
			for id in ids:
				if str(db.get(id, {}).get("tag", "")) == "퀘스트":
					out.append({"text": str(db[id]["name"]), "id": id})
	return out


func _quests() -> Array:
	var out: Array = []
	for id in st.quests.defs:
		var s := st.quests.stage(id)
		if s <= 0:
			continue
		out.append({"id": id, "title": st.quests.title(id), "active": s < 100, "stage": s})
	out.sort_custom(func(a, b): return a["active"] and not b["active"])
	return out


# ---------------------------------------------------------------- 그리기
func _draw_doc() -> void:
	rows = _rows()
	sel = clampi(sel, 0, maxi(0, rows.size() - 1))
	view.draw_rect(Rect2(Vector2(40, 28), Vector2(560, 304)), U[1])
	var on := clampf((t_open - OPEN_S) / ON_S, 0.0, 1.0)
	if on < 1.0:                                                         # 켜짐: 가운데 가로줄이 위아래로 벌어진다
		var h := maxf(2.0, 304.0 * on)
		view.draw_rect(Rect2(Vector2(40, 28), Vector2(560, 304)), U[0])
		view.draw_rect(Rect2(Vector2(40, 180 - h / 2.0), Vector2(560, h)), U[2] if on < 0.6 else U[1])
		fig.visible = false
		item("power", Rect2(614, 180, 20, 40))
		return
	# 주 탭
	var x := 56.0
	for i in TABS.size():
		var r := Rect2(x - 4, 32, 60, 16)
		item("tab%d" % i, r)
		if i == tab:
			view.draw_rect(r, U[7])
			text(Vector2(x, 33), TABS[i], f12b, 12, U[0])
		else:
			text(Vector2(x, 33), TABS[i], f12, 12, U[4])
		x += 72.0
	text(Vector2(470, 33), str(info.get("date", "")), f10, 10, U[4])
	text(Vector2(48, 51), _info_line(), f10, 10, U[5])
	text(Vector2(520, 51), "관제망", f10, 10, U[4])                       # 관제망 램프: 화면의 유일한 호박색(SD-12 §3.8)
	view.draw_circle(Vector2(569.5, 56.5), 3.5, Color("C47A12"))
	view.draw_rect(Rect2(568, 55, 1, 1), Color("FFC24A"))
	hline(48, 591, 66, U[3])
	# 하위 탭
	var subs: Array = SUBS[tab]
	var w := floorf(544.0 / subs.size())
	for i in subs.size():
		var sx := 48.0 + i * w
		var r := Rect2(sx + 2, 296, w - 5, 16)
		item("sub%d" % i, r)
		if i == sub[tab]:
			box(r, U[6], false)
			text(Vector2(sx + w / 2.0, 298), subs[i], f12, 12, U[6], HORIZONTAL_ALIGNMENT_CENTER)
		else:
			text(Vector2(sx + w / 2.0, 298), subs[i], f12, 12, U[3], HORIZONTAL_ALIGNMENT_CENTER)
	hline(48, 591, 313, U[2])
	# 목록(12px 행 15행)
	for i in rows.size():
		var y := 74.0 + i * 15.0
		if y > 282.0:
			break
		var rr := Rect2(48, y - 1, 199, 14)
		item("row%d" % i, rr)
		var row: Dictionary = rows[i]
		var col: Color = U[3] if row.get("dim", false) else U[5]
		if i == sel:
			view.draw_rect(rr, U[6])
			col = U[0]
		text(Vector2(52, y), row["text"], f12, 12, col)
		if row.get("right", "") != "":
			text(Vector2(242, y), row["right"], f12, 12, col, HORIZONTAL_ALIGNMENT_RIGHT)
	view.draw_line(Vector2(250.5, 70), Vector2(250.5, 290), U[2])
	fig.visible = false
	_detail()
	var hint := "[Tab] 닫기   [Q·E] 탭   [←→] 하위 탭   [↑↓] 선택   [Enter] " + _enter_label()
	if tab == 1 and sub[1] in [0, 2]:
		hint += "   [1~8] 단축키"
	if first:
		hint = "핍-보이: [Q·E] 능력치·아이템·데이터   [←→] 하위 탭   [Tab] 닫기"
	item("close", Rect2(44, 314, 50, 14))
	item("power", Rect2(614, 180, 20, 40))
	text(Vector2(48, 316), hint, f10, 10, U[4] if not first or fmod(time, 1.0) < 0.6 else U[6])


## 정보 줄(SD-12 §3.4): 능력치 = 레벨·HP·AP·XP / 아이템 = 무게·HP·DR·캡 / 데이터 = 위치
func _info_line() -> String:
	match tab:
		0:
			return "레벨 %d  |  HP %d/%d  |  AP %d/%d  |  XP %d/%d" % [int(info.get("level", 1)), int(info.get("hp", 0)), int(info.get("hp_max", 0)),
				int(info.get("ap", 0)), int(info.get("ap_max", 0)), int(info.get("xp", 0)), int(info.get("xp_next", 0))]
		1:
			return "무게 %s/%d  |  HP %d/%d  |  DR %d  |  캡 %d" % [_num(float(info.get("carry", 0))), int(info.get("carry_max", 0)),
				int(info.get("hp", 0)), int(info.get("hp_max", 0)), int(info.get("dr", 0)), int(info.get("caps", 0))]
	return "위치: " + str(info.get("place", ""))


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _enter_label() -> String:
	if rows.is_empty():
		return "—"
	match [tab, sub[tab]]:
		[0, 0]:
			return "스팀팩 사용"
		[1, 0]:
			return "해제" if rows[sel]["id"] == info.get("equipped", "") else "장착"
		[1, 1]:
			return "입는 중" if rows[sel]["id"] == info.get("worn", "") else "갈아입기"
		[1, 2]:
			return "사용"
	return "—"


func _detail() -> void:
	if rows.is_empty():
		text(Vector2(264, 78), "아직 없다." if [tab, sub[tab]] != [0, 3] else "레벨이 오르면 퍽을 고른다.", f12, 12, U[3])
		return
	var row: Dictionary = rows[sel]
	var id: String = row["id"]
	match [tab, sub[tab]]:
		[0, 0]:
			if id == "body":
				_body_page()
			elif id == "rad":
				text(Vector2(264, 78), "방사능 0", f12b, 12, U[6])
				_para(Vector2(264, 100), "볼트 안 공기 정화 정상. 라드어웨이 없음.", U[4])
			else:
				text(Vector2(264, 78), "효과 없음", f12b, 12, U[6])
				_para(Vector2(264, 100), "중독 없음 · 부위 손상 없음", U[4])
		[0, 1]:
			var tx: Dictionary = stats_text.get(id, {})
			var v := st.stat(id)
			text(Vector2(264, 78), "%s (%s)  %d" % [StoryState.STATS[id], id, v], f12b, 12, U[6])
			var y := _para(Vector2(264, 100), str(tx.get("desc", "")), U[5])
			y = _para(Vector2(264, y + 4), "관련: " + str(tx.get("skills", "")) + " · " + str(tx.get("effects", "")), U[4])
			text(Vector2(264, y + 6), "기본 %d   장비 +0   약물 +0" % v, f10, 10, U[5])
			var cm := CharDocs.comment(id, v)
			if cm != "":
				text(Vector2(264, y + 28), "생활기록부 · " + CharDocs.record_item(id), f10, 10, U[4])
				_para(Vector2(264, y + 42), "\"%s\"" % cm, U[6])
		[0, 2]:
			var nm: String = StoryState.SKILLS[id][0]
			var tx: Dictionary = skills_text.get(nm, {})
			text(Vector2(264, 78), "%s  %d%s" % [nm, st.skill(id), "  [태그]" if st.tagged(id) else ""], f12b, 12, U[6])
			text(Vector2(264, 96), "연관 능력치: " + StoryState.STATS[StoryState.SKILLS[id][1]], f10, 10, U[4])
			var y := _para(Vector2(264, 114), str(tx.get("desc", "")), U[5])
			_para(Vector2(264, y + 4), "쓰임: " + str(tx.get("uses", "")), U[4])
		[0, 3]:
			text(Vector2(264, 78), "관리 후보 1순위", f12b, 12, U[6])
			text(Vector2(264, 96), "특별 퍽 · 적성 평가 결과 통지서(2274)", f10, 10, U[4])
			var y := _para(Vector2(264, 114), "결과 통지서 맨 아래 칸에 처음부터 인쇄되어 있던 순위. 누가 무엇을 답해도 같다고 한다.", U[5])
			_para(Vector2(264, y + 4), "뜻을 알 수 없는 순위.", U[6])
		[0, 4]:
			_general_page(id)
		[1, _], [2, 1]:
			var it: Dictionary = db.get(id, {"name": id})
			text(Vector2(264, 78), str(it.get("name", id)), f12b, 12, U[6])
			var y := 98.0
			for kv in _item_lines(id, it):
				text(Vector2(264, y), kv[0], f10, 10, U[4])
				text(Vector2(588, y), kv[1], f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
				y += 14.0
			_para(Vector2(264, y + 8), str(it.get("desc", "")), U[5])
		[2, 0]:
			_quest_page(id)


func _item_lines(id: String, it: Dictionary) -> Array:
	var out: Array = []
	if it.has("dmg"):
		out.append(["DAM 피해", _num(float(it["dmg"]))])
	if it.get("mag") != null and it.has("mag"):
		out.append(["탄창", _num(float(it["mag"]))])
	if str(it.get("ammo", "")) not in ["", "—"]:
		out.append(["탄약", "%s (%d)" % [it["ammo"], int(st.items.get(str(it.get("ammo_id", "")), 0))]])
	if it.has("dr"):
		out.append(["DR", _num(float(it["dr"]))])
	if it.has("heal") and float(it["heal"]) > 0.0:
		out.append(["효과", "HP +%s" % _num(float(it["heal"]))])
	if it.has("tag"):
		out.append(["구분", "[%s]" % it["tag"]])
	out.append(["WG 무게", _num(float(it.get("weight", 0)))])
	out.append(["VAL 가치", _num(float(it.get("value", 0)))])
	if str(id).ends_with("탄"):
		out = [["보유", str(st.items.get(id, 0))]]
	return out


func _body_page() -> void:
	fig.visible = true
	fig.position = view.position + Vector2(376 - 4, 96)
	var parts := [["머리", 404, 78], ["오른팔", 300, 112], ["왼팔", 486, 112], ["몸통", 300, 160], ["오른다리", 300, 200], ["왼다리", 486, 200]]
	for p in parts:
		text(Vector2(p[1], p[2]), p[0], f10, 10, U[4])
		box(Rect2(p[1], p[2] + 12, 51, 5), U[3], false)
		view.draw_rect(Rect2(p[1] + 1, p[2] + 13, 48, 3), U[6])
	var hp := int(info.get("hp", 0))
	var mx := int(info.get("hp_max", 1))
	text(Vector2(264, 236), "HP %d / %d" % [hp, mx], f12, 12, U[6] if hp >= mx else U[5])
	var n := int(st.items.get(str(info.get("stimpak_id", "")), 0))
	text(Vector2(264, 254), "스팀팩 (%d)  사용하면 HP를 회복한다" % n, f12, 12, U[5] if n > 0 else U[3])
	text(Vector2(264, 272), "회복량 30 × (1 + 의학/50), 2초에 걸쳐", f10, 10, U[4])
	var rads := int(info.get("rads", 0))                                   # 방사능(SD-11 §11.2: 200 경미 · 400 심화 · 600 위험 · 800 치명 · 1000)
	var rl := "없음" if rads < 200 else ("경미" if rads < 400 else ("심화" if rads < 600 else ("위험" if rads < 800 else "치명")))
	text(Vector2(264, 290), "방사능 %d 라드 — %s" % [rads, rl], f12, 12, U[6] if rads < 200 else U[5])


## 일반(SD-12 §3.5): 등록 카드(맨 위, §3.8 단계 0) · 카르마 칭호와 막대(숫자는 숨김, SD-10 §6.1) · 통계
func _general_page(id: String) -> void:
	match id:
		"card":
			text(Vector2(264, 78), "볼트-텍 서울 S-07 주민 등록 카드", f12b, 12, U[6])
			hline(264, 588, 96, U[3])
			var lines := [["성명", st.player_full()], ["등록번호", str(st.vars.get_v("P_REGNO"))], ["출생", "2258. 03. 02."],
				["배정 구역", "제3 생활동"]]
			var stage := int(st.vars.get_v("V_REGCARD"))
			if stage >= 1:                                              # 단계 1(SD-12 §3.8): 적성 평가 줄에 관리 후보 1순위
				lines.append(["적성 평가", "관리 후보 1순위 (2274)"])
			var y := 104.0
			for kv in lines:
				text(Vector2(268, y), kv[0], f10, 10, U[4])
				text(Vector2(340, y), kv[1], f12, 12, U[5])
				y += 18.0
			text(Vector2(268, y + 6), "관리자 코드 칸 · 관제망 응답 칸 없음 (단계 %d)" % stage, f10, 10, U[3])
		"karma":
			var k := int(info.get("karma", 0))
			var band := "good" if k >= 250 else ("evil" if k <= -250 else "neutral")
			var row: Dictionary = karma_titles.get(str(int(info.get("level", 1))), {})
			text(Vector2(264, 78), str(row.get(band, "")), f12b, 12, U[6])
			text(Vector2(264, 96), {"good": "선함", "neutral": "중립", "evil": "악함"}[band], f10, 10, U[4])
			var bx := Rect2(264, 116, 320, 8)
			box(bx, U[3], false)
			var mid := bx.position.x + bx.size.x / 2.0
			var px := mid + clampf(k / 1000.0, -1.0, 1.0) * (bx.size.x / 2.0 - 2.0)
			view.draw_line(Vector2(mid, 114), Vector2(mid, 126), U[3])
			view.draw_rect(Rect2(px - 1, 113, 3, 14), U[6])
			text(Vector2(264, 130), "악", f10, 10, U[4])
			text(Vector2(584, 130), "선", f10, 10, U[4], HORIZONTAL_ALIGNMENT_RIGHT)
		"stats":
			var y := 78.0
			for kv in [["받은 퀘스트", str(_quests().size())], ["끝낸 퀘스트", str(_quests().filter(func(q): return not q["active"]).size())],
					["소지품 종류", str(st.items.size())]]:
				text(Vector2(264, y), kv[0], f10, 10, U[4])
				text(Vector2(588, y), kv[1], f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
				y += 14.0


func _quest_page(id: String) -> void:
	text(Vector2(264, 78), "[메인] " + st.quests.title(id), f12b, 12, U[6])
	var s := st.quests.stage(id)
	var y := 100.0
	var cur_n := _cur_stage(id, s)
	for n in st.quests.stages_of(id):
		if int(n) > s or int(n) >= 100:
			continue
		var line := st.quests.log_text(id, int(n))
		if line == "":
			continue
		var cur := int(n) == cur_n
		view.draw_rect(Rect2(266, y + 3, 6, 6), U[6] if cur else U[3], cur)
		if not cur:
			view.draw_line(Vector2(266, y + 9), Vector2(272, y + 3), U[5])
		y = _para(Vector2(280, y), "- " + line, U[6] if cur else U[3], 300.0) + 4.0


## 지금 하는 단계: 지금 단계 값 이하에서 기록이 있는 가장 큰 단계(끝난 퀘스트는 없음)
func _cur_stage(id: String, s: int) -> int:
	var best := 0
	for n in st.quests.stages_of(id):
		if int(n) <= s and st.quests.log_text(id, int(n)) != "":
			best = maxi(best, int(n))
	return best if s < 100 else -1


## 줄바꿈 글. 돌려줌: 다음 줄 y
func _para(p: Vector2, s: String, col: Color, w := 320.0) -> float:
	var y := p.y
	for ln in TextWrap.wrap(s, func(t: String) -> float: return tw(t, f10, 10), w):
		text(Vector2(p.x, y), ln, f10, 10, col)
		y += 14.0
	return y


# ---------------------------------------------------------------- 입력
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	var k: int = e.keycode if e is InputEventKey and e.pressed and not e.echo else -1
	if k in [KEY_TAB, KEY_ESCAPE]:
		close(true)
	elif k == KEY_Q:
		_tab(tab - 1)
	elif k == KEY_E:
		_tab(tab + 1)
	elif k in [KEY_F1, KEY_F2, KEY_F3]:
		_tab(k - KEY_F1)
	elif k == KEY_J:
		open_at(2, 0)
	elif k >= KEY_1 and k <= KEY_8:
		if tab == 1 and sub[1] in [0, 2] and not rows.is_empty():
			action.emit("hotkey:%d" % (k - KEY_0), rows[sel]["id"])
	elif e.is_action_pressed("ui_left", true):
		_sub(-1)
	elif e.is_action_pressed("ui_right", true):
		_sub(1)
	elif e.is_action_pressed("ui_up", true):
		sel = maxi(0, sel - 1)
	elif e.is_action_pressed("ui_down", true):
		sel = mini(rows.size() - 1, sel + 1)
	elif e.is_action_pressed("ui_accept"):
		_enter()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := _item_at(_local(e.position))
		if i >= 0:
			_press(items[i]["id"])
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		sel = clampi(sel + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, rows.size() - 1))
	else:
		handled = false
	if handled:
		if e is InputEventKey or e is InputEventMouseButton:
			first = false
		get_viewport().set_input_as_handled()
		view.queue_redraw()


func _press(id: String) -> void:
	if id.begins_with("tab"):
		_tab(int(id.substr(3)))
	elif id.begins_with("sub"):
		sub[tab] = int(id.substr(3))
		sel = 0
	elif id.begins_with("row"):
		var i := int(id.substr(3))
		if i == sel:
			_enter()
		sel = i
	elif id in ["close", "power"]:
		close(true)


func _tab(i: int) -> void:
	tab = posmod(i, TABS.size())
	sel = 0


func _sub(d: int) -> void:
	sub[tab] = posmod(sub[tab] + d, SUBS[tab].size())
	sel = 0


func _enter() -> void:
	rows = _rows()
	if rows.is_empty():
		return
	var id: String = rows[sel]["id"]
	match [tab, sub[tab]]:
		[0, 0]:
			action.emit("use", str(info.get("stimpak_id", "")))
		[1, 0]:
			action.emit("unequip" if id == info.get("equipped", "") else "equip", id)
		[1, 1]:
			if id != info.get("worn", ""):
				action.emit("equip", id)                                   # 옷 갈아입기(0-10, 몸통 슬롯 하나)
		[1, 2]:
			action.emit("use", id)
