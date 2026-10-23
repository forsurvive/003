## 핍-보이 데이터 > 세력(단계 1-12m, SD-12 §3.10 · SD-16 §9.6): 만난 세력만 목록에, 오른쪽에 휘장 64×64(관계 상태 덧그림) · 이름 · 소개 ·
## 관계 한 줄(SD-06 §4.3 '핍-보이 한 줄' — 경계 ±5면 기울고 있음 문장) · 지금 받는 대우 · 들리는 말 · 최근 일(날짜 + 사실) · 작은 판도 지도(R01 · R02).
## 숫자 · 게이지 · 단계 이름은 그리지 않는다. [Enter] 판도 지도 = 월드 지도에 판도 레이어를 켜고 그 세력 구역을 강조한다.
class_name FactionTab
extends RefCounted

const EMBLEM := ["BJ", "YH", "WP", "JH", "GS", "JG", "SB", "JC", "NJ", "KD", "YT", "S7", "BC", "SA"]   ## art/tools/ui_faction_emblems.py CODES
const MINI := Rect2(500, 74, 88, 60)                  ## 작은 판도 지도(청크 4px — R01 · R02 청크 x 6~27 · y 26~40)
const MINI_O := Vector2i(6, 26)

static var emb16: Texture2D
static var emb64: Texture2D
static var states64: Texture2D


static func _load() -> void:
	if emb64 == null:
		emb16 = load("res://assets/ui/faction_emblems16.png")
		emb64 = load("res://assets/ui/faction_emblems64.png")
		states64 = load("res://assets/ui/faction_states64.png")


## 휘장 열(정착지 'JC_BC'는 봉천 휘장)
static func col_of(f: String) -> int:
	if f.begins_with("JC_"):
		var i := EMBLEM.find(f.substr(3))
		return i if i >= 0 else EMBLEM.find("JC")
	return EMBLEM.find(f)


## 목록 줄: [{"text", "id", "right", "icon"}]
static func rows(pb) -> Array:
	var out: Array = []
	for e in pb.st.fbook.listed(pb.st):
		var f := str(e["f"])
		var mark := ""
		if bool(e["dot"]):
			mark = "•"
		if bool(e["warn"]):
			mark += "!"
		out.append({"text": ("  " if bool(e["sub"]) else "") + pb.st.fbook.name_of(f), "id": f, "right": mark, "icon": col_of(f), "sub": bool(e["sub"])})
	return out


static func page(pb, f: String) -> void:
	_load()
	var st = pb.st
	var fb: FactionBook = st.fbook
	fb.read(f)
	var U: Array = PipBoy.U
	var v: Control = pb.view
	var s := int(fb.stage.get(f, FactionBook.nominal(FactionBook.aff_of(st, f))))
	var ci := col_of(f)
	var er := Rect2(264, 74, 64, 64)
	v.draw_rect(er, U[0])
	if ci >= 0:
		v.draw_texture_rect_region(emb64, er, Rect2(ci * 64, 0, 64, 64))
	if s == 5 and fmod(pb.time, 1.2) < 0.15:                               # 동맹: 섬광(U7) 깜박
		v.draw_rect(er.grow(1), U[7], false)
	v.draw_texture_rect_region(states64, er, Rect2(s * 64, 0, 64, 64))
	pb.text(Vector2(336, 76), fb.name_of(f), pb.f12b, 12, U[6])
	var y: float = pb._para(Vector2(336, 94), fb.desc_of(f), U[4], 158.0)
	_mini(pb, f, U)
	y = maxf(y, 146.0)
	y = pb._para(Vector2(264, y), "\"%s\"" % fb.relation_line(st, f), U[6])
	var tr := fb.treat_line(st, f)
	if tr != "":
		pb.text(Vector2(264, y + 4), "지금 받는 대우", pb.f10, 10, U[4])
		y = pb._para(Vector2(264, y + 17), tr, U[5])
	var hr := fb.hear_line(st, f)
	if hr != "":
		pb.text(Vector2(264, y + 3), "들리는 말", pb.f10, 10, U[4])
		y = pb._para(Vector2(264, y + 16), hr, U[5])
	pb.hline(264, 588, y + 4, U[2])
	pb.text(Vector2(264, y + 7), "최근 일", pb.f10, 10, U[4])
	var ly := y + 21
	var lines := fb.lines_of(f)
	if lines.is_empty():
		pb.text(Vector2(264, ly), "아직 없다.", pb.f10, 10, U[3])
	for i in lines.size():
		if ly > 280.0:
			break
		var e: Dictionary = lines[i]
		pb.text(Vector2(264, ly), pb._fit("%s %s" % [str(e["date"]), str(e["text"])], 324.0), pb.f10, 10, U[5] if i < 3 else U[3])
		ly += 13.0


## 작은 판도 지도: 아는 구역만, 이 세력이 1위인 구역은 진하게 · 2위(다툼)는 사선 · 나머지는 회색 테
static func _mini(pb, f: String, U: Array) -> void:
	var v: Control = pb.view
	Turf.load_data()
	v.draw_rect(MINI.grow(1), U[0])
	var g := Turf.group(pb.st, f.substr(3) if f.begins_with("JC_") else f)
	var col := PipMap.fac_color(g)
	var cz: Dictionary = Turf.data.get("chunk_zone", {})
	for key in cz:
		var xy := str(key).split(",")
		var r := Rect2(MINI.position + Vector2((int(xy[0]) - MINI_O.x) * 4, (int(xy[1]) - MINI_O.y) * 4), Vector2(4, 4))
		if not MINI.encloses(r):
			continue
		var k: Dictionary = pb.st.turf.known_of(str(cz[key]))
		if k.is_empty():
			v.draw_rect(r, Color(U[2], 0.6))
		elif str(k["a"]) == g:
			v.draw_rect(r, Color(col, [0.3, 0.55, 0.75, 1.0][int(k["s"])]))
		elif str(k["b"]) == g and int(k["s"]) == 1:
			v.draw_rect(r, Color(col, 0.35))
			v.draw_line(r.position, r.end, U[0])
		else:
			v.draw_rect(r, U[1])
	v.draw_rect(MINI.grow(1), U[3], false)
	pb.text(Vector2(MINI.position.x, MINI.end.y + 2), "판도(아는 곳만)", pb.f10, 10, U[3])
