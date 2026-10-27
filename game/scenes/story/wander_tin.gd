## 1-13j2 관악 비탈 '바위 틈 탄약 깡통'(계획 docs/seoul-fallout/_plans/1-13j2_wander_tin_plan.md — 재미 검수 반영, 사용자 지시 2026-10-27).
## 월드 손 자리 @949,1459(maps/world/r01.spots): 돌탑 wander_cairn · 군화 발자국 · 용기 wander_tin(캡 20~25 한 번).
## 사실은 변수 한 곳(SD-20 P1): WT_STATE 0 그대로 · 1 비움 · 2 무언가 남김(캡 반 · 내 물건) · 3 주인이 다녀감 '고맙다.'(남긴 것을 가져감) ·
##   4 주인이 다녀감 '누가 가져갔냐.' · WT_DAY 처음 손댄 날. 주인이 누구인지는 말하지 않는다(P2 — 새 인물 · 새 사실 없음).
## ① 글은 용기와 같은 자리에서: 돌탑을 누르면 그 상태의 글을 한 번 먼저 띄우고, 글이 끝나면 용기 창을 연다(같은 상태 글은 한 번만 — WT 본 상태는 st.boxes).
## ② 용기를 닫을 때: 손댔으면(꺼냄 · 넣음) 0 → 1 · 2, 주인이 오기 전엔 닫을 때마다 내용으로 다시 정한다.
## ③ 하루 넘김 · 맵 들어섬: GAME_DAY ≥ WT_DAY + 2이고 주인공이 돌탑에서 30칸 밖(또는 실내)이면 2 → 3(깡통을 비운다) · 1 → 4. 그 뒤로는 그대로(P10).
class_name WanderTin
extends Node

const TILE := Vector2i(949, 1459)
const AWAY := 30.0                         ## 주인은 보는 데서 오지 않는다(칸)
const BACK_DAYS := 2
const LINES := {
	0: "바위 발치에 돌 몇 개를 쌓아 틈을 막아 두었다. 틈 안에 녹슨 탄약 깡통. 뚜껑에 칼끝으로 긁은 글씨 — '비 그치면 가지러 옴.'",
	1: "쌓아 둔 돌이 흩어져 있다. 틈 안에 녹슨 깡통.",
	2: "쌓아 둔 돌이 흩어져 있다. 틈 안에 녹슨 깡통.",
	3: "흩어졌던 돌이 다시 쌓여 있다. 깡통 안은 비었다. 뚜껑 글씨 밑에 새로 긁은 한 줄 — '고맙다.'",
	4: "흩어졌던 돌이 다시 쌓여 있다. 뚜껑 글씨 밑에 새로 긁은 한 줄 — '누가 가져갔냐.'",
}
const PROP_STATE := {0: "", 1: "scattered", 2: "scattered", 3: "restacked", 4: "restacked"}

var host: InteriorHost
var st: StoryState
var log_on := false


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.interact_pre.append(_pre)
	host.box_closed.connect(_on_box)
	host.day_tick.connect(func(_d: int) -> void: _owner_back())
	host.map_entered.connect(func(_id: String) -> void: _owner_back())


func state() -> int:
	return int(st.vars.get_v("WT_STATE"))


func _log(s: String) -> void:
	if log_on:
		print("[바위 틈 깡통] " + s)


func _on_world() -> bool:
	return host.map != null and host.map.id == "W"


## 깡통 용기(맵의 자리 자료)와 그 내용(st.boxes) — 월드에 있을 때만
func _tin() -> Dictionary:
	if not _on_world() or not host.map.boxes.has(TILE):
		return {}
	var b: Dictionary = host.map.boxes[TILE]
	return b if str(b.get("kind", "")) == "wander_tin" else {}


## ① 돌탑을 누르면: 이 상태의 글을 아직 안 봤으면 글 먼저, 끝나면 용기 창
func _pre() -> bool:
	var b := _tin()
	if b.is_empty() or not (TILE in host._front_cells()):
		return false
	var line: String = LINES[state()]
	if str(st.boxes.get("wt_seen", {}).get("t", "")) == line:
		return false                                                   # 본 글 — 곧장 용기(평소 조사)
	st.boxes["wt_seen"] = {"t": line}
	host.say_text(line)
	host.box.finished.connect(func() -> void: host.open_box(b), CONNECT_ONE_SHOT)
	return true


## ② 용기를 닫았다: 손댔으면 비움(1) · 남김(2). 주인이 오기 전(0 · 1 · 2)에만
func _on_box(b: Dictionary, c: Dictionary) -> void:
	if str(b.get("kind", "")) != "wander_tin" or state() > 2:
		return
	var items: Dictionary = c.get("items", {})
	var touched := int(c.get("taken", 0)) > 0 or items.size() != 1 or not items.has("M-001")
	if not touched:
		return
	if state() == 0:
		st.vars.set_v("WT_DAY", maxi(1, int(st.vars.get_v("GAME_DAY"))))
	var ns := 1 if items.is_empty() else 2
	if ns != state():
		st.vars.set_v("WT_STATE", ns)
		_log("상태 %d(%s)" % [ns, "비움" if ns == 1 else "남김"])
	_prop()


## ③ 주인이 다녀감: 이틀이 지났고 주인공이 멀리(또는 실내) 있을 때 한 번
func _owner_back() -> void:
	var s := state()
	if s != 1 and s != 2:
		return
	if int(st.vars.get_v("GAME_DAY")) < int(st.vars.get_v("WT_DAY")) + BACK_DAYS:
		return
	if _on_world() and host.player != null and Vector2(host.map.tile_of(host.player.loco.logical)).distance_to(Vector2(TILE)) <= AWAY:
		return
	if s == 2:
		var k := Loot.key("W", {"x": TILE.x, "y": TILE.y}, st.year())
		if st.boxes.has(k):
			st.boxes[k]["items"] = {}                                   # 남긴 것을 가져갔다(받은 것 — 되찾는 길 없음)
	st.vars.set_v("WT_STATE", 3 if s == 2 else 4)
	_log("주인이 다녀감 — 상태 %d" % state())
	_prop()


func _prop() -> void:
	if _on_world():
		host.map.set_prop_state(TILE, PROP_STATE[state()])
