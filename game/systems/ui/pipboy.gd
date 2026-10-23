## 핍-보이 3000 (SD-12 §3, 견본 art/samples/07_pipboy_stat.png): 기기 틀 + 초록 CRT(U 팔레트), 주 탭 3개(능력치·아이템·데이터).
##   능력치: 상태(주민 그림·부위 막대·스팀팩) · S.P.E.C.I.A.L.(SD-10 §2.2 정의 + 생활기록부 문구) · 스킬 · 퍽 · 일반(카르마·등록 카드)
##   아이템: 무기 · 의복 · 구호품 · 잡화 · 탄약 (결정 = 장착/해제·사용, 1~8 = 단축키 지정)
##   데이터: 지역 지도 · 월드 지도(빠른 이동, 1-2 — systems/ui/pip_map.gd) · 퀘스트 · 기록
##   데이터 > 라디오(1-10b, SD-12 §10.6): 방송국 목록(범위 밖 `(수신 불가)`) · 상세(로고 48×48 · 코너 · 진행자 · 신호) · 지난 소식 20 · 방송 기록
##   데이터 > 세력(1-12m, SD-12 §3.10 · SD-16 §9.6 — systems/ui/faction_tab.gd): 만난 세력 · 휘장 상태 그림 · 관계 한 줄 · 대우 · 들리는 말 · 최근 일 · [Enter] 판도 지도
## 조작(SD-12 §3.2·§13.8): Tab·Esc 닫기, Q·E 주 탭, ←→ 하위 탭, ↑↓ 목록, Enter 사용, F1·F2·F3 주 탭 바로, J 퀘스트.
## 마우스·터치(마우스 흉내): 탭·하위 탭·줄을 누르고(고른 줄을 다시 누르면 사용), 아래 줄 [닫기]·오른쪽 위 전원 단추를 누르면 닫힌다.
## 열 때(§3.2): 기기가 아래에서 0.2초 올라오고 화면이 0.15초 켜진다(가로 주사선이 위아래로 벌어짐). 열어 둔 동안 시간이 멈춘다.
class_name PipBoy
extends DocScreen

signal action(kind: String, id: String)              ## "equip"·"unequip"·"use"·"hotkey:n" — 받는 쪽(전투·소지품)이 처리한다

const U := DocScreen.GREEN
const TABS := ["능력치", "아이템", "데이터"]
const SUBS := [["상태", "S.P.E.C.I.A.L.", "스킬", "퍽", "일반"], ["무기", "의복", "구호품", "잡화", "탄약"], ["지역 지도", "월드 지도", "퀘스트", "기록", "라디오", "세력"]]
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
var map: PipMap                                      ## 지도 화면(데이터 탭 지역·월드 지도)
var book_filter := 0                                 ## 인물 수첩 거르기(NpcBook.FILTERS)
var book_q := ""                                     ## 인물 수첩 이름 찾기(초성 가능)
var searching := false                               ## 찾기 글자를 받는 중('/'로 시작, Enter·Esc로 끝)
var lv_on := false                                   ## 능력치 > 퍽: 레벨업 화면(1-12p — systems/ui/level_tab.gd)
var face: TextureRect                                ## 인물 수첩 얼굴(48×48 — 그림은 노드로 얹는다, DocScreen 머리글)
static var svc_icons: Texture2D


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
	face = TextureRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.size = Vector2(48, 48)
	face.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://systems/ui/crt_mono.gdshader")
	face.material = mat
	add_child(face)
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
	toast_t = maxf(0.0, toast_t - dt)


## 핍-보이 안 한 줄 알림(수리 결과 등 — 화면 뒤 HUD 알림은 핍-보이에 가린다)
var toast := ""
var toast_t := 0.0


func say(t: String) -> void:
	toast = t
	toast_t = 3.0


## 열쇠가 바뀐 줄(수리로 '낡음' → '양호')을 다시 고른다
func select_id(id: String) -> void:
	rows = _rows()
	for i in rows.size():
		if str(rows[i]["id"]) == id:
			sel = i
			return


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
		[0, 3]:                                                         # 퍽(1-12p): 미배분 레벨업 줄 · 가진 퍽(특별 퍽 관리 후보 1순위 PK-103 포함)
			out = LevelTab.perk_rows(self)
		[0, 4]:
			out = [{"text": "등록 카드", "id": "card"}, {"text": "카르마", "id": "karma"}]
			if st.quests.cur_act() >= 1:                                  # 수배(SD-12 §9.7, 1-3): 볼트를 나온 뒤
				out.append({"text": "수배", "id": "wanted", "right": Wanted.NAMES[Wanted.grade(st)]})
			out.append({"text": "통계", "id": "stats"})
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
				var on: bool = id == info.get("equipped", "") or id == info.get("worn", "") or id == info.get("head", "") or id == info.get("eyes", "")
				var hk := ""
				for k in info.get("hotkeys", {}):
					if info["hotkeys"][k] == id:
						hk = " (%d)" % int(k)
				var nm := str(it.get("name", id))
				if Gear.cond(id) == 0 and Gear.is_gear(it):
					nm += " (새것)"                                         # 상태는 늘 이름 뒤 괄호(SD-13 §8.1, SD-18 §7.1)
				out.append({"text": nm + (" (%d)" % n if n > 1 and cat != "ammo" else "") + (" [장착]" if on else ""),
					"id": id, "right": (str(n) if cat == "ammo" else hk.strip_edges()), "dim": Gear.cond(id) >= 4})
		[2, 2]:
			out = _quest_rows()
		[2, 3]:
			out = _record_rows()
		[2, 4]:
			out = _radio_rows()
		[2, 5]:
			out = FactionTab.rows(self)
	return out


## 라디오 목록: 방송국(켜짐 · 수신 불가) + 지난 소식 + 방송 기록
func _radio_rows() -> Array:
	var r: Radio = st.radio
	var ctx: Dictionary = info.get("radio", {})
	var out: Array = []
	for sid in r.listed(ctx):
		var q := Radio.quality(sid, ctx)
		out.append({"text": Radio.station_name(sid), "id": sid, "dim": q < 0,
			"right": "(수신 불가)" if q < 0 else ("켜짐" if r.on and r.tuned == sid else "")})
	if not r.news_log.is_empty():
		out.append({"text": "지난 소식", "id": "past", "right": str(r.news_log.size())})
	if not r.air_log.is_empty():
		out.append({"text": "방송 기록", "id": "log", "right": str(r.air_log.size())})
	return out


## 퀘스트 목록(SD-12 §3.12): 메인(지금 막 머리 + 그 막 퀘스트 → 지난 막은 머리 한 줄로 접힘) · 단서(아직 오지 않은 막에서 먼저 시작한 퀘스트) ·
## 세력의 일(FQ) · 사이드(SQ) · 기타(RQ). 비표시(UQ)는 없음. 묶음 이름 줄은 id ""(고를 수 없다). 표식: ▶ 추적 · ◆ 고정
func _quest_rows() -> Array:
	var q := st.quests
	var out: Array = []
	var cur := q.cur_act()
	var listed := {}
	var a := q.act_def(cur)
	if not a.is_empty():
		out.append({"text": _qmark("act:%d" % cur, "") + "[메인] " + str(a["name"]), "id": "act:%d" % cur, "right": _short(q.act_tag(cur))})
		var shown: Array = []
		for id in a["quests"]:
			listed[id] = true
			var rumor := false
			for lid in q.places_of(id):
				rumor = rumor or st.places.get_state(lid) >= PlaceLog.RUMOR
			if q.stage(id) > 0 or (q.defs.get(id, {}).get("path", false) and rumor):   # 시작 안 한 경로는 장소 소문이라도 있어야 보인다
				shown.append(id)
		for i in shown.size():
			var id: String = shown[i]
			out.append({"text": _qmark(id, "└ " if i == shown.size() - 1 else "├ ") + q.title(id), "id": id, "right": _short(q.path_tag(id)),
				"dim": q.stage(id) >= 100})
	for n in range(cur - 1, -1, -1):                                     # 지난 막(접힘)
		var pa := q.act_def(n)
		if pa.is_empty():
			continue
		for id in pa["quests"]:
			listed[id] = true
		out.append({"text": _qmark("act:%d" % n, "") + "[메인] " + str(pa["name"]), "id": "act:%d" % n, "right": _short(q.act_tag(n)), "dim": true})
	var groups := {"단서": [], "세력의 일": [], "사이드": [], "기타": []}
	for id in q.defs:
		if listed.has(id) or q.stage(id) <= 0 or id.begins_with("UQ"):
			continue
		var g := "단서" if id.begins_with("MQ") else ("세력의 일" if id.begins_with("FQ") else ("사이드" if id.begins_with("SQ") else "기타"))
		groups[g].append(id)
	for g in ["단서", "세력의 일", "사이드", "기타"]:
		if groups[g].is_empty():
			continue
		out.append({"text": "— " + g, "id": "", "dim": true})
		var ids: Array = groups[g]
		ids.sort_custom(func(x, y): return q.stage(x) < 100 and q.stage(y) >= 100)   # 진행 중 → 끝난 것
		for id in ids:
			out.append({"text": _qmark(id, "  ") + q.title(id), "id": id, "right": _short(q.path_tag(id)), "dim": q.stage(id) >= 100})
	var memo: Array = []                                                  # 비표시 퀘스트(SD-05 §2.6): 제목 없이 '메모'에 사실 한 줄 · 끝나면 흐려지고 7게임일 뒤 사라진다
	for id in q.defs:
		if not id.begins_with("UQ") or q.stage(id) <= 0:
			continue
		var fin: Dictionary = st.boxes.get("uqdone:" + id, {})
		if q.stage(id) >= 100 and not fin.is_empty() and int(st.vars.get_v("GAME_DAY")) - int(fin["day"]) > 7:
			continue
		memo.append({"text": "  - " + q.log_text(id, q.stage(id)), "id": "", "dim": q.stage(id) >= 100})
	if not memo.is_empty():
		out.append({"text": "— 기타 · 메모", "id": "", "dim": true})
		out.append_array(memo)
	return out


func _qmark(id: String, plain: String) -> String:
	if id == st.quests.tracked:
		return "▶ " if plain != "" else "▶"
	if id in st.quests.pinned:
		return "◆ " if plain != "" else "◆"
	return plain


## 기록(SD-12 §3.2 데이터 > 기록): 문서(퀘스트 문서) · 인물 수첩(§3.11, 최근 만난 순 — [S] 거르기 · [/] 이름·초성 찾기)
func _record_rows() -> Array:
	var out: Array = []
	var ids := st.items.keys()
	ids.sort()
	var docs: Array = []
	for id in ids:
		if str(db.get(id, {}).get("tag", "")) == "퀘스트":
			docs.append({"text": str(db[id]["name"]), "id": id})
	var book: NpcBook = st.book
	var people := book.list(book_filter, _region(), book_q, _active_quests())
	var hid := StashBook.rows(st, str(info.get("date", "")), StashBook.here(info.get("tile", Vector2(-1, -1)), str(info.get("map_id", ""))), db)   # 숨겨 둔 자리(1-12o D-225) — 실내에서도 가까운 순
	if not docs.is_empty() and (not book.entries.is_empty() or not hid.is_empty()):
		out.append({"text": "— 문서", "id": "", "dim": true})
	out.append_array(docs)
	if not hid.is_empty():
		out.append({"text": "— 숨겨 둔 자리 %d/%d" % [StashBook.count(st), StashBook.MAX], "id": "", "dim": true})
		var safe_head := false
		for r in hid:
			if bool(r["safe"]) and not safe_head:
				safe_head = true
				out.append({"text": "— 맡긴 자리", "id": "", "dim": true})
			out.append({"text": _fit(str(r["text"]), 178.0 - tw(str(r["right"]), f12b, 12)), "id": r["id"], "right": str(r["right"]), "dim": false})
	if not book.entries.is_empty() or book_q != "":
		var head := "— 인물 수첩 %d" % people.size()
		if book_filter > 0:
			head += " · " + NpcBook.FILTERS[book_filter]
		if book_q != "" or searching:
			head += " · '%s%s'" % [book_q, "_" if searching and fmod(time, 1.0) < 0.5 else ""]
		out.append({"text": head, "id": "", "dim": true})
		for c in people:
			var e: Dictionary = book.entries[c]
			var dead := str(e["dead"]) != ""
			out.append({"text": str(book.info(c).get("name", c)), "id": "npc:" + c, "right": "고인" if dead else _fit(book.title(c), 116.0),
				"dim": dead})
	return out


## 지금 권역 코드(인물 수첩 '이 권역' 거르기)
func _region() -> String:
	var t: Vector2 = info.get("tile", Vector2(-1, -1))
	if t.x < 0:
		return "R01"
	PipMap._load()
	return str(PipMap.regions.get("%d,%d" % [int(t.x) / 40, int(t.y) / 40], "R01"))


func _active_quests() -> Array:
	var out: Array = []
	for id in st.quests.defs:
		if st.quests.stage(id) > 0 and st.quests.stage(id) < 100:
			out.append(id)
	return out


## 글을 폭 w(px, 12px 글꼴)에 맞춰 자른다
func _fit(t: String, w: float) -> String:
	if tw(t, f12, 12) <= w:
		return t
	var n := t.length()
	while n > 1 and tw(t.substr(0, n) + "…", f12, 12) > w:
		n -= 1
	return t.substr(0, n).strip_edges() + "…"


## 목록 오른쪽 칸은 좁아서 상태를 줄여 쓴다(상세 쪽은 원래 표기)
static func _short(tag: String) -> String:
	return {"[진행 중]": "진행", "[이룸]": "이룸", "[다른 길로 이룸]": "다른 길", "[끝남]": "끝남", "[놓침]": "놓침", "[알려진 것 없음]": "?",
		"[선택]": "선택"}.get(tag, "")


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
		var lab: String = subs[i] + (" ▲" if tab == 0 and i == 3 and Perks.pending(st) > 0 else "")   # 미배분 레벨업(1-12p)
		if i == sub[tab]:
			box(r, U[6], false)
			text(Vector2(sx + w / 2.0, 298), lab, f12, 12, U[6], HORIZONTAL_ALIGNMENT_CENTER)
		else:
			text(Vector2(sx + w / 2.0, 298), lab, f12, 12, U[3], HORIZONTAL_ALIGNMENT_CENTER)
	hline(48, 591, 313, U[2])
	if _map_mode():                                                      # 지역·월드 지도(1-2): 목록·상세 대신 지도 한 장
		if map == null:
			map = PipMap.new(self)
		item("map", PipMap.AREA)
		if sub[2] == 0:
			map.draw_local()
		else:
			map.draw_world()
		fig.visible = false
		var mh := "[Tab] 닫기   [Q·E] 탭   [Shift+←→] 하위 탭" + ("   [방향키] 커서   [Z·X] 확대   [Enter] 빠른 이동   [G] 판도" if sub[2] == 1 else "")
		item("close", Rect2(44, 314, 50, 14))
		item("power", Rect2(614, 180, 20, 40))
		text(Vector2(48, 316), mh, f10, 10, U[4])
		var gat := mh.find("[G] 판도")
		if gat >= 0:                                                     # 터치: 안내 줄 '[G] 판도'를 누르면 레이어를 켜고 끈다
			item("turf", Rect2(48 + tw(mh.substr(0, gat), f10, 10) - 2, 314, tw("[G] 판도", f10, 10) + 4, 14))
		return
	if lv_on and tab == 0 and sub[0] == 3:                               # 레벨업 화면(1-12p): 목록 · 상세 대신
		fig.visible = false
		face.visible = false
		LevelTab.draw(self)
		if lv_on:
			var lh := LevelTab.hint(self)
			if toast_t > 0.0:
				view.draw_rect(Rect2(258, 250, 334, 16), U[0])
				text(Vector2(262, 252), _fit(toast, 326.0), f10, 10, U[6])
			item("close", Rect2(44, 314, 50, 14))
			item("power", Rect2(614, 180, 20, 40))
			text(Vector2(48, 316), lh, f10, 10, U[4])
			return
		rows = _rows()
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
		var ix := 52.0
		if int(row.get("icon", -1)) >= 0:                                 # 세력 휘장 16×16(SD-16 §9.6 목록)
			FactionTab._load()
			ix = 70.0 + (8.0 if row.get("sub", false) else 0.0)
			view.draw_texture_rect_region(FactionTab.emb16, Rect2(ix - 18, y - 2, 16, 16), Rect2(int(row["icon"]) * 16, 0, 16, 16), col)
			text(Vector2(ix, y), str(row["text"]).strip_edges(), f12, 12, col)
		else:
			text(Vector2(52, y), row["text"], f12, 12, col)
		if row.get("right", "") != "":
			text(Vector2(242, y), row["right"], f12, 12, col, HORIZONTAL_ALIGNMENT_RIGHT)
	view.draw_line(Vector2(250.5, 70), Vector2(250.5, 290), U[2])
	fig.visible = false
	face.visible = false
	_detail()
	var hint := "[Tab] 닫기   [Q·E] 탭   [←→] 하위 탭   [↑↓] 선택   [Enter] " + _enter_label()
	if tab == 1 and sub[1] in [0, 2]:
		hint += "   [1~8] 단축키"
	if tab == 1 and sub[1] in [0, 1] and not rows.is_empty() and Gear.cond(str(rows[sel]["id"])) > 0:
		hint += "   [R] 수리"
	if tab == 2 and sub[2] == 2:
		hint = "[Tab] 닫기   [Q·E] 탭   [←→] 하위 탭   [↑↓] 선택   [Enter] %s   [F] 고정" % _enter_label()
	if tab == 2 and sub[2] == 3 and not st.book.entries.is_empty():
		hint = "[Tab] 닫기   [←→] 하위 탭   [↑↓] 선택   [Enter] %s   [S] 거르기   [/] 찾기" % _enter_label()
		if searching:
			hint = "이름 찾기: 글자·초성(ㅂㅇㅎ)을 치세요   [Backspace] 지우기   [Enter·Esc] 끝"
	if first:
		hint = "핍-보이: [Q·E] 능력치·아이템·데이터   [←→] 하위 탭   [Tab] 닫기"
	if toast_t > 0.0:
		view.draw_rect(Rect2(258, 274, 334, 16), U[0])
		text(Vector2(262, 276), toast, f10, 10, U[6])
	item("close", Rect2(44, 314, 50, 14))
	item("power", Rect2(614, 180, 20, 40))
	text(Vector2(48, 316), hint, f10, 10, U[4] if not first or fmod(time, 1.0) < 0.6 else U[6])
	for kv in [["[F] 고정", "pin"], ["[S] 거르기", "filter"], ["[/] 찾기", "find"], ["[R] 수리", "repair"]]:   # 터치: 안내 줄의 이 글자를 누르면 그 키와 같다
		var at := hint.find(kv[0])
		if at >= 0 and not first:
			item(kv[1], Rect2(48 + tw(hint.substr(0, at), f10, 10) - 2, 314, tw(kv[0], f10, 10) + 4, 14))


func _map_mode() -> bool:
	return tab == 2 and sub[2] in [0, 1]


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


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## 살펴볼 장면이 있는 물건(원고 EXAMINE_<붙임표 뺀 ID> — 인식표 M-158 등, SD-04a §4.1 단계 40)
static func examinable(id: String) -> bool:
	return id != "" and FileAccess.file_exists("res://data/dialogue/EXAMINE_%s.json" % Gear.base(id).replace("-", ""))


func _enter_label() -> String:
	if rows.is_empty():
		return "—"
	match [tab, sub[tab]]:
		[0, 0]:
			return "스팀팩 사용"
		[0, 3]:
			return "레벨업 시작" if rows[sel]["id"] == "lvup" else "—"
		[1, 0]:
			return "해제" if rows[sel]["id"] == info.get("equipped", "") else "장착"
		[1, 1]:
			var rid: String = rows[sel]["id"]
			if rid == info.get("head", "") or rid == info.get("eyes", ""):
				return "벗기"                                                    # 머리 · 눈 장비(1-D6 방독면 · 1-11e 구울 가면)는 다시 고르면 벗는다
			return "입는 중" if rid == info.get("worn", "") else "갈아입기"
		[1, 2]:
			return "사용"
		[1, 3]:
			if rows[sel]["id"] == Craft.BURNER:
				return "조리"
			return "살펴보기" if PipBoy.examinable(str(rows[sel]["id"])) else "—"
		[2, 2]:
			return "—" if rows[sel]["id"] == "" else ("추적 끄기" if rows[sel]["id"] == st.quests.tracked else "추적")
		[2, 4]:
			var rid := str(rows[sel]["id"])
			if rid in ["past", "log"]:
				return "—"
			if Radio.quality(rid, info.get("radio", {})) < 0:
				return "—"
			return "끄기" if st.radio.on and st.radio.tuned == rid else "켜기"
		[2, 3]:
			var rid2 := str(rows[sel]["id"])
			if rid2.begins_with("stash:") or rid2.begins_with("safe:"):
				return "지도에서 보기" if StashBook.at_of(st, rid2).x >= 0 else "—"
			return "지도에서 보기" if _npc_lid(rid2) != "" else "—"
		[2, 5]:
			return "판도 지도"
	return "—"


static var radio_logos: Texture2D


## 라디오 상세(SD-12 §10.6): 로고 48×48(1비트, CRT 단색) · 이름 · 진행자 · 신호 · 지금 코너 · 지금 줄 / 지난 소식 · 방송 기록
func _radio_page(id: String) -> void:
	var r: Radio = st.radio
	var ctx: Dictionary = info.get("radio", {})
	if id in ["past", "log"]:
		var rows_: Array = r.news_log if id == "past" else r.air_log
		text(Vector2(264, 78), "지난 소식" if id == "past" else "방송 기록(최근 블록)", f12b, 12, U[6])
		var y := 98.0
		for e in rows_:
			if y > 262.0:
				break
			var head := "[%s] %s" % [Radio.station_short(str(e["st"])), str(e.get("date", "")).get_slice("  ", 0)]
			text(Vector2(264, y), head, f10, 10, U[4])
			y += 13.0
			var ls: Array = e["lines"]
			var body := " ".join(ls.slice(0, 3).map(func(l): return str(l[1])))
			y = _para(Vector2(272, y), body, U[5], 312.0) + 4.0
		return
	var q := Radio.quality(id, ctx)
	if radio_logos == null and ResourceLoader.exists("res://assets/ui/radio_logos.png"):
		radio_logos = load("res://assets/ui/radio_logos.png")
	box(Rect2(263, 77, 50, 50), U[3], false)
	if radio_logos != null:
		var at := AtlasTexture.new()
		at.atlas = radio_logos
		at.region = Rect2(Radio.ORDER.find(id) * 48, 0, 48, 48)
		face.texture = at
		face.position = view.position + Vector2(264, 78)
		face.modulate = Color(1, 1, 1, 1.0 if q >= 0 else 0.45)
		face.visible = true
	text(Vector2(322, 78), Radio.station_name(id), f12b, 12, U[6] if q >= 0 else U[3])
	text(Vector2(322, 96), "진행: " + Radio.station_host(id), f10, 10, U[5])
	text(Vector2(322, 110), "신호: " + ("수신 불가" if q < 0 else Radio.Q_NAME[q]), f10, 10, U[4])
	var y := 136.0
	text(Vector2(264, y), "지금: " + (r.corner(id) if q >= 0 else "—"), f10, 10, U[5])
	y += 16.0
	if r.on and r.tuned == id:
		var np := r.now_playing()
		if str(np.get("kind", "")) in ["line", "gap"]:
			y = _para(Vector2(264, y), "%s: %s" % [str(np["who"]), Radio.garble(str(np["text"]), q)], U[6], 320.0)
	else:
		y = _para(Vector2(264, y), "[Enter] 이 방송국에 맞춰 켠다. 꺼 두어도 방송은 흐른다.", U[4], 320.0)
	text(Vector2(264, 262), "필드: R 길게 = 켜기 · 끄기  /  음악 없음 — 자막 방송", f10, 10, U[3])


func _detail() -> void:
	if rows.is_empty():
		text(Vector2(264, 78), "아직 없다." if [tab, sub[tab]] != [0, 3] else "레벨이 오르면 퍽을 하나씩 고른다.", f12, 12, U[3])
		return
	var row: Dictionary = rows[sel]
	var id: String = row["id"]
	match [tab, sub[tab]]:
		[2, 4]:
			_radio_page(id)
		[2, 5]:
			FactionTab.page(self, id)
		[0, 0]:
			if id == "body":
				_body_page()
			elif id == "rad":
				_rad_page()
			else:
				_effects_page()
		[0, 1]:
			var tx: Dictionary = stats_text.get(id, {})
			var v := st.stat(id)
			text(Vector2(264, 78), "%s (%s)  %d" % [StoryState.STATS[id], id, v], f12b, 12, U[6])
			var y := _para(Vector2(264, 100), str(tx.get("desc", "")), U[5])
			y = _para(Vector2(264, y + 4), "관련: " + str(tx.get("skills", "")) + " · " + str(tx.get("effects", "")), U[4])
			var rp := st.stat_base(id) - v                                   # 방사능 단계 감소(1-9d)
			text(Vector2(264, y + 6), ("기본 %d   장비 +0   약물 +0" % st.stat_base(id)) + (("   방사능 −%d" % rp) if rp > 0 else ""), f10, 10, U[5])
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
			LevelTab.perk_page(self, id)
		[0, 4]:
			_general_page(id)
		[2, 3] when id.begins_with("npc:"):
			_npc_page(id.substr(4))
		[2, 3] when id.begins_with("stash:") or id.begins_with("safe:"):
			_stash_page(id)
		[1, _], [2, 3]:
			if id == "":
				return
			var it: Dictionary = db.get(id, {"name": id})
			text(Vector2(264, 78), str(it.get("name", id)), f12b, 12, U[6])
			var y := 98.0
			for kv in _item_lines(id, it):
				text(Vector2(264, y), kv[0], f10, 10, U[4])
				text(Vector2(588, y), kv[1], f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
				y += 14.0
			_para(Vector2(264, y + 8), str(it.get("desc", "")), U[5])
		[2, 2]:
			if id.begins_with("act:"):
				_act_page(int(id.substr(4)))
			elif id != "":
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
	if Gear.is_gear(it):                                                 # 상태 4칸 막대(SD-11 §12.5) + 이번 단계 닳은 정도
		var c := Gear.cond(id)
		var per := Gear.stage_of(id)
		var used := int(st.wear.get(id, 0))
		var bar := "■".repeat(4 - c) + "□".repeat(c)
		out.append(["상태", "%s %s%s" % [bar, Gear.NAMES[c], "" if c >= 4 or per <= 0 else " · %d%%" % roundi(100.0 * (per - used) / per)]])
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


## 방사능(SD-11 §11.2, 1-9d): 라드 · 단계 막대(200씩) · 지금 깎인 능력치 · 저항 내역 · 약 남은 시간 · 라드어웨이 수 · 피폭 중이면 초당 라드
func _rad_page() -> void:
	var rads := int(info.get("rads", 0))
	var stg := Radiation.stage(rads)
	text(Vector2(264, 78), "방사능 %d 라드" % rads, f12b, 12, U[6] if stg == 0 else U[5])
	text(Vector2(264, 96), Radiation.NAMES[stg], f12, 12, U[5] if stg == 0 else Color("E04A35"))
	for i in 5:                                                           # 0~1,000 막대: 단계 칸 다섯
		var r := Rect2(264 + i * 64, 116, 60, 8)
		box(r, U[3], false)
		var f := clampf(float(rads - i * 200) / 200.0, 0.0, 1.0)
		if f > 0.0:
			view.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(58 * f, 6)), U[6] if i < 2 else Color("E04A35"))
		text(Vector2(264 + i * 64, 128), "%s %d" % [Radiation.SHORT[i + 1], (i + 1) * 200], f10, 10, U[4], HORIZONTAL_ALIGNMENT_RIGHT, 60.0)   # 칸 끝 = 다음 단계 문턱
	var pen: Dictionary = Radiation.PEN[stg]
	var parts: Array = []
	for k in ["EN", "AG", "ST"]:
		if pen.has(k):
			parts.append("%s −%d" % [StoryState.STATS[k], int(pen[k])])
	text(Vector2(264, 150), "효과: " + (" · ".join(parts) if not parts.is_empty() else "없음"), f12, 12, U[5])
	var res := float(info.get("rad_res", 0.0)) * 100.0
	text(Vector2(264, 170), "방사능 저항 %d%%  (지구력 %d%%%s)" % [roundi(res), (st.stat_base("EN") - 1) * 2,
		("  약 +%d%%" % roundi(float(st.rad_drug.get("pct", 0.0)))) if not st.rad_drug.is_empty() else ""], f12, 12, U[5])
	if not st.rad_drug.is_empty():
		var t := int(float(st.rad_drug.get("t", 0.0)))
		text(Vector2(264, 188), "%s 남은 시간 %d:%02d" % [str(items_db_name(str(st.rad_drug.get("id", "")))), t / 60, t % 60], f10, 10, U[4])
	var rr := float(info.get("rad_rate", 0.0))
	if rr > 0.0:
		text(Vector2(264, 206), "지금 피폭 중: 초당 %.1f 라드" % rr, f12, 12, Color("E04A35"))
	text(Vector2(264, 236), "라드어웨이 (%d)  라드 −50 × (1 + 의학/50)" % int(st.items.get("I-002", 0)), f12, 12, U[5] if int(st.items.get("I-002", 0)) > 0 else U[3])
	text(Vector2(264, 254), "라드-X (%d)  저항 +25 × (1 + 의학/50)%% · 4분" % int(st.items.get("I-003", 0)), f12, 12, U[5] if int(st.items.get("I-003", 0)) > 0 else U[3])
	_para(Vector2(264, 276), "라드는 저절로 빠지지 않는다. 1,000 라드면 죽는다. 의사에게 빼거나 라드어웨이를 먹을 것.", U[4])


func items_db_name(id: String) -> String:
	return {"I-003": "라드-X", "I-005": "갑상선 방호정", "I-093": "노래하는 알약"}.get(id, id)


## 효과: 방사능 단계 · 약 효과(중독 · 부위 손상은 그 단계에서)
func _effects_page() -> void:
	var rows: Array = []
	var stg := Radiation.stage(int(info.get("rads", 0)))
	if stg > 0:
		rows.append(Radiation.NAMES[stg])
	if not st.rad_drug.is_empty():
		rows.append("%s — 방사능 저항 +%d%%" % [items_db_name(str(st.rad_drug.get("id", ""))), roundi(float(st.rad_drug.get("pct", 0.0)))])
	if rows.is_empty():
		text(Vector2(264, 78), "효과 없음", f12b, 12, U[6])
		_para(Vector2(264, 100), "중독 없음 · 부위 손상 없음", U[4])
		return
	text(Vector2(264, 78), "효과 %d" % rows.size(), f12b, 12, U[6])
	var y := 100.0
	for r in rows:
		text(Vector2(264, y), "· " + r, f12, 12, U[5])
		y += 18.0


## 관리자 코드 줄(SD-12 §3.8 `####-####-##`): 깨진 글자 도트 4종을 시간으로 돌리고, 끝 두 자리만 숫자로 읽힌다 — 여의도 지하 벙커 청크 (20, 27)
## (SD-03a §8.2 단서 2 '주인공이 지도를 직접 보고 추론' · 하숙자 "이 줄 끝의 숫자 둘… 좌표 같은데", 1-12k D-046)
const CARD_CHUNK := Vector2i(20, 27)
const CARD_GLYPHS := "▚▞▙▜"


static func card_code(t: float) -> String:
	var s := ""
	for k in 8:
		s += CARD_GLYPHS[(int(t * 3.0) + k * 7) % 4]
		if k == 3:
			s += "-"
	return "%s-%d %d" % [s, CARD_CHUNK.x, CARD_CHUNK.y]


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
			if stage < 2:
				text(Vector2(268, y + 6), "관리자 코드 칸 · 관제망 응답 칸 없음 (단계 %d)" % stage, f10, 10, U[3])
			else:                                                       # 단계 2~4(SD-12 §3.8 배치): 관리자 코드 · 관제망 응답 · 비고
				hline(264, 588, y + 2, U[3])
				y += 8.0
				text(Vector2(268, y), "관리자 코드", f10, 10, U[4])
				if stage >= 4:
					text(Vector2(340, y), "수도 관제망 등록 관리자 / 인증 등급: 후보", f12, 12, U[6])
				else:
					text(Vector2(340, y), card_code(time), f12, 12, U[5])
					text(Vector2(340, y + 13), "[판독 불가]", f10, 10, U[3])
				y += 26.0
				text(Vector2(268, y), "관제망 응답", f10, 10, U[4])
				text(Vector2(340, y), "대기  ○", f12, 12, U[5])
				y += 18.0
				if stage == 3:
					text(Vector2(268, y), "비고", f10, 10, U[4])
					text(Vector2(340, y), "읽을 수 있는 사람이 필요하다", f12, 12, U[5])
				elif stage >= 4:
					text(Vector2(268, y), "비고", f10, 10, U[4])
					text(Vector2(340, y), "[관리자 인증] — 관제망 단말 · 로봇(조회)", f12, 12, U[5])
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
		"wanted":                                                       # 등급 이름 + 공고 문안 1줄 + 현상금(공고된 경우). 수치는 숨김(SD-12 §9.7)
			var g := Wanted.grade(st)
			text(Vector2(264, 78), Wanted.NAMES[g], f12b, 12, U[6])
			text(Vector2(588, 80), "현상금 %s캡" % _comma(Wanted.bounty(st)) if Wanted.bounty(st) > 0 else "공고 금액 없음", f10, 10,
				U[6] if Wanted.bounty(st) > 0 else U[3], HORIZONTAL_ALIGNMENT_RIGHT)
			var y := _para(Vector2(264, 100), Wanted.notice(st), U[5])
			if g >= 1:
				text(Vector2(264, y + 4), "인상착의", f10, 10, U[4])
				_para(Vector2(330, y + 4), Wanted.look_text(st, db), U[5], 256.0)
				var dis := Wanted.disguised(st, str(info.get("worn", "")))
				text(Vector2(264, y + 24), "지금 옷은 공고와 다르다 — 무명은 잘 못 알아본다." if dis else "지금 옷이 공고와 같다.", f10, 10,
					U[6] if dis else U[3])
		"stats":
			var y := 78.0
			for kv in [["받은 퀘스트", str(_quests().size())], ["끝낸 퀘스트", str(_quests().filter(func(q): return not q["active"]).size())],
					["발견한 장소", str(st.places.count_found())],
					["소지품 종류", str(st.items.size())]]:
				text(Vector2(264, y), kv[0], f10, 10, U[4])
				text(Vector2(588, y), kv[1], f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
				y += 14.0


func _quest_page(id: String) -> void:
	var q := st.quests
	var a := q.act_of(id)
	var head := ("[메인] %s · " % str(q.act_def(a).get("name", "")).get_slice(" ", 0)) if id.begins_with("MQ") and a >= 0 else \
		("[부탁받은 일] " if id.begins_with("FQ") else ("[사이드] " if id.begins_with("SQ") else ""))
	text(Vector2(264, 78), head + q.title(id), f12b, 12, U[6])
	text(Vector2(588, 94), q.path_tag(id), f10, 10, U[6], HORIZONTAL_ALIGNMENT_RIGHT)
	if id == q.tracked or id in q.pinned:
		text(Vector2(264, 94), "▶ 추적 중" if id == q.tracked else "◆ 고정", f10, 10, U[5])
	var s := q.stage(id)
	var y := 112.0
	var cur_n := _cur_stage(id, s)
	for n in q.stages_of(id):
		if int(n) > s or int(n) >= 100:
			continue
		var line := q.log_text(id, int(n))
		if line == "":
			continue
		var cur := int(n) == cur_n
		view.draw_rect(Rect2(266, y + 3, 6, 6), U[6] if cur else U[3], cur)
		if not cur:
			view.draw_line(Vector2(266, y + 9), Vector2(272, y + 3), U[5])
		y = _para(Vector2(280, y), "- " + line, U[6] if cur else U[3], 300.0) + 4.0
	var tag := q.path_tag(id)
	if tag == "[놓침]":
		var why := q.log_text(id, 200)
		if why != "":
			y = _para(Vector2(280, y), "- " + why, U[6], 300.0) + 4.0
		for o in q.act_def(a).get("paths", []):                           # 다른 경로가 남아 있음을 사실로(바이블 §5.3-4)
			if o != id and q.stage(o) < 100:
				y = _para(Vector2(280, y), "- 다른 길은 아직 닫히지 않았다.", U[5], 300.0) + 4.0
				break
	elif bool(q.defs.get(id, {}).get("path", false)) and q.act_goal_met(a) and s > 0 and s < 100:
		y = _para(Vector2(280, y), "목표는 이미 이뤘다. 이 길에는 아직 할 일이 남아 있다.", U[5], 300.0) + 4.0
	elif s <= 0:
		y = _para(Vector2(280, y), "- 아직 아는 것이 거의 없다.", U[3], 300.0) + 4.0
	var known: Array = []                                                # 알려진 장소(지도 ▼)
	for lid in q.places_of(id):
		var ps := st.places.get_state(lid)
		if ps >= PlaceLog.RUMOR:
			known.append(str(PlaceLog.db[lid]["name"]) + (" (소문)" if ps == PlaceLog.RUMOR else ""))
	if not known.is_empty() and y < 270.0:
		hline(264, 588, y + 4, U[2])
		_para(Vector2(264, y + 10), "장소: " + ", ".join(known), U[4])


## 인물 수첩 한 사람(SD-12 §3.11): 얼굴 48×48 · 이름 · 직함 · 소속 / 주로 있는 곳 · 서비스 · 처음 만난 날 · 한 줄 메모 · 생사
func _npc_page(c: String) -> void:
	var book: NpcBook = st.book
	var e: Dictionary = book.entries.get(c, {})
	var dead := str(e.get("dead", "")) != ""
	var tex := _face_of(c)
	box(Rect2(263, 77, 50, 50), U[3], false)
	if tex != null:
		face.texture = tex
		face.position = view.position + Vector2(264, 78)
		face.modulate = Color(1, 1, 1, 1.0 if not dead else 0.45)         # CRT 단색(셰이더) — 고인은 흐리게
		face.visible = true
	var nm := str(book.info(c).get("name", c))
	text(Vector2(322, 78), nm, f12b, 12, U[3] if dead else U[6])
	text(Vector2(322, 96), book.title(c), f10, 10, U[5])
	text(Vector2(322, 110), book.faction_text(c), f10, 10, U[4])
	var y := 136.0
	var lid := book.place_of(c)
	var pname := str(PlaceLog.db.get(lid, {}).get("name", "알 수 없는 곳"))
	text(Vector2(264, y), "마지막으로 본 곳" if str(e.get("seen", "")) != "" else "주로 있는 곳", f10, 10, U[4])
	text(Vector2(360, y), pname, f10, 10, U[5])
	y += 15.0
	var svs: Array = book.info(c).get("services", [])
	if not svs.is_empty():
		text(Vector2(264, y), "서비스", f10, 10, U[4])
		if svc_icons == null:
			svc_icons = load("res://assets/ui/service_icons.png")
		var x := 360.0
		for sv in svs:
			var i := NpcBook.SERVICE_ORDER.find(str(sv))
			if i >= 0:
				view.draw_texture_rect_region(svc_icons, Rect2(x, y + 2, 8, 8), Rect2(i * 8, 0, 8, 8), U[6])
			var lb: String = NpcBook.SERVICES.get(str(sv), str(sv))
			text(Vector2(x + 11, y), lb, f10, 10, U[5])
			x += 15.0 + tw(lb, f10, 10)
		y += 15.0
	text(Vector2(264, y), "처음 만난 날", f10, 10, U[4])
	text(Vector2(360, y), str(e.get("met", "")), f10, 10, U[5])
	y += 15.0
	if dead:
		text(Vector2(264, y), "고인 (%s)" % str(e["dead"]), f12, 12, U[5])
		y += 17.0
	if str(e.get("memo", "")) != "":
		hline(264, 588, y + 4, U[2])
		_para(Vector2(264, y + 10), "- " + str(e["memo"]), U[6])


## 숨겨 둔 자리 한 곳(1-12o D-225 · 1-L §3.1): 내 메모 · 어디 · 위험 · 마지막으로 본 날 · 그때 든 것 · 마음에 걸림 · 지난 일 — 기억만(열어 보기 전엔 털림을 모른다)
func _stash_page(id: String) -> void:
	var d := StashBook.data(st)
	var safe := id.begins_with("safe:")
	var s: Dictionary = (d.get("safe", {}) if safe else d.get("spots", {})).get(id.substr(5 if safe else 6), {})
	if s.is_empty():
		return
	var now := str(info.get("date", ""))
	text(Vector2(264, 78), _fit(StashBook.memo(s, db, true) if not safe else str(s.get("name", "사물함")), 324.0), f12b, 12, U[6])
	var y := 98.0
	var rows2: Array = []
	if safe:
		rows2.append(["어디", str(StashBook.SAFE.get(str(s["map"]), {}).get("where", ""))])
		rows2.append(["지킴", "털리지 않는다 · " + StashBook.safe_status(st, s, now)])
	else:
		rows2.append(["어디", StashBook.long_where(st, s)])
		rows2.append(["삼은 날", StashBook.md(st, int(s.get("since", 0)), int(s.get("since_at", 0)), now)])
	var seen: Dictionary = s.get("seen", {})
	rows2.append(["마지막으로 본 날", StashBook.md(st, int(seen.get("day", s.get("since", 0))), int(seen.get("at", 0)), now)])
	for kv in rows2:
		text(Vector2(264, y), kv[0], f10, 10, U[4])
		y = _para(Vector2(370, y), str(kv[1]), U[5], 218.0) + 1.0
	if not safe and str(seen.get("risk", "")) != "":
		y = _para(Vector2(264, y + 2), str(seen["risk"]), U[5]) + 2.0
	hline(264, 588, y + 3, U[2])
	text(Vector2(264, y + 8), "그때 든 것", f10, 10, U[4])
	y += 22.0
	var mem := StashBook.memory_lines(seen.get("items", {}), db)
	if mem.is_empty():
		text(Vector2(272, y), "비어 있었다.", f10, 10, U[5])
		y += 13.0
	for ln in mem:
		text(Vector2(272, y), "· " + str(ln), f10, 10, U[5])
		y += 13.0
	if safe:
		return
	var kn: Dictionary = s.get("known", {})
	y += 4.0
	if not kn.is_empty() and StashBook.status(st, s, now) == "털림":
		var lost := StashBook.memory_lines(kn.get("lost", {}), db, 4)
		if not lost.is_empty():
			y = _para(Vector2(264, y), "잃은 것 — " + " · ".join(lost), U[6]) + 2.0
		y = _para(Vector2(264, y), "털린 흔적 — " + str(kn.get("text", "")), U[5]) + 2.0
	else:
		y = _para(Vector2(264, y), StashBook.worry(st, s), U[6]) + 2.0
	var lg: Array = s.get("log", [])
	if lg.size() > 0:
		hline(264, 588, y + 3, U[2])
		y += 8.0
		var parts: Array = []
		for e in lg.slice(maxi(0, lg.size() - 3)):                      # 최근 셋 · 마디마다 짧게(탭 줄에 닿지 않게)
			parts.append("%s %s" % [StashBook.md(st, 0, int(e["at"])), _fit(str(e["text"]), 150.0)])
		if y < 268.0:
			_para(Vector2(264, y), " · ".join(parts), U[4])


## 얼굴: 초상화(A·B 등급, 기본 표정)가 있으면 그것, 없으면 맵 스프라이트 정면 첫 칸
func _face_of(c: String) -> Texture2D:
	var idx := "res://assets/portraits/portraits.json"
	if not has_meta("portraits") and FileAccess.file_exists(idx):
		set_meta("portraits", JSON.parse_string(FileAccess.get_file_as_string(idx))["portraits"])
	var pt: Dictionary = get_meta("portraits", {})
	for k in [c] + (st.npcs.get(c, {}).get("ids", []) as Array):
		if pt.has(k):
			return load("res://assets/portraits/" + str(pt[k].get("기본", "")))
	var cast := "res://assets/sprites/story_cast.json"
	if FileAccess.file_exists(cast):
		var sh: String = JSON.parse_string(FileAccess.get_file_as_string(cast))["sheets"].get(c, "")
		if sh != "" and FileAccess.file_exists("res://assets/sprites/%s.json" % sh):
			var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % sh))
			var row := maxi(0, (m.get("rows", []) as Array).find("S"))
			var at := AtlasTexture.new()
			at.atlas = load("res://assets/sprites/%s.png" % sh)
			at.region = Rect2(0, row * float(m["frame"][1]), float(m["frame"][0]), float(m["frame"][1]))
			return at
	return null


## 인물 줄의 '지도에서 보기' 장소(지도에 있는 곳만 — 모르는 곳을 알려 주지 않는다). 아니면 ""
func _npc_lid(id: String) -> String:
	if not id.begins_with("npc:"):
		return ""
	var lid := st.book.place_of(id.substr(4))
	return lid if PlaceLog.db.has(lid) and st.places.on_map(lid) else ""


## 막 머리 상세(SD-12 §3.12 메인 묶음 예): 목표 1줄 + 경로·퀘스트마다 상태와 가장 최근 사실 줄
func _act_page(n: int) -> void:
	var q := st.quests
	var a := q.act_def(n)
	text(Vector2(264, 78), "[메인] " + str(a.get("name", "")), f12b, 12, U[6])
	text(Vector2(588, 80), q.act_tag(n), f10, 10, U[6], HORIZONTAL_ALIGNMENT_RIGHT)
	if "act:%d" % n == q.tracked or "act:%d" % n in q.pinned:
		text(Vector2(264, 94), "▶ 추적 중 — 경로 마커 전부" if "act:%d" % n == q.tracked else "◆ 고정", f10, 10, U[5])
	var y := _para(Vector2(264, 110), "목표: " + str(a.get("goal", "")), U[6], 324.0) + 4.0
	for id in a.get("quests", []):
		var s := q.stage(id)
		var tag := q.path_tag(id)
		if s <= 0 and tag != "[알려진 것 없음]":
			continue
		if s <= 0:                                                       # 시작 안 한 경로: 장소 소문이 있어야 보인다(목록과 같다)
			var rumor := false
			for lid in q.places_of(id):
				rumor = rumor or st.places.get_state(lid) >= PlaceLog.RUMOR
			if not rumor:
				continue
		if y > 272.0:
			break
		text(Vector2(268, y), q.title(id), f10, 10, U[5] if s < 100 else U[3])
		text(Vector2(588, y), tag, f10, 10, U[5] if s < 100 else U[3], HORIZONTAL_ALIGNMENT_RIGHT)
		y += 14.0
		var line := q.latest_line(id)
		if line != "" and s < 100 and y <= 272.0:
			y = _para(Vector2(280, y), "- " + line, U[4], 304.0)
		y += 2.0


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
	if searching and e is InputEventKey and e.pressed:
		_search_key(e)
		get_viewport().set_input_as_handled()
		view.queue_redraw()
		return
	if lv_on and tab == 0 and sub[0] == 3 and not (k in [KEY_TAB, KEY_ESCAPE, KEY_Q, KEY_E, KEY_F1, KEY_F2, KEY_F3, KEY_J]) \
			and not (e is InputEventMouseButton) and LevelTab.key(self, e):   # 레벨업 화면(1-12p): ↑↓ ←→ Enter T Backspace
		get_viewport().set_input_as_handled()
		view.queue_redraw()
		return
	if k in [KEY_TAB, KEY_ESCAPE]:
		close(true)
	elif k == KEY_Q:
		_tab(tab - 1)
	elif k == KEY_E:
		_tab(tab + 1)
	elif k in [KEY_F1, KEY_F2, KEY_F3]:
		_tab(k - KEY_F1)
	elif k == KEY_J:
		open_at(2, 2)
	elif k == KEY_R and tab == 1 and sub[1] in [0, 1] and not rows.is_empty():   # 스스로 고치기(SD-13 §8.3): 부품 · 수리 키트 · 군용 정비 키트
		action.emit("repair", str(rows[sel]["id"]))
	elif k == KEY_S and tab == 2 and sub[2] == 3:                      # 인물 수첩 거르기 바꾸기
		book_filter = (book_filter + 1) % NpcBook.FILTERS.size()
		sel = 0
	elif (k == KEY_SLASH or (e is InputEventKey and e.pressed and e.unicode == 47)) and tab == 2 and sub[2] == 3:
		searching = true
		DisplayServer.window_set_ime_active(true)                        # 한글 조합 입력(초성 포함)
	elif k == KEY_F and tab == 2 and sub[2] == 2:                      # 고정(SD-12 §3.12, 2개까지)
		if not rows.is_empty() and str(rows[sel]["id"]) != "":
			st.quests.pin(str(rows[sel]["id"]))
	elif _map_mode() and e is InputEventKey and e.pressed and e.shift_pressed and e.keycode in [KEY_LEFT, KEY_RIGHT]:
		_sub(-1 if e.keycode == KEY_LEFT else 1)
	elif _map_mode() and sub[2] == 1 and _map_key(e):
		pass
	elif k >= KEY_1 and k <= KEY_8:
		if tab == 1 and sub[1] in [0, 2] and not rows.is_empty():
			action.emit("hotkey:%d" % (k - KEY_0), rows[sel]["id"])
	elif e.is_action_pressed("ui_left", true):
		_sub(-1)
	elif e.is_action_pressed("ui_right", true):
		_sub(1)
	elif e.is_action_pressed("ui_up", true):
		_step(-1)
	elif e.is_action_pressed("ui_down", true):
		_step(1)
	elif e.is_action_pressed("ui_accept"):
		_enter()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := _item_at(_local(e.position))
		if i >= 0:
			_press(items[i]["id"])
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _map_mode() and map != null:
			map.zoom_by(1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		else:
			sel = clampi(sel + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, rows.size() - 1))
	else:
		handled = false
	if handled:
		if e is InputEventKey or e is InputEventMouseButton:
			first = false
		get_viewport().set_input_as_handled()
		view.queue_redraw()


## 찾기 글자 받기: 글자(IME로 조합한 한글·초성 포함)를 붙이고, Backspace는 지우고, Enter·Esc는 끝낸다
func _search_key(e: InputEventKey) -> void:
	if e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		searching = false
		DisplayServer.window_set_ime_active(false)
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
		if e.keycode == KEY_ESCAPE:
			book_q = ""
	elif e.keycode == KEY_BACKSPACE:
		book_q = book_q.substr(0, maxi(0, book_q.length() - 1))
	elif e.unicode >= 0x20:
		book_q += String.chr(e.unicode)
	sel = 0
	rows = _rows()
	if not rows.is_empty() and str(rows[0]["id"]) == "":
		_step(1)


## 월드 지도 키(방향키 커서 · Z·X 확대 · Enter 빠른 이동). 처리했으면 true
func _map_key(e: InputEvent) -> bool:
	if map == null:
		return false
	var d := Vector2.ZERO
	if e.is_action_pressed("ui_left", true):
		d = Vector2.LEFT
	elif e.is_action_pressed("ui_right", true):
		d = Vector2.RIGHT
	elif e.is_action_pressed("ui_up", true):
		d = Vector2.UP
	elif e.is_action_pressed("ui_down", true):
		d = Vector2.DOWN
	if d != Vector2.ZERO:
		map.move_cursor(d, 0.06 if e.is_echo() else 0.0)
		return true
	var k: int = e.keycode if e is InputEventKey and e.pressed and not e.echo else -1
	if k in [KEY_Z, KEY_MINUS]:
		map.zoom_by(-1)
		return true
	if k in [KEY_X, KEY_EQUAL, KEY_PLUS]:
		map.zoom_by(1)
		return true
	if k == KEY_G and sub[2] == 1:                                       # 판도 레이어(1-12m)
		map.toggle_layer()
		return true
	if e.is_action_pressed("ui_accept"):
		_travel()
		return true
	return false


## 빠른 이동(SD-12 §5.6): 커서 아래 장소가 갈 수 있으면 받는 쪽(진행기)에 넘기고 닫는다. 못 가면 이유를 그대로 둔다(정보 줄에 보인다)
func _travel() -> void:
	if map == null:
		return
	if PipMap.infer_hit(st, map.cursor, map.zoom):                      # 지도를 보고 하는 단서 2 추론(1-12k D-046): 카드 끝 숫자 둘의 청크를 짚었다
		st.vars.set_v("MQ102_MAPC", 1)
		if info.has("hint"):
			info["hint"].call("20 · 27 — 카드의 깨진 줄 끝, 그 숫자. 여의도.", 6.0)
		close(true)
		return
	if map.sel == "" or not info.has("travel"):
		return
	var why: Array = info["travel"].call(map.sel)
	if why[0]:
		action.emit("travel", map.sel)
		close(true)


func _press(id: String) -> void:
	if id == "map":
		if map != null and map.click(_local(get_viewport().get_mouse_position())):
			_travel()
		return
	if lv_on and LevelTab.press(self, id):                              # 레벨업 화면 단추 · 줄(1-12p)
		return
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
	elif id == "pin" and not rows.is_empty() and str(rows[sel]["id"]) != "":
		st.quests.pin(str(rows[sel]["id"]))
	elif id == "repair" and not rows.is_empty():
		action.emit("repair", str(rows[sel]["id"]))
	elif id == "filter":
		book_filter = (book_filter + 1) % NpcBook.FILTERS.size()
		sel = 0
	elif id == "find":
		searching = true
		DisplayServer.window_set_ime_active(true)
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_show("")                      # 모바일: 화면 자판(글자는 키 이벤트로 들어온다)
	elif id == "turf" and map != null:
		map.toggle_layer()
	elif id in ["close", "power"]:
		close(true)


## 목록 한 칸 옮기기: 묶음 이름 줄(id "")은 건너뛴다
func _step(d: int) -> void:
	var i := sel + d
	while i >= 0 and i < rows.size() and str(rows[i]["id"]) == "":
		i += d
	if i >= 0 and i < rows.size():
		sel = i


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
		[0, 3]:
			if id == "lvup":
				LevelTab.start(self)                                       # 레벨업 화면(1-12p)
		[0, 0]:
			action.emit("use", str(info.get("stimpak_id", "")))
		[1, 0]:
			action.emit("unequip" if id == info.get("equipped", "") else "equip", id)
		[1, 1]:
			if id != info.get("worn", ""):
				action.emit("equip", id)                                   # 옷 갈아입기(0-10, 몸통 슬롯 하나)
		[1, 2]:
			action.emit("use", id)
		[1, 3]:
			if id == Craft.BURNER:
				action.emit("use", id)                                     # 휴대용 버너: 그 자리에서 조리(1-8c, SD-13 §7.9.5)
			elif PipBoy.examinable(id):
				action.emit("examine", id)                                 # 살펴보기(1-11a): 물건에 딸린 장면(EXAMINE_<ID>)
		[2, 4]:
			if not (id in ["past", "log"]) and Radio.quality(id, info.get("radio", {})) >= 0:
				if st.radio.on and st.radio.tuned == id:
					st.radio.on = false
				else:
					st.radio.tune(id)
		[2, 5]:                                                          # 판도 지도(SD-12 §5.8 세력 기록 연동): 레이어를 켜고 그 세력 구역 · 거점을 강조
			open_at(2, 1)
			if map == null:
				map = PipMap.new(self)
			map.layer = true
			map.opened_at = -1.0
			map.focus = Turf.group(st, id.substr(3) if id.begins_with("JC_") else id)
			map.zoom = 1
			map.cursor = Vector2(800, 1300)                               # 그 세력이 1위인 아는 구역(없으면 R01 · R02 가운데)
			for z in Turf.zones():
				var kz: Dictionary = st.turf.known_of(z)
				if not kz.is_empty() and str(kz["a"]) == map.focus:
					var sd: Array = Turf.data["zones"][z]["seed"]
					map.cursor = Vector2(int(sd[0]) * 40 + 20, int(sd[1]) * 40 + 20)
					break
			map.center = map.cursor
		[2, 2]:
			if id != "":
				st.quests.track(id)                                      # 추적(SD-12 §3.12) — 같은 줄을 다시 고르면 끈다
		[2, 3] when id.begins_with("stash:") or id.begins_with("safe:"):
			var at := StashBook.at_of(st, id)
			if at.x >= 0:                                                # 지도에서 보기(숨겨 둔 자리 — 칸에 깜박이는 겹원)
				open_at(2, 1)
				if map == null:
					map = PipMap.new(self)
				map.cursor = Vector2(at) + Vector2(0.5, 0.5)
				map.center = map.cursor
				map.zoom = 2
				map.temp = ""
				map.temp_at = Vector2(at) + Vector2(0.5, 0.5)
		[2, 3]:
			var lid := _npc_lid(id)
			if lid != "":                                                # 지도에서 보기: 그 장소에 임시 표식을 찍고 월드 지도로
				open_at(2, 1)
				if map == null:
					map = PipMap.new(self)
				var pe: Dictionary = PlaceLog.db[lid]
				map.cursor = Vector2(int(pe["tx"]) + 0.5, int(pe["ty"]) + 0.5)
				map.center = map.cursor
				map.zoom = 2
				map.temp = lid
				map.temp_at = Vector2(-1, -1)
