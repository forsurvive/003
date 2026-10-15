## 실내 놀이 진행기 (단계 0-5): 실내 맵 하나를 띄우고 주인공을 걷게 한다. 퀘스트 장면(0-6~0-9)이 이것 위에 얹힌다.
##   맵 전환: 출구 칸에 들어서면 디더 페이드 → 갈 맵의 표지(from_<지금 맵>)에 내려 그 방향을 본다 → 맵 이름 띠(쯔꾸르식).
##   조사 키(interact: E·Enter, 터치는 조사 단추): 바라보는 쪽 인물에게 말을 걸고(조건이 맞는 대화 장면, 없으면 한 줄 바크),
##     인물이 없으면 앞 칸의 조사 글(벽 앞이면 벽면 두 칸까지)을 읽는다.
##   인물: 맵 원고의 npc(cond가 참인 사람만), 일과(route)가 있으면 NpcRoutine으로 오간다. 대화 중에는 멈추고 주인공을 본다.
##   대화·연출 중에는 주인공이 움직이지 않는다. 이벤트 실행기(연출)·서류(Documents)도 여기에 붙는다.
class_name InteriorHost
extends Node2D

signal map_entered(map_id: String)
signal talked(npc_id: String, scene: String)
signal day_tick(day: int)                          ## 게임 시간 06:00을 넘었다(SD-05 §6.4 하루 판정, 1-3)
signal pc_died                                     ## 주인공이 쓰러졌고 생포도 아니다(1막 이후 — 진행이 마지막 저장을 연다)

const BANNER_SECS := 2.4

var st: StoryState
var map: InteriorMap
var player: Actor
var cam: Camera2D
var box: DialogueBox
var ev: EventRunner
var npcs: Array = []                             ## [{"id", "actor", "routine", "bark"}]
var scenes_by_npc := {}                          ## 인물 ID -> [대화 장면, …](원고 순서)
var input_vec := Vector2.ZERO                    ## 외부(봇·터치)가 넣는 이동 입력. 없으면 키보드
var input_fn := Callable()                       ## 봇: 1/60초마다 다시 묻는 이동 입력(긴 프레임에서 칸 가운데를 지나쳐 맴돌지 않게)
var use_keyboard := true
var busy := false                                ## 전환·대화·연출 중
var banner: Control
var banner_text := ""
var banner_t := 0.0
var font: Font
var body := "adult"                              ## 주인공 모습: adult 페이퍼돌 · kid 아이 페이퍼돌(K1, 2268 열 살) · toddler 걸음마(2259 돌잔치,
                                                 ## 걷기만·느림) · hidden 안 보임(컷신)
var locked := false                              ## 주인공 조작 막기(연출 장면)
var fired := {}                                  ## once 밟는 칸: "맵:x,y" -> true
var hints: Array = []                           ## 조작 도움말 차례: [[글, 초], …] — 맵 이름 띠가 지나간 뒤, 대화 중에는 멈췄다가 하나씩
var hint_t := 0.0
const CROUCH_WALK := {"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.5}}   ## 웅크려 걷기 1.5t/초(SD-11 §2.4)
const TODDLER_WALK := {"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.8}}
var combat: InteriorCombat                       ## 실내 전투(무기·표적·적) — 무기를 들지 않으면 아무것도 하지 않는다
var pipboy: PipBoy                               ## 열려 있는 핍-보이(없으면 null)
var container: ContainerScreen                   ## 열려 있는 용기 창(없으면 null, 0-9)
var terminal: TerminalScreen                     ## 열려 있는 단말 화면(1-4) — 단말·해킹 중에는 게임 시간이 멈춘다(SD-12 §8.1)
var lockpick: LockScreen                         ## 열려 있는 자물쇠 따기 화면(1-5) — 게임 시간이 멈춘다(SD-12 §8.1)
var lock_assist := false                         ## 옵션 '자물쇠 보조'(근접도 막대)
var terms_db := {}                               ## 단말 원고(game/data/terminals.json)
var _prompt_shake := -1.0                        ## 요구치 미달로 시도하면 상호작용 문구가 0.8초 흔들린다(SD-12 §8.1)
var pipboy_ok := false                           ## 핍-보이를 받았다(MQ-P2 생일잔치부터)
var items_db := {}                               ## 아이템 ID -> 이름·분류·설명(data/items.json + weapons.json)
var date_text := "":                             ## 핍-보이 위 줄 날짜(바뀌면 GAME_HOUR도 — 맵 조건식의 시각, 1-6)
	set(v):
		date_text = v
		if st != null and st.vars.has("GAME_HOUR") and v != "":
			st.vars.set_v("GAME_HOUR", Clock.hour(v))
var cam_lead := Vector2.ZERO                     ## 카메라 리드(조준 쪽으로 끌린 만큼)
var text_seen := {}                              ## 여러 번 조사하는 글: 키 -> 읽은 횟수
var _talking: Dictionary = {}
var _barking := false                                               ## 지금 대화가 바크 한 줄인가(수첩에 올리지 않는다)
var _last_tile := Vector2i(-99, -99)
var _zone := ""                                                  ## 월드에서 지금 선 구역(손 맵 이름 또는 "W") — 바뀌면 map_entered(1-1)
var _region := ""
var zone_walk := false                                           ## map_entered가 걸어서 구역을 넘은 것인가(문 전환이 아님)                                                ## 월드에서 지금 선 권역(R01~R11·HR) — 바뀌면 배너
var _from := ""
const TIME_SCALE := 30.0                                          ## 실시간 1초 = 게임 30초(SD-11 §1, SD-12 확정)
var _clock_acc := 0.0
var enc_live: EncounterLive                                       ## 인카운터 진행(1-3)
var story_hold := false                                           ## 이야기 사건 중(MQ-106 버티버드 등): 무작위 인카운터를 세우지 않는다(1-7)
var capture_hooks := {}                                           ## 잡은 쪽 → 진행기 함수(1-7: "BJ" 계엄군 생포 · "BJ_HANDOVER" 새벽인력 인계 → 청계산 귀빈실)


func _ready() -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	if st == null:
		st = StoryState.new()
		st.load_data()
	_index_scenes()
	cam = Camera2D.new()
	add_child(cam)
	if is_inside_tree():                                             # 시험은 나무 밖에서 _ready를 부른다
		cam.make_current()
	box = DialogueBox.new()
	add_child(box)
	box.finished.connect(_on_dialogue_done)
	box.line_shown.connect(_on_line)
	box.subject = _subject
	ev = EventRunner.new()
	add_child(ev)
	ev.attach(box)
	Documents.attach(ev, st, self)
	combat = InteriorCombat.new()
	add_child(combat)
	combat.message.connect(func(t: String) -> void: hint(t, 3.0))
	enc_live = EncounterLive.new().setup(self)
	add_child(enc_live)
	combat.hurt.connect(func(_a: float) -> void: _hurt_t = 0.3)
	combat.hurt.connect(_armor_hit)
	combat.armor_dr = pc_dr
	combat.resident_hit.connect(_on_resident_hit)
	combat.resident_down.connect(_on_resident_down)
	combat.enemy_down.connect(_on_enemy_down)                        # 유해 소지품(1-4 파밍)
	_handlers()
	_load_items()
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	banner = Control.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_banner)
	layer.add_child(banner)


# ---------------------------------------------------------------- 밤(0-10, SD-16 §4.7 상황 필터 + §10.6 빛 원판)
var night := false
var _night_layer: CanvasLayer
var _light_layer: CanvasLayer
var _lights: Node2D
var _flicker_t := 0.0
const LIGHT_PROPS := {"drum_fire": Vector2(0, -20), "guard_booth": Vector2(0, -26), "watchtower": Vector2(0, -78)}


func set_night(on: bool) -> void:
	night = on
	if on and _night_layer == null:
		_night_layer = CanvasLayer.new()
		_night_layer.layer = 1                                        # 맵(0층) 위, HUD·대화(8층~) 아래
		add_child(_night_layer)
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)                # 화면 전체(크기는 앵커가 정한다)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load("res://systems/display/night_tone.gdshader")
		r.material = m
		_night_layer.add_child(r)
		_light_layer = CanvasLayer.new()
		_light_layer.layer = 2
		_light_layer.follow_viewport_enabled = true                  # 빛은 세상 좌표(카메라를 따라간다)
		add_child(_light_layer)
		_lights = Node2D.new()
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_lights.material = cm
		_lights.draw.connect(_draw_lights)
		_light_layer.add_child(_lights)
	if _night_layer != null:
		_night_layer.visible = on
		_light_layer.visible = on
		_lights.queue_redraw()


## 빛 원판: 반지름 64px 4단(가운데가 가장 밝다), 백열 P50. 디더·그라데이션 없이 단 색 띠(§10.6)
func _draw_lights() -> void:
	if map == null:
		return
	for p in map.props:
		var off: Variant = LIGHT_PROPS.get(p["name"])
		if off == null:
			continue
		var c := Vector2(int(p["x"]) * 32 + 16 * int(p["w"]), (int(p["y"]) + int(p["h"])) * 32) + (off as Vector2)
		var k := 1.0 + (0.06 if p["name"] == "drum_fire" and int(_flicker_t * 6.0) % 2 == 0 else 0.0)
		for i in 4:
			var r := 64.0 * k * (1.0 - i * 0.22)
			_lights.draw_circle(c, r, Color(1.0, 0.92, 0.6, 0.05 + i * 0.035))


func _night_tick(dt: float) -> void:
	if not night or map == null:
		return
	_flicker_t += dt
	var f := int(_flicker_t * 6.0) % 3
	if f != int((_flicker_t - dt) * 6.0) % 3:
		for p in map.props:
			if p["name"] == "drum_fire":
				map.set_prop_state(Vector2i(int(p["x"]), int(p["y"])), ["", "f1", "f2"][f])
		_lights.queue_redraw()


func _index_scenes() -> void:
	var p := "res://data/dialogue/_index.json"
	if not FileAccess.file_exists(p):
		return
	for sid in JSON.parse_string(FileAccess.get_file_as_string(p))["scenes"]:
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % sid))
		var who: String = g.get("npc", "")
		if who != "":
			if not scenes_by_npc.has(who):
				scenes_by_npc[who] = []
			scenes_by_npc[who].append(g)


## 맵을 연다. mark: 주인공이 설 표지(없으면 첫 표지)
## at: 표지 대신 이 자리에 세운다(불러오기 — 월드는 그 자리로 구역·청크를 정한다)
var last_mark := ""                              ## 마지막으로 들어온 표지(1-4: 어느 문으로 들어왔나 — 북쪽 출구 매복은 안에서 나올 때만)


func enter(map_id: String, mark: String = "", look: Dictionary = {}, at: Vector2 = Vector2.INF) -> void:
	last_mark = mark
	var keep_buddy := buddy_id if combat.buddy != null and is_instance_valid(combat.buddy) else ""   # 일시 동행은 맵을 넘어 따라온다(0-9)
	if map != null:
		for n in npcs:
			if is_instance_valid(n["actor"]):
				n["actor"].queue_free()
		npcs.clear()
		if player != null:
			map.remove_actor(player)
			map.objects.remove_child(player)
		map.queue_free()
	for a in ev.actors.values():                                    # 연출로 세운 인물·맵 인물은 옛 맵과 함께 사라진다
		if is_instance_valid(a) and a != player:
			a.queue_free()
	ev.actors.clear()
	ev._bg.clear()
	ev.cam_locked = false
	var world_mode := WorldMap.covers(map_id)                       # 바깥(관악산 비탈·봉천 등)은 심리스 월드 하나(1-1)
	var from_inside := map != null and not (map is WorldMap)
	if enc_live != null:
		enc_live.on_map_changed()
	map = WorldMap.new() if world_mode else InteriorMap.new()
	map.load_map(map_id, st)
	if not world_mode:                                                   # 자물쇠로 딴 문은 열린 채로 남는다(1-5)
		for d in map.doors:
			if bool(d["locked"]) and st.boxes.has("door:%s:%d,%d" % [map_id, int(d["x"]), int(d["y"])]) \
					and bool(st.boxes["door:%s:%d,%d" % [map_id, int(d["x"]), int(d["y"])]].get("open", false)):
				map.unlock_door(int(d["x"]), int(d["y"]))
	if world_mode and map_id != "W" and map.marks.has("%s:%s" % [map_id, mark]):
		mark = "%s:%s" % [map_id, mark]
	add_child(map)
	move_child(map, 0)
	if player != null and player.get_meta("body", "") != body:
		player.queue_free()                                          # 모습이 바뀌었다(걸음마 ↔ 어른): 새로 만든다
		player = null
	if player == null:
		player = Actor.new()
		if body == "toddler":
			var sk: String = CharDocs.look_of(st)["skin"]
			player.setup("st_look_k1_%s_hr00_h1_t01_0_pf11_hd00_ey00" % sk.to_lower(), Vector2.ZERO, map)
			player.loco.custom = TODDLER_WALK
		else:
			var lk := look if not look.is_empty() else CharDocs.paperdoll_look(CharDocs.look_of(st))
			if body == "kid":
				lk["body"] = "K1"
			player.setup_doll(lk, Vector2.ZERO, map)
		player.set_meta("body", body)
	player.world = map
	if player.doll != null and worn() != "A-001" and torso_of(worn()) != "":
		player.doll.set_look({"torso": torso_of(worn())})                 # 갈아입은 옷(0-10)
	player.visible = body != "hidden"
	map.add_actor(player)
	if world_mode and at == Vector2.INF and mark.begins_with("@"):     # 들어가 본 건물에서 나온다(1-5e): 그 문 앞 칸, 남쪽을 보고
		var xy := mark.substr(1).split(",")
		at = Vector2(int(xy[0]) * 32 + 16, int(xy[1]) * 32 + 16)
	if world_mode and at == Vector2.INF and mark.begins_with("L-"):    # 실내에서 월드의 장소로 나간다(1-3): 그 장소의 도착 칸
		PlaceLog.load_db()
		var arr = PlaceLog.db.get(mark, {}).get("arrive")
		if arr != null:
			at = Vector2(int(arr[0]) * 32 + 16, int(arr[1]) * 32 + 16)
	var m: String = mark if map.marks.has(mark) else (map.marks.keys()[0] if not map.marks.is_empty() else "")
	player.loco.place(map.mark_pos(m) if at == Vector2.INF else at)
	player.loco.facing = EventRunner.DIR_IDX.get(map.mark_dir(m), 2)
	player.position = player.loco.render
	if map is WorldMap:
		map.follow = player
		map.id = map.zone_of(map.tile_of(player.loco.logical))
		map.load_now(player.loco.logical)
		map_id = map.id
		_zone = map.id
	player._show()
	_last_tile = map.tile_of(player.loco.logical)
	_spawn_npcs()
	if map_id == "V-00" and int(st.vars.get_v("V_ESCAPE")) >= 1 and st.quests.stage("MQ-P4") < 60:
		map.set_gate(1.0)                                              # 탈출 중 레버로 다시 연 방폭문은 맵을 다시 열어도 열린 채
	ev.actors["PC"] = player                                          # 연출 명령이 주인공도 부를 수 있다(move PC 표지 · face PC 방향, 0-9)
	combat.on_map(map, player, st)
	combat.set_residents(npcs)
	ev.setup(map, map_id, cam)
	if keep_buddy != "":
		_bring_buddy(keep_buddy)
	if world_mode and from_inside and enc_live != null:
		enc_live.on_exit_interior.call_deferred()                    # 실내에서 밖으로 나온 순간도 판정 기회(SD-05 §6.1)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = map.size.x * 32
	cam.limit_bottom = map.size.y * 32
	cam.position = player.loco.logical.round()
	cam.reset_smoothing()
	if _lights != null:
		_lights.queue_redraw()
	banner_text = map.zone_name() if map is WorldMap else map.data["name"]
	banner_t = BANNER_SECS
	map_entered.emit(map_id)


func _spawn_npcs() -> void:
	for i in map.data["npcs"].size():
		var n: Dictionary = map.data["npcs"][i]
		var cond: String = n.get("cond", "")
		if cond != "" and not StoryExpr.test(cond, st):
			continue
		if st.dead.has(str(n["id"])):                                    # 죽인 주민은 다시 서지 않는다(SD-10 §6.3, 0-9)
			continue
		_spawn_npc(i, n)


## 맵 인물을 조건대로 다시 세운다(연출 명령 `refresh`, 단계 0-8): 조건이 거짓이 된 인물은 치우고, 참이 된 인물은 그 자리에 세운다.
## 같은 장면 안에서 사건 결과에 따라 교실 자리가 바뀌는 데 쓴다(맵을 다시 열지 않는다).
func refresh_npcs() -> void:
	var keep: Array = []
	var live := {}
	for e in npcs:
		var n: Dictionary = map.data["npcs"][int(e["idx"])] if int(e.get("idx", -1)) >= 0 else {}
		var cond: String = n.get("cond", "")
		if not is_instance_valid(e["actor"]) or (cond != "" and not StoryExpr.test(cond, st)):
			if is_instance_valid(e["actor"]):
				map.remove_actor(e["actor"])
				map.blockers.erase(e["actor"])
				if ev.actors.get(e["id"]) == e["actor"]:
					ev.actors.erase(e["id"])
				e["actor"].queue_free()
			continue
		keep.append(e)
		live[int(e["idx"])] = true
	npcs = keep
	for i in map.data["npcs"].size():
		var n: Dictionary = map.data["npcs"][i]
		var cond: String = n.get("cond", "")
		if live.has(i) or (cond != "" and not StoryExpr.test(cond, st)) or st.dead.has(str(n["id"])):
			continue
		_spawn_npc(i, n)
	combat.set_residents(npcs)


func _spawn_npc(i: int, n: Dictionary) -> void:
	var sheet: String = n.get("sheet", ev.cast_sheets.get(n["id"], ""))
	if sheet == "" or not ResourceLoader.exists("res://assets/sprites/%s.tres" % sheet):
		return
	if n.has("sheet"):
		st.portrait_alias[n["id"]] = n["sheet"]                    # 다른 시대 모습: 초상화도 그 모습으로
	else:
		st.portrait_alias.erase(n["id"])
	var a := Actor.new()
	a.setup(sheet, Vector2(int(n["x"]) * 32 + 16, int(n["y"]) * 32 + 16), map)
	a.mode = "walk"
	a.loco.facing = EventRunner.DIR_IDX.get(n["dir"], 2)
	a._show()
	map.add_actor(a)
	var r: NpcRoutine = NpcRoutine.new(a, map, n["route"]) if not n["route"].is_empty() else null
	npcs.append({"id": n["id"], "actor": a, "routine": r, "bark": n.get("bark", ""), "idx": i})
	ev.actors[n["id"]] = a                                       # 연출 명령(move·face·balloon·pose)이 맵 인물을 부를 수 있게
	map.blockers.append(a)


## 장소 표시(일시 정지·저장 칸): 볼트 실내 = 볼트 S-07 · 맵 이름, 월드 = 권역 · 구역 이름(1-1)
func _place_name() -> String:
	if map == null:
		return ""
	if map is WorldMap:
		var rn: String = map.region_name(map.region_at(map.tile_of(player.loco.logical))) if player != null else "서울"
		var zn: String = map.zone_name()
		return rn if zn == rn else "%s · %s" % [rn, zn]
	return ("볼트 S-07 · " if map.id.begins_with("V-") else "관악 · ") + str(map.data["name"])


func _physics_process(dt: float) -> void:
	if map == null:
		return
	if map is WorldMap and map.id != _zone:                          # 걸어서 다른 구역(손 맵)에 들어섰다: 맵에 들어선 것과 같이 알린다
		_zone = map.id
		_region = map.region_at(map.tile_of(player.loco.logical))
		banner_text = map.zone_name()
		banner_t = BANNER_SECS
		zone_walk = true                                             # 걸어서 바뀐 구역: 문 전환 자동 저장 사유가 아니다(SD-12 §13.2)
		map_entered.emit(_zone)
		zone_walk = false
	elif map is WorldMap and _zone == "W":                           # 월드 안에서 권역 경계를 넘으면 권역 이름만 띄운다
		var rc: String = map.region_at(map.tile_of(player.loco.logical))
		if rc != _region and rc != "":
			_region = rc
			banner_text = map.region_name(rc)
			banner_t = BANNER_SECS
	banner_t = maxf(0.0, banner_t - dt)
	_night_tick(dt)
	_hurt_t = maxf(0.0, _hurt_t - dt)
	_hud_t += dt
	_drain_events()
	for n in notes:
		n[1] -= dt
	notes = notes.filter(func(n): return n[1] > 0.0)
	if not hints.is_empty() and banner_t <= 0.0 and not box.active:
		hint_t += dt
		if hint_t >= float(hints[0][1]):
			hints.pop_front()
			hint_t = 0.0
	banner.queue_redraw()
	var talking: bool = box.active or ev.busy() or busy or locked or body == "hidden"
	for n in npcs:
		if float(n.get("down_t", 0.0)) > 0.0:
			_down_tick(n, dt)
			continue
		if n["routine"] != null and is_instance_valid(n["actor"]) and not n.get("dead", false):
			n["routine"].tick(dt, player.loco.logical)
	talking = talking or pipboy != null or container != null or terminal != null or lockpick != null
	if talking:
		if not ev.drives(player):                                         # 연출이 주인공을 걷게 하는 중이면(move PC …) 멈추지 않는다
			player.move(Vector2.ZERO, dt)
	else:
		var v := input_vec
		if use_keyboard and v == Vector2.ZERO:
			v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		player.mode = "walk" if body == "toddler" or combat.crouch or combat.inject_t > 0.0 else "run"
		player.loco.custom = TODDLER_WALK if body == "toddler" else (CROUCH_WALK if combat.crouch else {})
		if input_fn.is_valid():
			var left := dt
			while left > 0.0001:
				var h := minf(left, 1.0 / 60.0)
				left -= h
				player.move(input_fn.call(), h)
		else:
			player.move(v, dt)
		if player.doll != null:
			player.doll.position.y = 2.0 if combat.crouch else 0.0               # 웅크리면 2px 낮게(전용 그림 전까지)
		if use_keyboard and Input.is_action_just_pressed("interact") and not box.active:
			interact()
		if use_keyboard and pipboy_ok and Input.is_action_just_pressed("pipboy"):
			open_pipboy()
		_check_exit()
		_clock_step(dt)
		enc_live.tick(dt)
	combat.tick(dt, not talking, st)
	var want := Vector2.ZERO                                              # 조준 쪽으로 카메라를 끈다(원거리 무기, 최대 3칸 — SD-12 §15 '카메라 리드')
	if combat.armed() and combat.weapon()["kind"] == "ranged" and not talking:
		want = ((combat._aim_point(player) - player.loco.logical) * 0.4).limit_length(96.0)
	cam_lead = cam_lead.lerp(want, 1.0 - exp(-dt * 5.0))
	if not ev.cam_locked:
		cam.position = (player.loco.logical + cam_lead).round()


## 맵을 옮긴 뒤 동행을 주인공 등 뒤(바라보는 반대쪽) 가장 가까운 빈 칸에 세운다
func _bring_buddy(id: String) -> void:
	var back: Vector2 = -Locomotion.VEC[player.loco.facing].normalized()
	var at := player.loco.logical
	for r in [1, 2, 3]:
		for off in [back, back.rotated(PI / 4.0), back.rotated(-PI / 4.0), back.rotated(PI / 2.0), back.rotated(-PI / 2.0)]:
			var c := map.tile_of(player.loco.logical + off * 32.0 * r)
			if not map.is_solid(c):
				at = Vector2(c.x * 32 + 16, c.y * 32 + 16)
				break
		if at != player.loco.logical:
			break
	ev._show_actor(id, at, "S")
	if ev.actors.has(id):
		var b: Actor = ev.actors[id]
		b.loco.facing = player.loco.facing
		b._show()
		combat.buddy = b


## 장소 발견(SD-12 §5.5): 반경 4타일 안에 들면 '발견' — 알림 · 발견 XP(마커 N은 구역 이름만, XP 없음)
func _discover(t: Vector2i) -> void:
	for lid in st.places.discover_near(t):
		var e: Dictionary = PlaceLog.db[lid]
		if bool(e["marker"]):
			_note("장소 발견: " + str(e["name"]))
			if int(e["xp"]) > 0:
				st.call_fn("xp", [int(e["xp"])])
		else:
			hint(str(e["name"]), 3.0)


func _check_exit() -> void:
	var t := map.tile_of(player.loco.logical)
	if t == _last_tile:
		return
	_last_tile = t
	if map is WorldMap:
		_discover(t)
		st.places.mark_seen(t)
		var rc: String = map.region_at(t)
		if rc != "":
			st.places.regions[rc] = true
	for g in map.triggers_at(t):                                      # 밟는 칸: 조건이 맞으면 장면을 연다
		var key: String = g.get("key", "%s:%d,%d" % [map.id, int(g["x"]), int(g["y"])])   # 월드는 손 맵 좌표 열쇠(옛 저장과 같다)
		if (g["once"] and fired.has(key)) or not InteriorMap._cond_ok(g["cond"], st):
			continue
		fired[key] = true
		player.move(Vector2.ZERO, 0.0)
		play_scene(g["scene"])
		return
	var e := map.exit_at(t)
	if e.is_empty():
		return
	go(e["to"], e["mark"])


## 원고의 대화 장면 하나를 연다(연출 명령은 이벤트 실행기가 맵 위에서 실행한다)
func play_scene(scene_id: String, label: String = "START") -> void:
	var p := "res://data/dialogue/%s.json" % scene_id
	if not FileAccess.file_exists(p):
		push_warning("없는 장면: " + scene_id)
		return
	box.open(st, JSON.parse_string(FileAccess.get_file_as_string(p)), label)


## 조작 도움말(쯔꾸르식 튜토리얼 띠): 화면 왼쪽 위에 secs초. 여럿이면 차례로, 맵 이름 띠가 사라진 뒤부터 센다
func hint(text: String, secs: float = 5.0) -> void:
	hints.append([text, secs])


## 다른 맵으로(디더 페이드). 갈 맵이 없으면(아직 만들지 않은 바깥 등) 막혔다는 글만 띄운다.
func go(map_id: String, mark: String) -> void:
	if map_id != "W" and not InteriorMap.exists(map_id):              # W = 심리스 월드(맵 파일이 아니라 청크)
		say_text("이 앞은 아직 갈 수 없다.")
		return
	busy = true
	player.move(Vector2.ZERO, 0.0)
	ev.run("fade_out", ["black", "3"], func() -> void:
		enter(map_id, mark)
		ev.run("fade_in", ["black", "3"], func() -> void: busy = false))


## 조사 키: 바라보는 쪽의 인물 → 조사 글(앞 칸, 벽 앞이면 벽면 두 칸)
func interact() -> bool:
	if box.active:                                                   # 대화·서류 중에는 새로 말을 걸지 않는다(장면이 처음부터 다시 열린다)
		return false
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	var best: Dictionary = {}
	var best_d := 1e9
	for n in npcs:
		if not is_instance_valid(n["actor"]) or n.get("dead", false) or float(n.get("down_t", 0.0)) > 0.0:
			continue
		var v: Vector2 = n["actor"].loco.logical - player.loco.logical
		var sc := v.length() * (1.5 - v.normalized().dot(f))            # 바라보는 쪽에 더 맞는 사람 먼저(나란히 선 두 사람 — 버티버드 문의 하도윤·육지환)
		if v.length() < 46.0 and v.normalized().dot(f) > 0.5 and sc < best_d:
			best = n
			best_d = sc
	if best.is_empty():                                             # 계산대·진열대 너머(앞 칸이 가구로 막혔고 그 너머가 트였다): 두 칸까지
		var fc := map.tile_of(player.loco.logical + f * 32.0)
		if map.is_solid(fc) and map.cover_at(fc) > 0:                   # 가구(엄폐가 되는 낮은·높은 소품) — 벽은 아니다
			for n in npcs:
				if not is_instance_valid(n["actor"]) or n.get("dead", false) or float(n.get("down_t", 0.0)) > 0.0:
					continue
				var v2: Vector2 = n["actor"].loco.logical - player.loco.logical
				if v2.length() < 76.0 and v2.normalized().dot(f) > 0.85 and v2.length() * (1.5 - v2.normalized().dot(f)) < best_d \
						and map.line_of_sight(player.loco.logical, n["actor"].loco.logical):
					best = n
					best_d = v2.length() * (1.5 - v2.normalized().dot(f))
	if not best.is_empty():
		talk(best)
		return true
	var cells := _front_cells()
	var b := _front_box(cells)
	if not b.is_empty():
		open_box(b)
		return true
	for cc in cells:                                                    # 자물쇠로 잠긴 문(1-5, lock=n): 자물쇠 따기
		var dr: Dictionary = map.locked_door_at(cc) if map.has_method("locked_door_at") else {}
		if not dr.is_empty() and int(dr.get("lock", -1)) >= 0:
			var lv := int(dr["lock"])
			var dkey := "door:%s:%d,%d" % [map.id, int(dr["x"]), int(dr["y"])]
			if st.boxes.has(dkey) and bool(st.boxes[dkey].get("jammed", false)):
				say_text("자물쇠 안이 부러져 있다. 열쇠가 있어야 연다.")
			elif not Lockpick.can_try(lv, st.skill("LOCKPICK")):
				_prompt_shake = _hud_t + 0.8
			else:
				open_lock(lv, "door", func() -> void:
					st.boxes[dkey] = {"open": true}
					map.unlock_door(int(dr["x"]), int(dr["y"])),
					func() -> void: st.boxes[dkey] = {"jammed": true})
			return true
	var tm := _front_term(cells)
	if not tm.is_empty():
		open_terminal(tm)
		return true
	var gd := _front_go(cells)
	if not gd.is_empty():
		_enter_go(gd)
		return true
	for cc in cells:
		if map.texts.has(cc):
			var m: Dictionary = map.text_meta.get(cc, {})
			if not m.is_empty():
				if not InteriorMap._cond_ok(str(m["cond"]), st):
					if str(m.get("plain", "")) != "":                         # 장면 조건이 아니면 그 자리의 보통 글(0-9)
						say_text(m["plain"])
						return true
					continue
				var n := int(text_seen.get(m["key"], 0))
				if n < m["seq"].size():                                      # 여러 번 조사: 차례로 다른 글, 다 읽으면 장면
					text_seen[m["key"]] = n + 1
					say_text(m["seq"][n])
					return true
				if m["scene"] != "":
					play_scene(m["scene"])
					return true
			say_text(map.texts[cc])
			if map.text_fx.has(cc):                                          # 소장소 쪽지(1-W): 지도 조각 — 가까운 장소 하나 표시(한 번만)
				var fk := "fx:%d,%d" % [cc.x, cc.y]
				if not st.boxes.has(fk):
					st.boxes[fk] = {"done": true}
					if str(map.text_fx[cc]) == "reveal_near":
						box.finished.connect(func() -> void: reveal_near(cc), CONNECT_ONE_SHOT)
			return true
	return false


## 앞 칸의 들어가는 문(1-5e 월드 건물 1층 문) — 없으면 빈 사전
func _front_go(cells: Array = []) -> Dictionary:
	if map == null or map.gos.is_empty():
		return {}
	for cc in (cells if not cells.is_empty() else _front_cells()):
		if map.gos.has(cc):
			return map.gos[cc]
	return {}


## 건물 문 열기: 잠겼으면 자물쇠 따기(딴 문은 'wdoor:x,y'에 남는다), 열리면 실내로
func _enter_go(gd: Dictionary) -> void:
	var key := "wdoor:%d,%d" % [int(gd["at"][0]), int(gd["at"][1])]
	var lv := int(gd.get("lock", 0))
	var opened := st.boxes.has(key) and bool(st.boxes[key].get("open", false))
	if lv > 0 and not opened:
		if st.boxes.has(key) and bool(st.boxes[key].get("jammed", false)):
			say_text("자물쇠 안이 부러졌다. 이 문은 이제 열리지 않는다.")
		elif not Lockpick.can_try(lv, st.skill("LOCKPICK")):
			_prompt_shake = _hud_t + 0.8
		else:
			open_lock(lv, "door", func() -> void:
				st.boxes[key] = {"open": true}
				go(str(gd["to"]), str(gd["mark"])),
				func() -> void: st.boxes[key] = {"jammed": true})
		return
	go(str(gd["to"]), str(gd["mark"]))


## 바라보는 앞 칸(벽을 보고 서면 벽면 두 칸까지)
func _front_cells() -> Array:
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	var c := map.tile_of(player.loco.logical + f * 24.0)
	var cells := [c]
	if f.y < -0.5:
		cells += [c + Vector2i(0, -1), c + Vector2i(0, -2)]
	return cells


## 앞 칸의 용기(조건이 맞는 것만, 없으면 빈 사전)
func _front_box(cells: Array = []) -> Dictionary:
	if map == null or map.boxes.is_empty():
		return {}
	for cc in (cells if not cells.is_empty() else _front_cells()):
		if map.boxes.has(cc):
			var b: Dictionary = map.boxes[cc]
			if InteriorMap._cond_ok(str(b.get("cond", "")), st):
				return b
	return {}


# ---------------------------------------------------------------- 용기(SD-12 §7.3·§9.2·§11.1, 0-9)
## 주인 이름: "" 없음 · PC 내 것 · S7 볼트 공용 · 인물 ID
func box_owner_label(b: Dictionary) -> String:
	var o := str(b.get("owner", ""))
	match o:
		"", "PC":
			return ""
		"S7":
			return "볼트 S-07 공용"
	return st.npc_name(o)


## 용기 내용물(1-4 파밍 v2): 맵 권역으로 등급을 정하고, 유해(_corpse)는 그 적의 드롭 표로 굴린다
func box_contents(b: Dictionary) -> Dictionary:
	if str(b.get("kind", "")) == "seized":                              # 계엄군 압수품 보관함(1-7): 진행기가 채운 한 상자
		if not st.boxes.has("bj_seized"):
			st.boxes["bj_seized"] = {"items": {}, "opened": 0, "taken": 0}
		return st.boxes["bj_seized"]
	if str(b.get("kind", "")) == "_corpse":
		var k := str(b["key"])
		if not st.boxes.has(k):
			st.boxes[k] = {"items": Loot.drop(str(b["eid"]), k, Loot.tier_of(st, map_region(Vector2i(int(b["x"]), int(b["y"])))),
				"enemy" if st.year() >= 2277 else ""),
				"opened": 0, "taken": 0}
		return st.boxes[k]
	return Loot.contents(st, map.id, b, map_region(Vector2i(int(b["x"]), int(b["y"]))))


## 칸의 권역(루팅 등급): 월드는 청크 권역, 실내는 맵 원고 폴더(r01·r02)
func map_region(t: Vector2i) -> String:
	if map is WorldMap:
		return (map as WorldMap).region_at(t)
	return str(map.data.get("region", ""))


## 쓰러진 적 자리에 유해(소지품 용기)를 둔다(SD-13 §9.3 세력·적 장비표). 바퀴·들개처럼 드롭이 없거나 고기만 주는 크리처는 두지 않는다
func _on_enemy_down(e: Enemy) -> void:
	var eid := str(e.get_meta("enemy_id", ""))
	if not Loot.drops.has(eid) or eid in ["CR-002", "CR-104"]:
		return
	var c := map.tile_of(e.loco.logical)
	if map.boxes.has(c):
		return
	var nm := str(combat.enemy_rows.get(eid, {}).get("name", "적"))
	map.boxes[c] = {"x": c.x, "y": c.y, "w": 1, "h": 1, "kind": "_corpse", "eid": eid, "name": nm + "의 유해", "owner": "", "lock": 0,
		"cond": "", "key": "corpse:%s:%d,%d@%d:%d" % [map.id, c.x, c.y, int(st.vars.get_v("GAME_DAY")), Time.get_ticks_msec()]}


func box_lock_key(b: Dictionary) -> String:
	return Loot.key(map.id, b, st.year())


## 잠김: 자물쇠 등급(SD-10 자물쇠 따기 25·50·75·100). 땄으면 st.boxes에 남는다
func box_locked(b: Dictionary) -> bool:
	var lv := int(b.get("lock", 0))
	if lv <= 0:
		return false
	var c := box_contents(b)
	return not bool(c.get("unlocked", false))


func open_box(b: Dictionary) -> void:
	player.move(Vector2.ZERO, 0.0)
	if body == "toddler":                                                # 돌잔치의 아기는 용기를 못 연다
		say_text("손이 닿지 않는다.")
		return
	var c := box_contents(b)
	if box_locked(b):
		if bool(c.get("jammed", false)):
			say_text("자물쇠 안이 부러져 있다. 열쇠가 있어야 연다.")
			return
		var lv := int(b.get("lock", 0))
		if not Lockpick.can_try(lv, st.skill("LOCKPICK")):
			_prompt_shake = _hud_t + 0.8                                 # 시도할 수 없다 — 문구만 흔들린다(SD-12 §8.1)
			return
		open_lock(lv, "dial" if str(b.get("kind", "")) == "safe" else ("pad" if str(b.get("kind", "")) in ["locker", "school_locker", "cabinet"] else "door"),
			func() -> void:
				c["unlocked"] = true                                         # 여는 것만으로는 절도가 아니다(꺼내야 절도)
				_open_container(b, c),
			func() -> void: c["jammed"] = true)
		return
	_open_container(b, c)


## 자물쇠 따기 화면(SD-12 §8.2)을 연다: 열리면 on_open, 강제 개방 실패(영구 파손)면 on_jam. 머리핀 M-070을 쓴다
func open_lock(lv: int, skin: String, on_open: Callable, on_jam: Callable = Callable()) -> void:
	lockpick = LockScreen.new().setup(st, lv, int(st.items.get("M-070", 0)), skin)
	lockpick.assist = lock_assist
	lockpick.pin_used.connect(func() -> void: st.call_fn("take", ["M-070", 1]))
	lockpick.opened.connect(func(xp: int) -> void:
		st.call_fn("xp", [xp])
		st.vars.set_v("STAT_LOCKS", int(st.vars.get_v("STAT_LOCKS")) + 1)
		_note("자물쇠를 땄다"))
	lockpick.jammed.connect(func() -> void:
		if on_jam.is_valid():
			on_jam.call())
	lockpick.closed.connect(func(ok: bool) -> void:
		lockpick = null
		if ok:
			on_open.call())
	add_child(lockpick)


func _open_container(b: Dictionary, c: Dictionary) -> void:
	var cmax := float(status()["carry_max"])
	container = ContainerScreen.new().setup(st, b, c, items_db, box_owner_label(b), cmax)
	container.stole.connect(_on_stole.bind(b))
	container.closed.connect(func(_ok: bool) -> void:
		container = null
		_after_theft())
	add_child(container)


# ---------------------------------------------------------------- 단말(SD-12 §7.4 · §8.1·§8.3 해킹, 1-4)
func _terms() -> Dictionary:
	if terms_db.is_empty() and FileAccess.file_exists("res://data/terminals.json"):
		terms_db = JSON.parse_string(FileAccess.get_file_as_string("res://data/terminals.json"))["terms"]
	return terms_db


func _front_term(cells: Array = []) -> Dictionary:
	if map == null or map.terms.is_empty():
		return {}
	for cc in (cells if not cells.is_empty() else _front_cells()):
		if map.terms.has(cc):
			var t: Dictionary = map.terms[cc]
			if InteriorMap._cond_ok(str(t.get("cond", "")), st) and _terms().has(str(t["id"])):
				return t
	return {}


## 단말 상태(저장): {"unlocked": 뚫음·비밀번호, "locked": 영구 잠김, "read": [읽은 항목 번호]}
func term_state(id: String) -> Dictionary:
	var k := "term:" + id
	if not st.boxes.has(k):
		st.boxes[k] = {"unlocked": false, "locked": false, "read": []}
	return st.boxes[k]


func term_prompt(t: Dictionary) -> String:
	var d: Dictionary = _terms()[str(t["id"])]
	var s := term_state(str(t["id"]))
	var tag := ""
	var lv := int(d.get("lock", 0))
	if lv > 0 and not s["unlocked"] and not (d.get("key", "") != "" and st.items.has(str(d["key"]))):
		var g: String = Hack.GRADES[maxi(0, Hack.REQ.find(lv))]
		if s["locked"]:
			tag = "  [잠김: 단말기 잠김]"
		elif st.skill("SCIENCE") < lv:
			tag = "  [잠김: %s · 과학 %d 필요]" % [g, lv]
		else:
			tag = "  [잠김: %s]" % g
	if str(d.get("owner", "")) != "":
		tag += "  [소유]"
	return "(E) 사용  " + str(d["name"]) + tag


func open_terminal(t: Dictionary) -> void:
	player.move(Vector2.ZERO, 0.0)
	var id := str(t["id"])
	var d: Dictionary = _terms()[id]
	var s := term_state(id)
	var lv := int(d.get("lock", 0))
	var need: bool = lv > 0 and not s["unlocked"]
	if need and str(d.get("key", "")) != "" and st.items.has(str(d["key"])):
		s["unlocked"] = true                                             # 비밀번호(SD-12 §8.3 흐름: 비밀번호가 있으면 메뉴 바로)
		need = false
		_note("비밀번호로 접속했다")
	if need and (s["locked"] or st.skill("SCIENCE") < lv):
		_prompt_shake = _hud_t + 0.8                                     # 시도할 수 없다 — 메시지 상자 없이 문구만 흔들린다
		return
	terminal = TerminalScreen.new().setup(st, id, d, need)
	terminal.hacked.connect(func(xp: int) -> void:
		s["unlocked"] = true
		st.call_fn("xp", [xp])
		st.vars.set_v("STAT_HACKED", int(st.vars.get_v("STAT_HACKED")) + 1)
		if str(d.get("owner", "")) != "":                              # 소유 단말 접근(해킹 포함) −5(SD-12 §9.2)
			st.call_fn("karma", [-5]))
	terminal.locked_out.connect(func() -> void: s["locked"] = true)
	terminal.read.connect(func(i: int) -> void:
		if not (i in s["read"]):
			s["read"].append(i)
			var fx := str(d["entries"][i].get("set", ""))
			if fx != "":
				StoryExpr.run(fx, st))
	terminal.closed.connect(func(_ok: bool) -> void: terminal = null)
	add_child(terminal)


## 거래 창(0-10c, SD-15 §3·§4): 상인 V번호. 진열·보유 캡은 st.boxes["shop:V01"]에 남고, 갱신 주기(일)마다 다시 채운다
## (보유 캡 = min(기준×1.5, max(기준, 현재×0.5)), 기준 = 등급 a + b × 주인공 레벨). done(오간 캡 합)은 창을 닫으면 부른다.
var merchants := {}


func shop_state(vid: String) -> Dictionary:
	if merchants.is_empty() and FileAccess.file_exists("res://data/merchants.json"):
		merchants = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	var m: Dictionary = merchants.get(vid, {})
	var key := "shop:" + vid
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 1
	var base := int(m["caps_base"][0]) + int(m["caps_base"][1]) * level()
	var sh: Dictionary = st.boxes.get(key, {})
	if sh.is_empty() or day - int(sh.get("day", day)) >= int(m.get("renew", 3)):
		var items := {}
		var stock: Array = (m["stock"] as Array).duplicate()
		if m.has("pick") and int(m["pick"]) < stock.size():            # 떠돌이 상인(1-E V57): 짐이 매번 다르다 — 갱신마다 그 판 씨앗으로 몇 줄만 고른다
			var rr := RandomNumberGenerator.new()
			rr.seed = hash("%s:%d:%d" % [vid, day, st.check_seed])
			for i in range(stock.size() - 1, 0, -1):
				var j := rr.randi_range(0, i)
				var tmp = stock[i]
				stock[i] = stock[j]
				stock[j] = tmp
			stock = stock.slice(0, int(m["pick"]))
		for r in stock:                                               # 진열 장비는 '양호' 이상(SD-15 §3.8) — 갱신마다 새로 굴린다(1-8a)
			var id := str(r[0])
			if Gear.is_gear_id(id):
				for i in int(r[1]):
					var kk := Gear.rolled_key(id, "shop", "%s:%d:%d" % [vid, day, i])
					items[kk] = int(items.get(kk, 0)) + 1
			else:
				items[id] = int(r[1])
		var caps := base if sh.is_empty() else mini(roundi(base * 1.5), maxi(base, roundi(int(sh["caps"]) * 0.5)))
		sh = {"items": items, "caps": caps, "day": day, "total": int(sh.get("total", 0))}
		st.boxes[key] = sh
	return sh


# ---------------------------------------------------------------- NPC 정비(1-8a, SD-15 §5.2)
## 정비 메뉴를 대화 선택지로 연다: 맡길 수 있는 장비마다 '한 단계 위로 · 정비비'([캡 N] 태그가 모자라면 꺼지고, 고르면 낸다).
## 한 단계를 고치면 메뉴가 다시 열린다(SD-15 '한 단계씩도 가능'). 상한(fix.cap)·계열(fix.kinds)·요율(fix.rate)은 상인 표가 정한다
func fix_menu(vid: String, again: bool = false) -> void:
	shop_state(vid)
	var m: Dictionary = merchants.get(vid, {})
	var fx: Dictionary = m.get("fix", {})
	var npc := str(m.get("npc", ""))
	var lines: Array = fx.get("lines", ["어느 걸 손볼까?", "됐다. 또?", "손볼 게 없네."])
	var ops: Array = []
	var labels := {"START": 0}
	var opts: Array = []
	var jobs := fix_jobs(vid)
	ops.append({"op": "line", "who": npc, "emo": "기본", "text": str(lines[1] if again else lines[0]) if not jobs.is_empty() else str(lines[2])})
	if not jobs.is_empty():
		for i in jobs.size():
			var j: Dictionary = jobs[i]
			opts.append({"text": "%s → %s" % [str(items_db.get(j["key"], {}).get("name", j["key"])), Gear.NAMES[int(j["to"])]],
				"tags": [{"k": "caps", "n": int(j["cost"])}], "cond": "", "fx": "", "to": "F%d" % i, "id": "FIX:%s:%d" % [vid, i]})
		opts.append({"text": "됐다", "tags": [], "cond": "", "fx": "", "to": "END", "id": "FIX:%s:end" % vid})
		ops.append({"op": "choice", "opts": opts})
		for i in jobs.size():
			labels["F%d" % i] = ops.size()
			ops.append({"op": "cmd", "name": "fixdo", "args": [vid, str(jobs[i]["key"])]})
			ops.append({"op": "goto", "to": "END"})
	ops.append({"op": "end"})
	box.open(st, {"id": "FIX_" + vid, "title": str(m.get("name", vid)), "npc": npc, "labels": labels, "ops": ops}, "START")


## 맡길 수 있는 일: [{"key", "to", "cost"}] — 정비사 계열 · 상한보다 나쁜 상태 · 파손 포함. 정비비는 한 단계 위까지
func fix_jobs(vid: String) -> Array:
	var m: Dictionary = merchants.get(vid, {})
	var fx: Dictionary = m.get("fix", {})
	if fx.is_empty():
		return []
	var ak := st._aff_key(str(m.get("settle", "")))
	var f := TradeScreen.tier_f(int(st.vars.get_v(ak)) if ak != "" else 0)
	if f.is_empty():
		return []
	var rate := float(fx.get("rate", 1.0))
	if vid == "V03" and int(st.vars.get_v("MQ101_RESULT")) == 5:
		rate *= 1.25                                                    # 마을을 판 손님: 값은 따로(원고 BC_NAM COLD)
	if vid == "V09" and st.vars.has("MQ103_CONF") and int(st.vars.get_v("MQ103_CONF")) == 1:
		rate *= 0.9                                                     # "정비는 1할 빼 줄게"(MQ-103 FRIEND)
	var out: Array = []
	var ks := st.items.keys()
	ks.sort()
	for k in ks:
		var c := Gear.cond(str(k))
		if c <= int(fx.get("cap", 0)) or not Gear.fixable_by(str(k), fx.get("kinds", [])):
			continue
		var v := int(items_db.get(Gear.base(str(k)), {}).get("value", 0))
		out.append({"key": str(k), "to": c - 1, "cost": Gear.fix_cost(v, c, c - 1, st.skill("BARTER"), float(f[0]), rate)})
	return out


func open_trade(vid: String, done: Callable, k := [1.0, 1.0], greet := "", item_k := {}) -> TradeScreen:
	player.move(Vector2.ZERO, 0.0)
	var sh := shop_state(vid)
	var m: Dictionary = merchants.get(vid, {})
	var ak := st._aff_key(str(m.get("settle", "")))
	var f := TradeScreen.tier_f(int(st.vars.get_v(ak)) if ak != "" else 0)
	if f.is_empty():
		say_text("상인이 고개를 젓는다. 거래하지 않겠다는 뜻이다.")
		done.call(0)
		return null
	k = [float(k[0]) * float(m.get("rate", 1.0)), k[1]]                # 상인 요율(손님 값 1.2배 등, SD-15 §3.1 K)
	var t := TradeScreen.new().setup_trade(st, vid, m, sh, items_db, float(150 + 10 * st.stat("ST")), st.skill("BARTER"), f, k,
		greet if greet != "" else str(m.get("greet", "")))
	t.item_k = item_k
	container = t
	t.closed.connect(func(_ok: bool) -> void:
		container = null
		sh["total"] = int(sh.get("total", 0)) + t.total
		done.call(t.total))
	add_child(t)
	return t


## 절도(SD-12 §9.2·SD-10 §6.3): 이 용기의 이 시대 첫 절도에 카르마 −5(주인이 악인이 아니면 — 볼트 주민은 모두 아니다).
## 보는 사람이 있으면(8칸 안·시야·이쪽을 보고 있음) 창을 닫은 뒤 그 사람이 한마디 하고 S7_THEFT_SEEN이 오른다.
var _theft_witness := ""
var _box_hinted := false


func _on_stole(first: bool, b: Dictionary) -> void:
	if first and not bool(st.npcs.get(str(b.get("owner", "")), {}).get("evil", false)):
		st.call_fn("karma", [-5])
	var w := theft_witness()
	if w != "" and _theft_witness == "":
		_theft_witness = w


## 지금 주인공을 보고 있는 주민(가장 가까운 사람의 ID, 없으면 "")
func theft_witness() -> String:
	var best := ""
	var best_d := 8.0 * 32.0
	for n in npcs:
		var a = n["actor"]
		if not is_instance_valid(a) or not a.visible:
			continue
		var v: Vector2 = player.loco.logical - a.loco.logical
		var d := v.length()
		if d >= best_d:
			continue
		var look: Vector2 = Locomotion.VEC[a.loco.facing].normalized()
		if d > 40.0 and look.dot(v.normalized()) < 0.2:                 # 등지고 있으면 못 본다(바로 옆이면 본다)
			continue
		if not map.line_of_sight(a.loco.logical, player.loco.logical):
			continue
		best = str(n["id"])
		best_d = d
	return best


const THEFT_BARKS := ["거기, 남의 거잖아!", "지금 뭐 하는 거야? 그거 내려놔.", "…봤어. 보안과에 말할 거야.", "손버릇이 그래서야 쓰나."]


func _after_theft() -> void:
	if _theft_witness == "":
		return
	var w := _theft_witness
	_theft_witness = ""
	st.vars.set_v("S7_THEFT_SEEN", int(st.vars.get_v("S7_THEFT_SEEN")) + 1)
	for n in npcs:
		if str(n["id"]) == w and is_instance_valid(n["actor"]):
			n["actor"].loco.facing = Locomotion.snap8(player.loco.logical - n["actor"].loco.logical)
			n["actor"]._show()
			ev.balloons.append({"actor": n["actor"], "kind": "!", "t": 0.0})
	var line: String = THEFT_BARKS[int(st.vars.get_v("S7_THEFT_SEEN")) % THEFT_BARKS.size()]
	box.open(st, {"id": "theft_" + w, "labels": {"START": 0}, "ops": [{"op": "line", "who": w, "emo": "분노", "text": line}, {"op": "end"}]})


# ---------------------------------------------------------------- 주민 폭행·살인(SD-10 §6.3, 0-9)
## 맞음: 맵 방문마다 처음 한 번 S7_ASSAULT +1, "!" 말풍선·외침, 하던 일을 멈추고 이쪽을 본다(폭행 자체는 카르마가 아니다 — 원작).
## 기절(공기총·근접, 프롤로그 볼트에서는 실총도): 8초 누웠다가 일어난다. 1막 이후 실총으로 죽임: 악인이 아니면 카르마 −100,
## st.dead에 남아 다시 서지 않는다.
## 불사 4인: HP 1에서 무릎을 꿇고(5초) 일어난다.
const ASSAULT_BARKS := ["으악! 왜 이래!", "미쳤어? 그만해!", "보안과! 보안과!", "살려 줘!"]
const KO_SECS := 8.0
const KNEEL_SECS := 5.0


func _npc_entry(id: String) -> Dictionary:
	for n in npcs:
		if str(n["id"]) == id and is_instance_valid(n["actor"]):
			return n
	return {}


func _on_resident_hit(id: String) -> void:
	var n := _npc_entry(id)
	if n.is_empty():
		return
	var a: Actor = n["actor"]
	var c := combat.resident(id)
	if c != null and c.hp_floor > 0.0 and c.hp <= c.hp_floor and float(n.get("down_t", 0.0)) <= 0.0:
		n["down_t"] = KNEEL_SECS                                         # 불사: 무릎
		n["down_kind"] = "kneel"
		a.set_pose("sit")
		combat._pop("그만… 그만해…", a.loco.logical + Vector2(0, -34), Color("E9E4D8"))
	if n.get("assaulted", false):
		return
	n["assaulted"] = true
	st.vars.set_v("S7_ASSAULT", int(st.vars.get_v("S7_ASSAULT")) + 1)
	if n["routine"] != null:
		n["routine"].talk_to(player.loco.logical)
	else:
		a.loco.facing = Locomotion.snap8(player.loco.logical - a.loco.logical)
		a._show()
	ev.balloons.append({"actor": a, "kind": "!", "t": 0.0})
	combat._pop(ASSAULT_BARKS[int(st.vars.get_v("S7_ASSAULT")) % ASSAULT_BARKS.size()], a.loco.logical + Vector2(0, -34), Color("E04A35"))


## 볼트원을 죽일 수 있는가: 프롤로그 볼트(V_ACT 0, 평시 — 죽이면 처벌받아야 하는 곳)에서는 실총도 기절로 끝난다.
## 살인 규칙(−100·st.dead)은 1막 이후(4막 볼트 귀환 등)를 위해 남겨 둔다.
func residents_killable() -> bool:
	return int(st.vars.get_v("V_ACT")) >= 1


func _on_resident_down(id: String, killed: bool) -> void:
	var n := _npc_entry(id)
	if n.is_empty():
		return
	if killed and not residents_killable():
		killed = false
	var a: Actor = n["actor"]
	a.set_pose("lie")
	map.blockers.erase(a)
	if killed:
		n["dead"] = true
		st.dead[id] = st.year()
		st.vars.set_v("S7_KILLS", int(st.vars.get_v("S7_KILLS")) + 1)
		if not bool(st.npcs.get(id, {}).get("evil", false)):
			st.call_fn("karma", [-100])                                  # 악하지 않은 인물 살해(목격자가 없어도)
		combat._pop(st.npc_name(id) + " 사망", a.loco.logical + Vector2(0, -20), Color("E04A35"))
		st.book.died(id, date_text)                                     # 눈앞의 죽음 = 아는 죽음
	else:
		n["down_t"] = KO_SECS
		n["down_kind"] = "ko"
		combat._pop("기절", a.loco.logical + Vector2(0, -20), Color("E8C23A"))


func _down_tick(n: Dictionary, dt: float) -> void:
	n["down_t"] = float(n["down_t"]) - dt
	if float(n["down_t"]) > 0.0 or not is_instance_valid(n["actor"]):
		return
	n["down_t"] = 0.0
	var a: Actor = n["actor"]
	a.set_pose("stand")
	if not map.blockers.has(a):
		map.blockers.append(a)
	var c := combat.resident(str(n["id"]))
	if c != null:
		c.dead = false
		c.ko = false
		c.hp = c.max_hp * 0.5
	if n["routine"] != null:
		n["routine"].resume()


## 터치 상황 단추 글(SD-11 §15.5): 앞에 인물이면 '말하기', 용기면 '열기', 조사 글이면 '조사'. 없으면 빈 글(단추를 숨긴다)
func interact_label() -> String:
	if map == null or player == null or box.active:
		return ""
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	for n in npcs:
		if is_instance_valid(n["actor"]) and not n.get("dead", false):
			var v: Vector2 = n["actor"].loco.logical - player.loco.logical
			if v.length() < 46.0 and v.normalized().dot(f) > 0.5:
				return "말하기"
	var cells := _front_cells()
	if not _front_box(cells).is_empty():
		return "열기"
	if not _front_term(cells).is_empty():
		return "사용"
	for cc in cells:
		if map.texts.has(cc):
			return "조사"
	return ""


## 조사 안내(HUD): 앞 칸이 용기면 "(E) 열기 이름 [소유]·[빈 상자]·[잠김]", 단말이면 "(E) 사용 이름 [잠김: 등급 · 과학 n 필요]"
func box_prompt() -> String:
	var b := _front_box()
	if b.is_empty() and map != null and map.has_method("locked_door_at"):
		for cc in _front_cells():
			var dr: Dictionary = map.locked_door_at(cc)
			if not dr.is_empty() and int(dr.get("lock", -1)) >= 0:
				var lv := int(dr["lock"])
				var gi := Lockpick.grade_of(lv)
				var dkey := "door:%s:%d,%d" % [map.id, int(dr["x"]), int(dr["y"])]
				if st.boxes.has(dkey) and bool(st.boxes[dkey].get("jammed", false)):
					return "(E) 따기  %s  [열쇠 필요]" % str(dr.get("label", "문"))
				if Lockpick.can_try(lv, st.skill("LOCKPICK")):
					return "(E) 따기  %s  [잠김: %s]" % [str(dr.get("label", "문")), Lockpick.NAMES[gi]]
				return "(E) 따기  %s  [잠김: %s · 자물쇠 따기 %d 필요]" % [str(dr.get("label", "문")), Lockpick.NAMES[gi], int(Lockpick.REQ[gi])]
	if b.is_empty():
		var gd := _front_go()
		if not gd.is_empty():                                            # 건물 1층 문(1-5e)
			var lv := int(gd.get("lock", 0))
			var key := "wdoor:%d,%d" % [int(gd["at"][0]), int(gd["at"][1])]
			if lv <= 0 or (st.boxes.has(key) and bool(st.boxes[key].get("open", false))):
				return "(E) 들어간다  " + str(gd["name"])
			if st.boxes.has(key) and bool(st.boxes[key].get("jammed", false)):
				return "(E) 들어간다  %s  [열쇠 필요]" % str(gd["name"])
			var gi := Lockpick.grade_of(lv)
			if Lockpick.can_try(lv, st.skill("LOCKPICK")):
				return "(E) 따기  %s  [잠김: %s]" % [str(gd["name"]), Lockpick.NAMES[gi]]
			return "(E) 따기  %s  [잠김: %s · 자물쇠 따기 %d 필요]" % [str(gd["name"]), Lockpick.NAMES[gi], int(Lockpick.REQ[gi])]
		var tm := _front_term()
		return term_prompt(tm) if not tm.is_empty() else ""
	var nm: String = str(b.get("name", "")) if str(b.get("name", "")) != "" else Loot.kind_name(str(b["kind"]))
	var tag := ""
	if box_locked(b):
		var lv := int(b.get("lock", 0))
		var gi := Lockpick.grade_of(lv)
		if bool(box_contents(b).get("jammed", false)):
			tag = "  [열쇠 필요]"
		elif Lockpick.can_try(lv, st.skill("LOCKPICK")):
			tag = "  [잠김: %s]" % Lockpick.NAMES[gi]
		else:
			tag = "  [잠김: %s · 자물쇠 따기 %d 필요]" % [Lockpick.NAMES[gi], int(Lockpick.REQ[gi])]
	elif box_contents(b)["items"].is_empty():
		tag = "  [빈 상자]"
	if Loot.owned(b):
		tag += "  [소유]"
	return "(E) 열기  " + nm + tag


func talk(n: Dictionary) -> void:
	if n["routine"] != null:
		n["routine"].talk_to(player.loco.logical)
	else:
		n["actor"].loco.facing = Locomotion.snap8(player.loco.logical - n["actor"].loco.logical)
		n["actor"]._show()
	_talking = n
	var g := scene_for(n["id"])
	if g.is_empty():
		var own := str(n["bark"])                                     # 소문(1-4f): 이 사람이 들은 주인공 이야기 — 없으면 제 혼잣말
		var rumor := "" if str(n["id"]).begins_with("CR-") else \
			Rumors.pick(st, map_region(map.tile_of(n["actor"].loco.logical)), str(n["id"]) + str(n.get("idx", 0)), own != "")   # 경비·병사(CR-)는 근무 중 — 주민 소문을 옮기지 않는다
		var bark: String = rumor if rumor != "" else (own if own != "" else "……")
		g = {"id": "bark_" + n["id"], "labels": {"START": 0}, "ops": [{"op": "line", "who": n["id"], "emo": "기본", "text": bark}, {"op": "end"}]}
		_barking = true
	talked.emit(n["id"], g.get("id", ""))
	box.open(st, g)


## 이 인물의 대화 장면 가운데 조건이 맞는 첫 장면(없으면 빈 사전)
func scene_for(npc_id: String) -> Dictionary:
	for g in scenes_by_npc.get(npc_id, []):
		var cond: String = g.get("cond", "")
		if cond == "" or StoryExpr.test(cond, st):
			return g
	return {}


func say_text(text: String) -> void:
	box.open(st, {"id": "text", "labels": {"START": 0}, "ops": [{"op": "line", "who": "SYS", "emo": "기본", "text": text}, {"op": "end"}]})


## 대화 창 자리 정하기: 말하는 사람(무대·맵 인물)과 주인공의 화면 위 발 위치
func _subject(who: String) -> Array:
	var out := []
	var a = ev.actors.get(who)
	if a != null and is_instance_valid(a) and a.visible:
		out.append((a as Node2D).get_global_transform_with_canvas().origin)
	if player != null and player.visible and a != player:
		out.append(player.get_global_transform_with_canvas().origin)
	return out


# ---------------------------------------------------------------- HUD (SD-12 §4.2 PC 배치, U 팔레트 단색 + 1px U0 테두리)
const HU := DocScreen.GREEN
const HUD_RED := Color("E04A35")
var touch_layout := false                        ## 터치 배치(SD-12 §17.2): 상태 표시를 위로 올리고 아래 모서리는 엄지에게 — TouchHud가 켠다
var hud_on := false                              ## 핍-보이를 받으면 켠다(HUD = 핍-보이 표시)
var buddy_name := ""                             ## 일시 동행 이름(HUD 동행 칸)
var buddy_id := ""                               ## 일시 동행 인물 ID(맵을 옮기면 주인공 뒤 빈 칸에 다시 세운다)
var _hurt_t := 0.0
var _hud_t := 0.0
var font_s: Font


func _draw_hud() -> void:
	if not hud_on or box.active or ev.busy() or busy or pipboy != null or container != null or terminal != null or lockpick != null or body == "hidden":
		return
	if font_s == null:
		font_s = load("res://assets/fonts/Galmuri9.ttf")
	var vs := banner.get_viewport_rect().size
	var b := vs.y - 360.0                                                    # 아래 붙이기
	var r := vs.x - 640.0                                                    # 오른쪽 붙이기
	var c := combat.pc
	var low := c.hp <= c.max_hp * 0.2
	if _hurt_t > 0.0 or low:                                                 # 맞음: 가장자리 붉은 테 0.3초 / 20% 이하 맥동
		var a := 0.5 if _hurt_t > 0.0 else 0.25 + 0.2 * sin(_hud_t * 7.0)
		for rr in [Rect2(0, 0, vs.x, 3), Rect2(0, vs.y - 3, vs.x, 3), Rect2(0, 0, 3, vs.y), Rect2(vs.x - 3, 0, 3, vs.y)]:
			banner.draw_rect(rr, Color(HUD_RED, a))
	var ap := float(status()["ap_max"])
	if touch_layout:
		_draw_hud_touch(vs, c, low, ap)
		return
	_bar(Vector2(70, 330 + b), 140.0, c.hp / maxf(1.0, c.max_hp), "HP", HUD_RED if low else HU[5])
	_bar(Vector2(430 + r, 330 + b), 140.0, 1.0 if ap > 0.0 else 0.0, "AP", HU[5])
	if combat.armed() and combat.weapon()["kind"] == "ranged":
		var t := "장전 중" if combat.reload_t > 0.0 else "%d/%d" % [int(combat.mags.get(combat.weapon_id, 0)), combat.ammo_left(st)]
		_txt(Vector2(632 + r, 322 + b), t, HU[6], HORIZONTAL_ALIGNMENT_RIGHT)
	elif combat.armed():
		_txt(Vector2(632 + r, 322 + b), str(combat.weapon()["name"]), HU[5], HORIZONTAL_ALIGNMENT_RIGHT)
	var det := combat.detect_state()
	if det != "":
		var blink := det == "위험" and fmod(_hud_t, 0.3) < 0.15
		if not blink:
			_txt(Vector2(320 + r / 2.0, 9), "[%s]" % det, HU[5] if det == "숨음" else HUD_RED, HORIZONTAL_ALIGNMENT_CENTER)
	_ring(Vector2(36, 324 + b))
	_quest_pointer(vs)
	var ny := 8.0 if hints.is_empty() else 36.0
	for n in notes:
		_txt(Vector2(8, ny), n[0], HU[6] if n[1] > 3.0 else HU[5])
		ny += 14.0
	var gy := maxf(66.0, ny + 4.0)                                         # 목표 줄 최대 3줄(추적 1 + 고정 2) — 알림 줄이 많으면 그 아래로
	for goal in st.quests.objectives():
		_txt(Vector2(8, gy), _clip(goal, 220.0), HU[5] if goal.begins_with("▶") else HU[4])
		gy += 12.0

	var bp := box_prompt()
	if bp != "" and not _box_hinted:                                        # 처음 용기 앞에 서면 한 번 알려 준다
		_box_hinted = true
		hint("E·Enter: 용기 열기 — 붉은 [소유]는 남의 물건, 꺼내면 절도(카르마)", 7.0)
	if bp != "":
		var owned := bp.ends_with("[소유]")
		_txt(Vector2(320 + r / 2.0 + _shake_x(), 296 + b), bp, HUD_RED if owned else HU[6], HORIZONTAL_ALIGNMENT_CENTER)
	if buddy_name != "" and combat.buddy != null:
		_txt(Vector2(8, 258 + b), buddy_name, HU[5])
		_bar(Vector2(8, 272 + b), 60.0, 1.0, "", HU[5])


## 터치 배치(§17.2, 640×360 기준 — 오른쪽 묶음은 오른쪽 끝에 붙는다): HP·AP 막대 왼쪽 위, 알림 (8,48), 탐지 (280,48),
## 방위 링 (576,52) 56×56, 목표 줄 (8,116), 동행 (8,152), 상호작용 문구 (176,250). 탄약·무기 이름은 터치 단추 위에 있다
func _draw_hud_touch(vs: Vector2, c: Combatant, low: bool, ap: float) -> void:
	var r := vs.x - 640.0
	_txt(Vector2(8, 4), "HP", HU[5])
	_bar(Vector2(28, 8), 140.0, c.hp / maxf(1.0, c.max_hp), "", HUD_RED if low else HU[5])
	_txt(Vector2(8, 16), "AP", HU[5])
	_bar(Vector2(28, 20), 140.0, 1.0 if ap > 0.0 else 0.0, "", HU[5])
	var det := combat.detect_state()
	if det != "" and not (det == "위험" and fmod(_hud_t, 0.3) < 0.15):
		_txt(Vector2(320 + r / 2.0, 48), "[%s]" % det, HU[5] if det == "숨음" else HUD_RED, HORIZONTAL_ALIGNMENT_CENTER)
	_ring(Vector2(604 + r, 80))
	_quest_pointer(vs)
	var ny := 48.0 + (28.0 if not hints.is_empty() else 0.0)
	for n in notes:
		_txt(Vector2(8, ny), n[0], HU[6] if n[1] > 3.0 else HU[5])
		ny += 14.0
	var gy := maxf(116.0, ny + 4.0)
	for goal in st.quests.objectives():
		_txt(Vector2(8, gy), _clip(goal, 220.0), HU[5] if goal.begins_with("▶") else HU[4])
		gy += 12.0
	var bp := box_prompt()
	if bp != "":
		_txt(Vector2(320 + r / 2.0 + _shake_x(), 250 + vs.y - 360.0), bp, HUD_RED if bp.ends_with("[소유]") else HU[6], HORIZONTAL_ALIGNMENT_CENTER)
	if buddy_name != "" and combat.buddy != null:
		_txt(Vector2(8, 152), buddy_name, HU[5])
		_bar(Vector2(8, 166), 60.0, 1.0, "", HU[5])


func _shake_x() -> float:
	return roundf(sin(_hud_t * 70.0) * 3.0) if _hud_t < _prompt_shake else 0.0


## HUD 글을 폭 w(px)에 맞춰 자른다(넘치면 '…')
func _clip(t: String, w: float) -> String:
	if font_s.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= w:
		return t
	var n := t.length()
	while n > 1 and font_s.get_string_size(t.substr(0, n) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > w:
		n -= 1
	return t.substr(0, n).strip_edges() + "…"


func _bar(p: Vector2, w: float, f: float, label: String, col: Color) -> void:
	if label != "":
		_txt(p - Vector2(0, 11), label, HU[5])
	banner.draw_rect(Rect2(p - Vector2(1, 1), Vector2(w + 2, 8)), HU[0])
	banner.draw_rect(Rect2(p, Vector2(w, 6)), HU[2])
	banner.draw_rect(Rect2(p, Vector2(roundf(w * clampf(f, 0.0, 1.0)), 6)), col)


func _txt(p: Vector2, t: String, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var w := font_s.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x := p.x - (w if align == HORIZONTAL_ALIGNMENT_RIGHT else (roundf(w / 2.0) if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		banner.draw_string(font_s, Vector2(x, p.y + font_s.get_ascent(10)) + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HU[0])
	banner.draw_string(font_s, Vector2(x, p.y + font_s.get_ascent(10)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


## 방위 링(SD-12 §4.3): 지름 56, 위 '북', 가운데 = 주인공, 적 = 붉은 마름모(반경 10 + 인지력×2 타일), 동행 = 푸른 원
func _ring(c: Vector2) -> void:
	banner.draw_arc(c, 27.0, 0, TAU, 32, HU[0], 3.0)
	var red: bool = enc_live != null and enc_live.flash_t > 0.0 and fmod(enc_live.flash_t, 0.4) < 0.2   # 추격자 예고: 테두리 붉게 점멸(SD-12 §9.7)
	banner.draw_arc(c, 27.0, 0, TAU, 32, HUD_RED if red else HU[3], 2.0 if red else 1.0)
	banner.draw_arc(c, 24.0, 0, TAU, 32, HU[2], 1.0)
	_txt(c + Vector2(0, -33), "북", HU[5], HORIZONTAL_ALIGNMENT_CENTER)
	banner.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), HU[6])
	var rad := (10.0 + 2.0 * st.stat("PE")) * 32.0
	for e in combat.enemies:
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		var d: Vector2 = e.loco.logical - player.loco.logical
		if d.length() > rad:
			continue
		var q := (c + d / rad * 22.0).round()
		banner.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -2), q + Vector2(2, 0), q + Vector2(0, 2), q + Vector2(-2, 0)]), HUD_RED)
	if combat.buddy != null and is_instance_valid(combat.buddy):
		var d: Vector2 = combat.buddy.loco.logical - player.loco.logical
		if d.length() <= rad:
			banner.draw_circle((c + d / rad * 22.0).round(), 2.0, Color("4C7DC8"))
	if enc_live != null and not enc_live.cur.is_empty():                 # 다가오는 추적대(비적대): 흰 마름모(SD-05 §6.9 예고)
		for a in enc_live.cur.get("actors", []):
			if not is_instance_valid(a):
				continue
			var d: Vector2 = a.loco.logical - player.loco.logical
			if d.length() > rad:
				continue
			var q := (c + d / rad * 22.0).round()
			banner.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -2), q + Vector2(2, 0), q + Vector2(0, 2), q + Vector2(-2, 0)]), HU[7])
	if map is WorldMap:                                                # 장소(SD-12 §4.3·§5.5): 40타일 안, 링 둘레에 방향만 — 발견 = 채움, 그 밖 = 빈 칸
		var me := map.tile_of(player.loco.logical)
		for lid in _ring_places(me):
			var e: Dictionary = PlaceLog.db[lid]
			var d := Vector2(int(e["tx"]) - me.x, int(e["ty"]) - me.y)
			if d.length() < 2.0:
				continue
			var q := (c + d.normalized() * 25.5).round()
			var found: bool = st.places.get_state(lid) >= PlaceLog.FOUND
			banner.draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), HU[0])
			banner.draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)) if found else Rect2(q - Vector2(1, 1), Vector2(3, 3)), HU[6], found)
		var lead := quest_lead()                                           # 퀘스트 마커(SD-12 §3.12): 가장 가까운 1개 굵게, 나머지 작게 — 방향만
		for m in st.quests.marks(st.places):
			var e: Dictionary = PlaceLog.db[m["lid"]]
			var d := Vector2(int(e["tx"]) - me.x, int(e["ty"]) - me.y)
			if d.length() < 1.0:
				continue
			var big: bool = not lead.is_empty() and m["lid"] == lead["lid"] and m["id"] == lead["id"]
			var u := d.normalized()
			var q := c + u * (25.5 if big else 26.0)
			var r := 4.0 if big else 2.5
			var tri := PackedVector2Array([q + u * r, q - u * r + u.orthogonal() * r, q - u * r - u.orthogonal() * r])
			banner.draw_colored_polygon(tri, HU[0])
			banner.draw_colored_polygon(PackedVector2Array([q + u * (r - 1.0), q - u * (r - 1.0) + u.orthogonal() * (r - 1.0),
				q - u * (r - 1.0) - u.orthogonal() * (r - 1.0)]), HU[7] if big else HU[5])


## 굵게 보일 퀘스트 마커: 추적 퀘스트(없으면 고정) 마커 중 가장 가까운 것. 없으면 {}
func quest_lead() -> Dictionary:
	if not (map is WorldMap) or player == null:
		return {}
	var me := map.tile_of(player.loco.logical)
	var best := {}
	var bd := INF
	for m in st.quests.marks(st.places):
		var e: Dictionary = PlaceLog.db[m["lid"]]
		var dd := Vector2(int(e["tx"]) - me.x, int(e["ty"]) - me.y).length() + (0.0 if m["main"] else 1e6)   # 추적 쪽이 먼저
		if dd < bd:
			bd = dd
			best = m
	return best


## 화면 위 퀘스트 표식(SD-12 §3.12 '화면 가장자리'): 굵은 마커 1개 — 화면 안이면 장소 위에 ▼(위아래로 까딱), 밖이면 가장자리에서 그쪽을 가리킨다
func _quest_pointer(vs: Vector2) -> void:
	var m := quest_lead()
	if m.is_empty():
		return
	var e: Dictionary = PlaceLog.db[m["lid"]]
	var me := map.tile_of(player.loco.logical)
	if Vector2(int(e["tx"]) - me.x, int(e["ty"]) - me.y).length() < 2.0:
		return
	var k := player.get_viewport().get_canvas_transform().get_scale().x
	var sp := player.get_global_transform_with_canvas().origin + (Vector2(int(e["tx"]) * 32 + 16, int(e["ty"]) * 32) - player.loco.logical) * k
	var inner := Rect2(Vector2(14, 14), vs - Vector2(28, 28))
	var tri: PackedVector2Array
	if inner.has_point(sp):
		var tip := sp + Vector2(0, -4.0 - 2.0 * absf(sin(_hud_t * 3.0)))
		tri = PackedVector2Array([tip + Vector2(-5, -7), tip + Vector2(5, -7), tip])
	else:
		var mid := vs / 2.0
		var u := (sp - mid).normalized()
		var t := INF                                                      # 가운데에서 그 방향으로 안쪽 사각형 테두리까지
		if absf(u.x) > 0.001:
			t = minf(t, (inner.size.x / 2.0) / absf(u.x))
		if absf(u.y) > 0.001:
			t = minf(t, (inner.size.y / 2.0) / absf(u.y))
		var q := mid + u * (t - 2.0 * absf(sin(_hud_t * 3.0)))              # 화살촉(꼬리 홈) — 그쪽으로 까딱
		var o := u.orthogonal()
		tri = PackedVector2Array([q + u * 6.0, q - u * 5.0 + o * 5.0, q - u * 2.0, q - u * 5.0 - o * 5.0])
	var c := tri[0] * 0.0
	for p in tri:
		c += p / tri.size()
	var outer := PackedVector2Array()
	for p in tri:
		outer.append(c + (p - c) * 1.4)
	banner.draw_colored_polygon(outer, HU[0])
	banner.draw_colored_polygon(tri, HU[7])


## 방위 링에 보일 장소: 40타일 안 · 마커 Y(숨김 장소는 발견 뒤) — 미상도 빈 칸으로 보인다(SD-12 §5.5 '미상: 40타일 안 빈 아이콘')
func _ring_places(me: Vector2i) -> Array:
	var out: Array = []
	var k := Vector2i(me.x / PlaceLog.CHUNK, me.y / PlaceLog.CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for lid in PlaceLog._grid.get(k + Vector2i(dx, dy), []):
				var e: Dictionary = PlaceLog.db[lid]
				if not bool(e["marker"]) or (bool(e["hidden"]) and st.places.get_state(lid) < PlaceLog.FOUND):
					continue
				if Vector2(int(e["tx"]) - me.x, int(e["ty"]) - me.y).length() <= 40.0:
					out.append(lid)
	return out


## 쪽지·지도 조각(1-E RE-042 · 1-W 소장소): 아직 표시 안 된 가장 가까운 장소 하나를 지도에 '표시'(60타일 안, 6타일 밖)
func reveal_near(from: Vector2i) -> bool:
	PlaceLog.load_db()
	var pick := ""
	var bd := 60.0
	for lid in PlaceLog.db:
		var e: Dictionary = PlaceLog.db[lid]
		if bool(e.get("hidden", false)) or not bool(e.get("marker", true)) or st.places.get_state(str(lid)) >= PlaceLog.MARKED:
			continue
		var dd := Vector2(int(e["tx"]) - from.x, int(e["ty"]) - from.y).length()
		if dd < bd and dd > 6.0:
			bd = dd
			pick = str(lid)
	if pick != "" and st.places.raise(pick, PlaceLog.MARKED):
		hint("쪽지가 가리킨 곳이 지도에 표시되었다", 5.0)
		return true
	return false


## 목표 줄 첫 줄(일시 정지 메뉴 '지금 할 일'): QuestLog.objectives()의 맨 위
func _objective() -> String:
	var o := st.quests.objectives()
	return str(o[0]) if not o.is_empty() else ""


## 원고의 진행기 명령(0-7). 이벤트 실행기가 모르는 명령을 여기서 처리하고 done을 부른다
func _handlers() -> void:
	ev.handlers["pipboy"] = func(_a: Array, done: Callable) -> void:     # 핍-보이 받기: HUD를 켜고 튜토리얼로 한 번 연다(닫으면 이어진다)
		pipboy_ok = true
		hud_on = true
		var p := open_pipboy()
		p.first = true
		p.closed.connect(func(_ok: bool) -> void: done.call())
	ev.handlers["fix"] = func(a: Array, done: Callable) -> void:       # NPC 정비(1-8a): 이 대화가 끝나면 정비 메뉴를 연다
		box.finished.connect(func() -> void: fix_menu.call_deferred(str(a[0])), CONNECT_ONE_SHOT)
		done.call()
	ev.handlers["fixdo"] = func(a: Array, done: Callable) -> void:     # 정비 한 단계(값은 선택지 [캡] 태그가 이미 받았다)
		var key := str(a[1])
		var nk := Gear.improve(st, key, 1, 0)
		if nk != key:
			combat.rekey(key, nk, st)
			if worn() == key and int(st.items.get(key, 0)) <= 0:
				st.vars.set_v("PC_TORSO", nk)
			hint("%s 정비 — '%s'" % [str(items_db.get(Gear.base(nk), {}).get("name", nk)), Gear.NAMES[Gear.cond(nk)]], 3.0)
			box.finished.connect(func() -> void: fix_menu.call_deferred(str(a[0]), true), CONNECT_ONE_SHOT)
		done.call()
	ev.handlers["meet"] = func(a: Array, done: Callable) -> void:      # 이름 소개(수첩 등록, SD-12 §3.11): meet 인물ID
		st.book.meet(str(a[0]), date_text)
		done.call()
	ev.handlers["memo"] = func(a: Array, done: Callable) -> void:      # 한 줄 메모(퀘스트가 정한 사실): memo 인물ID 문장…
		st.book.memo(str(a[0]), " ".join(a.slice(1)), date_text)
		done.call()
	ev.handlers["re"] = func(a: Array, done: Callable) -> void:        # 인카운터 첫 분대 대화의 결말: re fight · run · leave(1-3)
		enc_live.cmd(str(a[0]))
		done.call()
	ev.handlers["cage"] = func(a: Array, done: Callable) -> void:      # 우리 문 열기(1-3 H-03): cage open x y — 그림을 열린 문으로, 칸을 지나가게
		var c := Vector2i(int(a[1]), int(a[2]))
		map.set_prop_state(c, "open")
		map._put_solid(c.x, c.y, 0)
		done.call()
	ev.handlers["capture"] = func(a: Array, done: Callable) -> void:   # capture wait: 사흘을 버텨 계엄군에 넘겨진다(SD-03a §6.7)
		done.call()
		_capture_handover.call_deferred()
	ev.handlers["obit"] = func(a: Array, done: Callable) -> void:      # 소식으로 안 죽음: obit 인물ID
		st.book.died(str(a[0]), date_text)
		done.call()
	ev.handlers["equip"] = func(a: Array, done: Callable) -> void:
		combat.equip(str(a[0]) if a.size() > 0 and str(a[0]) != "none" else "", st)
		done.call()
	ev.handlers["hurt"] = func(a: Array, done: Callable) -> void:      # 연출 피해(증기 분출 등)
		combat.damage(float(a[0]))
		_hurt_t = 0.3
		done.call()
	ev.handlers["buddy"] = func(a: Array, done: Callable) -> void:     # 일시 동행 시작(인물 ID) · 끝(off)
		var id := str(a[0])
		if id == "off":
			combat.buddy = null
			buddy_name = ""
			buddy_id = ""
		elif ev.actors.has(id):
			var b: Actor = ev.actors[id]
			map.blockers.erase(b)                                              # 동행은 길을 막지 않는다
			for n in npcs:
				if n["actor"] == b:
					n["routine"] = null
			combat.buddy = b
			buddy_id = id
			buddy_name = st.npc_name(id).get_slice("(", 0).strip_edges()
		done.call()
	ev.handlers["refresh"] = func(_a: Array, done: Callable) -> void:   # 맵 인물·적을 지금 조건대로 다시 세운다(0-8, 적은 0-9)
		refresh_npcs()
		combat.refresh_enemies(st)
		done.call()
	ev.handlers["range"] = func(a: Array, done: Callable) -> void:     # 사격장 단계: stealth = 은신 표적을 세운다
		combat.set_stealth_live(str(a[0]) == "stealth")
		done.call()
	ev.handlers["pc"] = func(a: Array, done: Callable) -> void:         # 주인공 자리 옮기기(페이드 사이, 0-9): pc 표지|x,y [방향] · pc hide|show
		var m := str(a[0])
		if m == "hide" or m == "show":
			player.visible = m == "show" and body != "hidden"
			done.call()
			return
		var lc := map.cell_local(int(m.get_slice(",", 0)), int(m.get_slice(",", 1))) if "," in m else Vector2i.ZERO
		var at := map.mark_pos(m) if not "," in m else Vector2(lc * 32) + Vector2(16, 16)
		player.loco.place(at)
		player.loco.facing = EventRunner.DIR_IDX.get(str(a[1]) if a.size() > 1 else map.mark_dir(m), 2)
		player.position = player.loco.render
		player._show()
		_last_tile = map.tile_of(player.loco.logical)
		cam.position = player.loco.logical.round()
		done.call()
	ev.handlers["unlock"] = func(a: Array, done: Callable) -> void:     # 잠긴 문 열기: unlock x y(0-9 무기고)
		var uc := map.cell_local(int(a[0]), int(a[1]))
		map.unlock_door(uc.x, uc.y)
		combat.nav = InteriorNav.new(map)                                  # 길찾기 격자를 다시 만든다
		done.call()
	ev.handlers["note"] = func(a: Array, done: Callable) -> void:      # 종이 기록물 창(1-5): 닫으면 장면이 이어진다
		var ns := NoteScreen.new().setup(st, str(a[0]))
		ns.closed.connect(func(_ok: bool) -> void: done.call())
		add_child(ns)
	ev.handlers["reveal"] = func(a: Array, done: Callable) -> void:   # 전망 지점(1-5e, SD-08 §12.3): 권역 코드·장소 ID 목록을 지도에 '표시'로
		PlaceLog.load_db()
		var n := 0
		if a.size() == 1 and str(a[0]) == "near":                     # 쪽지·지도 조각(1-E RE-042): 아직 표시 안 된 가장 가까운 장소 하나(60타일 안)
			reveal_near(map.tile_of(player.loco.logical))
			done.call()
			return
		for tok in a:
			for lid in PlaceLog.db:
				var hit := str(lid) == str(tok) or (str(tok).length() == 3 and str(PlaceLog.db[lid]["region"]) == str(tok))
				if hit and not bool(PlaceLog.db[lid].get("hidden", false)) and st.places.raise(str(lid), PlaceLog.MARKED):
					n += 1
		if n > 0:
			hint("지도에 장소 %d곳이 표시되었다" % n, 5.0)
		done.call()
	ev.handlers["hint"] = func(a: Array, done: Callable) -> void:
		hint(str(a[0]), float(a[1]) if a.size() > 1 else 6.0)
		done.call()
	ev.handlers["hud"] = func(a: Array, done: Callable) -> void:
		hud_on = str(a[0]) != "off"
		done.call()


# ---------------------------------------------------------------- 핍-보이·소지품
func _load_items() -> void:
	for f in ["items_aid", "items_food", "items_drink", "items_quest", "items_apparel", "items_misc_money", "items_misc_mat", "items_misc_func",
			"items_chems", "items_misc_other", "items_apparel_head", "items_misc_crit", "items_junk", "items_ammo"]:          # 파이프라인이 SD-13 표에서 뽑은 아이템(1-4: 표 전체)
		var p := "res://data/%s.json" % f
		if FileAccess.file_exists(p):
			items_db.merge(JSON.parse_string(FileAccess.get_file_as_string(p)))
	for id in combat.weapons:
		var w: Dictionary = combat.weapons[id]
		items_db[id] = {"name": w["name"], "cat": "weapon", "dmg": w["dmg"], "mag": w.get("mag"), "ammo": w.get("ammo", ""),
			"ammo_id": w.get("ammo_id", ""), "weight": w.get("weight", 0), "value": w.get("price", 0), "durability": w.get("durability", "B"),
			"desc": "%s · %s · 사거리 %s타일 · 초당 %s회" % [w["skill"], "양손" if w.get("two_handed", false) else "한손",
				PipBoy._num(float(w["range_eff"])), PipBoy._num(float(w["rate"]))]}
		var am := str(w.get("ammo_id", ""))
		if am != "" and not items_db.has(am):                          # 탄약: SD-13 §3 탄약 표 가치 1 · 무게 0(원작)
			items_db[am] = {"name": am, "cat": "ammo", "value": 1, "weight": 0}
	Gear.expand_items(items_db)                                        # 장비 상태 변형 "W-002@2" = 10mm 권총 (낡음)(1-8a)
	for id in items_db:                                                # 원고 태그 [물건: ID n]·\I 코드가 이름으로 보이게(이름 표에 아이템 이름을 채운다)
		if not st.names.has(id):
			st.names[id] = str(items_db[id].get("name", id))


## 핍-보이·HUD 위 줄 수치. 레벨(SD-10 §4.2): 다음 레벨까지 50 + 150 × 레벨, 누적 (L−1)(50 + 75L)
func status() -> Dictionary:
	var d := InteriorCombat.derived(st)
	var xp := int(st.vars.get_v("PC_XP"))
	var lv := level()
	var carry := 0.0
	for id in st.items:
		carry += float(items_db.get(id, {}).get("weight", 0)) * int(st.items[id])
	return {"level": lv, "hp": int(ceilf(combat.pc.hp)), "hp_max": int(combat.pc.max_hp), "ap": int(d["ap_max"]), "ap_max": int(d["ap_max"]),
		"xp": xp, "xp_next": lv * (50 + 75 * (lv + 1)), "date": date_text, "equipped": combat.weapon_id if not combat.holstered else "",
		"stimpak_id": InteriorCombat.STIMPAK, "carry": carry, "carry_max": 150 + 10 * st.stat("ST"), "caps": int(st.vars.get_v("PC_CAPS")),
		"place": _place_name(), "hotkeys": combat.hotkeys,
		"karma": int(st.vars.get_v("V_KARMA")) if st.vars.has("V_KARMA") else 0,
		"worn": worn(), "rads": int(st.vars.get_v("PC_RADS")),
		"dr": int(items_db.get(worn(), {}).get("dr", 0)) if st.items.has(worn()) else 0,
		"tile": Vector2(map.tile_of(player.loco.logical)) if map is WorldMap and player != null else Vector2(-99, -99),
		"world": map if map is WorldMap else null, "travel": travel_check}


# ---------------------------------------------------------------- 빠른 이동(SD-12 §5.6)
signal traveled(lid: String)
const TRAVEL_MSG := {"F1": "아직 가 보지 않은 장소입니다.", "F2": "실내에서는 이동할 수 없습니다.", "F3": "근처에 적이 있습니다.",
	"F4": "짐이 너무 무겁습니다.", "F6": "지금은 이동할 수 없습니다.", "F7": "건널 수 있는 길을 아직 확보하지 못했습니다.",
	"F8": "추격자를 따돌려야 합니다."}


## [갈 수 있나, 안내 문구, 걸리는 시간(게임 시간)]. 불가 조건 F1~F8 순서대로 본다
func travel_check(lid: String) -> Array:
	var e: Dictionary = PlaceLog.db.get(lid, {})
	if not map is WorldMap:
		return [false, TRAVEL_MSG["F2"], 0]
	if st.places.get_state(lid) < PlaceLog.FOUND:
		return [false, TRAVEL_MSG["F1"], 0]
	var rad := (10.0 + 2.0 * st.stat("PE")) * 32.0
	for en in combat.enemies:
		if is_instance_valid(en) and not en.cmb.dead and en.loco.logical.distance_to(player.loco.logical) <= rad:
			return [false, TRAVEL_MSG["F3"], 0]
	var s := status_carry()
	if s[0] > s[1]:
		return [false, TRAVEL_MSG["F4"], 0]
	if enc_live != null and enc_live.chasing():                       # 추적대가 다가오거나 싸우는 중(1-3)
		return [false, TRAVEL_MSG["F8"], 0]
	if story_hold:                                                     # 이야기 사건 중(MQ-106 무전·대치 등): 사건 무대를 빠른 이동으로 떠나지 않는다(SD-20 P4)
		return [false, TRAVEL_MSG["F8"], 0]
	if st.quests.stage("MQ-P4") < 100 or e.get("arrive") == null or busy or box.active or str(e.get("region", "")) == "R05":
		return [false, TRAVEL_MSG["F6"], 0]
	var here := PlaceLog.bank_at(map.tile_of(player.loco.logical))
	var there := str(e.get("bank", here))
	if there != "" and there != here:                                    # 강 건너: 확보한 횡단로가 하나라도 있어야(2막 첫 횡단 전에는 없다)
		if secured_crossings().is_empty():
			return [false, TRAVEL_MSG["F7"], 0]
		return [true, "", 2]
	return [true, "", 1]


func status_carry() -> Array:
	var carry := 0.0
	for id in st.items:
		carry += float(items_db.get(id, {}).get("weight", 0)) * int(st.items[id])
	return [carry, 150 + 10 * st.stat("ST")]


## 확보한 횡단로(SD-12 §5.7): 이야기 변수 X_SECURED_<ID> = 1. 1막에는 없다
func secured_crossings() -> Array:
	var out: Array = []
	for i in range(1, 16):
		var k := "X_SECURED_X%02d" % i
		if st.vars.has(k) and int(st.vars.get_v(k)) == 1:
			out.append("X%02d" % i)
	return out


## 빠른 이동: 암전 → 도착 칸 → 시간 경과(같은 강변 1시간 · 건너면 2시간) → 밝아짐 → 도착 자동 저장(진행기가 traveled를 받아)
func fast_travel(lid: String) -> void:
	var why := travel_check(lid)
	if not why[0]:
		hint(str(why[1]), 3.0)
		return
	var e: Dictionary = PlaceLog.db[lid]
	busy = true
	player.move(Vector2.ZERO, 0.0)
	ev.run("fade_out", ["black", "3"], func() -> void:
		_arrive(lid, int(why[2]))
		ev.run("fade_in", ["black", "3"], func() -> void:
			busy = false
			traveled.emit(lid)))


## 빠른 이동 도착(화면이 가려진 사이): 도착 칸에 세우고 둘레 청크를 붙이고 시각을 넘긴다
func _arrive(lid: String, hours: int) -> void:
	var e: Dictionary = PlaceLog.db[lid]
	var at := Vector2(int(e["arrive"][0]) * 32 + 16, int(e["arrive"][1]) * 32 + 16)
	map.load_now(at)
	player.loco.place(at)
	player.position = player.loco.render
	player._show()
	map.update_focus(at)
	map.id = map.zone_of(map.tile_of(at))
	_last_tile = map.tile_of(at)
	st.places.mark_seen(_last_tile)
	cam.position = at.round()
	cam.reset_smoothing()
	advance_minutes(hours * 60)
	_note("%s 도착 — %d시간이 지났다" % [str(e["name"]), hours])
	enc_live.on_arrive.call_deferred()                                # 도착 지점 = 추적대 첫 출현 후보(SD-05 §6.2)


# ---------------------------------------------------------------- 시각 흐름(1-3)
## 시간이 흐르나: 1막 MQ-101이 끝난 아침부터(그 전은 진행기가 시각을 정한다), 자유 행동 중에만(대화·핍-보이·연출은 멈춤 — SD-12 §16)
func clock_running() -> bool:
	return st.quests.cur_act() >= 1 and st.quests.stage("MQ-101") >= 50 and int(st.vars.get_v("MQ101_NIGHT")) >= 3 and not busy


func _clock_step(dt: float) -> void:
	if not clock_running():
		return
	_clock_acc += dt * TIME_SCALE / 60.0
	if _clock_acc >= 1.0:
		var m := int(_clock_acc)
		_clock_acc -= m
		advance_minutes(m)


## 게임 시간을 m분 보낸다. 06:00을 넘을 때마다 하루 판정(day_tick) — 사흘 구금·긴 잠처럼 여러 날을 한 번에 보내도
## 넘어간 06:00마다 한 번씩, 그 날짜(GAME_DAY)로 차례대로 부른다(SD-20 P6 시간 도약)
func advance_minutes(m: int) -> void:
	var a := Clock.abs_min(date_text)
	if a <= 0:
		date_text = Clock.add_minutes(date_text, m, st)
		return
	while m > 0:
		var to6 := posmod(360 - a, 1440)                                  # 다음 06:00까지 남은 분(지금이 06:00 정각이면 하루 뒤)
		if to6 == 0:
			to6 = 1440
		var step := mini(m, to6)
		date_text = Clock.add_minutes(date_text, step, st)
		a += step
		m -= step
		if step == to6:
			_daily()


## 하루 판정(06:00): 수배도 하한 다시 걸기 · 생포 사흘 넘김(SD-03a §6.7 — 계엄군 인계는 청계산 맵과 함께, 정합)
func _daily() -> void:
	Wanted.refresh(st)
	day_tick.emit(int(st.vars.get_v("GAME_DAY")))
	if int(st.vars.get_v("CAPTURE_BY")) == 1 and map != null and map.id == "H-03" \
			and Clock.abs_min(date_text) - int(st.vars.get_v("CAPTURE_AT")) >= 3 * 1440:
		hint("사흘이 지났다. 반장이 계엄군에 넘길 날짜를 장부에 적는다.", 6.0)


# ---------------------------------------------------------------- 쓰러짐·생포(1-3, SD-03a §6.7)
## 주인공 HP 0(1막 이후 자유 행동): 생포 분대가 곁에 있고 오늘 처음이면 생포, 아니면 쓰러짐(pc_died)
func on_pc_down() -> void:
	var by := ""
	for e in combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.has_meta("capture") \
				and e.loco.logical.distance_to(player.loco.logical) <= 20.0 * 32.0:
			var c := str(e.get_meta("capture"))
			if by == "" or capture_hooks.has(c):                          # 이야기 사건(MQ-106 계엄군)의 생포가 이긴다 — 목록 순서로 행선지가 갈리지 않게(SD-20 §5)
				by = c
	var day := int(st.vars.get_v("GAME_DAY"))
	if (by == "SB" or capture_hooks.has(by)) and int(st.vars.get_v("CAPTURE_DAY")) != day:
		capture(by)
		return
	pc_died.emit()


## 새벽인력 생포(SD-03a §6.7 표 새벽인력 판): 캡 30% 압수(공통) → 근태 목걸이·수갑 → 본소 창고동 '인력' 우리(H-03)에서 깬다.
## 현상금은 새벽인력이 받는다(이야기 기록만). 하루 한 번 — 같은 날 또 쓰러지면 일반 쓰러짐
func capture(by: String) -> void:
	if capture_hooks.has(by):                                          # 계엄군 판(1-7): 진행기가 귀빈실로
		(capture_hooks[by] as Callable).call()
		return
	busy = true
	st.vars.set_v("CAPTURE_DAY", int(st.vars.get_v("GAME_DAY")))
	var caps := int(st.vars.get_v("PC_CAPS"))
	var taken := int(floor(caps * 0.3))
	if taken > 0:
		st.call_fn("caps", [-taken])
	enc_live.captured()
	ev.run("fade_out", ["black", "8"], func() -> void:
		combat.pc.dead = false
		combat.pc.hp = maxf(1.0, combat.pc.max_hp * 0.3)
		combat.equip("", st)
		advance_minutes(3 * 60)                                       # 끌려가는 길(정합: 3시간)
		st.vars.set_v("CAPTURE_BY", 1)
		st.vars.set_v("CAPTURE_AT", Clock.abs_min(date_text))
		st.vars.set_v("SB_COLLAR", 1)
		st.vars.set_v("SB_CUFF", 1)
		enter("H-03", "cage_pc")
		ev.run("fade_in", ["black", "8"], func() -> void:
			busy = false
			play_scene("CAPTURE_SB")))


## 사흘 버팀 → 계엄군 인계(1~3막 전원 없음 판, SD-03a §6.7 표): 청계산 귀빈실 → 남궁혁 면담 → 관악 산자락. 비상 +5.
## 1-7부터는 capture_hooks["BJ_HANDOVER"](MQ-106 진행기)가 맡는다 — 압수품 보관함 · 청계산 귀빈실 · 남궁혁 면담. 아래는 훅이 없을 때의 옛 판
func _capture_handover() -> void:
	if capture_hooks.has("BJ_HANDOVER"):                               # 1-7: 청계산 귀빈실 구간(남궁혁 면담 · 압수품 보관함)
		(capture_hooks["BJ_HANDOVER"] as Callable).call()
		return
	busy = true
	ev.run("fade_out", ["black", "10"], func() -> void:
		advance_minutes(3 * 24 * 60)
		st.vars.set_v("SB_CUFF", 0)
		st.vars.set_v("SB_COLLAR", 0)
		st.vars.set_v("CAPTURE_BY", 2)
		st.call_fn("aff", ["BJ", 5])
		enter("X-S07", "from_vault")
		ev.run("fade_in", ["black", "10"], func() -> void:
			busy = false
			play_scene("CAPTURE_HANDOVER")
			st.vars.set_v("CAPTURE_BY", 0)))


## 레벨(SD-10 §4.2): 누적 XP (L−1)(50 + 75L)
func level() -> int:
	var xp := int(st.vars.get_v("PC_XP"))
	var lv := 1
	while xp >= lv * (50 + 75 * (lv + 1)):
		lv += 1
	return lv


## 입은 몸통 옷(0-10): PC_TORSO. 처음은 볼트 점프슈트 A-001
func worn() -> String:
	return str(st.vars.get_v("PC_TORSO"))


## 옷 갈아입기: 페이퍼돌 몸통 그림을 바꾼다. 외형 차분 BD → 실루엣 T(SD-13 §5.3 표). 파워 아머(BD23·24)는 훈련·리그가 따로라 아직 못 입는다
const BD_TORSO := {"BD01": "T01", "BD02": "T02", "BD03": "T03", "BD04": "T11", "BD05": "T11", "BD06": "T12", "BD07": "T13", "BD08": "T08",
	"BD09": "T03", "BD10": "T08", "BD11": "T04", "BD12": "T05", "BD13": "T07", "BD14": "T12", "BD15": "T06", "BD16": "T08", "BD17": "T06",
	"BD18": "T09", "BD19": "T15", "BD20": "T12", "BD21": "T14", "BD22": "T10"}


## 이 몸통 옷의 실루엣 코드(입을 수 없으면 "")
func torso_of(id: String) -> String:
	var it: Dictionary = items_db.get(Gear.base(id), {})
	if str(it.get("cat", "")) != "apparel" or not (str(it.get("slot", "")) in ["몸통", "전신"]):
		return ""
	return str(BD_TORSO.get(str(it.get("layer", "")), ""))


func wear(id: String) -> void:
	if not st.items.has(id) or torso_of(id) == "":
		return
	if Gear.cond(id) >= 4:                                             # 파손: 입은 채면 '위태' 값으로 버티지만, 벗으면 다시 입을 수 없다(SD-13 §8.1)
		_note("찢어지고 부서져서 다시 입을 수 없다")
		return
	st.vars.set_v("PC_TORSO", id)
	if player != null and player.doll != null:
		player.doll.set_look({"torso": torso_of(id)})
	_note("%s 입음" % str(items_db.get(id, {}).get("name", id)))


## 방어구 열화(SD-13 §8.2): DR 적용 뒤 피해가 5 이상인 피격마다 입은 옷 카운터 1. 볼트 안(프롤로그)은 닳지 않는다(정합 1-8a)
func _armor_hit(amount: float) -> void:
	if amount < 5.0 or st.quests.cur_act() < 1:
		return
	var key := worn()
	var nk := Gear.use(st, key, 1)
	if nk == key:
		return
	st.vars.set_v("PC_TORSO", nk)
	var nm := str(items_db.get(Gear.base(nk), {}).get("name", nk))
	hint("%s — %s" % [nm, "찢어지고 부서졌다. 벗으면 다시 입을 수 없다." if Gear.cond(nk) >= 4 else "상태가 '%s'(으)로 떨어졌다." % Gear.NAMES[Gear.cond(nk)]], 3.0)


## 스스로 고치기(핍-보이 [R], SD-13 §8.3): 든 무기·입은 옷은 부품으로 쓰지 않는다. 고친 것이 든 무기·입은 옷이면 열쇠를 바꿔 낀다
func repair_self(id: String) -> Dictionary:
	var keep := [combat.weapon_id, worn()].filter(func(k): return k != id)
	var r := Gear.self_repair(st, id, keep, id == combat.weapon_id or id == worn())
	if not r["ok"]:
		_note(str(r["why"]))
		if pipboy != null:
			pipboy.say(str(r["why"]))
		return r
	var nk := str(r["key"])
	combat.rekey(id, nk, st)
	if worn() == id and int(st.items.get(id, 0)) <= 0:
		st.vars.set_v("PC_TORSO", nk)
	var used := str(r["used"])
	var how := "수리 키트" if used == Gear.KIT else ("군용 정비 키트" if used == Gear.MIL_KIT else "부품 " + str(items_db.get(used, {}).get("name", used)))
	var msg := "%s 손봄 — %s 사용" % [str(items_db.get(nk, {}).get("name", nk)), how]
	_note(msg)
	if pipboy != null:
		pipboy.say(msg)
		pipboy.info = status()
		pipboy.select_id(nk)
	return r


## 주인공 DR(SD-11 D11-06): 입은 몸통 옷 DR × 상태 배율(변형 항목의 dr). 상한 85. 입은 옷이 소지품에 없으면 0
func pc_dr() -> float:
	var id := worn()
	if int(st.items.get(id, 0)) <= 0:
		return 0.0
	return minf(85.0, float(items_db.get(id, {}).get("dr", 0)))


## 먹고 마시기(SD-13 §7.2): 음식·음료 HP는 5초에 걸쳐, 라드는 즉시. 라드어웨이 −50 × (1 + 의학/50)
func consume(id: String) -> bool:
	var it: Dictionary = items_db.get(id, {})
	if int(st.items.get(id, 0)) <= 0:
		return false
	if id == "I-002":
		st.call_fn("take", [id, 1])
		var cut := roundi(50.0 * (1.0 + float(st.skill("MEDICINE")) / 50.0))
		st.vars.set_v("PC_RADS", maxi(0, int(st.vars.get_v("PC_RADS")) - cut))
		_note("라드어웨이 — 방사능 −%d" % cut)
		return true
	if not it.has("heal") and not it.has("rads"):
		return false
	st.call_fn("take", [id, 1])
	var heal := float(it.get("heal", 0.0))
	if heal > 0.0:
		combat.heal_q.append(heal)
		if combat.heal_q.size() == 1:
			combat.heal_rate = heal / 5.0
	var rad := int(it.get("rads", 0))
	if rad > 0:
		st.vars.set_v("PC_RADS", int(st.vars.get_v("PC_RADS")) + rad)
	_note("%s — HP +%d%s" % [str(it.get("name", id)), int(heal), ("  방사능 +%d" % rad) if rad > 0 else "  방사능 없음"])
	if id in ["I-054", "I-055", "I-056", "I-057", "I-058", "I-059"]:
		st.vars.set_v("MQ101_WATER", 1)                                   # MQ-101 '물': 마셔 봐야 안다
	return true


## 알림(SD-12 §4.6): 이야기 상태의 사건(아이템·카르마·XP·퀘스트)을 꺼내 알림 줄로. 새 무기·스팀팩은 빈 단축키 칸에
var notes: Array = []                           ## [[글, 남은 초]]


func _drain_events() -> void:
	for e in st.events:
		match str(e.get("kind", "")):
			"item":
				var id := str(e["id"])
				var nm := str(items_db.get(id, {}).get("name", id))
				if int(e["delta"]) > 0:
					_note("%s 획득%s" % [nm, " ×%d" % int(e["delta"]) if int(e["delta"]) > 1 else ""])
					if combat.weapons.has(id) or id == InteriorCombat.STIMPAK:
						combat.auto_hotkey(id)
				elif not combat.weapons.has(id) and id != InteriorCombat.STIMPAK and not id.ends_with("탄"):
					_note("%s 건넴" % nm)
			"karma":
				_note("카르마가 %s." % ("올라갔습니다" if int(e["delta"]) > 0 else "내려갔습니다"))
			"xp":
				_note("+%d XP" % int(e["delta"]))
			"wanted":                                                   # SD-12 §4.6 예문 '수배 등급이 올라갔습니다: 수배 공고'
				_note("수배 등급이 %s: %s" % ["올라갔습니다" if bool(e["up"]) else "내려갔습니다", Wanted.NAMES[int(e["grade"])]])
	st.events.clear()
	for q in st.quests.events:
		match str(q.get("kind", "")):
			"start":
				_note("새 퀘스트: " + st.quests.title(str(q["id"])))
				st.quests.auto_track(str(q["id"]))
				for lid in st.quests.places_of(str(q["id"])):                # 목표 장소의 위치를 알게 된다(지도 윤곽 아이콘·퀘스트 ▼)
					st.places.raise(lid, PlaceLog.MARKED)
			"done":
				_note("퀘스트 완료: " + st.quests.title(str(q["id"])))
	st.quests.events.clear()


func _note(t: String) -> void:
	for n in notes:
		if n[0] == t:
			n[1] = 3.5
			return
	notes.append([t, 3.5])
	if notes.size() > 4:
		notes.pop_front()


func _unhandled_input(e: InputEvent) -> void:
	if not hud_on or not use_keyboard or box.active or ev.busy() or busy or pipboy != null:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_8:
		combat.hotkey(int(e.keycode - KEY_0), st)
		get_viewport().set_input_as_handled()


func open_pipboy() -> PipBoy:
	if pipboy != null:
		return pipboy
	player.move(Vector2.ZERO, 0.0)
	pipboy = PipBoy.new().setup(st, items_db, status())
	pipboy.action.connect(_pip_action)
	pipboy.closed.connect(func(_ok: bool) -> void: pipboy = null)
	add_child(pipboy)
	return pipboy


func _pip_action(kind: String, id: String) -> void:
	match kind:
		"equip":
			if str(items_db.get(id, {}).get("cat", "")) == "apparel":
				wear(id)
			else:
				combat.equip(id, st)
		"unequip":
			combat.equip("", st)
		"travel":
			fast_travel(id)
		"repair":
			repair_self(id)
		"use":
			if id == InteriorCombat.STIMPAK:
				combat.use_stimpak(st)                                          # 핍-보이 안: 시간이 멈춘 채 쓴다(투여 모션 없음)
			else:
				consume(id)
		_:
			if kind.begins_with("hotkey:"):
				var n := int(kind.substr(7))
				for k in combat.hotkeys.keys():
					if combat.hotkeys[k] == id:
						combat.hotkeys.erase(k)
				combat.hotkeys[n] = id
	if pipboy != null:
		pipboy.info = status()


## 대화 줄이 뜰 때: 말한 이름 있는 인물을 인물 수첩에 올린다(바크만 들은 인물은 없음, SD-12 §3.11)
func _on_line(s: Dictionary) -> void:
	if _barking:
		return
	st.book.meet(str(s.get("who", "")), date_text)                       # 알림은 띄우지 않는다(프롤로그에서 수십 명 — 수첩을 열면 최근 순 맨 위)


func _on_dialogue_done() -> void:
	_barking = false
	ev.cam_locked = false
	if not _talking.is_empty() and _talking["routine"] != null:
		_talking["routine"].resume()
	_talking = {}


func _draw_banner() -> void:
	_draw_hud()
	if not hints.is_empty() and banner_t <= 0.0 and not box.active:
		var hint_text: String = hints[0][0]
		var hw := font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
		var hr := Rect2(10, 10, hw, 20)
		banner.draw_rect(hr.grow(1), Color("0B0A0D"))
		banner.draw_rect(hr, Color("1F3A6E"))
		banner.draw_rect(Rect2(hr.position + Vector2(0.5, 0.5), hr.size - Vector2.ONE), Color("4C7DC8"), false, 1.0)
		banner.draw_string(font, Vector2(hr.position.x + 10, hr.position.y + 3 + font.get_ascent(12)), hint_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 12, Color("E9E4D8"))
	if banner_t <= 0.0 or banner_text == "":
		return
	var vs := banner.get_viewport_rect().size
	var a := clampf(banner_t / 0.4, 0.0, 1.0) if banner_t < 0.4 else clampf((BANNER_SECS - banner_t) / 0.3, 0.0, 1.0)
	if a < 0.5:
		return                                                       # 반투명 없이: 나타날 때·사라질 때는 통째로 켜고 끈다
	var w := font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 40.0
	var r := Rect2(floorf((vs.x - w) / 2.0), 14, w, 22)
	banner.draw_rect(r.grow(1), Color("0B0A0D"))
	banner.draw_rect(r, Color("1A181D"))
	banner.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), Color("ABA49A"), false, 1.0)
	banner.draw_line(r.position + Vector2(6, 11), r.position + Vector2(14, 11), Color("B08A1C"))
	banner.draw_line(r.end - Vector2(14, 11), r.end - Vector2(6, 11), Color("B08A1C"))
	banner.draw_string(font, Vector2(r.position.x + 20, r.position.y + 4 + font.get_ascent(12)), banner_text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 12, Color("E9E4D8"))
