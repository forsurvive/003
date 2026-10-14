## 게임 상태 한 장(SD-12 §13.2 '세계 상태', SD-19 §6.10, 단계 0-11): 이야기 상태 + 맵·주인공 자리 + 전투(무기·탄창·HP) + 진행기.
## 저장 → 불러오기 → 저장이 바이트까지 같도록(SD-19) 사전 키는 늘 정렬해 넣고, 실수는 저장 전에 0.01 단위로 자른다.
## 맵 위 적·연출 인물은 저장하지 않는다 — 수동 저장은 대화·연출 중에 막히고, 자동 저장은 교전·적 감지 중에 미뤄진다(§13.1·§13.2).
## 맵을 다시 열면 맵 원고의 인물·용기 상태(st.boxes)·문 상태가 이야기 변수로 다시 선다.
class_name GameSnapshot
extends RefCounted

const VERSION := 1


static func _sorted(d: Dictionary) -> Dictionary:
	var out := {}
	var ks := d.keys()
	ks.sort()
	for k in ks:
		var v = d[k]
		out[k] = _sorted(v) if v is Dictionary else (_round(v) if v is float else v)
	return out


static func _round(f: float) -> float:
	return snappedf(f, 0.01)


## 이야기 상태 전부(변수는 기본값과 다른 것만 — VarStore.dump)
static func story(st: StoryState) -> Dictionary:
	var d := st.dump()
	d["boxes"] = _sorted(st.boxes)
	d["stolen"] = _sorted(st.stolen)
	var dead := st.dead.keys()
	dead.sort()
	d["dead"] = dead
	d["alias"] = _sorted(st.portrait_alias)
	d["places"] = st.places.to_dict()
	return _sorted(d)


static func apply_story(st: StoryState, d: Dictionary) -> void:
	st.restore(d)
	st.boxes = (d.get("boxes", {}) as Dictionary).duplicate(true)
	st.stolen = (d.get("stolen", {}) as Dictionary).duplicate(true)
	st.dead = {}
	for k in d.get("dead", []):
		st.dead[k] = true
	st.portrait_alias = (d.get("alias", {}) as Dictionary).duplicate(true)
	st.places = PlaceLog.new()
	st.places.from_dict(d.get("places", {}))
	st.events.clear()


## 맵·주인공·전투·화면 상태
static func host(h: InteriorHost) -> Dictionary:
	var c := h.combat
	var fired := h.fired.keys()
	fired.sort()
	var seen := {}
	for k in h.text_seen:
		seen[k] = h.text_seen[k]
	return _sorted({
		"map": ("W" if h.map is WorldMap else h.map.id) if h.map != null else "",   # 월드는 "W" + 월드 픽셀(1-1)
		"pos": [_round(h.player.loco.logical.x), _round(h.player.loco.logical.y)] if h.player != null else [0, 0],
		"facing": h.player.loco.facing if h.player != null else 2,
		"body": h.body, "date": h.date_text, "hud": h.hud_on, "pip": h.pipboy_ok, "night": h.night,
		"fired": fired, "seen": seen,
		"hp": _round(c.pc.hp) if c.pc != null else 0.0,
		"weapon": c.weapon_id, "holstered": c.holstered, "crouch": c.crouch,
		"mags": c.mags.duplicate(), "hotkeys": _str_keys(c.hotkeys),
	})


static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out


## 불러오기: 맵을 열고 주인공을 저장한 자리에 세운다(맵 진입 신호가 진행기의 _on_map을 부른다)
static func apply_host(h: InteriorHost, d: Dictionary) -> void:
	h.body = str(d.get("body", "adult"))
	h.date_text = str(d.get("date", ""))
	h.hud_on = bool(d.get("hud", false))
	h.pipboy_ok = bool(d.get("pip", false))
	h.fired = {}
	for k in d.get("fired", []):
		h.fired[k] = true
	h.text_seen = (d.get("seen", {}) as Dictionary).duplicate()
	var c := h.combat
	c.mags = (d.get("mags", {}) as Dictionary).duplicate()
	c.hotkeys = {}
	var hk: Dictionary = d.get("hotkeys", {})
	for k in hk:
		c.hotkeys[int(k)] = hk[k]
	var p: Array = d.get("pos", [0, 0])
	var at := Vector2(float(p[0]), float(p[1]))
	var mid := str(d["map"])
	if mid != "W" and WorldMap.covers(mid):                            # 1-1 이전 저장: 손 맵 이름 + 손 맵 좌표 → 월드 좌표
		at += Vector2(WorldMap.origin_of(mid) * 32)
	h.enter(mid, "", {}, at)
	h.player.loco.place(at)
	h.player.loco.facing = int(d.get("facing", 2))
	h.player.position = h.player.loco.render
	h.player._show()
	h.cam.position = at.round()
	h.cam.reset_smoothing()
	var w := str(d.get("weapon", ""))
	if w != "" and int(h.st.items.get(w, 0)) > 0:
		c.equip(w, h.st)
	c.holstered = bool(d.get("holstered", false))
	c.crouch = bool(d.get("crouch", false))
	if c.pc != null:
		c.pc.hp = clampf(float(d.get("hp", c.pc.max_hp)), 1.0, c.pc.max_hp)
	h.st.weapon_out = c.armed()
	h.set_night(bool(d.get("night", false)))


## 칸 정보(목록 화면용): 이름 · 레벨 · 막 · 장소 · 날짜 · 플레이 시간 · 축소 그림
static func slot_info(h: InteriorHost, play_time: float, thumb: PackedByteArray = PackedByteArray()) -> Dictionary:
	var act := int(h.st.vars.get_v("V_ACT")) if h.st.vars.has("V_ACT") else 0
	return {"name": h.st.player_full(), "level": h.level(), "act": "프롤로그" if act == 0 else "%d막" % act,
		"place": h.status()["place"] if h.map != null else "", "date": h.date_text, "play_time": int(play_time),
		"thumb": thumb, "version": VERSION}


## 화면 축소 그림 160×90 PNG(§13.1). 머리 없는 실행(봇·시험)에서는 빈 바이트
static func thumbnail(vp: Viewport) -> PackedByteArray:
	if DisplayServer.get_name() == "headless":
		return PackedByteArray()
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return PackedByteArray()
	img.resize(160, 90, Image.INTERPOLATE_NEAREST)
	return img.save_png_to_buffer()
