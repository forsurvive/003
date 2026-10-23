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
signal slept(hours: int)                           ## 침대에서 잤다(SD-12 §13.2 '수면 뒤' 자동 저장)
signal box_closed(box: Dictionary, contents: Dictionary)   ## 용기 창을 닫았다(1-D6 가산 작업복 상자 바꿔치기 판정 등 — 진행기가 듣는다)

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
var radio_icons: Texture2D                        ## 라디오 화자 24×24(송미래 · 남궁혁 · 공보방송 · 구내방송)
var _r_hold := 0.0                                ## 재장전 키를 누른 초(0.6초 = 라디오)
var _rctx := {}                                   ## 이번 프레임 라디오 수신 조건(그리기 · 핍-보이가 같이 쓴다)
var act_held := false                             ## 터치 '상황' 단추를 누르고 있다(일으키기 2초)
var cur_map := ""                                 ## 지금 맵 ID(대기 동행이 남는 자리)
var touch_sprint := false                         ## 터치: 이동 스틱을 바깥 링 밖까지 0.3초 밀었다(SD-11 §15.5)
var roll_req := false                             ## 터치 '구르기' 단추(한 번)
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
var wait_ui: WaitScreen                          ## 열려 있는 대기·수면 창(1-8b)
var craft_ui: CraftScreen                        ## 열려 있는 작업대·조리 창(1-8c)
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
			if st.vars.has("GAME_WDAY"):
				st.vars.set_v("GAME_WDAY", Clock.weekday(v))            # 요일(0 월 ~ 6 일) — 맵 조건식(1-12h UQ-70 수 · 토 수금)
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
static var track := false                                         ## 시험 실행기 전용: 만든 host를 모아 시험마다 치운다(트리 밖 host 누수로 전체 시험이 14GB에서 OOM)
static var made: Array = []


func _init() -> void:
	if track:
		made.append(self)


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
	ev.is_dead = st.is_dead
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
	combat.colony.note.connect(func(t: String) -> void: hint(t, 3.0))      # 1-D5b 왕개미 군체 알림(위장 씻김 · 더듬이 · 줄 끊김)
	combat.colony.corrode.connect(func() -> void: _armor_hit(5.0))         # 개미산 분사: 방어구 내구도 −(SD-14 CR-081)
	combat.armor_dr = pc_dr
	combat.rad_items = items_db                                          # 옷의 방사능 저항(1-9d)
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


# ---------------------------------------------------------------- 낮밤(0-10 밤 · 1-T1 하루 순환, SD-16 §4.7 상황 필터 1~5 · 11 + §10.6 빛 원판)
## 바깥(월드 · 바깥 손 맵)은 시각을 따라 새벽 → 낮 → 노을 → 밤 → 깊은 밤 색조가 1시간씩 섞여 바뀐다(TimeOfDay).
## 실내는 시각과 무관: 불 켜진 방은 색조 없음(포켓몬 골드처럼 바깥 하늘이 실내에 들어오지 않는다), 전기가 끊긴 암거 · 동굴(타일셋 cv)은
## '실내 정전'에 핍-보이 조명. 이야기가 밤을 정하면(MQ-101 그날 밤 — set_night) 시각과 무관하게 밤.
var night := false                                                   ## 이야기가 정한 밤(저장되는 값)
var tone_now := Vector4.ZERO                                         ## 지금 화면 색조(시험 · 벤치)
var pip_light := 0.0                                                 ## 핍-보이 조명 세기 0~1(깊은 밤 · 어두운 지하)
var light_k := 0.0                                                   ## 빛 원판 세기 0~1
var fog_k := 0.0                                                     ## 새벽 지면 안개 세기 0~1
var _night_layer: CanvasLayer
var _night_mat: ShaderMaterial
var _light_layer: CanvasLayer
var _lights: Node2D
var _flicker_t := 0.0
var _tone_t := 0.0
const LIGHT_PROPS := {"oil_lamp": Vector2(0, -26), "drum_fire": Vector2(0, -20), "guard_booth": Vector2(0, -26), "watchtower": Vector2(0, -78), "radar_beacon": Vector2(16, -10)}
var travel_block := Callable()                                     ## (lid) -> 막는 까닭 문자열("" = 막지 않음) — 진행기가 건다(1-11f)
var travel_blocks: Array = []                                       ## 더 거는 막음들(같은 꼴, 1-12e — 진행기 여럿이 하나를 덮어쓰지 않게)
var wait_vetoes: Array = []                                         ## () -> 기다리기 · 잠을 막는 까닭(""이면 막지 않음) — 진행기가 건다(1-12e 박춘삼 계약 '지상에서 자자고?')
var travel_mul := 1.0                                               ## 빠른 이동 시간 배수(1-11f — 굶주린 동행 ×1.25)
var extra_lights: Array = []                                        ## 진행기가 켠 빛 [[위치, 색], …] — 맵이 바뀌면 비운다
const DARK_SETS := ["cv"]                                            ## 전기가 끊긴 지하(하수 · 빗물 암거 TS-I10 · 동굴 TS-I11)


func set_night(on: bool) -> void:
	night = on
	_tone_update(true)


func _ensure_tone_layers() -> void:
	if _night_layer != null:
		return
	_night_layer = CanvasLayer.new()
	_night_layer.layer = 1                                        # 맵(0층) 위, HUD·대화(8층~) 아래
	add_child(_night_layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)                # 화면 전체(크기는 앵커가 정한다)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_mat = ShaderMaterial.new()
	_night_mat.shader = load("res://systems/display/night_tone.gdshader")
	r.material = _night_mat
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


## 바깥인가(시각 색조를 받는 맵): 심리스 월드와 바깥 손 맵(set r01)
func outdoor() -> bool:
	return map != null and (map is WorldMap or str(map.data.get("set", "")) == "r01")


## 불 꺼진 지하인가(실내 정전 + 핍-보이 조명)
func dark_inside() -> bool:
	if map == null or outdoor():
		return false
	if map.data.has("dark_if"):                                          # 1-D2 조건부 어둠(맵 'dark 식'): 회로를 살리면 밝고 끊으면 어둡다
		return InteriorMap._cond_ok(str(map.data["dark_if"]), st)
	return str(map.data.get("set", "")) in DARK_SETS or bool(map.data.get("dark", false))


## 지금 색조 · 빛 세기를 정한다(매 0.25초, 맵이 바뀌면 바로)
func _tone_update(force := false) -> void:
	var m := TimeOfDay.minute(date_text)
	var t := Vector4.ZERO
	var lk := 0.0
	var pk := 0.0
	var fk := 0.0
	if map == null:
		pass
	elif outdoor():
		t = TimeOfDay.TONES["밤"] if night else TimeOfDay.tone(m)
		lk = 1.0 if night else TimeOfDay.light_k(m)
		pk = 0.0 if night else TimeOfDay.pip_k(m)
		fk = 0.0 if night else TimeOfDay.fog_k(m)
	elif dark_inside():
		t = TimeOfDay.TONES["실내 정전"]
		lk = 1.0
		pk = 1.0
	if not force and t == tone_now and is_equal_approx(lk, light_k) and is_equal_approx(pk, pip_light) and is_equal_approx(fk, fog_k):
		return
	tone_now = t
	light_k = lk
	pip_light = pk
	fog_k = fk
	var on := TimeOfDay.is_dark(t) or fk > 0.01
	if on:
		_ensure_tone_layers()
		_night_mat.set_shader_parameter("tone", t)
		_night_mat.set_shader_parameter("fog", fk)
	if _night_layer != null:
		_night_layer.visible = on
		_light_layer.visible = on
		_lights.queue_redraw()


## 빛 원판: 반지름 64px 4단(가운데가 가장 밝다), 백열 P50. 디더·그라데이션 없이 단 색 띠(§10.6). 핍-보이 조명은 주인공 둘레 96px 청록빛
func _draw_lights() -> void:
	if map == null:
		return
	if light_k > 0.01:
		for p in map.props:
			var off: Variant = LIGHT_PROPS.get(p["name"])
			if off == null:
				continue
			var c := Vector2(int(p["x"]) * 32 + 16 * int(p["w"]), (int(p["y"]) + int(p["h"])) * 32) + (off as Vector2)
			var k := 1.0 + (0.06 if p["name"] == "drum_fire" and int(_flicker_t * 6.0) % 2 == 0 else 0.0)
			var col := Color(1.0, 0.92, 0.6) if p["name"] != "radar_beacon" else Color(1.0, 0.7, 0.25)
			if p["name"] == "oil_lamp":
				col = Color(1.0, 0.78, 0.42)                                 # 등유 램프: 백열보다 주황(1-11f 탄약고)
				k += 0.04 if int(_flicker_t * 5.0) % 3 == 0 else 0.0
			for i in 4:
				var r := 64.0 * k * (1.0 - i * 0.22)
				_lights.draw_circle(c, r, Color(col.r, col.g, col.b, (0.05 + i * 0.035) * light_k))
	if light_k > 0.01:
		for l in extra_lights:                                            # 진행기가 켠 빛(1-11e 낙성대 비상등 — 방송이 들어오면): [위치, 색]
			for i in 4:
				var r2 := 72.0 * (1.0 - i * 0.22)
				var lc: Color = l[1]
				_lights.draw_circle(l[0], r2, Color(lc.r, lc.g, lc.b, (0.05 + i * 0.035) * light_k))
	if pip_light > 0.01 and player != null and is_instance_valid(player):
		var pc: Vector2 = player.loco.render + Vector2(0, -16)
		for i in 4:
			var r := TimeOfDay.PIP_R * (1.0 - i * 0.2)
			_lights.draw_circle(pc, r, Color(0.55, 1.0, 0.85, (0.045 + i * 0.03) * pip_light))


func _night_tick(dt: float) -> void:
	_tone_t += dt
	if _tone_t >= 0.25:
		_tone_t = 0.0
		_tone_update()
	if _night_layer == null or not _night_layer.visible or map == null:
		return
	_flicker_t += dt
	var f := int(_flicker_t * 6.0) % 3
	if f != int((_flicker_t - dt) * 6.0) % 3:
		for p in map.props:
			if p["name"] == "drum_fire":
				map.set_prop_state(Vector2i(int(p["x"]), int(p["y"])), ["", "f1", "f2"][f])
	_lights.queue_redraw()                                            # 핍-보이 조명은 주인공을 따라간다
	if fog_k > 0.01:                                                  # 안개는 땅에 붙는다: 화면 왼쪽 위의 세상 좌표 · 화면이 덮는 세상 크기
		var inv := get_viewport().get_canvas_transform().affine_inverse()
		var vs := get_viewport().get_visible_rect().size
		_night_mat.set_shader_parameter("cam", inv * Vector2.ZERO)
		_night_mat.set_shader_parameter("view", inv.basis_xform(vs))


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
	var keep_mates: Array = combat.mates.leaving(cur_map) if map != null else []   # 따라오는 동행은 맵을 넘고, 기다리는 동행은 그 맵에 남는다(1-10a)
	cur_map = map_id
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
	extra_lights.clear()
	ev.cam_locked = false
	var world_mode := WorldMap.covers(map_id)                       # 바깥(관악산 비탈·봉천 등)은 심리스 월드 하나(1-1)
	var from_inside := map != null and not (map is WorldMap)
	if enc_live != null:
		enc_live.on_map_changed(map_id)
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
	var head_on := str(st.vars.get_v("PC_HEAD"))
	if player.doll != null and head_on != "":
		if st.items.has(head_on):
			player.doll.set_look({"gear": str(items_db.get(Gear.base(head_on), {}).get("layer", ""))})   # 쓴 머리 장비(1-D6)
		else:
			st.vars.set_v("PC_HEAD", "")                                   # 팔았거나 잃었다
	var eyes_on := str(st.vars.get_v("PC_EYES"))
	if player.doll != null and eyes_on != "":
		if st.items.has(eyes_on):
			player.doll.set_look({"eyes": str(items_db.get(Gear.base(eyes_on), {}).get("layer", ""))})   # 쓴 눈 장비(1-11e)
		else:
			st.vars.set_v("PC_EYES", "")                                   # 팔았거나 잃었다
	player.visible = body != "hidden"
	map.add_actor(player)
	if world_mode and at == Vector2.INF and mark.begins_with("@"):     # 들어가 본 건물에서 나온다(1-5e): 그 문 앞 칸, 남쪽을 보고
		var xy := mark.substr(1).split(",")
		at = Vector2(int(xy[0]) * 32 + 16, int(xy[1]) * 32 + 16)
	if world_mode and at == Vector2.INF and mark.begins_with("L-") and mark.contains(">"):   # 1-D 두 입구: 'L-ID>표지' = 그 장소의 문 가운데 이 표지로 드는 문 앞
		PlaceLog.load_db()
		var lm := mark.split(">")
		for door in PlaceLog.doors:
			if str(door.get("lid", "")) == lm[0] and str(door.get("mark", "")) == lm[1]:
				at = Vector2(int(door["at"][0]) * 32 + 16, (int(door["at"][1]) + 1) * 32 + 16)
				break
		if at == Vector2.INF:
			mark = lm[0]
	if world_mode and at == Vector2.INF and mark.begins_with("L-"):    # 실내에서 월드의 장소로 나간다(1-3): 그 장소의 도착 칸
		PlaceLog.load_db()
		var arr = PlaceLog.db.get(mark, {}).get("arrive")
		if arr != null:
			at = Vector2(int(arr[0]) * 32 + 16, int(arr[1]) * 32 + 16)
	var m: String = mark if map.marks.has(mark) else (map.marks.keys()[0] if not map.marks.is_empty() else "")
	player.loco.place(map.mark_pos(m) if at == Vector2.INF else at)
	player.loco.facing = EventRunner.DIR_IDX.get(map.mark_dir(m), 2)
	player.position = player.loco.render
	player.set_floor(0)                                                 # 맵에 들어서는 자리는 땅(불러오기는 저장한 층을 뒤에 다시 세운다)
	if map is WorldMap:
		map.follow = player
		map.id = map.zone_of(map.tile_of(player.loco.logical))
		map.load_now(player.loco.logical)
		map_id = map.id
		_zone = map.id
	player._show()
	_last_tile = map.tile_of(player.loco.logical)
	if map is WorldMap:
		_turf_see(_last_tile)                                             # 판도(1-12m): 들어선 칸의 구역(빠른 이동 · 문 나섬 — 걷기 전에도)
	_spawn_npcs()
	_lay_spills(map_id)
	alarmed.clear()
	if map_id == "V-00" and int(st.vars.get_v("V_ESCAPE")) >= 1 and st.quests.stage("MQ-P4") < 60:
		map.set_gate(1.0)                                              # 탈출 중 레버로 다시 연 방폭문은 맵을 다시 열어도 열린 채
	ev.actors["PC"] = player                                          # 연출 명령이 주인공도 부를 수 있다(move PC 표지 · face PC 방향, 0-9)
	combat.on_map(map, player, st)
	sync_residents()
	for n in npcs.duplicate():                                        # 적대 정착지(≤ −60)에 들어왔다: 자경단이 사격한다(SD-06 §4.3.8 · SD-14 §9.12)
		var tg := Crimes.target(st, str(n["id"]))
		if tg.begins_with("JC_") and Crimes.hostile(st, tg) and int(st.vars.get_v("V_ACT")) >= 1:
			settlement_alarm.call_deferred(tg, "적대")
			break
	ev.setup(map, map_id, cam)
	for k in keep_mates:
		_bring_buddy(str(k["id"]))
		var km := combat.mates.get_mate(str(k["id"]))
		if not km.is_empty():
			(km["cmb"] as Combatant).hp = clampf(float(k["hp"]), 1.0, (km["cmb"] as Combatant).max_hp)
			if str(k.get("mode", "follow")) == "escort":
				km["mode"] = "escort"                                          # 호위 대상은 맵을 넘어도 호위(1-11f)
	for id in combat.mates.away.keys():                               # 이 맵에 기다리게 두고 간 동행: 그 자리에 다시 세운다
		var aw: Dictionary = combat.mates.away[id]
		if str(aw["map"]) != cur_map:
			continue
		combat.mates.away.erase(id)
		var at2 := Vector2(float(aw["pos"][0]), float(aw["pos"][1]))
		ev._show_actor(str(id), at2, "S", str(Companions.row(str(id)).get("sheet", "")))
		if ev.actors.has(str(id)):
			var wm := combat.mates.add(str(id), ev.actors[str(id)], str(aw.get("name", "")), str(aw.get("mode", "wait")))
			if not wm.is_empty():
				(wm["cmb"] as Combatant).hp = clampf(float(aw["hp"]), 1.0, (wm["cmb"] as Combatant).max_hp)
	_sync_mates()
	if world_mode and from_inside and enc_live != null:
		enc_live.on_exit_interior.call_deferred()                    # 실내에서 밖으로 나온 순간도 판정 기회(SD-05 §6.1)
	if outdoor():                                                     # 바깥: 맵 끝에서 카메라가 멈춘다
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = map.size.x * 32
		cam.limit_bottom = map.size.y * 32
	else:                                                              # 실내 · 지하(1-T3, 포켓몬 골드식): 카메라는 늘 주인공 가운데 — 방 밖은 검은 어둠
		cam.limit_left = -10000000
		cam.limit_top = -10000000
		cam.limit_right = 10000000
		cam.limit_bottom = 10000000
	RenderingServer.set_default_clear_color(Color("0B0A0D") if outdoor() else Color("1A181D"))   # 실내 바깥 = 벽 윗면과 같은 검정(P01)
	cam.position = player.loco.logical.round()
	cam.reset_smoothing()
	_tone_update(true)
	banner_text = map.zone_name() if map is WorldMap else str(map.data["name"]) + _floor_tag()
	banner_t = BANNER_SECS
	map_entered.emit(map_id)


func _spawn_npcs() -> void:
	for i in map.data["npcs"].size():
		var n: Dictionary = map.data["npcs"][i]
		var cond: String = n.get("cond", "")
		if cond != "" and not StoryExpr.test(cond, st):
			continue
		if st.is_dead(str(n["id"])) or st.is_dead("%s@%s" % [n["id"], map.id]):   # 죽인 주민은 다시 서지 않는다(SD-10 §6.3, 0-9 · 1-L 가게마다 장사꾼)
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
		if live.has(i) or (cond != "" and not StoryExpr.test(cond, st)) or st.is_dead(str(n["id"])):
			continue
		_spawn_npc(i, n)
	sync_residents()


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
	if str(n.get("pose", "")) != "":
		a.set_pose(str(n["pose"]))                                   # 맵 원고의 자세(pose=sleep 낮잠 등)
	var r: NpcRoutine = NpcRoutine.new(a, map, n["route"]) if not n["route"].is_empty() else null
	if r != null:
		a.set_meta("routine", true)                                  # 일과로 걷는 인물: 이벤트 실행기가 세우지 않는다(일과가 걷기·멈춤을 맡는다)
	npcs.append({"id": n["id"], "actor": a, "routine": r, "bark": n.get("bark", ""), "idx": i})
	ev.actors[n["id"]] = a                                       # 연출 명령(move·face·balloon·pose)이 맵 인물을 부를 수 있게
	map.blockers.append(a)


## 장소 표시(일시 정지·저장 칸): 볼트 실내 = 볼트 S-07 · 맵 이름, 월드 = 권역 · 구역 이름(1-1)
## 손대지 못한 자물쇠 · 단말을 기억해 둔다(1-12p 레벨업 문턱 한 마디 — 직접 만져 본 자리만, 최근 여섯)
##   key = 그 문(door:…) · 용기(Loot.key) · 단말(term:ID) — 나중에 열면 레벨업 때 다시 말하지 않는다(LevelDraft.still_shut). 볼트 시대 자리는 적지 않는다(다시 못 간다)
func _tried(skill: String, lv: int, what: String, key := "") -> void:
	if map == null or map.id.begins_with("V-") or st.quests.cur_act() < 1:
		return
	var req := int(Lockpick.REQ[Lockpick.grade_of(lv)]) if skill == "LOCKPICK" else lv
	var tr: Dictionary = st.boxes.get("tried", {})
	var arr: Array = tr.get(skill, [])
	var where := ("%s의 그 %s" % [_place_name(), what]) if _place_name() != "" else "그 " + what
	for e in arr:
		if str(e["where"]) == where:
			return
	arr.append({"req": req, "where": where, "day": int(st.vars.get_v("GAME_DAY")), "key": key})
	if arr.size() > 6:
		arr.pop_front()
	tr[skill] = arr
	st.boxes["tried"] = tr


func _place_name() -> String:
	if map == null:
		return ""
	if map is WorldMap:
		var rn: String = map.region_name(map.region_at(map.tile_of(player.loco.logical))) if player != null else "서울"
		var zn: String = map.zone_name()
		return rn if zn == rn else "%s · %s" % [rn, zn]
	if not Dungeon.of_map(map.id).is_empty():                          # 던전(1-D0): 이름 · 층
		return str(map.data["name"]) + _floor_tag()
	return ("볼트 S-07 · " if map.id.begins_with("V-") else "관악 · ") + str(map.data["name"])


func _floor_tag() -> String:
	var f := Dungeon.floor_of(map.id) if map != null else ""
	return "" if f == "" else " · " + f


const WET_MUL := [1.0, 0.8, 0.6]                  ## 침수 이동 배수(SD-09f §3.5: 발목 ×0.8 · 허리 ×0.6)
var _wet_said := false
var last_move := Vector2.ZERO                      ## 이번 프레임 주인공 이동 입력(1-D10 수레 밀기 판정)
var interact_pre: Array[Callable] = []             ## 조사 키 — 다른 무엇보다 먼저 묻는 진행기 고리(참이면 그것으로 끝)
var interact_post: Array[Callable] = []            ## 조사 키 — 앞에 아무것도 없을 때 묻는 진행기 고리
var lead_walk := false                             ## 고삐를 쥐고 걷는다(1-12g UQ-05 누렁이 — 짐소 걷기 3.0에 맞춰 뛰기 · 달리기 없음, 진행기 UqR01이 정한다)
var carry_mul := 1.0                               ## 들고 걷는 짐 배수(1-D7 금형 M-395 과적 0.6 — 진행기 Ks가 정한다). 침수 배수와 곱한다


## 1-D 침수: 발 딛은 칸의 물 깊이로 주인공 · 적의 걸음을 늦춘다. 허리 물에서는 웅크릴 수 없다(한 번 알림)
func _wet_tick() -> void:
	if map == null or player == null:
		return
	if map.wet.is_empty():
		player.loco.terrain_mul = carry_mul
		return
	var w: int = map.wet_at(map.tile_of(player.loco.logical))
	player.loco.terrain_mul = WET_MUL[w] * carry_mul
	if w == 2 and combat.crouch:
		combat.crouch = false
		if not _wet_said:
			_wet_said = true
			hint("물이 허리까지 찬다 — 웅크릴 수 없다.", 3.0)
	for e in combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead:
			e.loco.terrain_mul = WET_MUL[map.wet_at(map.tile_of(e.loco.logical))]


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
	_wet_tick()
	_hurt_t = maxf(0.0, _hurt_t - dt)
	_hud_t += dt
	_radio_tick(dt)
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
	talking = talking or pipboy != null or container != null or terminal != null or lockpick != null or wait_ui != null or craft_ui != null
	if talking:
		if player.rolling():
			player.roll_step(dt)                                          # 대화 · 연출이 구르는 중에 시작돼도 0.35초를 마저 구른다
		elif not ev.drives(player):                                         # 연출이 주인공을 걷게 하는 중이면(move PC …) 멈추지 않는다
			player.move(Vector2.ZERO, dt)
		combat.mates.push = Vector2.ZERO
		last_move = Vector2.ZERO
	else:
		var v := input_vec
		if use_keyboard and v == Vector2.ZERO:
			v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if combat.pc.held():                                             # 1-9a: 넘어짐·기절·마비·그물 — 서 있다
			v = Vector2.ZERO
		player.mode = "walk" if body == "toddler" or combat.crouch or combat.inject_t > 0.0 or combat.heavy_slow() or lead_walk else "run"
		player.loco.custom = TODDLER_WALK if body == "toddler" else (CROUCH_WALK if combat.crouch else {})
		_ap_input(v)                                                     # 1-9e3 질주 · 구르기(SD-11 §5.3)
		if combat.sprinting:
			player.mode = "sprint"
		if player.rolling():
			player.roll_step(dt)
		elif input_fn.is_valid():
			var left := dt
			while left > 0.0001:
				var h := minf(left, 1.0 / 60.0)
				left -= h
				var bv: Vector2 = input_fn.call()
				v = bv
				player.move(bv, h)
		else:
			player.move(v, dt)
		last_move = v                                                    # 1-D10 수레 밀기: 진행기가 이번 걸음의 방향을 읽는다
		combat.mates.push = v                                            # 동행이 길목에서 비킨다(1-10a)
		_nudge_npcs(v, dt)
		if player.doll != null:
			player.doll.position.y = 2.0 if combat.crouch else 0.0               # 웅크리면 2px 낮게(전용 그림 전까지)
		var hold_act: bool = (use_keyboard and Input.is_action_pressed("interact")) or act_held
		if hold_act and not box.active and not combat.mates.revive_target(player.loco.logical).is_empty():
			combat.mates.revive_tick(player.loco.logical, dt, st)          # 동행 일으키기 2초 + 스팀팩(1-10a)
		elif combat.mates.rev_prog >= 0.0:
			combat.mates.rev_prog = -1.0                                   # 손을 떼면 처음부터
		if use_keyboard and combat.can_disarm_here() and Input.is_action_pressed("interact") and not box.active:
			combat.disarm_tick(dt, st)                                       # 웅크려 상호작용 길게 = 함정·지뢰 해체(1-9c, SD-11 §9.2)
		elif use_keyboard and Input.is_action_just_pressed("interact") and not box.active:
			combat.disarm_prog = -1.0
			interact()
		elif combat.disarm_prog >= 0.0:
			combat.disarm_prog = -1.0                                        # 손을 떼면 처음부터(반쯤 된 해체 없음, SD-20 P10)
		if use_keyboard and pipboy_ok and Input.is_action_just_pressed("pipboy"):
			open_pipboy()
		if use_keyboard and pipboy_ok and Input.is_action_just_pressed("wait"):
			open_wait()
		_check_exit()
		_clock_step(dt)
		Radiation.drug_tick(st, dt)                                          # 라드-X 류는 실시간 초로 닳는다(1-9d)
		enc_live.tick(dt)
	if map is WorldMap:
		map.update_hole(player.loco.logical, player.floor_id)                # 고가 상판 아래·끝 앞: 둘레를 디더로 비춘다(1-Rd)
	combat.tick(dt, not talking, st)
	var want := Vector2.ZERO                                              # 조준 쪽으로 카메라를 끈다(원거리 무기, 최대 3칸 — SD-12 §15 '카메라 리드')
	if combat.armed() and combat.weapon()["kind"] == "ranged" and not talking:
		var lim := 192.0 if combat.scope_steady() else (128.0 if combat.aim_held else 96.0)   # 정조준 4칸 · 스코프 안정 6칸(1-9e3)
		want = ((combat._aim_point(player) - player.loco.logical) * (0.6 if combat.scope_steady() else 0.4)).limit_length(lim)
	cam_lead = cam_lead.lerp(want, 1.0 - exp(-dt * 5.0))
	if not ev.cam_locked:
		cam.position = (player.loco.logical + cam_lead).round()


## 질주(누르는 동안 · 터치 링 밖 0.3초)와 회피 구르기(Space · 터치 단추 · 봇 dodge). 걸음마 · 웅크림 · 붙잡힘 · 과적 감속엔 못 뛴다.
## 구르기는 어른 몸만(아이 · 아기 시트에 구르기 컷이 없다). 과적이면 AP ×2 · 거리 ×0.6(SD-11 §5.3)
func _ap_input(v: Vector2) -> void:
	var key := touch_sprint or (use_keyboard and Input.is_action_pressed("sprint")) or bool(combat.bot.get("sprint", false))
	combat.sprint_want = key and v != Vector2.ZERO and body != "toddler" and not combat.crouch and not combat.pc.held() and not combat.heavy_slow() and not lead_walk
	var roll := roll_req or (use_keyboard and Input.is_action_just_pressed("dodge")) or bool(combat.bot.get("dodge", false))
	roll_req = false
	combat.bot.erase("dodge")
	if roll and body == "adult" and not player.rolling():
		var c := status_carry()
		combat.try_roll(player, v, float(c[0]) > float(c[1]))


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
	ev._show_actor(id, at, "S", str(Companions.row(id).get("sheet", "")))
	if ev.actors.has(id):
		var b: Actor = ev.actors[id]
		b.loco.facing = player.loco.facing
		b._show()
		combat.mates.add(id, b, _mate_name(id))
		_sync_mates()


## 일과 주민이 길을 막았다: 주인공이 0.6초 넘게 그쪽으로 밀어도 못 가면 그 사람이 옆으로 비켜 선다(서로 막혀 둘 다 서 있지 않게)
var _push_t := 0.0


func _nudge_npcs(v: Vector2, dt: float) -> void:
	if v.length() < 0.2 or player.loco.motion != "idle":
		_push_t = 0.0
		return
	_push_t += dt
	if _push_t < 0.6:
		return
	_push_t = 0.0
	var f := v.normalized()
	for n in npcs:
		if n["routine"] == null or not is_instance_valid(n["actor"]) or n.get("dead", false) or n["routine"].paused:
			continue
		var rel: Vector2 = n["actor"].loco.logical - player.loco.logical
		if rel.length() < 44.0 and rel.normalized().dot(f) > 0.5:
			n["routine"].step_aside(Vector2(signf(f.x) if absf(f.x) > 0.38 else 0.0, signf(f.y) if absf(f.y) > 0.38 else 0.0))


func _mate_name(id: String) -> String:
	return st.npc_name(id).get_slice("(", 0).strip_edges()


## 옛 이름(buddy_id · buddy_name — 저장 · 진행기가 읽는다)을 첫 동행에 맞춘다
func _sync_mates() -> void:
	if combat.mates.list.is_empty():
		buddy_id = ""
		buddy_name = ""
	else:
		buddy_id = str(combat.mates.list[0]["id"])
		buddy_name = str(combat.mates.list[0]["name"])


## 말 걸기(SD-12 §11.4 '대화하면 퀘스트가 정한 선택지만'): 동행 퀘스트 장면이 따로 없으면 '기다려 · 따라와' 두 가지만
func _mate_talk(m: Dictionary) -> void:
	var id := str(m["id"])
	var r := Companions.row(id)
	var waiting: bool = m["mode"] in ["wait", "guard"]
	var ops: Array = [{"op": "line", "who": id, "emo": "기본", "text": str(r["hello"])}]
	var opts: Array = []
	if not scene_for(id).is_empty():                                    # 퀘스트 장면이 있는 동행: 그 이야기로도 갈 수 있다
		opts.append({"text": "할 말이 있어", "tags": [], "cond": "", "fx": "", "to": "SCENE", "id": "MATE:%s:scene" % id})
	if waiting:
		opts.append({"text": "같이 가자", "tags": [], "cond": "", "fx": "", "to": "GO", "id": "MATE:%s:go" % id})
	else:
		opts.append({"text": "잠깐 여기서 기다려 줘", "tags": [], "cond": "", "fx": "", "to": "STAY", "id": "MATE:%s:stay" % id})
	opts.append({"text": "아니야, 됐어", "tags": [], "cond": "", "fx": "", "to": "END", "id": "MATE:%s:end" % id})
	ops.append({"op": "choice", "opts": opts})
	var labels := {"START": 0}
	labels["STAY"] = ops.size()
	ops.append({"op": "cmd", "name": "mate", "args": [id, "wait"]})
	ops.append({"op": "line", "who": id, "emo": "기본", "text": str(r["wait"])})
	ops.append({"op": "goto", "to": "END"})
	labels["GO"] = ops.size()
	ops.append({"op": "cmd", "name": "mate", "args": [id, "follow"]})
	ops.append({"op": "line", "who": id, "emo": "기본", "text": str(r["follow"])})
	ops.append({"op": "goto", "to": "END"})
	labels["SCENE"] = ops.size()
	ops.append({"op": "cmd", "name": "mate_scene", "args": [id]})
	ops.append({"op": "goto", "to": "END"})
	labels["END"] = ops.size()
	ops.append({"op": "end"})
	box.open(st, {"id": "MATE_" + id, "title": str(m["name"]), "npc": id, "labels": labels, "ops": ops}, "START")


## 앞에 선 동행(쓰러지지 않은, 46px 안 · 바라보는 쪽)
func _mate_front() -> Dictionary:
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	for m in combat.mates.list:
		if m["down"] or not is_instance_valid(m["actor"]):
			continue
		var v: Vector2 = (m["actor"] as Actor).loco.logical - player.loco.logical
		if v.length() < 46.0 and v.normalized().dot(f) > 0.5:
			return m
	return {}


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


## 고가 상판 위(층 1, 1-Rd): 그 아래 땅의 문·출구·밟는 칸·조사 글·땅 용기는 걸리지 않는다
func _up() -> bool:
	return map != null and map.has_deck and player.floor_id >= 1


## 그 인물과 같은 층에서 마주 서 있나(상판 위·아래 사이로는 말을 걸지 않는다)
func _same_floor(a) -> bool:
	return map == null or not map.has_deck or map.floors_meet(a.loco.logical, a.floor_id, player.loco.logical, player.floor_id)


var _fb_chunk := Vector2i(-99, -99)                                    ## 세력 기록을 마지막으로 살핀 청크(1-12m)


## 판도(1-12m): 선 구역을 지금 판으로 적는다 — 알던 판과 다르면 한 줄(재미 검수 ③)
func _turf_see(t: Vector2i) -> void:
	var tmsg: String = st.turf.see(st, t)
	if tmsg != "":
		hint(tmsg, 4.5)


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
		_turf_see(t)
		if Vector2i(t.x / 40, t.y / 40) != _fb_chunk:
			_fb_chunk = Vector2i(t.x / 40, t.y / 40)
			st.fbook.refresh(st, date_text)
		var had: bool = int(st.vars.get_v("LM_SEEN")) != 0
		for nm in Landmarks.tick(st, t, Clock.is_night(date_text)):        # 원경 표식(1-12k, SD-08 §12.2): 반경 안에 처음 들어간 랜드마크 — 설명은 처음 한 번만
			hint(("원경 표식: %s — 방위 링 밖 회색 실루엣이 방향이다" if not had else "멀리 %s이(가) 보인다") % nm, 4.0)
			had = true
	if _up():
		return
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
	for hk in interact_pre:                                          # 진행기 먼저(1-D10 수레를 탄 채 브레이크 등)
		if hk.call():
			return true
	var sur := combat.surrendered_near(player.loco.logical)             # 항복한 적(1-9e, SD-11 §7.5): 놓아준다
	if sur != null:
		combat.release(sur)
		return true
	if not combat.mates.revive_target(player.loco.logical).is_empty():   # 쓰러진 동행(1-10a): 누르고 있으면 일으킨다(_physics_process)
		if int(st.items.get(InteriorCombat.STIMPAK, 0)) <= 0:
			hint("스팀팩이 있어야 일으킬 수 있다.", 2.5)
		return true
	var mf := _mate_front()
	if not mf.is_empty() and not combat.mates.fight:                   # 동행에게 말 걸기: 퀘스트 장면이 있으면 그것, 없으면 '기다려 · 같이 가자'
		_mate_talk(mf)
		return true
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	var best: Dictionary = {}
	var best_d := 1e9
	for n in npcs:
		if not is_instance_valid(n["actor"]) or n.get("dead", false) or float(n.get("down_t", 0.0)) > 0.0:
			continue
		if not _same_floor(n["actor"]):
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
	if _up():
		return false
	var wb := bench_front(cells)                                        # 작업대·화덕(1-8c): 제작·조리 창
	if not wb.is_empty():
		if str(wb.get("why", "")) != "":
			say_text(str(wb["why"]))
		else:
			open_craft(wb)
		return true
	var bd := bed_front(cells)                                          # 침대(1-8b): 남의 것이면 못 자고, 아니면 수면 창
	if not bd.is_empty() and not bool(bd.get("script", false)):
		if bool(bd["other"]):
			say_text(str(bd.get("why", "[소유] 남의 침대다. 함부로 누울 수 없다.")))
		else:
			open_wait(bd)
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
				_tried("LOCKPICK", lv, "문", dkey)
			else:
				open_lock(lv, "door", func() -> void:
					st.boxes[dkey] = {"open": true}
					map.unlock_door(int(dr["x"]), int(dr["y"])),
					func() -> void: st.boxes[dkey] = {"jammed": true})
			return true
	var tm := _front_term(cells)
	if not tm.is_empty():
		if combat.hazards.on_use(Vector2i(int(tm["x"]), int(tm["y"]))):     # 폭탄 단말기(1-9c): 켜는 순간 감전 + 폭발
			hint("단말기 속에서 무언가 딸깍 했다.", 3.0)
			return true
		open_terminal(tm)
		return true
	var gd := _front_go(_before_text(cells))
	if not gd.is_empty():
		_enter_go(gd)
		return true
	for cc in cells:
		if map.texts.has(cc):
			var m: Dictionary = map.text_meta.get(cc, {})
			for alt in map.text_alt.get(cc, []):                            # 같은 칸 여러 장면 글 — 지금 조건이 맞는 첫 것(1-11k)
				if InteriorMap._cond_ok(str(alt["cond"]), st):
					m = alt
					break
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
	for hk in interact_post:                                         # 아무것도 없을 때 진행기(1-D10 레일에 귀 대기 · 두드리기)
		if hk.call():
			return true
	return false


## 앞 칸 목록을 첫 조사 글 칸까지로 자른다(그 칸 포함 — 글과 문이 같은 칸이면 문). 1-B: 문 앞 표지 · 분필 표식이 먼 문에 가리지 않게
func _before_text(cells: Array) -> Array:
	var out: Array = []
	for cc in cells:
		out.append(cc)
		if map.texts.has(cc) and not map.gos.has(cc):
			break
	return out


## 앞 칸의 들어가는 문(1-5e 월드 건물 1층 문) — 없으면 빈 사전
func _front_go(cells: Array = []) -> Dictionary:
	if map == null or map.gos.is_empty() or _up():
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
			_tried("LOCKPICK", lv, "문", key)
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
			if map.has_deck and int(b.get("fl", 0)) != player.floor_id:
				continue                                                   # 상판 위 차 트렁크(층 1)와 그 아래 땅 용기(층 0)는 제 층에서만
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
	if e.has_meta("militia") and e.who != "":                           # 총을 든 자경단원(먼저 쏜 쪽은 그들이다 — 카르마는 없다, 학살 수에는 든다)
		st.kill(e.who)
		var dd := st.deeds
		var tg := str(e.get_meta("militia"))
		dd.kills[tg] = int(dd.kills.get(tg, 0)) + 1
		if int(dd.kills[tg]) >= Crimes.MASSACRE and int(dd.grudge.get(tg, 0)) < 2:
			dd.record(st, "범죄", map_region(map.tile_of(e.loco.logical)), 2, {tg: 0}, Clock.abs_min(date_text),
				{"tag": "CRIME_PERM", "what": "학살", "seen_by": [tg]})
	var eid := str(e.get_meta("enemy_id", ""))
	if map is WorldMap:
		st.turf.note_kill(st, map.tile_of(e.loco.logical), str(StoryState.ENEMY_FACTION.get(eid, "")))   # 판도(1-12m): 구역 안 세력원 처치 = 그 세력 −1(하루 3)
	if not Loot.drops.has(eid) or eid in ["CR-002", "CR-104"]:
		return
	var c := map.tile_of(e.loco.logical)
	if map.boxes.has(c):
		return
	var nm := str(combat.enemy_rows.get(eid, {}).get("name", "적"))
	map.boxes[c] = {"x": c.x, "y": c.y, "w": 1, "h": 1, "kind": "_corpse", "eid": eid, "name": nm + "의 유해", "owner": "", "lock": 0,
		"cond": "", "key": "corpse:%s:%d,%d@%d:%d" % [map.id, c.x, c.y, int(st.vars.get_v("GAME_DAY")), Time.get_ticks_msec()]}


## 보이는 빔(1-L §9.1): 생성 실내에 들어서면, 이미 털린 용기 앞 바닥 칸에 털린 자리 무늬(서랍 · 종이 · 문짝 · 분필 · 깨진 병)를 깐다.
## 무늬는 용기 종류로 고른다(찬장 → 문짝 · 서랍 → 서랍 · 서류 → 종이 · 진열대 → 병 · 상자 → 분필). 막지 않는 덧그림이다
const SPILL := {"pantry": "spill_door", "conv": "spill_glass", "apartment": "spill_drawer", "desk": "spill_drawer", "cabinet": "spill_paper",
	"pharmacy": "spill_glass", "toolbox": "spill_chalk", "crate": "spill_chalk", "stall": "spill_chalk", "trash": "spill_chalk", "safe": "spill_paper"}


func _lay_spills(map_id: String) -> void:
	if not map_id.begins_with("G-") or map is WorldMap or st.year() < 2277:
		return
	var seen := {}
	var used := {}
	for c in map.boxes:
		var b: Dictionary = map.boxes[c]
		if seen.has(b) or not Loot.visibly_empty(st, map_id, b):
			continue
		seen[b] = true
		var nm := str(SPILL.get(str(b.get("kind", "")), "spill_chalk"))
		for i in int(b.get("w", 1)):                                      # 용기 앞(아래) 칸 — 비어 있는 바닥만
			var fc := Vector2i(int(b["x"]) + i, int(b["y"]) + int(b.get("h", 1)))
			if map.is_solid(fc) or used.has(fc) or map.boxes.has(fc) or not map.exit_at(fc).is_empty():
				continue
			map.add_runtime_prop(nm, fc)
			used[fc] = true
			break


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
	if Loot.visibly_empty(st, map.id, b):                                # 보이는 빔(1-L §9.1): 창을 열지 않고 빈 이유 한 줄
		var vc := box_contents(b)
		vc["opened"] = int(vc.get("opened", 0)) + 1
		say_text(Loot.empty_line(vc) if Loot.empty_line(vc) != "" else "비었다.")
		return
	var c := box_contents(b)
	if box_locked(b):
		if bool(c.get("jammed", false)):
			say_text("자물쇠 안이 부러져 있다. 열쇠가 있어야 연다.")
			return
		var lv := int(b.get("lock", 0))
		if not Lockpick.can_try(lv, st.skill("LOCKPICK")):
			_prompt_shake = _hud_t + 0.8                                 # 시도할 수 없다 — 문구만 흔들린다(SD-12 §8.1)
			_tried("LOCKPICK", lv, str(b.get("name", "")) if str(b.get("name", "")) != "" else "자물쇠", Loot.key(map.id, b, st.year()))
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
	var swap := str(b.get("kind", "")) == "swap"
	if swap and bool(c.get("shut", false)):
		say_text("상자 뚜껑에 분필 — '도둑 사절'. 안은 비었다. 다음 사람도 그럴 것이다.")
		return
	var before := _box_value(c["items"]) if swap else 0
	container = ContainerScreen.new().setup(st, b, c, items_db, box_owner_label(b), cmax)
	container.stole.connect(_on_stole.bind(b))
	if stash != null:
		stash.on_open(b, c, container)                                    # 보관 자리 · UQ-125(1-L): 삼기 단추 · 위험 한 줄 · 털린 흔적
	container.closed.connect(func(_ok: bool) -> void:
		container = null
		if swap:
			_swap_after(c, before)
		if stash != null:
			stash.on_close(b, c)
		_vanish_check(b, c)                                                # 파밍 뒤 사라질 물건(배낭 · 자루 · 더미 — 사용자 지시 2026-10-22)
		box_closed.emit(b, c)
		_after_theft())
	add_child(container)


## 다 꺼낸 '사라지는' 용기(맵 원고 vanish — 배낭 · 여행 가방 · 자루 · 고물 더미 등): 소품과 용기를 그 자리에서 거두고 기록에 남긴다(다시 들어와도 없음)
func _vanish_check(b: Dictionary, c: Dictionary) -> void:
	if not bool(b.get("vanish", false)) or not (c.get("items", {}) as Dictionary).is_empty() or int(c.get("taken", 0)) == 0:
		return
	c["gone"] = true
	var cell := Vector2i(int(b["x"]), int(b["y"]))
	for p in map.props.duplicate():
		if int(p["x"]) == cell.x and int(p["y"]) == cell.y and p.has("node") and map.has_method("remove_runtime_prop"):
			map.remove_runtime_prop(p)
	for k in map.boxes.keys():
		if map.boxes[k] == b:
			map.boxes.erase(k)
	hint("%s — 비었다. 더 볼 것이 없다." % str(b.get("name", "")), 2.5)


func _box_value(items: Dictionary) -> int:
	var v := 0
	for id in items:
		v += int(items_db.get(Gear.base(str(id)), {}).get("value", 0)) * int(items[id])
	return v


## 바꿈 상자(1-L §4.2): 두고 간 값보다 더 가져가면(5캡 넘게) 카르마 −2 · 표시 하나. 표시 셋이면 '도둑 사절' — 그 상자는 다시 차지 않는다
func _swap_after(c: Dictionary, before: int) -> void:
	var after := _box_value(c["items"])
	if after < before - 5:
		c["bad"] = int(c.get("bad", 0)) + 1
		st.call_fn("karma", [-2])
		if int(c["bad"]) >= 3:
			c["shut"] = true
			c["items"] = {}
			hint("누군가 상자 뚜껑에 분필로 쓴다 — '도둑 사절'. 이 상자는 이제 비어 있을 것이다.", 5.0)
		else:
			hint("가져간 것이 두고 간 것보다 많다. 뚜껑 안쪽에 분필 줄이 하나 늘었다.", 4.0)
	elif after > before + 5:
		hint("두고 간 것이 가져간 것보다 많다. 다음 사람이 반길 것이다.", 3.5)


# ---------------------------------------------------------------- 단말(SD-12 §7.4 · §8.1·§8.3 해킹, 1-4)
func _terms() -> Dictionary:
	if terms_db.is_empty() and FileAccess.file_exists("res://data/terminals.json"):
		terms_db = JSON.parse_string(FileAccess.get_file_as_string("res://data/terminals.json"))["terms"]
	return terms_db


func _front_term(cells: Array = []) -> Dictionary:
	if map == null or map.terms.is_empty() or _up():
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
		if not s["locked"]:
			_tried("SCIENCE", lv, "단말", "term:" + id)
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


var stash: Node = null                          ## 보관 자리 · UQ-125 진행기(1-L, Stash) — 없으면 용기 창은 예전 그대로


## 상인 표(틀): 'VG_SCRAP@G-12-34'처럼 가게마다 따로 쓰는 일반 장사꾼(1-L §4.1)은 '@' 앞이 틀 이름
func merchant_def(vid: String) -> Dictionary:
	if merchants.is_empty() and FileAccess.file_exists("res://data/merchants.json"):
		merchants = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	return merchants.get(vid.get_slice("@", 0), {})


func shop_state(vid: String) -> Dictionary:
	var m: Dictionary = merchant_def(vid)
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
		var slow: Dictionary = (sh.get("slow", {}) as Dictionary).duplicate()
		for r in stock:                                               # 진열 장비는 '양호' 이상(SD-15 §3.8) — 갱신마다 새로 굴린다(1-8a)
			var id := str(r[0])
			if (r as Array).size() > 2:                                   # 느린 재입고(설계도 1장 · 30일, SD-15 §8 — 1-8c): 그 날수가 지나야 다시 놓는다
				if not slow.has(id) or day - int(slow[id]) >= int(r[2]):
					items[id] = int(r[1])
					slow[id] = day
				elif int((sh.get("items", {}) as Dictionary).get(id, 0)) > 0:
					items[id] = int(sh["items"][id])
				continue
			if Gear.is_gear_id(id):
				for i in int(r[1]):
					var kk := Gear.rolled_key(id, "shop", "%s:%d:%d" % [vid, day, i])
					items[kk] = int(items.get(kk, 0)) + 1
			else:
				items[id] = int(r[1])
				if vid == "V05" and id == "I-044" and st.vars.has("SQ_S05_PYO") and int(st.vars.get_v("SQ_S05_PYO")) == 1:
					items[id] = int(r[1]) * 2                                 # SQ-S05 뒤 서쪽 측실 선반(SD-04a §4.5): 느타리 재고 2배
		var caps := base if sh.is_empty() else mini(roundi(base * 1.5), maxi(base, roundi(int(sh["caps"]) * 0.5)))
		var mine: Dictionary = sh.get("mine", {})                         # UQ-125 장물(1-L): 갱신해도 진열에 남는다(팔리기 전까지)
		for id in mine:
			items[id] = int(items.get(id, 0)) + int(mine[id])
		var want := ""
		if m.has("want") and not (m["want"] as Array).is_empty():         # 요즘 찾는 것(1-L §9.2): 갱신마다 하나 — 그 물건은 ×1.5로 산다
			var wr := RandomNumberGenerator.new()
			wr.seed = hash("%s:want:%d:%d" % [vid, day / 3, st.check_seed])
			want = str(m["want"][wr.randi() % (m["want"] as Array).size()])
		var old_sh := sh
		sh = {"items": items, "caps": caps, "day": day, "total": int(sh.get("total", 0)), "slow": slow, "want": want}
		if old_sh.has("mine"):
			sh["mine"] = old_sh["mine"]
			sh["mine_b"] = old_sh.get("mine_b", 0)
		st.boxes[key] = sh
	return sh


# ---------------------------------------------------------------- NPC 정비(1-8a, SD-15 §5.2)
## 정비 메뉴를 대화 선택지로 연다: 맡길 수 있는 장비마다 '한 단계 위로 · 정비비'([캡 N] 태그가 모자라면 꺼지고, 고르면 낸다).
## 한 단계를 고치면 메뉴가 다시 열린다(SD-15 '한 단계씩도 가능'). 상한(fix.cap)·계열(fix.kinds)·요율(fix.rate)은 상인 표가 정한다
func fix_menu(vid: String, again: bool = false) -> void:
	shop_state(vid)
	var m: Dictionary = merchant_def(vid)
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
	var m: Dictionary = merchant_def(vid)
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
	if vid == "V09" and st.vars.has("UQ07_DISC") and int(st.vars.get_v("UQ07_DISC")) == 1 and not st.is_dead("N-R02-017"):
		rate *= 0.8                                                     # UQ-07 ①②: 작은 정비는 공하경 몫(SD-05 '소형 수리 −20%')
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
	if bool(merchant_def(vid).get("inst", false)) and not vid.contains("@"):
		vid = "%s@%s" % [vid, map.id]                                    # 일반 장사꾼(1-L §4.1): 가게마다 따로 재고 · 캡
	var want := str(shop_state(vid).get("want", ""))
	var own := _shop_voice(vid) if greet == "" else ""                  # 그 가게 목소리(재미 검수 ②): 원래 무엇이던 집인가
	if want != "" and greet == "":                                      # 요즘 찾는 것(§9.2)을 인사에 섞는다
		greet = "%s 요즘은 %s 같은 거 찾아." % [own if own != "" else str(merchant_def(vid).get("greet", "")), str(items_db.get(want, {}).get("name", want))]
	elif own != "":
		greet = own
	var sh := shop_state(vid)
	if sh.has("mine"):                                                  # UQ-125 장물(1-L §5): 내 물건은 반값 — '알고 산 물건 아니다'
		item_k = item_k.duplicate()
		for id in (sh["mine"] as Dictionary):
			item_k[id] = 0.5
		greet = "그거? 며칠 전에 들어온 물건이야. 알고 산 건 아니니까 반값에 줘."
	var m: Dictionary = merchant_def(vid)
	var ak := st._aff_key(str(m.get("settle", "")))
	var f := TradeScreen.tier_f(int(st.vars.get_v(ak)) if ak != "" else 0)
	if f.is_empty():
		say_text("상인이 고개를 젓는다. 거래하지 않겠다는 뜻이다.")
		done.call(0)
		return null
	k = [float(k[0]) * float(m.get("rate", 1.0)), k[1]]                # 상인 요율(손님 값 1.2배 등, SD-15 §3.1 K)
	var reg := Perks.regular_k(st, int(sh.get("reg", sh.get("total", 0))))   # 단골(PK-026, 1-12p): 그 상인과 누적 500캡마다 −5% · +5%, 세 번까지(되사고 되판 왕복은 셈하지 않는다)
	if int(reg[2]) > 0:
		k = [float(k[0]) * float(reg[0]), float(k[1]) * float(reg[1])]
		if not sh.has("mine") and want == "":
			greet = str(m.get("regular", "어, 단골 왔네.")) + " " + (greet if greet != "" else str(m.get("greet", "")))
	var t := TradeScreen.new().setup_trade(st, vid, m, sh, items_db, carry_max(), st.skill("BARTER"), f, k,
		greet if greet != "" else str(m.get("greet", "")))
	t.item_k = item_k
	if Perks.rank(st, "PK-026") > 0:                                     # 거래 창 머리: 단골 단계 · 다음까지(퍽이 일하는 게 보이게)
		var rv := int(sh.get("reg", sh.get("total", 0)))
		t.regular_line = "단골 %d/3" % int(reg[2]) + (" — 다음까지 %d캡" % (500 * (int(reg[2]) + 1) - rv) if int(reg[2]) < 3 else "")
	container = t
	t.closed.connect(func(_ok: bool) -> void:
		container = null
		sh["reg"] = int(sh.get("reg", sh.get("total", 0))) + t.regular_add
		sh["total"] = int(sh.get("total", 0)) + t.total
		if stash != null:
			stash.after_trade(vid)
		done.call(t.total))
	add_child(t)
	return t


var _tr_voice := {}


func _shop_voice(vid: String) -> String:
	if not vid.contains("@"):
		return ""
	if _tr_voice.is_empty() and FileAccess.file_exists("res://data/world/traders.json"):
		_tr_voice = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/traders.json"))
	return str(_tr_voice.get(vid.get_slice("@", 1), {}).get("greet", ""))


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
		st.kill(id + "@" + map.id if id.begins_with("N-VG-") else id)    # 일반 장사꾼(1-L)은 가게마다 한 사람 — 같은 결 다른 가게 사람은 살아 있다
		st.vars.set_v("S7_KILLS", int(st.vars.get_v("S7_KILLS")) + 1)
		if not bool(st.npcs.get(id, {}).get("evil", false)):
			st.call_fn("karma", [-25 if Crimes.animal(st, id) else -100])   # 악하지 않은 인물 살해(목격자가 없어도) · 마을 개는 −25(SQ-S01 '백구를 때림'과 같은 결, 리드 결정 2026-10-16)
		combat._pop(st.npc_name(id) + " 사망", a.loco.logical + Vector2(0, -20), Color("E04A35"))
		st.book.died(id, date_text)                                     # 눈앞의 죽음 = 아는 죽음
		_crime_kill(id, a.loco.logical)
	else:
		n["down_t"] = KO_SECS
		n["down_kind"] = "ko"
		combat._pop("기절", a.loco.logical + Vector2(0, -20), Color("E8C23A"))


## 범죄 반응(1-X, SD-06 §3.4 · §6.4 · Crimes): 다른 주민이 10칸 안에서 보았나(눈 · 시야). 정착지 안에서 목격된 살인은 자경단을 깨운다(SD-14 §9.12)
func _crime_kill(id: String, at: Vector2) -> void:
	var seen := false
	for n in npcs:
		if str(n["id"]) == id or n.get("dead", false) or not is_instance_valid(n["actor"]) or float(n.get("down_t", 0.0)) > 0.0:
			continue
		var p: Vector2 = n["actor"].loco.logical
		if p.distance_to(at) <= 320.0 and map.line_of_sight(p, at):
			seen = true
			break
	var tgt := Crimes.target(st, id)
	var w: Dictionary = combat.weapon() if combat.armed() else {}
	var rare := str(w.get("sound", "")) == "suppressed" or Arms.proj(w) in ["laser", "plasma", "tesla"]   # 주인공만 쓰는 무기 계열(§6.4 +20%)
	Crimes.on_kill(st, id, seen, map_region(map.tile_of(at)), Clock.abs_min(date_text), tgt.substr(3) if tgt.begins_with("JC_") else "", rare)
	if seen and tgt.begins_with("JC_"):
		settlement_alarm(tgt, "동물" if Crimes.animal(st, id) else "살인", st.npc_name(id))


var alarmed := {}                                    ## 이 맵에서 깨어난 정착지(대상 → true): 맵을 떠나면 잊는다 — 적대 단계면 들어올 때마다 다시 깬다


## 자경단이 총을 든다(SD-14 §9.12 · SD-06 §4.3.8 적대 '사격'): 그 정착지의 자경단원(Crimes.GUARDS)은 그 모습 그대로 적(CR-466)이 되고,
## 나머지 주민은 말을 섞지 않는다(talk). 아이는 공격 대상이 아니다. 같은 정착지 사람만.
func settlement_alarm(tgt: String, why := "", who := "") -> void:
	if alarmed.has(tgt):
		return
	alarmed[tgt] = true
	var guards: Array = Crimes.GUARDS.get(tgt, [])
	for n in npcs.duplicate():
		var id := str(n["id"])
		if not guards.has(id) or n.get("dead", false) or not is_instance_valid(n["actor"]) or Crimes.target(st, id) != tgt:
			continue
		var a: Actor = n["actor"]
		var e := combat.spawn("CR-466", a.loco.logical, map, st, {"lv": 5, "sheet": a.sheet, "who": id, "dir": "S"})
		e.loco.custom = {"run": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 3.2, "anim": "walk"}}   # 주민 시트엔 달리기 컷이 없다 — 걷기 컷 보폭으로(미끄러짐 없음)
		e.set_meta("militia", tgt)
		e.brain.gauge = 100.0
		e.brain.state = AIBrain.S.COMBAT
		map.remove_actor(a)
		map.blockers.erase(a)
		if ev.actors.get(id) == a:
			ev.actors.erase(id)
		a.queue_free()
		npcs.erase(n)
	sync_residents()
	var line: String = Crimes.ALARM.get(why, Crimes.ALARM[""])
	if line.contains("%s"):
		line = line % Crimes.obj(who)
	combat._pop(line, player.loco.logical + Vector2(0, -40), Color("E04A35"))


## 적대 · 경보 중인 정착지 주민은 말을 섞지 않는다(SD-06 §4.3.8 적대 인사 · 상점 불가)
func _hostile_bark(id: String) -> String:
	var tgt := Crimes.target(st, id)
	if tgt == "" or not (alarmed.has(tgt) or Crimes.hostile(st, tgt)):
		return ""
	if st.is_child(id):
		return "……(아이가 뒷걸음질 쳐 어른 뒤로 숨는다)"
	if not tgt.begins_with("JC"):
		return "꺼져. 너하고는 말 안 해."
	var lines: Array = HOSTILE_KILLER if Crimes.killer_known_by(st, tgt) else HOSTILE_OTHER   # 원인에 맞는 말(1-X 재미 검수 ③ — 살인이 아닌 적대에 '살인자'라 부르지 않는다)
	return str(lines[absi(hash(id)) % lines.size()])


const HOSTILE_KILLER := ["그 살인자다! 문 닫아!", "가까이 오지 마. 손 보이는 데 둬.", "…애들 들어가. 문 걸어.", "네가 한 짓, 마을이 다 안다."]
const HOSTILE_OTHER := ["너한테 팔 건 없어. 가.", "볼트 손님 대접은 끝났어.", "문 닫아. 저 사람 또 왔다.", "…말 걸지 마."]


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
	if combat.surrendered_near(player.loco.logical) != null:
		return "놓아준다"
	if not combat.mates.revive_target(player.loco.logical).is_empty():
		return "일으키기"
	if not _mate_front().is_empty() and not combat.mates.fight:
		return "말하기"
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	for n in npcs:
		if is_instance_valid(n["actor"]) and not n.get("dead", false) and _same_floor(n["actor"]):
			var v: Vector2 = n["actor"].loco.logical - player.loco.logical
			if v.length() < 46.0 and v.normalized().dot(f) > 0.5:
				return "말하기"
	var cells := _front_cells()
	if not _front_box(cells).is_empty():
		return "열기"
	if _up():
		return ""
	var wb := bench_front(cells)
	if not wb.is_empty() and str(wb.get("why", "")) == "":
		return "작업대" if bool(wb["bench"]) else "조리"
	var bd := bed_front(cells)
	if not bd.is_empty() and not bool(bd.get("script", false)):
		return "자기"
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
		var gd := _front_go(_before_text(_front_cells()))
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
	elif Loot.visibly_empty(st, map.id, b):
		tag = "  [털린 자리]"                                             # 1-L §9.1 보이는 빔
	elif box_contents(b)["items"].is_empty() and (int(box_contents(b).get("opened", 0)) > 0 or not Loot.is_v3(st, map.id, b)):
		tag = "  [빈 상자]"                                               # 파밍 v3 닫힌 용기는 열어 봐야 안다(닫힌 빔 — 열면 반쯤은 무언가 있다)
	if Loot.owned(b):
		tag += "  [소유]"
	return "(E) 열기  " + nm + tag


## 맵 인물 → 전투 주민 목록(한 곳): 아이는 공격 대상이 아니다(SD-11 §580 — StoryState.is_child). 진행기가 맵 인물을 떼어 낸 뒤에도 이것을 부른다
func sync_residents() -> void:
	combat.set_residents(npcs.filter(func(x): return not st.is_child(str(x["id"]))))


func talk(n: Dictionary) -> void:
	if map != null and player != null:                                  # 사람 눈에 띄었다(시체 조사 +20% — SD-06 §6.4, 1-12q)
		st.deeds.saw(map_region(map.tile_of(player.loco.logical)), Clock.abs_min(date_text))
	if n["routine"] != null:
		n["routine"].talk_to(player.loco.logical)
	else:
		n["actor"].loco.facing = Locomotion.snap8(player.loco.logical - n["actor"].loco.logical)
		n["actor"]._show()
	_talking = n
	var g := scene_for(n["id"])
	var hb := _hostile_bark(str(n["id"]))
	if hb != "":
		g = {"id": "bark_" + n["id"], "labels": {"START": 0}, "ops": [{"op": "line", "who": n["id"], "emo": "분노", "text": hb}, {"op": "end"}]}
		_barking = true
	if g.is_empty():
		var own := str(n["bark"])                                     # 소문(1-4f): 이 사람이 들은 주인공 이야기 — 없으면 제 혼잣말
		var rumor := "" if str(n["id"]).begins_with("CR-") else \
			Rumors.pick(st, map_region(map.tile_of(n["actor"].loco.logical)), str(n["id"]) + str(n.get("idx", 0)), own != "")   # 경비·병사(CR-)는 근무 중 — 주민 소문을 옮기지 않는다
		var gos: Array = st.deeds.gossip(Crimes.target(st, str(n["id"])), Clock.abs_min(date_text)) if not str(n["id"]).begins_with("CR-") and Crimes.target(st, str(n["id"])) != "" else []
		var bark: String = str(gos[0]) if not gos.is_empty() else (rumor if rumor != "" else (own if own != "" else "……"))   # 연동 소식 · 샌 입막음 · 세탁 소식은 출처를 붙여 한 번(1-12q)
		g = {"id": "bark_" + n["id"], "labels": {"START": 0}, "ops": [{"op": "line", "who": n["id"], "emo": str(gos[1]) if not gos.is_empty() else "기본", "text": bark}, {"op": "end"}]}
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
	var ap := combat.ap.ap / maxf(1.0, combat.ap.max_ap)               # 1-9a: 실제 AP(파워 공격이 쓴다)
	if combat.rad_rate > 0.0 and str(st.rad_drug.get("id", "")) != "I-093":     # 1-9d 피폭(노래하는 알약은 선량계를 끈다, SD-13 I-093): 가장자리 녹색 색조 + 오른쪽 위 선량계(터치는 방위 링 아래)
		_draw_geiger(vs, Vector2(584.0 + (vs.x - 640.0), 112.0 if touch_layout else 24.0))
	if touch_layout:
		_draw_hud_touch(vs, c, low, ap)
		return
	_bar(Vector2(70, 330 + b), 140.0, c.hp / maxf(1.0, c.max_hp), "HP", HUD_RED if low else HU[5])
	_lv_glow(vs, Vector2(70, 330 + b), 140.0, c)
	var pend := Perks.pending(st)
	if pend > 0:                                                             # 미배분 레벨업(§4.2 'HUD 구석 아이콘')
		_txt(Vector2(70, 314 + b), "▲ 레벨업%s" % ((" ×%d" % pend) if pend > 1 else ""), _pend_col())
	_bar(Vector2(430 + r, 330 + b), 140.0, ap, "AP", HU[5])
	_ap_ticks(Vector2(430 + r, 330 + b), 140.0)
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
	var ny := 8.0 if hints.is_empty() else 16.0 + _hint_h()
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
	_draw_mates(Vector2(8, 258 + b))
	_draw_radio(vs, false)


# ---------------------------------------------------------------- 라디오(1-10b, SD-12 §10 · SD-17 §4)
const RADIO_WHO := {"송미래": 0, "남궁혁": 1, "공보방송": 2, "구내방송": 3}
const UNDER_MAPS := ["D-", "J-", "Y-", "CG-", "K-08"]           ## 지하 실내(지하철역 · 지하상가 · 벙커 · 배수로): 신호 한 단계 나빠짐


## 라디오 수신 조건(Radio.quality가 읽는다)
func radio_ctx() -> Dictionary:
	var mid := map.id if map != null else ""
	var ctx := {"act": st.quests.cur_act(), "vault": mid.begins_with("V-"), "pip": pipboy_ok, "under": false, "clean01": false,
		"public": st.vars.has("RADIO_PUBLIC") and int(st.vars.get_v("RADIO_PUBLIC")) >= 1,
		"now": Clock.abs_min(date_text), "date": date_text}
	if map is WorldMap and player != null:
		var t: Vector2i = map.tile_of(player.loco.logical)
		var rc: String = map.region_at(t)
		ctx["clean01"] = rc in ["R06", "HR"] or (rc == "R02" and map.region_at(t + Vector2i(0, -24)) == "HR")   # 용산 · 한강(노들섬) · R02 북쪽 강변
	elif map != null:
		for pf in UNDER_MAPS:
			if mid.begins_with(pf):
				ctx["under"] = true
	return ctx


func _radio_tick(dt: float) -> void:
	_rctx = radio_ctx()
	_rctx["hold"] = box.active or ev.busy() or busy or pipboy != null
	var r := st.radio
	var fresh := r.tick(dt, st, _rctx)
	if not fresh.is_empty() and hud_on:
		var nm := Radio.station_name(str(fresh[0]))
		if touch_layout:
			hint("라디오에 %s%s 잡힌다 — 화면 위 [라디오]를 누르면 켜고 끈다" % [nm, Josa.pick("이", nm)], 6.0)
		else:
			hint("라디오에 %s%s 잡힌다 — R을 길게 누르면 켜고 끈다(핍-보이 데이터 > 라디오)" % [nm, Josa.pick("이", nm)], 6.0)
	if use_keyboard and not box.active and pipboy == null and Input.is_action_pressed("reload"):
		if Input.is_action_just_pressed("reload"):
			_r_hold = 0.0
			combat.r_long = false
		_r_hold += dt
		if _r_hold >= 0.6 and not combat.r_long:
			combat.r_long = true
			radio_toggle()


## 켜기 · 끄기(R 길게 · 터치 표시 탭) — 알림 한 줄
func radio_toggle() -> void:
	var r := st.radio
	if r.toggle(_rctx if not _rctx.is_empty() else radio_ctx()):
		_note("라디오 켬: " + Radio.station_name(r.tuned))
	elif Radio.receivable(_rctx if not _rctx.is_empty() else radio_ctx()).is_empty():
		_note("잡히는 방송이 없다")
	else:
		_note("라디오 끔")


## 화면에 라디오가 보이나(터치 표시 단추가 쓴다): 켜져 있거나 잡히는 방송국이 있다
func radio_shown() -> bool:
	return st.radio.on or not Radio.receivable(_rctx if not _rctx.is_empty() else radio_ctx()).is_empty()


## HUD 라디오 표시(SD-12 §4.2: PC (520, 60) · 터치 (476, 112) 92×16) + 자막 띠(PC (120, 286) 400×2행 · 터치 (160, 8) 320×2행).
## 자막 `[방송국] 화자: 문장` · 왼쪽 24×24 화자 얼굴 · 배경 60%. 화자 얼굴 · 띠는 12px 글(한 줄 33자, SD-12 §14.5). 교전 중에는 1행(SD-12 §10.1). 신호가 약하면 끊김 · ▒(SD-17 §7.6)
func _draw_radio(vs: Vector2, touch: bool) -> void:
	var r := st.radio
	var rr := vs.x - 640.0
	var ip := Vector2(476 + rr, 112) if touch else Vector2(520 + rr, 60)
	if not r.on:
		if touch and radio_shown():
			_txt(ip, "[라디오] 끔", HU[3])
		return
	var q := Radio.quality(r.tuned, _rctx)
	var tag: String = ["", " ·잡음", " ·약함"][clampi(q, 0, 2)]
	var np := r.now_playing()
	var lit: bool = np.get("kind", "") in ["line", "gap"] or fmod(_hud_t, 0.8) < 0.6     # 징글 · 휴지 중에는 표시만 깜빡
	_txt(ip, "[라디오] %s%s" % [Radio.station_short(r.tuned), tag], HU[6] if lit else HU[4])
	if str(np.get("kind", "")) != "line" or Radio.dropout(q, _hud_t):
		return
	var body := Radio.garble(str(np["text"]), q)
	if str(np.get("sting", "")) != "":
		body += " [%s]" % str(np["sting"])
	var line := "[%s] %s: %s" % [Radio.station_short(r.tuned), str(np["who"]), body]
	var w := 300.0 if touch else 400.0                                    # 터치: HP · AP 막대(8~168)와 얼굴이 겹치지 않게 (196, 8) 300폭(정합)
	var band := Rect2(196 + rr / 2.0, 8, w, 34) if touch else Rect2(120 + rr / 2.0, 284 + vs.y - 360.0, w, 30)
	var rows: Array = TextWrap.wrap(line, func(t: String) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, w - 10.0)
	if combat.in_combat() and rows.size() > 1:
		rows = [_clip(line, w - 10.0)]                                    # 교전 중: 1행
		band.size.y = 17.0
	band.size.y = minf(band.size.y, 4.0 + 13.0 * rows.size() + (4.0 if touch else 0.0))
	banner.draw_rect(band, Color(0, 0, 0, 0.6))
	banner.draw_rect(Rect2(band.position + Vector2(0.5, 0.5), band.size - Vector2.ONE), Color(HU[3], 0.6), false, 1.0)
	for i in mini(2, rows.size()):
		banner.draw_string(font, Vector2(band.position.x + 5, band.position.y + 2 + i * (16.0 if touch else 13.0) + font.get_ascent(12)),
			str(rows[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("E9E4D8"))
	if radio_icons == null and ResourceLoader.exists("res://assets/ui/radio_icons.png"):
		radio_icons = load("res://assets/ui/radio_icons.png")
	var who := int(RADIO_WHO.get(str(np["who"]), -1))
	if radio_icons != null and who >= 0:                                    # 화자 얼굴 24×24(SD-12 §10.1) — 띠 왼쪽 바깥
		var fp := band.position + Vector2(-27, roundf((band.size.y - 24.0) / 2.0))
		banner.draw_rect(Rect2(fp - Vector2(1, 1), Vector2(26, 26)), HU[0])
		banner.draw_texture_rect_region(radio_icons, Rect2(fp, Vector2(24, 24)), Rect2(who * 24, 0, 24, 24))


## 선량계(SD-11 §11.2 · §12.5 · SD-12 §5.6): 피폭 중에만. 반원 눈금(로그) · 바늘 · 초당 라드 · 단계가 오르면 1초 흔들림.
## 화면 가장자리 녹색 색조는 가이거 단계(1~5)만큼 진하게. 소리 SE-ENV-GEI-1~5는 SD-17 소리 단계에서(지금은 이름만 넘긴다).
func _draw_geiger(vs: Vector2, at: Vector2) -> void:
	var rate := combat.rad_rate
	var lv := Radiation.geiger_level(rate)
	var tint := Color("7CD62B")
	var a := 0.06 + 0.05 * lv + 0.04 * sin(_hud_t * (6.0 + lv * 3.0))
	for k in 3:                                                               # 바깥에서 안으로 옅어지는 테
		var w := 3.0 + k * 3.0
		var col := Color(tint, a * (1.0 - k * 0.3))
		for rr in [Rect2(0, 0, vs.x, w), Rect2(0, vs.y - w, vs.x, w), Rect2(0, 0, w, vs.y), Rect2(vs.x - w, 0, w, vs.y)]:
			banner.draw_rect(rr, col)
	var box_r := Rect2(at, Vector2(48, 32))                                   # SD-12 §4.2: (584, 24) 48×32
	banner.draw_rect(box_r.grow(1.0), HU[0])
	banner.draw_rect(box_r, Color(HU[1], 0.92))
	banner.draw_rect(box_r, HU[3], false, 1.0)
	var c := at + Vector2(24, 28)
	var hot := lv >= 4 and fmod(_hud_t, 0.4) < 0.2
	banner.draw_arc(c, 17.0, PI * 1.1, PI * 1.9, 18, HU[3], 2.0)
	banner.draw_arc(c, 17.0, PI * 1.62, PI * 1.9, 8, Color(HUD_RED, 0.8), 2.0)   # 붉은 구역(25라드/초 이상)
	for i in 6:                                                               # 눈금 0 · 1 · 3 · 8 · 25 · 80(로그)
		var an := PI * (1.1 + 0.8 * float(i) / 5.0)
		banner.draw_line(c + Vector2.from_angle(an) * 14.0, c + Vector2.from_angle(an) * 19.0, HU[5], 1.0)
	var f := clampf(log(1.0 + rate) / log(81.0), 0.0, 1.0)
	var jit := sin(_hud_t * 47.0) * 0.06 * combat.rad_shake + sin(_hud_t * 23.0) * 0.012 * lv   # 바늘 떨림
	var na := PI * (1.1 + 0.8 * clampf(f + jit, 0.0, 1.0))
	banner.draw_line(c, c + Vector2.from_angle(na) * 16.0, HUD_RED if hot else HU[7], 1.5)
	banner.draw_circle(c, 2.0, HU[6])
	_txt(at + Vector2(2, -2), "RAD", HU[4])
	_txt(at + Vector2(24, 33), "+%s 라드/초" % (("%.1f" % rate) if rate < 10.0 else str(roundi(rate))), HUD_RED if hot else HU[7], HORIZONTAL_ALIGNMENT_CENTER)


## 터치 배치(§17.2, 640×360 기준 — 오른쪽 묶음은 오른쪽 끝에 붙는다): HP·AP 막대 왼쪽 위, 알림 (8,48), 탐지 (280,48),
## 방위 링 (576,52) 56×56, 목표 줄 (8,116), 동행 (8,152), 상호작용 문구 (176,250). 탄약·무기 이름은 터치 단추 위에 있다
func _draw_hud_touch(vs: Vector2, c: Combatant, low: bool, ap: float) -> void:
	var r := vs.x - 640.0
	_txt(Vector2(8, 4), "HP", HU[5])
	_bar(Vector2(28, 8), 140.0, c.hp / maxf(1.0, c.max_hp), "", HUD_RED if low else HU[5])
	_txt(Vector2(8, 16), "AP", HU[5])
	_bar(Vector2(28, 20), 140.0, ap, "", HU[5])
	_ap_ticks(Vector2(28, 20), 140.0)
	_lv_glow(vs, Vector2(28, 8), 140.0, c)
	var pend := Perks.pending(st)
	if pend > 0:                                                             # 미배분 레벨업 — 누르면 핍-보이 능력치 > 퍽(TouchHud)
		_txt(Vector2(176, 10), "▲ 레벨업%s" % ((" ×%d" % pend) if pend > 1 else ""), _pend_col())
	var det := combat.detect_state()
	if det != "" and not (det == "위험" and fmod(_hud_t, 0.3) < 0.15):
		_txt(Vector2(320 + r / 2.0, 48), "[%s]" % det, HU[5] if det == "숨음" else HUD_RED, HORIZONTAL_ALIGNMENT_CENTER)
	_ring(Vector2(604 + r, 80))
	_quest_pointer(vs)
	var ny := 48.0 + (8.0 + _hint_h() if not hints.is_empty() else 0.0)
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
	_draw_mates(Vector2(8, 152))
	_draw_radio(vs, true)


## 레벨업 금빛: 화면 가장자리 0.25초 번짐 · HP 바 끝의 늘어난 몫(+10)이 0.8초 깜빡(보상이 눈에 보이게 — 구현 뒤 재미 검수 ③)
func _lv_glow(vs: Vector2, at: Vector2, w: float, c: Combatant) -> void:
	if _lv_t < 0.0:
		return
	_lv_t += get_process_delta_time()
	var gold := Color("E8C23A")
	if _lv_t < 0.25:
		var a := 0.55 * (1.0 - _lv_t / 0.25)
		for rr in [Rect2(0, 0, vs.x, 3), Rect2(0, vs.y - 3, vs.x, 3), Rect2(0, 0, 3, vs.y), Rect2(vs.x - 3, 0, 3, vs.y)]:
			banner.draw_rect(rr, Color(gold, a))
	if _lv_t < 0.8 and fmod(_lv_t, 0.2) < 0.13:
		var mx := maxf(1.0, c.max_hp)
		var seg := maxf(2.0, roundf(w * 10.0 / mx))
		banner.draw_rect(Rect2(at.x + w - seg, at.y, seg, 4), gold)
	if _lv_t > 0.8:
		_lv_t = -1.0


func _pend_col() -> Color:
	_pend_t += get_process_delta_time()
	return Color("E8C23A") if _pend_t > 10.0 or fmod(_hud_t, 1.6) < 1.2 else HU[5]


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


## 동행·지원 상태(SD-12 §4.2 · §11.4): 동행마다 한 줄 — `[동행] 이름` + HP 막대 + 상태(따라옴 · 기다림 · 쓰러짐). 최대 3행
func _draw_mates(p: Vector2) -> void:
	var y := 0.0
	for m in combat.mates.list:
		var cmb: Combatant = m["cmb"]
		var st_txt := "쓰러짐" if m["down"] else ("기다림" if m["mode"] in ["wait", "guard"] else "")
		_txt(p + Vector2(0, y), "[동행] %s" % str(m["name"]), HUD_RED if m["down"] else HU[5])
		_bar(p + Vector2(0, y + 14), 52.0, cmb.hp / maxf(1.0, cmb.max_hp), "", HUD_RED if m["down"] else HU[5])
		if st_txt != "":
			_txt(p + Vector2(56, y + 10), st_txt, HU[6] if not m["down"] else HUD_RED)   # 막대 오른쪽(이름 줄 아래)
		y += 24.0


func _bar(p: Vector2, w: float, f: float, label: String, col: Color) -> void:
	if label != "":
		_txt(p - Vector2(0, 11), label, HU[5])
	banner.draw_rect(Rect2(p - Vector2(1, 1), Vector2(w + 2, 8)), HU[0])
	banner.draw_rect(Rect2(p, Vector2(w, 6)), HU[2])
	banner.draw_rect(Rect2(p, Vector2(roundf(w * clampf(f, 0.0, 1.0)), 6)), col)


## AP 막대 눈금(SD-12 §17.2 '집중 사격 비용 눈금', 1-9e3): 든 원거리 무기의 집중 사격 비용마다 세로 눈금 · AP 0이면 '숨참'
func _ap_ticks(p: Vector2, w: float) -> void:
	var mx := maxf(1.0, combat.ap.max_ap)
	if combat.armed() and combat.weapon()["kind"] == "ranged":
		var cost := InteriorCombat.focus_cost(combat.weapon())
		var k := cost
		while k < mx - 0.5:
			banner.draw_rect(Rect2(p + Vector2(roundf(w * k / mx), 0), Vector2(1, 6)), HU[0])
			k += cost
	if combat.ap.winded() or (combat._sprint_latch and combat.ap.ap < 10.0):
		_txt(p + Vector2(w + 4, -3), "숨참", HUD_RED)


func _txt(p: Vector2, t: String, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var w := font_s.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x := p.x - (w if align == HORIZONTAL_ALIGNMENT_RIGHT else (roundf(w / 2.0) if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		banner.draw_string(font_s, Vector2(x, p.y + font_s.get_ascent(10)) + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HU[0])
	banner.draw_string(font_s, Vector2(x, p.y + font_s.get_ascent(10)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


static var lm_icons: Texture2D                                           ## 원경 표식 실루엣 8×8 × 21(Landmarks.ROWS 차례)


## 방위 링(SD-12 §4.3): 지름 56, 위 '북', 가운데 = 주인공, 적 = 붉은 마름모(반경 10 + 인지력×2 타일), 동행 = 푸른 원
func _ring(c: Vector2) -> void:
	banner.draw_arc(c, 27.0, 0, TAU, 32, HU[0], 3.0)
	var red: bool = enc_live != null and enc_live.flash_t > 0.0 and fmod(enc_live.flash_t, 0.4) < 0.2   # 추격자 예고: 테두리 붉게 점멸(SD-12 §9.7)
	banner.draw_arc(c, 27.0, 0, TAU, 32, HUD_RED if red else HU[3], 2.0 if red else 1.0)
	banner.draw_arc(c, 24.0, 0, TAU, 32, HU[2], 1.0)
	_txt(c + Vector2(0, -41), "북", HU[5], HORIZONTAL_ALIGNMENT_CENTER)
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
	for m in combat.mates.list:                                         # 일시 동행: 푸른 원 + 테두리(SD-12 §4.3 · §11.4)
		if not is_instance_valid(m["actor"]):
			continue
		var d: Vector2 = (m["actor"] as Actor).loco.logical - player.loco.logical
		if d.length() <= rad:
			var q := (c + d / rad * 22.0).round()
			banner.draw_circle(q, 3.0, HU[0])
			banner.draw_circle(q, 2.0, Color("4C7DC8") if not m["down"] else Color("8E9BA8"))
			banner.draw_arc(q, 3.0, 0, TAU, 10, HU[6], 1.0)
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
		if lm_icons == null:
			lm_icons = load("res://assets/ui/landmark_icons.png")
		for lm in Landmarks.visible(st, me, Clock.is_night(date_text)):   # 원경 표식(SD-08 §12.1 ① · SD-12 §4.3): 링 테두리 밖 8×8 회색 실루엣, 방향만
			var q: Vector2 = (c + (lm["dir"] as Vector2) * 32.0).round()
			banner.draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), HU[0])
			banner.draw_texture_rect_region(lm_icons, Rect2(q - Vector2(4, 4), Vector2(8, 8)), Rect2(int(lm["i"]) * 8, 0, 8, 8), HU[4])
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
	ev.handlers["info"] = func(a: Array, done: Callable) -> void:      # 정보상 메뉴(1-8d): info 상인ID [권역]
		box.finished.connect(func() -> void: info_menu.call_deferred(str(a[0]), str(a[1]) if a.size() > 1 else ""), CONNECT_ONE_SHOT)
		done.call()
	ev.handlers["infodo"] = func(a: Array, done: Callable) -> void:    # 장소 소문 하나(값은 선택지 [캡] 태그가 이미 받았다)
		var lid := str(a[1])
		var rg := str(PlaceLog.db.get(lid, {}).get("region", ""))
		st.places.raise(lid, PlaceLog.MARKED)
		st.vars.set_v("INFO_RUMOR_" + rg, int(st.vars.get_v("INFO_RUMOR_" + rg)) + 1)
		hint("지도에 표시: %s" % str(PlaceLog.db.get(lid, {}).get("name", lid)), 4.0)
		done.call()
	ev.handlers["info_turf"] = func(_a: Array, done: Callable) -> void:   # 판도 소식(1-12q): R01 · R02 구역을 지금 판으로 '들음'
		for z in Turf.zones():
			st.turf.hear(st, z)
		st.vars.set_v("INFO_TURF_DAY", int(st.vars.get_v("GAME_DAY")))
		done.call()
	ev.handlers["info_hush"] = func(a: Array, done: Callable) -> void:   # 입막음(목격자 매수 — 값은 선택지 [캡] 태그가 받았다)
		for d in st.deeds.list:
			if str(d["id"]) == str(a[1]):
				st.deeds.hush(d, Clock.abs_min(date_text))
		done.call()
	ev.handlers["info_launder"] = func(a: Array, done: Callable) -> void:   # 정보 세탁: 카르마 −10 · 15% 발각(지하시장 −10 · 누명 쓴 쪽 −10)
		for d in st.deeds.list:
			if str(d["id"]) == str(a[1]):
				st.deeds.launder(d, str(a[2]), Clock.abs_min(date_text))   # 발각 여부는 하루 뒤 구문철 입으로(재미 검수 ③ — 그 자리에서 알려 주지 않는다)
				st.call_fn("karma", [-10])
		done.call()
	ev.handlers["rent"] = func(a: Array, done: Callable) -> void:      # 숙박(1-8f, SD-15 §5.5): rent 변수 시간 — 값은 선택지 [캡] 태그가 받았다. 지금부터 N시간 '소유 침대'
		st.vars.set_v(str(a[0]), Clock.abs_min(date_text) + int(a[1]) * 60)
		done.call()
	ev.handlers["doctor"] = func(a: Array, done: Callable) -> void:    # 의사 메뉴(1-8d): doctor 상인ID
		box.finished.connect(func() -> void: doctor_menu.call_deferred(str(a[0])), CONNECT_ONE_SHOT)
		done.call()
	ev.handlers["docdo"] = func(a: Array, done: Callable) -> void:     # 치료 하나(값은 선택지 [캡] 태그가 이미 받았다): 암전 2초 → 효과
		busy = true
		ev.run("fade_out", ["black", "4"], func() -> void:
			if str(a[1]) == "heal":
				combat.pc.hp = combat.pc.max_hp
			elif str(a[1]) == "rad":
				Radiation.remove(st, Radiation.rads(st))
			advance_minutes(30)
			ev.run("fade_in", ["black", "4"], func() -> void:
				busy = false
				done.call()))
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
	ev.handlers["mate"] = func(a: Array, done: Callable) -> void:      # 동행 말 걸기: [인물, follow | wait](1-10a)
		combat.mates.set_mode(str(a[0]), str(a[1]))
		done.call()
	ev.handlers["mate_scene"] = func(a: Array, done: Callable) -> void:   # 동행 메뉴에서 '할 말이 있어': 이 창이 닫힌 뒤 그 인물의 퀘스트 장면
		var sid := str(a[0])
		box.finished.connect(func() -> void:
			var g := scene_for(sid)
			if not g.is_empty():
				talked.emit(sid, str(g.get("id", "")))
				box.open.call_deferred(st, g), CONNECT_ONE_SHOT)
		done.call()
	ev.handlers["chain"] = func(a: Array, done: Callable) -> void:      # 퀘스트 앞 장면 뒤 평소 이야기로(1-11l): chain 인물ID 건너뛸_접두 — 이 창이 닫힌 뒤 접두가 다른 첫 장면
		var sid := str(a[0])
		var skip := str(a[1]) if a.size() > 1 else ""
		box.finished.connect(func() -> void:
			for g in scenes_by_npc.get(sid, []):
				if skip != "" and str(g.get("id", "")).begins_with(skip):
					continue
				var cond: String = g.get("cond", "")
				if cond == "" or StoryExpr.test(cond, st):
					talked.emit(sid, str(g.get("id", "")))
					box.open.call_deferred(st, g)
					return, CONNECT_ONE_SHOT)
		done.call()
	ev.handlers["buddy"] = func(a: Array, done: Callable) -> void:     # 일시 동행 시작(인물 ID) · 끝(off)
		var id := str(a[0])
		if id == "off":
			combat.buddy = null
			combat.mates.away.clear()
			buddy_name = ""
			buddy_id = ""
		elif ev.actors.has(id):
			var b: Actor = ev.actors[id]
			map.blockers.erase(b)                                              # 동행은 길을 막지 않는다
			for n in npcs:
				if n["actor"] == b:
					n["routine"] = null
			combat.mates.add(id, b, _mate_name(id))
			_sync_mates()
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
			"items_chems", "items_misc_other", "items_apparel_head", "items_misc_crit", "items_junk", "items_ammo", "items_tokens", "items_craft", "items_side", "items_unique", "items_trade"]:          # 파이프라인이 SD-13 표에서 뽑은 아이템(1-4: 표 전체)
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
	st.fbook.refresh(st, date_text)                                       # 세력 탭(1-12m)이 읽기 전에 등록 · 단계 · 닿은 소식을 옮긴다
	var d := InteriorCombat.derived(st)
	var xp := int(st.vars.get_v("PC_XP"))
	var lv := level()
	var carry := 0.0
	for id in st.items:
		carry += float(items_db.get(id, {}).get("weight", 0)) * int(st.items[id])
	return {"level": lv, "hp": int(ceilf(combat.pc.hp)), "hp_max": int(combat.pc.max_hp), "ap": int(combat.ap.ap), "ap_max": int(d["ap_max"]),
		"xp": xp, "xp_next": lv * (50 + 75 * (lv + 1)), "date": date_text, "equipped": combat.weapon_id if not combat.holstered else "",
		"stimpak_id": InteriorCombat.STIMPAK, "carry": carry, "carry_max": carry_max(), "caps": int(st.vars.get_v("PC_CAPS")),
		"place": _place_name(), "hotkeys": combat.hotkeys,
		"karma": int(st.vars.get_v("V_KARMA")) if st.vars.has("V_KARMA") else 0,
		"worn": worn(), "head": str(st.vars.get_v("PC_HEAD")), "eyes": str(st.vars.get_v("PC_EYES")), "rads": int(st.vars.get_v("PC_RADS")), "rad_rate": snappedf(combat.rad_rate, 0.01), "rad_res": Radiation.resist(st, items_db),
		"rad_drug": st.rad_drug.duplicate(),
		"dr": int(items_db.get(worn(), {}).get("dr", 0)) if st.items.has(worn()) else 0,
		"tile": Vector2(map.tile_of(player.loco.logical)) if map is WorldMap and player != null else Vector2(-99, -99),
		"map_id": map.id if map != null else "",
		"world": map if map is WorldMap else null, "travel": travel_check, "radio": radio_ctx(), "hint": hint}


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
	var me := map.tile_of(player.loco.logical)
	var ok_now: bool = st.quests.stage("MQ-P4") >= 100 and e.get("arrive") != null and not busy and not box.active and not story_hold
	if ok_now and PipMap.trade_link_open(st) and lid in PipMap.TRADE_LINK:   # 사당 ↔ 서울대입구 지하 교역로(1-12k D-048, SD-04a SQ-S05 L729): 한쪽 끝 24타일 안에서 반대쪽 끝으로 30분.
		var other: String = PipMap.TRADE_LINK[1 - PipMap.TRADE_LINK.find(lid)]   #   지하길이라 '낮 지상 계약 동행'(travel_blocks)은 묻지 않는다(재미 검수 (b))
		var oa: Array = PlaceLog.db[other]["arrive"]
		if Vector2(int(oa[0]) - me.x, int(oa[1]) - me.y).length() <= PipMap.TRADE_NEAR:
			return [true, "", 0.5]
	if travel_block.is_valid():                                        # 진행기가 막는 이동(1-11f — 전투복 차림 탈영병과 큰길은 못 간다)
		var tb := str(travel_block.call(lid))
		if tb != "":
			return [false, tb, 0]
	for f in travel_blocks:                                            # 1-12e: 낮 지상 계약 동행(박춘삼)과 큰길 빠른 이동은 못 간다
		var tb2 := str((f as Callable).call(lid))
		if tb2 != "":
			return [false, tb2, 0]
	if story_hold:                                                     # 이야기 사건 중(MQ-106 무전·대치 등): 사건 무대를 빠른 이동으로 떠나지 않는다(SD-20 P4)
		return [false, TRAVEL_MSG["F8"], 0]
	if st.quests.stage("MQ-P4") < 100 or e.get("arrive") == null or busy or box.active or str(e.get("region", "")) == "R05":
		return [false, TRAVEL_MSG["F6"], 0]
	var here := PlaceLog.bank_at(me)
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
	return [carry, carry_max()]


## 소지 한도(SD-10 §2.3): 150 + 힘 × 10 + 스트롱 백 50 · 배달 기사 25(1-12p)
func carry_max() -> float:
	return 150.0 + 10.0 * st.stat("ST") + Perks.carry_bonus(st)


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
		_arrive(lid, float(why[2]))
		ev.run("fade_in", ["black", "3"], func() -> void:
			busy = false
			traveled.emit(lid)))


## 빠른 이동 도착(화면이 가려진 사이): 도착 칸에 세우고 둘레 청크를 붙이고 시각을 넘긴다
func _arrive(lid: String, hours: float) -> void:
	var e: Dictionary = PlaceLog.db[lid]
	var at := Vector2(int(e["arrive"][0]) * 32 + 16, int(e["arrive"][1]) * 32 + 16)
	map.load_now(at)
	player.loco.place(at)
	player.position = player.loco.render
	player.set_floor(0)
	player._show()
	map.update_focus(at)
	map.id = map.zone_of(map.tile_of(at))
	_last_tile = map.tile_of(at)
	st.places.mark_seen(_last_tile)
	_turf_see(_last_tile)
	cam.position = at.round()
	cam.reset_smoothing()
	for m in combat.mates.list:                                         # 따라오던 동행은 함께 도착한다(뒤 한 칸)
		if str(m["mode"]) in ["follow", "escort"] and is_instance_valid(m["actor"]):
			(m["actor"] as Actor).loco.place(at + Vector2(-32, 0))
			(m["actor"] as Actor).position = (m["actor"] as Actor).loco.render
	var mins := roundi(hours * 60 * travel_mul)
	advance_minutes(mins)
	if hours < 1.0 and lid in PipMap.TRADE_LINK:                       # 지하 교역로(1-12k): 반로아가 가르쳐 준 대로 걸었다
		_note("레일 가운데로 걸었다. 낙성대에선 입을 다물었다 — %s 도착, %s" % [str(e["name"]), PipMap.hours_text(mins / 60.0)])
	else:
		_note("%s 도착 — %s이 지났다" % [str(e["name"]), PipMap.hours_text(mins / 60.0)])
	enc_live.on_arrive.call_deferred()                                # 도착 지점 = 추적대 첫 출현 후보(SD-05 §6.2)


# ---------------------------------------------------------------- 시각 흐름(1-3)
## 시간이 흐르나: 1막 MQ-101이 끝난 아침부터(그 전은 진행기가 시각을 정한다), 자유 행동 중에만(대화·핍-보이·연출은 멈춤 — SD-12 §16)
func clock_running() -> bool:
	return st.quests.cur_act() >= 1 and st.quests.stage("MQ-101") >= 50 and int(st.vars.get_v("MQ101_NIGHT")) >= 3 and not busy


var _absorb := 0.0                                                    ## 라드 앱소프션(PK-100) 쌓인 게임 분(10분 = 실시간 20초마다 라드 1)


func _clock_step(dt: float) -> void:
	if not clock_running():
		if Perks.rad_absorb(st):                                          # 시계가 멈춘 때(프롤로그 · 1막 첫날)도 실시간으로 턴다
			_absorb_tick(dt * TIME_SCALE / 60.0)
		return
	_clock_acc += dt * TIME_SCALE / 60.0
	if _clock_acc >= 1.0:
		var m := int(_clock_acc)
		_clock_acc -= m
		advance_minutes(m)
		_rest_check()


## 게임 시간을 m분 보낸다. 06:00을 넘을 때마다 하루 판정(day_tick) — 사흘 구금·긴 잠처럼 여러 날을 한 번에 보내도
## 넘어간 06:00마다 한 번씩, 그 날짜(GAME_DAY)로 차례대로 부른다(SD-20 P6 시간 도약)
func advance_minutes(m: int) -> void:
	if Perks.rad_absorb(st):
		_absorb_tick(float(m))                                            # 걷는 시간 · 기다리기 · 잠 · 빠른 이동 모두(1-12p)
	if int(st.vars.get_v("PC_SMELL")) > 0:                               # 여왕 페로몬 위장(1-D5b)도 기다린 만큼 날아간다
		st.vars.set_v("PC_SMELL", maxi(0, int(st.vars.get_v("PC_SMELL")) - m))
	if m >= 60:
		Radiation.drug_tick(st, m * 2.0)                                     # 한꺼번에 보내는 시간(대기 · 수면 · 생포): 게임 1분 = 실시간 2초
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
		st.deeds.tick(st, a)                                              # 정보 전파(1-10c): 그사이 도착한 소식을 시각 순서대로
		if step == to6:
			_daily()


## 하루 판정(06:00): 수배도 하한 다시 걸기 · 생포 사흘 넘김(SD-03a §6.7 — 계엄군 인계는 청계산 맵과 함께, 정합)
func _daily() -> void:
	Wanted.refresh(st)
	for n in st.turf.day(st, int(st.vars.get_v("GAME_DAY"))):           # 판도 하루(1-12m): 감쇠 · 틱 · 가맹 — 세력 기록 한 줄
		st.fbook.add_line(str(n[0]), FactionBook._md(date_text), str(n[1]))
	st.fbook.refresh(st, date_text)
	day_tick.emit(int(st.vars.get_v("GAME_DAY")))
	st.turf.sync(st)                                                      # 하루 판정이 판도 원천을 바꿨으면(가산 상자 등) 상태 변수를 바로(1-12n — 맵 조건이 읽는다)
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
	return Perks.level(st)                                              # 상한 35(§4.1) — 식은 Perks 한 곳


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
	var it: Dictionary = items_db.get(Gear.base(id), {})
	if st.items.has(id) and str(it.get("slot", "")).begins_with("머리"):   # 머리 장비(1-D6 — A-074 민방위 방독면 HD19): 한 번 더 고르면 벗는다
		var hon := str(st.vars.get_v("PC_HEAD")) != id
		st.vars.set_v("PC_HEAD", id if hon else "")
		if player != null and player.doll != null:
			player.doll.set_look({"gear": str(it.get("layer", "")) if hon else ""})
		_note("%s %s" % [str(it.get("name", id)), "씀" if hon else "벗음"])
		return
	if st.items.has(id) and str(it.get("slot", "")).begins_with("눈"):     # 눈 장비(1-11e — A-106 구울 가면): 한 번 더 고르면 벗는다
		var on := str(st.vars.get_v("PC_EYES")) != id
		st.vars.set_v("PC_EYES", id if on else "")
		if player != null and player.doll != null:
			player.doll.set_look({"eyes": str(it.get("layer", "")) if on else ""})
		_note("%s %s" % [str(it.get("name", id)), "씀" if on else "벗음"])
		return
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
	var perk := Perks.dr_bonus(st)                                      # 터프니스(PK-025) DR +10(1-12p)
	var head := str(st.vars.get_v("PC_HEAD"))                          # 머리 장비 DR도 더한다(SD-13 §5.2 'DR 합산' — 1-13a3 깡철이의 헬멧이 빈 보상이던 것)
	var hd := float(items_db.get(Gear.base(head), {}).get("dr", 0)) if head != "" and int(st.items.get(head, 0)) > 0 else 0.0
	if int(st.items.get(id, 0)) <= 0:
		return minf(85.0, hd + perk)
	return minf(85.0, float(items_db.get(id, {}).get("dr", 0)) + hd + perk)


## 먹고 마시기(SD-13 §7.2): 음식·음료 HP는 5초에 걸쳐, 라드는 즉시. 라드어웨이 −50 × (1 + 의학/50)
func consume(id: String) -> bool:
	var it: Dictionary = items_db.get(id, {})
	if int(st.items.get(id, 0)) <= 0:
		return false
	if id == "I-002":
		st.call_fn("take", [id, 1])
		var cut := roundi(50.0 * (1.0 + float(st.skill("MEDICINE")) / 50.0))
		Radiation.remove(st, cut)
		_note("라드어웨이 — 방사능 −%d" % cut)
		return true
	if Radiation.DRUGS.has(id):                                          # 라드-X · 갑상선 방호정 · 노래하는 알약(1-9d, SD-13 §7): 저항 + 시간 누적
		st.call_fn("take", [id, 1])
		var pct := Radiation.take_drug(st, id)
		_note("%s — 방사능 저항 +%d%% (%d분 %02d초)" % [str(it.get("name", id)), roundi(pct), int(float(st.rad_drug["t"])) / 60, int(float(st.rad_drug["t"])) % 60])
		return true
	if not it.has("heal") and not it.has("rads"):
		return false
	st.call_fn("take", [id, 1])
	var eat := Perks.eat_mult(st, id)                                   # 손맛(PK-009) 음식 HP +30% · 조리 음식 라드 절반 · 레드 벨리(PK-024) 물 라드 절반(1-12p)
	var heal := float(it.get("heal", 0.0)) * float(eat[0])
	if heal > 0.0:
		combat.heal_q.append(heal)
		if combat.heal_q.size() == 1:
			combat.heal_rate = heal / float(it.get("heal_secs", 5.0))         # 부대찌개는 10초에 걸쳐(SD-13 §7.9.5)
	var rad := int(it.get("rads", 0))
	var taste := ""
	if id == "I-059" and st.vars.has("UQ09_CLEAN"):                      # UQ-09 탁한 물(1-12h): 자료값 라드 +1이 '오염' — 맑아지면 0(원문 '라드 0 회복')
		if int(st.vars.get_v("UQ09_CLEAN")) == 1:
			rad = 0
		else:
			taste = "  끝맛이 쇠 같다. 핍-보이가 틱."
		if int(st.vars.get_v("UQ09_SMOKE")) > 0 and int(st.vars.get_v("GAME_DAY")) == int(st.vars.get_v("UQ09_SMOKE")) + 1 and int(st.vars.get_v("UQ09_PIPE")) == 0:
			taste = "  물에서 굴뚝 맛이 난다."
	if rad > 0:
		rad = roundi(rad * float(eat[1]))
	if rad != 0:
		st.vars.set_v("PC_RADS", maxi(0, int(st.vars.get_v("PC_RADS")) + rad))   # 말린 버섯 나물처럼 라드를 줄이는 음식(음수)
	var why := Perks.eat_tags(st, id, heal > 0.0, int(it.get("rads", 0)) > 0)   # 퍽이 숫자를 바꾼 줄엔 퍽 이름(구현 뒤 재미 검수 ②)
	_note("%s — HP +%d%s%s%s" % [str(it.get("name", id)), int(heal), ("  방사능 +%d" % rad) if rad > 0 else (("  방사능 %d" % rad) if rad < 0 else "  방사능 없음"), why, taste])
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
			"level":                                                    # 레벨업(SD-10 §4.2): 최대 HP +10 즉시 · 알림 · 효과음 · 게임은 멈추지 않는다
				combat.refresh_pc(st)
				_level_up(int(e["value"]))
			"wanted":                                                   # SD-12 §4.6 예문 '수배 등급이 올라갔습니다: 수배 공고'
				_note("수배 등급이 %s: %s" % ["올라갔습니다" if bool(e["up"]) else "내려갔습니다", Wanted.NAMES[int(e["grade"])]])
	st.events.clear()
	for q in st.quests.events:
		if str(q.get("id", "")).begins_with("UQ"):                       # 비표시 퀘스트(SD-05 §2.6): 알림 없음 · 끝난 날만 적어 둔다(메모 줄이 7일 뒤 사라진다)
			if str(q.get("kind", "")) == "done":
				st.boxes["uqdone:" + str(q["id"])] = {"day": int(st.vars.get_v("GAME_DAY"))}
			continue
		match str(q.get("kind", "")):
			"start":
				_note("새 퀘스트: " + st.quests.title(str(q["id"])))
				st.quests.auto_track(str(q["id"]))
				for lid in st.quests.places_of(str(q["id"])):                # 목표 장소의 위치를 알게 된다(지도 윤곽 아이콘·퀘스트 ▼)
					st.places.raise(lid, PlaceLog.MARKED)
			"done":
				_note("퀘스트 완료: " + st.quests.title(str(q["id"])))
	st.quests.events.clear()


func _absorb_tick(mins: float) -> void:
	_absorb += mins
	var n := int(_absorb / 10.0)
	if n > 0:
		_absorb -= n * 10.0
		if Radiation.rads(st) > 0:
			Radiation.remove(st, n)


## 레벨업 순간(SD-10 §4.2): 알림 · 빛 · HP 바가 늘어난 만큼 금빛으로 자람 · 가장자리 금빛(효과음은 소리 단계 D-156) · 처음 한 번은 어디서 나누는지 안내. 게임은 멈추지 않는다
var _lv_t := -1.0                                                      ## 레벨업 뒤 지난 초(HUD 금빛 — 바 0.8초 · 가장자리 0.25초)
var _pend_t := 0.0                                                     ## 미배분 ▲가 깜빡인 초(처음 10초만 깜빡이고 그 뒤엔 멈춰 있다 — 잔소리 금지)


func _level_up(v: int) -> void:
	_note("레벨 업 — Lv %d" % v)
	combat.level_fx()
	_lv_t = 0.0
	_pend_t = 0.0
	if not st.boxes.has("lv_hinted"):
		st.boxes["lv_hinted"] = {"day": int(st.vars.get_v("GAME_DAY"))}
		hint("레벨이 올랐다 — 핍-보이 능력치 > 퍽에서 스킬을 나누고 퍽을 고른다(" + ("왼쪽 위 ▲를 눌러도 된다" if touch_layout else "Tab") + ").", 7.0)


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
		"levelup":                                                      # 레벨업 확정(1-12p): 최대 HP · AP(라이프 기버 · 액션 보이) · 위 줄 수치 · 안내 줄마다 알림(잘리지 않게)
			combat.refresh_pc(st)
			for ln in id.split("\n"):
				if ln != "":
					_note(ln)
			if pipboy != null:
				pipboy.info = status()
		"equip":
			if str(items_db.get(id, {}).get("cat", "")) == "apparel":
				wear(id)
			else:
				combat.equip(id, st)
		"unequip":
			combat.equip("", st)
		"examine":                                                      # 물건 살펴보기: 핍-보이를 닫고 그 물건의 장면
			if pipboy != null:
				pipboy.close(true)
			play_scene.call_deferred("EXAMINE_" + Gear.base(id).replace("-", ""))
		"travel":
			fast_travel(id)
		"repair":
			repair_self(id)
		"use":
			if id == InteriorCombat.STIMPAK:
				combat.use_stimpak(st)                                          # 핍-보이 안: 시간이 멈춘 채 쓴다(투여 모션 없음)
			elif id == Craft.BURNER:
				if pipboy != null:
					pipboy.close(true)
				open_craft.call_deferred({"name": "조리 — 휴대용 버너", "bench": false, "station": false})
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


## 안내 띠 줄 나누기: 화면 폭(양옆 10px 여백 · 글 안쪽 10px)을 넘으면 띄어쓰기에서 나눈다(최대 3줄 — 1-11c 긴 원고 안내)
func _hint_lines(text: String) -> PackedStringArray:
	var maxw := (banner.get_viewport_rect().size.x if banner != null else 640.0) - 40.0
	var out := PackedStringArray()
	var cur := ""
	for w in text.split(" "):
		var t := w if cur == "" else cur + " " + w
		if cur != "" and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > maxw:
			out.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out


## 지금 안내 띠의 높이(줄 수 × 16 + 4)
func _hint_h() -> float:
	if hints.is_empty() or font == null:
		return 20.0
	return 4.0 + 16.0 * _hint_lines(str(hints[0][0])).size()


func _draw_banner() -> void:
	_draw_hud()
	if not hints.is_empty() and banner_t <= 0.0 and not box.active:
		var lines := _hint_lines(str(hints[0][0]))
		var hw := 0.0
		for ln in lines:
			hw = maxf(hw, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		var hr := Rect2(10, 10, hw + 20.0, 4.0 + 16.0 * lines.size())
		banner.draw_rect(hr.grow(1), Color("0B0A0D"))
		banner.draw_rect(hr, Color("1F3A6E"))
		banner.draw_rect(Rect2(hr.position + Vector2(0.5, 0.5), hr.size - Vector2.ONE), Color("4C7DC8"), false, 1.0)
		for i in lines.size():
			banner.draw_string(font, Vector2(hr.position.x + 10, hr.position.y + 2 + 16.0 * i + font.get_ascent(12)), lines[i], HORIZONTAL_ALIGNMENT_LEFT,
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


# ---------------------------------------------------------------- 침대·대기·수면(1-8b, SD-12 §7.6 · SD-11 §11.5)
const BEDS := {"yo_bed": "요", "cot": "야전 침대", "bedroll": "침낭", "bedroll2": "침낭", "hosp_bed": "병원 침대", "vip_bed": "침대",
	"bunk": "2층 침대", "straw_mat": "거적", "straw_mat2": "거적", "sd_rent_mat": "승강장 매트"}
const RENT_BEDS := {"sd_rent_mat": ["SA_MAT_UNTIL", "표하경에게 10캡을 내면 하룻밤 쓸 수 있는 매트다."], "gt_rent_cot": ["GT_COT_UNTIL", "번영회 사무실에 10캡을 내면 하룻밤 쓸 수 있는 침상 칸이다."]}   ## 돈 내고 빌리는 잠자리(SD-15 §5.5): 빌린 동안 '소유 침대'(숙면)
const OTHERS_MAPS := ["B-", "J-", "H-", "K-", "V-", "X-", "D-"]          ## 정착지·손 실내의 침대는 주인이 있다(거처 침대만 예외)


## 앞 칸의 침대: {"name", "owned"(숙면), "other"(남의 것), "script"(원고 장면이 맡는 침대)} — 없으면 빈 사전
func bed_front(cells: Array = []) -> Dictionary:
	if map == null:
		return {}
	for cc in (cells if not cells.is_empty() else _front_cells()):
		for p in map.props:
			if not BEDS.has(str(p["name"])):
				continue
			if cc.x < int(p["x"]) or cc.x >= int(p["x"]) + int(p["w"]) or cc.y < int(p["y"]) or cc.y >= int(p["y"]) + int(p["h"]):
				continue
			var home := map.id == "B-01" and str(p["name"]) == "yo_bed"         # 봉천 옥탑방: 조만석의 '빌린 침대'가 거처가 된다(SD-15 §7.2)
			if home:
				if st.quests.stage("MQ-101") < 40:
					return {"script": true}                                  # MQ-101 첫날 밤은 원고 B-01_BED가 맡는다
				if int(st.vars.get_v("HOME_BC")) == 2:                       # 압류(SD-15 §7.7): 적대인 동안 못 쓴다
					return {"name": "요", "owned": false, "other": true, "why": "압류된 방이다. 반상회 딱지가 이불 위에 붙어 있다."}
				var hb := int(st.vars.get_v("HOME_BC"))
				if (hb == 1 and int(st.vars.get_v("HOME_BC_NOTE")) in [1, 2]) or (hb == 0 and int(st.vars.get_v("AFF_JC_BC")) <= -20):
					return {"name": "요", "owned": false, "other": true,                # 경계 이하 영역의 침대(SD-11 §11.5) — 방은 드나들 수 있다(SD-15 §7.7)
						"why": "마을 인심이 사납다. 이 방에서 마음 놓고 누울 수 없다."}
				return {"name": "312번째 계단 옥탑방 요" if int(st.vars.get_v("HOME_BC")) == 1 else "빌린 침대",
					"owned": int(st.vars.get_v("HOME_BC")) == 1, "other": false}
			if RENT_BEDS.has(str(p["name"])):                                 # 빌린 매트(1-8f 사당): 기한 안이면 내 침대
				var rb: Array = RENT_BEDS[str(p["name"])]
				if Clock.abs_min(date_text) < int(st.vars.get_v(str(rb[0]))):
					return {"name": str(BEDS[p["name"]]), "owned": true, "other": false}
				return {"name": str(BEDS[p["name"]]), "owned": false, "other": true, "why": str(rb[1])}
			var other := false
			for pre in OTHERS_MAPS:
				if map.id.begins_with(pre):
					other = true
			return {"name": str(BEDS[p["name"]]), "owned": false, "other": other}
	return {}


## 기다리거나 잘 수 없는 까닭(없으면 ""): 근처 교전 중인 적 · 쫓기는 중 · 대화·연출 중(SD-12 §7.6 · SD-11 §11.5)
func wait_block() -> String:
	if box.active or ev.busy() or busy or story_hold:
		return "지금은 쉴 수 없다."
	for e in combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.brain.state == AIBrain.S.COMBAT \
				and e.loco.logical.distance_to(player.loco.logical) < 30.0 * 32.0:
			return "근처에 적이 있다. 쉴 수 없다."
	if enc_live.chasing():
		return "쫓기고 있다. 쉴 수 없다."
	if combat.rad_dose > 0.0:
		return "방사능 지대에서는 쉴 수 없다."                               # SD-11 §11.2 · SD-12 §7.6
	for f in wait_vetoes:                                              # 진행기가 거는 막음(1-12e 계약 동행이 지상에서 쉬기를 거절)
		var why := str((f as Callable).call())
		if why != "":
			return why
	return ""


## 대기·수면 창을 연다(bed가 비면 그냥 기다리기 — T 키)
func open_wait(bed: Dictionary = {}) -> void:
	var why := wait_block()
	if why != "":
		_note(why)
		hint(why, 3.0)
		return
	player.move(Vector2.ZERO, 0.0)
	var w := WaitScreen.new().setup(st, date_text, str(bed.get("name", "")), bool(bed.get("owned", false)))
	wait_ui = w
	w.closed.connect(func(ok: bool) -> void:
		wait_ui = null
		if ok:
			_do_wait(w.hours, bed))
	add_child(w)


func _do_wait(h: int, bed: Dictionary) -> void:
	busy = true
	ev.run("fade_out", ["black", "3"], func() -> void:
		advance_minutes(h * 60)
		var msg := "%d시간을 기다렸다." % h
		if not bed.is_empty():
			if combat.pc != null:
				combat.pc.hp = combat.pc.max_hp                              # 수면 = HP·부위 전부(시간 길이와 무관, SD-11 §11.5)
			msg = "%d시간 잤다. 몸이 가볍다." % h
			if bool(bed.get("owned", false)):
				st.vars.set_v("WELL_RESTED", Clock.abs_min(date_text) + 12 * 60)
				msg += " 숙면 — 경험치 +10% (12시간)"
		_rest_check()
		_note(msg)
		ev.run("fade_in", ["black", "3"], func() -> void:
			busy = false
			if not bed.is_empty():
				slept.emit(h)))


## 숙면이 끝났으면 지운다(시계가 갈 때마다)
func _rest_check() -> void:
	var until := int(st.vars.get_v("WELL_RESTED"))
	if until > 0 and Clock.abs_min(date_text) >= until:
		st.vars.set_v("WELL_RESTED", 0)
		_note("숙면 효과가 끝났다.")



# ---------------------------------------------------------------- 작업대·조리(1-8c, SD-13 §7.9 · SD-12 §11.3)
## 제작 작업대: 한결 공구 작업대(어디서나) · 생성 창고(G-)의 작업대(공장 창고 = 시설 작업대) · 마영식 작업대(J-06, 지하시장 동맹 — SD-13 §6 '작업대 사용권').
## 불(조리만): 드럼통 화덕 · 대장간 화로. 근태 목걸이 작업실(H-05) 같은 남의 작업대는 쓸 수 없다.
const BENCHES := {"hangyeol_bench": "한결 공구 작업대", "workbench": "작업대"}
const FIRES := {"drum_fire": "드럼통 화덕", "forge": "대장간 화로"}
const JH_BENCH_AFF := 80


## 앞 칸의 작업대·불: {"name", "bench"(제작 탭), "station"(불), "why"(못 쓰는 까닭)} — 없으면 빈 사전
func bench_front(cells: Array = []) -> Dictionary:
	if map == null:
		return {}
	for cc in (cells if not cells.is_empty() else _front_cells()):
		for p in map.props:
			var nm := str(p["name"])
			if not BENCHES.has(nm) and not FIRES.has(nm):
				continue
			var pw := int(p.get("w", 1))
			var ph := int(p.get("h", 1))
			if cc.x < int(p["x"]) or cc.x >= int(p["x"]) + maxi(pw, 1) or cc.y < int(p["y"]) or cc.y >= int(p["y"]) + maxi(ph, 1):
				continue
			if FIRES.has(nm):
				if map.texts.has(cc):
					continue                                                  # 조사 글이 달린 불(지하시장 경비들의 드럼통 등)은 글이 먼저
				return {"name": "조리 — " + str(FIRES[nm]), "bench": false, "station": true}
			if nm == "workbench" and not (map.id.begins_with("G-") or map.id == "J-06"):
				continue                                                  # 남의 작업대(본소 목걸이 작업실 등): 조사 글로
			if nm == "workbench" and map.id == "J-06" and int(st.vars.get_v("AFF_JH")) < JH_BENCH_AFF:
				return {"name": "마영식 작업대", "bench": true, "station": true, "why": "마영식의 작업대다. 상인회가 믿어 주기 전엔 손댈 수 없다."}
			return {"name": str(BENCHES[nm]) if map.id != "J-06" else "마영식 작업대", "bench": true, "station": true}
	return {}


func open_craft(wb: Dictionary) -> void:
	if craft_ui != null:
		return
	player.move(Vector2.ZERO, 0.0)
	var c := CraftScreen.new().setup(st, items_db, str(wb.get("name", "작업대")), bool(wb.get("bench", true)), bool(wb.get("station", true)))
	craft_ui = c
	c.crafted.connect(func(rid: String, _r: Dictionary) -> void: _note_craft(rid))
	c.closed.connect(func(_ok: bool) -> void: craft_ui = null)
	add_child(c)


func _note_craft(_rid: String) -> void:
	_drain_events()


# ---------------------------------------------------------------- 정보상(1-8d, SD-15 §5.3)
## 장소 소문: 50캡에 아직 모르는 장소 1곳을 지도에 '표시'로 띄운다(권역별 목록에서 고른다, 권역당 5곳까지).
## 판도 소식·누가 나를 아는가·목격자 매수·정보 세탁·추격자 동선·정보 매입은 판도 겹치기·공개도(1-10·1-12) 단계에서 더한다.
const INFO_REGIONS := {"R01": "관악·동작", "R02": "영등포·여의도"}
const RUMOR_PRICE := 50
const RUMOR_CAP := 5


## 권역에서 소문으로 살 수 있는 장소(아직 '표시' 전 · 숨은 곳 아님 · 지도 표시가 있는 곳) — 가까운 순
func rumor_places(region: String, n: int = 6) -> Array:
	PlaceLog.load_db()
	var me := map.tile_of(player.loco.logical) if map is WorldMap else Vector2i(-1, -1)
	if me.x < 0:                                                          # 실내: 바깥으로 나가는 출구의 장소(월드 문)를 기준점으로
		for ex in map.data.get("exits", []):
			var lid0 := str(ex.get("mark", ex.get("to_mark", "")))
			if PlaceLog.db.has(lid0):
				me = Vector2i(int(PlaceLog.db[lid0]["tx"]), int(PlaceLog.db[lid0]["ty"]))
				break
	var out: Array = []
	for lid in PlaceLog.db:
		var e: Dictionary = PlaceLog.db[lid]
		if str(e.get("region", "")) != region or bool(e.get("hidden", false)) or not bool(e.get("marker", true)):
			continue
		if st.places.get_state(lid) >= PlaceLog.MARKED:
			continue
		out.append(lid)
	if me.x >= 0:
		out.sort_custom(func(a, b): return Vector2i(int(PlaceLog.db[a]["tx"]), int(PlaceLog.db[a]["ty"])).distance_squared_to(me) \
			< Vector2i(int(PlaceLog.db[b]["tx"]), int(PlaceLog.db[b]["ty"])).distance_squared_to(me))
	else:
		out.sort()
	return out.slice(0, n)


func info_menu(vid: String, region: String = "") -> void:
	shop_state(vid)
	var m: Dictionary = merchants.get(vid, {})
	var npc := str(m.get("npc", ""))
	var ops: Array = []
	var labels := {"START": 0}
	var opts: Array = []
	if region.begins_with("@"):                                         # 구문철의 공개도 상품(1-12q — SD-15 §5.3 · SD-06 §6.5)
		_broker_menu(vid, npc, region, ops, labels)
		ops.append({"op": "end"})
		box.open(st, {"id": "INFO_" + vid, "title": str(m.get("name", vid)), "npc": npc, "labels": labels, "ops": ops}, "START")
		return
	if region == "":
		var broker := vid.begins_with("V12")
		var now := Clock.abs_min(date_text)
		for hh in st.deeds.hushed:                                       # 입막음이 먹혔는지(재미 검수 ② 다): 도착 시각이 지났으면 한 줄
			if not bool(hh["told"]) and int(hh["until"]) <= now and broker:
				hh["told"] = true
				ops.append({"op": "line", "who": npc, "emo": "기본", "text": "그 얘기, %s까진 안 갔어. 내가 막았지." % "·".join(hh["to"])})
				break
		for lw in st.deeds.laundered:                                    # 세탁이 먹혔는지 — 하루 지나 다음 만남에(재미 검수 ③)
			if broker and not bool(lw["told"]) and now - int(lw["at"]) >= 1440:
				lw["told"] = true
				var tn := str(Deeds.FAC_NAME.get(str(lw["to"]), lw["to"]))
				ops.append({"op": "line", "who": npc, "emo": "불만" if bool(lw["caught"]) else "미소", "text":
					("…말이 새 버렸어. %s 쪽도 누가 덮어씌웠는지 알아. 덕분에 우리도 체면 구겼고." % tn) if bool(lw["caught"])
					else ("그 얘기, 다들 %s 짓인 줄 알더라. 네 이름은 안 나와." % tn)})
				break
		ops.append({"op": "line", "who": npc, "emo": "기본", "text": "뭘 사려고? 장소 얘기는 한 군데 50캡, 권역마다 다섯 군데까지만 판다. 그 밖에 귀동냥도 있고." if broker
			else "어디 얘기가 궁금해? 한 군데 50캡. 권역마다 다섯 군데까지만 판다. 내 밑천이라서."})
		var i := 0
		for rg in INFO_REGIONS:
			var left := RUMOR_CAP - int(st.vars.get_v("INFO_RUMOR_" + rg))
			var have := not rumor_places(rg, 1).is_empty()
			opts.append({"text": "장소 소문 — %s (남은 %d곳)" % [INFO_REGIONS[rg], maxi(left, 0) if have else 0], "tags": [],
				"cond": "INFO_RUMOR_%s < %d" % [rg, RUMOR_CAP] if have else "1 == 0", "fx": "", "to": "R%d" % i, "id": "INFO:%s:%s" % [vid, rg]})
			i += 1
		if broker:
			opts.append({"text": "판도 소식 — 요즘 누가 어디를 쥐었나", "tags": [{"k": "caps", "n": 30}], "cond": "INFO_TURF_DAY != GAME_DAY", "fx": "", "to": "TURF", "id": "INFO:%s:turf" % vid})
			var pend := st.deeds.pending(now)
			opts.append({"text": "누가 나를 아는가 — 내 얘기가 어디까지 갔나", "tags": [{"k": "caps", "n": 50}] if not pend.is_empty() else [], "cond": "", "fx": "", "to": "WHO", "id": "INFO:%s:who" % vid})
			opts.append({"text": "입막음 — 아직 덜 퍼진 얘기 하나", "tags": [], "cond": "", "fx": "", "to": "HUSH", "id": "INFO:%s:hush" % vid})
			opts.append({"text": "정보 세탁 — 남의 짓으로 돌리기", "tags": [], "cond": "", "fx": "", "to": "LAUNDER", "id": "INFO:%s:launder" % vid})
		opts.append({"text": "됐다", "tags": [], "cond": "", "fx": "", "to": "END", "id": "INFO:%s:end" % vid})
		ops.append({"op": "choice", "opts": opts})
		if broker:
			labels["TURF"] = ops.size()
			ops.append({"op": "line", "who": npc, "emo": "기본", "text": _broker_turf_line()})
			ops.append({"op": "cmd", "name": "info_turf", "args": [vid]})
			ops.append({"op": "goto", "to": "END"})
			labels["WHO"] = ops.size()
			for ln in _broker_who_lines(now):
				ops.append({"op": "line", "who": npc, "emo": "기본", "text": ln})
			ops.append({"op": "goto", "to": "END"})
			for kv in [["HUSH", "@hush"], ["LAUNDER", "@launder"]]:
				labels[kv[0]] = ops.size()
				ops.append({"op": "cmd", "name": "info", "args": [vid, kv[1]]})
				ops.append({"op": "goto", "to": "END"})
		i = 0
		for rg in INFO_REGIONS:
			labels["R%d" % i] = ops.size()
			ops.append({"op": "cmd", "name": "info", "args": [vid, rg]})
			ops.append({"op": "goto", "to": "END"})
			i += 1
	else:
		var cands := rumor_places(region)
		ops.append({"op": "line", "who": npc, "emo": "기본", "text": "%s 쪽 얘기라면 들은 데가 몇 군데 있지. 어느 쪽?" % str(INFO_REGIONS.get(region, region))})
		for i in cands.size():
			var e: Dictionary = PlaceLog.db[cands[i]]
			opts.append({"text": "%s(%s)" % [str(e["name"]), str(e.get("type", ""))], "tags": [{"k": "caps", "n": RUMOR_PRICE}], "cond": "", "fx": "",
				"to": "P%d" % i, "id": "INFOP:%s:%s" % [vid, cands[i]]})
		opts.append({"text": "됐다", "tags": [], "cond": "", "fx": "", "to": "END", "id": "INFOP:%s:end" % vid})
		ops.append({"op": "choice", "opts": opts})
		for i in cands.size():
			labels["P%d" % i] = ops.size()
			ops.append({"op": "line", "who": npc, "emo": "기본", "text": "핍-보이에 찍어 둬. 내가 말했다고는 하지 말고."})
			ops.append({"op": "cmd", "name": "infodo", "args": [vid, cands[i]]})
			ops.append({"op": "goto", "to": "END"})
	ops.append({"op": "end"})
	box.open(st, {"id": "INFO_" + vid, "title": str(m.get("name", vid)), "npc": npc, "labels": labels, "ops": ops}, "START")


# ---------------------------------------------------------------- 정보상 구문철의 공개도 상품(1-12q — SD-15 §5.3 · SD-06 §6.5)
const HUSH_PRICE := 200
const LAUNDER_PRICE := 500
## 세탁해 덮어씌울 만한 쪽(1막 R01 · R02에 이미 있는 손): 세력 코드 · 구문철이 대는 까닭
const LAUNDER_TO := [["SB", "새벽인력 인솔조 — 요즘 그쪽 동네를 자주 돈다"], ["BJ", "계엄군 순찰 — 거기 검문이 서는 날이었어"], ["NJ", "떠돌이 고철 패거리 — 아무도 뒤를 안 캔다"]]


## 판도 소식(30캡 · 하루 한 번): R01 · R02 구역을 지금 판으로 듣고, 바뀐 곳 하나를 말로 짚는다
func _broker_turf_line() -> String:
	var line := "다 그대로야. 네 지도가 맞아."
	for z in Turf.zones():
		var k: Dictionary = st.turf.known_of(z)
		var s2: Dictionary = st.turf.state_of(st, z)
		if not k.is_empty() and str(k["a"]) != str(s2["a"]):
			var who := Turf.fac_name(str(s2["a"])) if str(s2["a"]) != "" else ""
			line = ("%s 쪽은 이제 %s 손에 있어. 지도 고쳐 적어." % [Turf.zone_name(z), who]) if who != "" else ("%s 쪽은 지금 주인이 없어. 서로 눈치만 봐." % Turf.zone_name(z))
			break
	return line


## 누가 나를 아는가(50캡): 퍼지는 중인 얘기 — 어느 쪽에 몇 시간 뒤(가까운 넷)
func _broker_who_lines(now: int) -> Array:
	var pend := st.deeds.pending(now)
	if pend.is_empty():
		return ["요즘 네 얘기는 조용해. 돈 아껴."]
	var out: Array = ["들어 봐. 네 얘기가 이렇게 돌고 있어."]
	var by_d := {}                                                     # 기록마다 한 줄(재미 검수 ①): 가까운 도착 둘 + 구문철이 손쓸 수 있나
	var order: Array = []
	for p in pend:
		var did := str(p["d"]["id"])
		if not by_d.has(did):
			by_d[did] = []
			order.append(did)
		var fs: Array = by_d[did]
		if fs.size() < 2 and not fs.any(func(x): return str(x["f"]) == str(p["f"])):
			fs.append(p)
	for did in order:
		var fs: Array = by_d[did]
		var d: Dictionary = fs[0]["d"]
		var parts: Array = []
		for p in fs:
			var h := maxi(1, int(ceil(float(int(p["at"]) - now) / 60.0)))
			parts.append("%s%s %s 귀에" % [{"행상": "행상 편에 ", "정보상": "우리 쪽 입으로 ", "소문": "소문으로 ", "남산 방송": "방송으로 ", "공보방송": "공보방송으로 ",
				"정보원": "정보원 입으로 ", "용산 기지 방송": "용산 방송으로 "}.get(str(p["route"]), ""),
				("반나절이면" if h <= 12 else ("하루면" if h <= 24 else ("이틀이면" if h <= 48 else "사흘이면"))), str(Deeds.FAC_NAME.get(str(p["f"]), p["f"]))])
		var ck := st.deeds.cover_kind(d)
		out.append("'%s' — %s. %s" % [str(d["what"]), ", ".join(parts),
			{"hush": "이건 내가 막을 수 있어.", "launder": "소문이라 막진 못해. 남 짓으로 돌릴 순 있지."}.get(ck, "이건 나도 손 못 써.")])
		if out.size() >= 5:
			break
	return out


## 입막음 · 세탁 하위 메뉴(@hush · @launder · @launder:기록ID)
func _broker_menu(vid: String, npc: String, region: String, ops: Array, labels: Dictionary) -> void:
	var opts: Array = []
	if region == "@hush" or region == "@launder":
		var kind := region.substr(1)
		var list := st.deeds.coverable(kind)
		if list.is_empty():
			ops.append({"op": "line", "who": npc, "emo": "기본", "text": "막을 얘기가 없어. 아직 아무도 네 얘기를 안 해." if kind == "hush" else "돌릴 얘기가 없어. 다 퍼졌거나, 아직 아무도 몰라."})
			return
		ops.append({"op": "line", "who": npc, "emo": "기본", "text": ("어느 얘기? 목격자 입은 내가 막아 줄게. %d캡. 대신 열에 둘은 결국 새." % HUSH_PRICE) if kind == "hush"
			else ("어느 얘기? 남의 짓으로 흘려 줄게. %d캡. 들키면 우리도 곤란해." % LAUNDER_PRICE)})
		for i in list.size():
			var d: Dictionary = list[i]
			if kind == "hush":
				opts.append({"text": _fit_line(str(d["what"])), "tags": [{"k": "caps", "n": HUSH_PRICE}], "cond": "", "fx": "", "to": "H%d" % i, "id": "INFOH:%s:%s" % [vid, str(d["id"])]})
			else:
				opts.append({"text": _fit_line(str(d["what"])), "tags": [], "cond": "", "fx": "", "to": "L%d" % i, "id": "INFOL:%s:%s" % [vid, str(d["id"])]})
		opts.append({"text": "됐다", "tags": [], "cond": "", "fx": "", "to": "END", "id": "INFOH:%s:end" % vid})
		ops.append({"op": "choice", "opts": opts})
		for i in list.size():
			var d2: Dictionary = list[i]
			labels[("H%d" if kind == "hush" else "L%d") % i] = ops.size()
			if kind == "hush":
				ops.append({"op": "line", "who": npc, "emo": "기본", "text": "내가 팔 걸 네가 사 가는 셈이네. …알았어, 거기서 끊을게."})
				ops.append({"op": "cmd", "name": "info_hush", "args": [vid, str(d2["id"])]})
			else:
				ops.append({"op": "cmd", "name": "info", "args": [vid, "@launder:" + str(d2["id"])]})
			ops.append({"op": "goto", "to": "END"})
		return
	if region.begins_with("@launder:"):
		var did := region.substr(9)
		var d3: Dictionary = {}
		for d in st.deeds.list:
			if str(d["id"]) == did:
				d3 = d
		if d3.is_empty():
			return
		var victims: Array = (d3["fx"] as Dictionary).keys()
		var last_at := 0                                                 # 다 돌기까지 — 실제 남은 도착에서
		for f in victims:
			if not (d3["known"] as Dictionary).has(f):
				var ar := st.deeds.arrival(d3, str(f))
				if ar.size() == 2:
					last_at = maxi(last_at, int(ar[0]))
		var hrs := maxi(1, int(ceil(float(last_at - Clock.abs_min(date_text)) / 60.0)))
		var when := "반나절이면" if hrs <= 12 else ("하루면" if hrs <= 24 else ("이틀이면" if hrs <= 48 else "사흘이면"))
		ops.append({"op": "line", "who": npc, "emo": "기본", "text": "누구한테 덮어씌울까? 그럴듯해야 먹혀."})
		var j := 0
		for o in LAUNDER_TO:
			if str(o[0]) in victims:
				continue
			opts.append({"text": str(o[1]), "tags": [{"k": "caps", "n": LAUNDER_PRICE}], "cond": "", "fx": "", "to": "F%d" % j, "id": "INFOF:%s:%s:%s" % [vid, did, str(o[0])]})
			j += 1
		var vname := str(Deeds.FAC_NAME.get(str(victims[0]), "")) if not victims.is_empty() else ""
		if vname != "":
			opts.append({"text": "%s 쪽 짓으로" % vname, "tags": [], "cond": "", "fx": "", "to": "SELF", "id": "INFOF:%s:%s:self" % [vid, did]})
		opts.append({"text": "됐다", "tags": [], "cond": "", "fx": "", "to": "END", "id": "INFOF:%s:end" % vid})
		ops.append({"op": "choice", "opts": opts})
		j = 0
		for o in LAUNDER_TO:
			if str(o[0]) in victims:
				continue
			labels["F%d" % j] = ops.size()
			ops.append({"op": "line", "who": npc, "emo": "기본", "text": "알았어. 그쪽 짓이라고 흘려 둘게. 계단참에서 퍼뜨리면 %s 다 돌아. 먹혔는지는 내일 와서 물어." % when})
			ops.append({"op": "cmd", "name": "info_launder", "args": [vid, did, str(o[0])]})
			ops.append({"op": "goto", "to": "END"})
			j += 1
		labels["SELF"] = ops.size()
		ops.append({"op": "line", "who": npc, "emo": "기본", "text": "%s 일을 %s한테 덮어씌워? 아무도 안 믿어. 돈 넣어 둬." % [vname, vname]})
		ops.append({"op": "goto", "to": "END"})


func _fit_line(t: String) -> String:
	return t if t.length() <= 30 else t.substr(0, 29) + "…"


# ---------------------------------------------------------------- 의사(1-8d, SD-15 §5.1)
## 요금은 물물교환과 무관, 의사 세력·정착지 호감도 단계 F구매만 곱한다. 손상 지수 = 1 − HP/최대 HP(부위 손상 체계가 생기면 + 0.15 × 부위 수):
## 0.34 미만 경상 40 · 0.67 미만 중상 70 · 그 이상 위중 100. 0이면 거절. 방사능 제거 100(라드 200 미만이면 60).
## 순회 의료반(V56): 카르마 선함(+250) 이상이면 치료 무료, 악함(−250) 이하면 치료 거절(약은 판다).
func injury_index() -> float:
	if combat.pc == null or combat.pc.max_hp <= 0.0:
		return 0.0
	return clampf(1.0 - combat.pc.hp / combat.pc.max_hp, 0.0, 1.0)


func doctor_prices(vid: String) -> Dictionary:
	var m: Dictionary = merchants.get(vid, {})
	var ak := st._aff_key(str(m.get("settle", "")))
	var f := TradeScreen.tier_f(int(st.vars.get_v(ak)) if ak != "" else 0)
	var fb := float(f[0]) if not f.is_empty() else 1.0
	var ii := injury_index()
	var base := 0 if ii <= 0.0 else (40 if ii < 0.34 else (70 if ii < 0.67 else 100))
	var rads := int(st.vars.get_v("PC_RADS"))
	var rad := 0 if rads <= 0 else (60 if rads < 200 else 100)
	var karma := int(st.vars.get_v("V_KARMA"))
	var out := {"heal": roundi(base * fb), "rad": roundi(rad * fb), "tier": ["", "경상", "중상", "위중"][0 if base == 0 else (1 if base == 40 else (2 if base == 70 else 3))],
		"refuse": false, "free": false}
	if vid == "V56":
		out["refuse"] = karma <= -250
		out["free"] = karma >= 250
		if out["free"]:
			out["heal"] = 0
			out["rad"] = 0
	return out


func doctor_menu(vid: String) -> void:
	shop_state(vid)
	var m: Dictionary = merchants.get(vid, {})
	var npc := str(m.get("npc", ""))
	var pr := doctor_prices(vid)
	var ops: Array = []
	var labels := {"START": 0}
	var opts: Array = []
	var say := "어디 봐요."
	if bool(pr["refuse"]):
		say = "당신 손에 묻은 건 내 붕대로 안 지워져요. 약은 팔아 줄게. 치료는 안 해."
	elif int(pr["heal"]) == 0 and str(pr["tier"]) == "" and int(st.vars.get_v("PC_RADS")) <= 0:
		say = "멀쩡한데 왜 왔어요? 다치면 와요."
	elif bool(pr["free"]):
		say = "그쪽 얘기는 들었어요. 돈은 넣어 둬요."
	ops.append({"op": "line", "who": npc, "emo": "기본", "text": say})
	if not bool(pr["refuse"]) and str(pr["tier"]) != "":
		opts.append({"text": "치료 — %s" % str(pr["tier"]), "tags": [{"k": "caps", "n": int(pr["heal"])}] if int(pr["heal"]) > 0 else [], "cond": "", "fx": "",
			"to": "H", "id": "DOC:%s:heal" % vid})
	if not bool(pr["refuse"]) and int(st.vars.get_v("PC_RADS")) > 0:
		opts.append({"text": "방사능을 빼 달라고 한다(라드 %d)" % int(st.vars.get_v("PC_RADS")), "tags": [{"k": "caps", "n": int(pr["rad"])}] if int(pr["rad"]) > 0 else [],
			"cond": "", "fx": "", "to": "R", "id": "DOC:%s:rad" % vid})
	opts.append({"text": "약을 산다", "tags": [], "cond": "", "fx": "", "to": "S", "id": "DOC:%s:shop" % vid})
	opts.append({"text": "됐다", "tags": [], "cond": "", "fx": "", "to": "END", "id": "DOC:%s:end" % vid})
	ops.append({"op": "choice", "opts": opts})
	labels["H"] = ops.size()
	ops.append({"op": "cmd", "name": "docdo", "args": [vid, "heal"]})
	ops.append({"op": "line", "who": npc, "emo": "미소", "text": "됐어요. 다음엔 덜 다치고 와요."})
	ops.append({"op": "goto", "to": "END"})
	labels["R"] = ops.size()
	ops.append({"op": "cmd", "name": "docdo", "args": [vid, "rad"]})
	ops.append({"op": "line", "who": npc, "emo": "기본", "text": "다 뺐어요. 물은 가려 마셔요."})
	ops.append({"op": "goto", "to": "END"})
	labels["S"] = ops.size()
	ops.append({"op": "cmd", "name": "trade", "args": [vid]})
	ops.append({"op": "goto", "to": "END"})
	ops.append({"op": "end"})
	box.open(st, {"id": "DOC_" + vid, "title": str(m.get("name", vid)), "npc": npc, "labels": labels, "ops": ops}, "START")
