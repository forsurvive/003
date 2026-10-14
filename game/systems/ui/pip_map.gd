## 핍-보이 지도(단계 1-2, SD-12 §5.1 월드 지도 · §5.2 지역 지도 · §5.6 빠른 이동). 핍-보이(PipBoy)의 데이터 탭 하위 화면을 그린다.
## 월드 지도: 2077년 공무용 단색 선화(굽기 world_map.png, 1px = 1타일)를 CRT 색으로 칠하고, 가~하 × 1~12 격자, 권역 이름(들어가 본 권역만 진하게),
##   장소 마커(SD-12 §5.4 아이콘 22종 — 발견 = 채움, 표시 = 윤곽, 소문 = 반경 원 + ?), 주인공 화살표, 커서 정보(장소명 / 권역 / 상태 /
##   빠른 이동 가능 여부·소요 시간), 좌표 줄(`R01 · 청크 (23, 37) · 타일 (39, 23)`). 확대 4단계: 전도 · 권역 · 구역(이름 전부) · 정밀(청크 격자).
## 지역 지도: 주인공 둘레 60×60타일, 본 칸만(안개 걷기) — 건물·구조물 · 길 · 물 · 걷는 땅을 명암으로.
## 조작: 방향키 = 커서(누르고 있으면 빨라진다), Z·X(또는 휠) = 확대, Enter = 빠른 이동, Shift+←→ = 하위 탭, 클릭 = 커서 옮기기(마커 두 번 = 이동).
class_name PipMap
extends RefCounted

const AREA := Rect2(48, 70, 544, 222)
const ZOOMS := [0.129, 0.5, 1.0, 2.0]
const ZOOM_NAMES := ["전도", "권역", "구역", "정밀"]
const COLS := "가나다라마바사아자차카타파하"
const WORLD := Vector2(2120, 1720)
const LOCAL_N := 60
const LOCAL_PX := 3

static var tex: Texture2D
static var icons: Texture2D
static var regions: Dictionary = {}                   ## 청크 "x,y" -> 권역 코드
static var region_names: Dictionary = {}
static var region_mid: Dictionary = {}                ## 권역 코드 -> 가운데(월드 타일)

var pb                                                ## PipBoy
var zoom := 1
var center := Vector2(959, 1503)
var cursor := Vector2(959, 1503)
var sel := ""                                         ## 커서 아래 장소
var hold := 0.0


static func _load() -> void:
	if tex != null:
		return
	tex = load("res://assets/ui/world_map.png")
	icons = load("res://assets/ui/map_icons.png")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world.json"))
	regions = meta.get("regions", {})
	region_names = meta.get("region_names", {})
	var acc := {}
	for k in regions:
		var c := str(regions[k])
		var xy := str(k).split(",")
		var p := Vector2(int(xy[0]) * 40 + 20, int(xy[1]) * 40 + 20)
		var a: Array = acc.get(c, [Vector2.ZERO, 0])
		acc[c] = [a[0] + p, a[1] + 1]
	for c in acc:
		region_mid[c] = acc[c][0] / float(acc[c][1])
	PlaceLog.load_db()


func _init(pip) -> void:
	pb = pip
	_load()
	var me: Vector2 = pb.info.get("tile", center)
	center = me
	cursor = me


func _sc() -> float:
	return ZOOMS[zoom]


func w2s(p: Vector2) -> Vector2:
	return (AREA.position + AREA.size / 2.0 + (p - center) * _sc()).round()


func s2w(s: Vector2) -> Vector2:
	return center + (s - AREA.position - AREA.size / 2.0) / _sc()


func _clamp_center() -> void:
	var half := AREA.size / 2.0 / _sc()
	center.x = clampf(center.x, half.x if half.x < WORLD.x / 2.0 else WORLD.x / 2.0, WORLD.x - half.x if half.x < WORLD.x / 2.0 else WORLD.x / 2.0)
	center.y = clampf(center.y, half.y if half.y < WORLD.y / 2.0 else WORLD.y / 2.0, WORLD.y - half.y if half.y < WORLD.y / 2.0 else WORLD.y / 2.0)


# ---------------------------------------------------------------- 월드 지도
func draw_world() -> void:
	var v: Control = pb.view
	var U: Array = PipBoy.U
	_clamp_center()
	v.draw_rect(AREA, U[0])
	var sc := _sc()
	var half := AREA.size / 2.0 / sc
	var src := Rect2(center - half, half * 2.0).intersection(Rect2(Vector2.ZERO, WORLD))
	if src.has_area():
		v.draw_texture_rect_region(tex, Rect2(w2s(src.position), src.size * sc), src, U[5])
	if zoom == 3:                                                         # 정밀: 청크 격자
		var x := floorf(src.position.x / 40.0) * 40.0
		while x <= src.end.x:
			var sx := w2s(Vector2(x, 0)).x + 0.5
			v.draw_line(Vector2(sx, AREA.position.y), Vector2(sx, AREA.end.y), Color(U[2], 0.6))
			x += 40.0
		var y := floorf(src.position.y / 40.0) * 40.0
		while y <= src.end.y:
			var sy := w2s(Vector2(0, y)).y + 0.5
			v.draw_line(Vector2(AREA.position.x, sy), Vector2(AREA.end.x, sy), Color(U[2], 0.6))
			y += 40.0
	var seen: Dictionary = pb.st.places.regions                          # 권역 이름: 들어가 본 권역만 진하게
	if zoom <= 1:
		for c in region_mid:
			var p := w2s(region_mid[c])
			if AREA.has_point(p):
				pb.text(p - Vector2(0, 6), str(region_names.get(c, c)), pb.f10, 10, U[6] if seen.has(c) else U[3], HORIZONTAL_ALIGNMENT_CENTER)
	_grid_labels(v, U)
	_markers(v, U)
	var me: Vector2 = pb.info.get("tile", Vector2(-99, -99))              # 주인공 화살표
	var mp := w2s(me + Vector2(0.5, 0.5))
	if AREA.grow(-2).has_point(mp):
		v.draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -5), mp + Vector2(4, 4), mp + Vector2(0, 2), mp + Vector2(-4, 4)]), U[7])
	var cp := w2s(cursor)                                                 # 커서
	v.draw_rect(Rect2(cp - Vector2(7, 7), Vector2(14, 14)), U[7], false)
	v.draw_line(cp + Vector2(-11, 0), cp + Vector2(-8, 0), U[7])
	v.draw_line(cp + Vector2(8, 0), cp + Vector2(11, 0), U[7])
	v.draw_line(cp + Vector2(0, -11), cp + Vector2(0, -8), U[7])
	v.draw_line(cp + Vector2(0, 8), cp + Vector2(0, 11), U[7])
	_info_box(v, U)


func _grid_labels(v: Control, U: Array) -> void:
	var cw := WORLD.x / 14.0
	var ch := WORLD.y / 12.0
	for i in 14:
		var sx := w2s(Vector2(i * cw + cw / 2.0, 0)).x
		if sx > AREA.position.x + 8 and sx < AREA.end.x - 8:
			pb.text(Vector2(sx, AREA.position.y + 1), COLS[i], pb.f10, 10, U[4], HORIZONTAL_ALIGNMENT_CENTER)
		var gx := w2s(Vector2(i * cw, 0)).x
		if zoom <= 1 and gx > AREA.position.x and gx < AREA.end.x:
			for y in range(int(AREA.position.y), int(AREA.end.y), 4):
				v.draw_rect(Rect2(gx, y, 1, 1), U[2])
	for j in 12:
		var sy := w2s(Vector2(0, j * ch + ch / 2.0)).y
		if sy > AREA.position.y + 8 and sy < AREA.end.y - 30:
			pb.text(Vector2(AREA.position.x + 3, sy - 6), str(j + 1), pb.f10, 10, U[4])
		var gy := w2s(Vector2(0, j * ch)).y
		if zoom <= 1 and gy > AREA.position.y and gy < AREA.end.y:
			for x in range(int(AREA.position.x), int(AREA.end.x), 4):
				v.draw_rect(Rect2(x, gy, 1, 1), U[2])


## 지도 격자 이름(예 '라7')
static func grid_name(t: Vector2) -> String:
	var i := clampi(int(t.x / (WORLD.x / 14.0)), 0, 13)
	var j := clampi(int(t.y / (WORLD.y / 12.0)), 0, 11)
	return "%s%d" % [COLS[i], j + 1]


func _markers(v: Control, U: Array) -> void:
	var places: PlaceLog = pb.st.places
	var best := ""
	var best_d := 9.0
	var cp := w2s(cursor)
	var labels: Array = []                                                 # 이름표 겹침: 먼저 놓인 이름(발견 우선)과 겹치면 생략, 커서 아래 이름은 늘
	var order: Array = PlaceLog.db.keys()
	order.sort_custom(func(a, b): return places.get_state(a) > places.get_state(b))
	for lid in order:
		var e: Dictionary = PlaceLog.db[lid]
		if str(e["region"]) == "UG":
			continue
		var s := places.get_state(lid)
		if not places.on_map(lid):
			continue
		var p := w2s(Vector2(int(e["tx"]) + 0.5, int(e["ty"]) + 0.5))
		if not AREA.grow(-6).has_point(p) or p.y > AREA.end.y - 34:
			continue
		if s == PlaceLog.RUMOR:                                           # 소문: 반경 원(8타일) + ?
			v.draw_arc(p, maxf(6.0, 8.0 * _sc()), 0, TAU, 20, U[4])
			pb.text(p - Vector2(0, 6), "?", pb.f10, 10, U[5], HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var found := s >= PlaceLog.FOUND
			var ic := int(e["icon"]) - 1
			v.draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), U[0])
			v.draw_texture_rect_region(icons, Rect2(p - Vector2(6, 6), Vector2(12, 12)), Rect2(ic * 12, 0 if found else 12, 12, 12), U[6] if found else U[4])
			if zoom >= 2:
				var nm := str(e["name"])
				var w: float = pb.tw(nm, pb.f10, 10)
				var lr := Rect2(p.x - w / 2.0 - 1, p.y + 7, w + 2, 12)
				var hit := false
				for q in labels:
					if lr.intersects(q):
						hit = true
						break
				if lr.end.y > AREA.end.y - 29 or lr.position.x < AREA.position.x or lr.end.x > AREA.end.x:
					hit = true                                                   # 정보 상자·지도 밖으로 나가는 이름은 그리지 않는다
				if not hit or (p.distance_to(cp) < 8.0 and lr.end.y <= AREA.end.y - 29):
					labels.append(lr)
					v.draw_rect(lr, Color(U[0], 0.75))
					pb.text(p + Vector2(0, 7), nm, pb.f10, 10, U[5] if found else U[3], HORIZONTAL_ALIGNMENT_CENTER)
		var d := p.distance_to(cp)
		if d < best_d:
			best_d = d
			best = lid
	sel = best


func _info_box(v: Control, U: Array) -> void:
	var r := Rect2(AREA.position.x, AREA.end.y - 28, AREA.size.x, 28)
	v.draw_rect(r, Color(U[0], 0.92))
	pb.hline(r.position.x, r.end.x, r.position.y, U[3])
	var t := Vector2i(cursor)
	var code := str(regions.get("%d,%d" % [t.x / 40, t.y / 40], ""))
	var line2 := "%s · %s 구역 · 청크 (%d, %d) · 타일 (%d, %d)   [%s]" % [code if code != "" else "—", grid_name(cursor), t.x / 40, t.y / 40,
		t.x % 40, t.y % 40, ZOOM_NAMES[zoom]]
	var line1 := "—"
	if sel != "":
		var e: Dictionary = PlaceLog.db[sel]
		var s: int = pb.st.places.get_state(sel)
		var why: Array = pb.info["travel"].call(sel) if pb.info.has("travel") else [false, "실내에서는 이동할 수 없습니다."]
		var st_name: String = ["미상", "소문", "표시", "발견"][s]
		var tv: String = ("빠른 이동 %d시간 [Enter]" % int(why[2])) if why[0] else str(why[1])
		line1 = "%s / %s / %s / %s" % [e["name"], region_names.get(str(e["region"]), str(e["region"])), st_name, tv]
	pb.text(r.position + Vector2(6, 2), line1, pb.f12, 12, U[6] if sel != "" else U[3])
	pb.text(r.position + Vector2(6, 16), line2, pb.f10, 10, U[4])


# ---------------------------------------------------------------- 지역 지도
func draw_local() -> void:
	var v: Control = pb.view
	var U: Array = PipBoy.U
	v.draw_rect(AREA, U[0])
	var wm = pb.info.get("world")
	if wm == null or not is_instance_valid(wm):
		pb.text(AREA.get_center() - Vector2(0, 8), "지역 지도는 바깥에서만 그린다(실내 지도는 이후).", pb.f12, 12, U[4], HORIZONTAL_ALIGNMENT_CENTER)
		return
	var me := Vector2i(pb.info.get("tile", Vector2.ZERO))
	var places: PlaceLog = pb.st.places
	var o := (AREA.get_center() - Vector2(LOCAL_N * LOCAL_PX, LOCAL_N * LOCAL_PX) / 2.0).round()
	var h := LOCAL_N / 2
	for y in LOCAL_N:
		for x in LOCAL_N:
			var t := me + Vector2i(x - h, y - h)
			if not places.seen(t):
				continue
			var k: int = wm.tile_class(t)
			if k <= 0:
				continue
			v.draw_rect(Rect2(o + Vector2(x, y) * LOCAL_PX, Vector2(LOCAL_PX, LOCAL_PX)), [U[0], U[2], U[3], U[5], U[6], U[4]][k])
	var c := o + Vector2(h, h) * LOCAL_PX + Vector2(1, 1)
	v.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3, 3), c + Vector2(-3, 3)]), U[7])
	v.draw_rect(Rect2(o - Vector2(1, 1), Vector2(LOCAL_N, LOCAL_N) * LOCAL_PX + Vector2(2, 2)), U[3], false)
	var lx := o.x + LOCAL_N * LOCAL_PX + 14
	pb.text(Vector2(lx, AREA.position.y + 6), str(pb.info.get("place", "")), pb.f12b, 12, U[6])
	pb.text(Vector2(lx, AREA.position.y + 24), "%s 구역 · 둘레 %d×%d타일" % [grid_name(Vector2(me)), LOCAL_N, LOCAL_N], pb.f10, 10, U[4])
	var y0 := AREA.position.y + 46
	for kv in [[U[6], "건물·구조물"], [U[3], "길"], [U[5], "물"], [U[2], "걷는 땅"], [U[4], "나무·소품"]]:
		v.draw_rect(Rect2(lx, y0 + 2, 8, 8), kv[0])
		pb.text(Vector2(lx + 14, y0), kv[1], pb.f10, 10, U[5])
		y0 += 15
	pb.text(Vector2(lx, y0 + 8), "본 곳만 그린다(안개 걷기).", pb.f10, 10, U[3])


# ---------------------------------------------------------------- 입력
func move_cursor(d: Vector2, dt: float) -> void:
	hold = hold + dt if d != Vector2.ZERO else 0.0
	var step := (3.0 + minf(hold, 1.0) * 9.0) / _sc()
	cursor += d * step
	cursor = cursor.clamp(Vector2.ZERO, WORLD - Vector2.ONE)
	var cp := w2s(cursor)                                                 # 커서가 가장자리에 닿으면 지도를 민다
	var m := AREA.grow(-24)
	if not m.has_point(cp):
		center += (cp - cp.clamp(m.position, m.end)) / _sc()


func zoom_by(k: int) -> void:
	zoom = clampi(zoom + k, 0, ZOOMS.size() - 1)
	center = cursor


func click(p: Vector2) -> bool:
	if not AREA.has_point(p):
		return false
	var before := sel
	cursor = s2w(p)
	pb.view.queue_redraw()
	return before != "" and before == sel and w2s(Vector2(int(PlaceLog.db[sel]["tx"]) + 0.5, int(PlaceLog.db[sel]["ty"]) + 0.5)).distance_to(p) < 8.0
