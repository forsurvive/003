## 계엄군 초소 정지(1-12l — D-081 '도주 관리자' 검문 정지 · D-118 인수증, SD-03a §8.6 기울기 체감 L1354 · SD-06 §4.3.1 BJ 반응표 · 계획 `_plans/1-12l_plan.md` A).
## 초소 셋(사당 고개 X-SG · 노량진 다리목 L-R01-20 · 여의도 환승센터 터 L-R02-28) 앞 6칸에 걸어 들어오면 그 초소에서 하루 한 번 세운다.
## 무엇으로 세우나는 kind() 한 곳(P1): 1 도주 관리자(MQ-106에서 싸움) · 3 적대 경고 · 4 여의도 초소 문서 검문(MQ-104 뒤). 우호 이상은 '등록증을 보고 통과'.
## 변수: BJS_<초소>_DAY(그 초소에서 세운 날) · BJS_<초소>_N(그 초소에서 선 횟수 — 두 번째부터 짧게) · BJS_<초소>_BACK(회차당한 날) · BJS_<초소>_PEN(같은 날 되돌아와 불응으로 친 날)
##   BJS_N(지금 장면의 그 횟수) · BJS_FIXED(화술로 '경위 정정' — 그 뒤 정지는 한 줄로 끝, RE-061도 안다) · BJS_COOP(손을 든 협조 기록 — BJ +1, 세 번까지)
## 원고 script/act1/BJ_STOP.txt(@cmd bjs back | pass | run | wait)
class_name BjStop
extends Node

const POSTS := {
	"SG": {"at": Vector2i(1113, 1462), "ids": ["N-R01-047", "CR-401", "CR-403"], "scene": "BJSTOP_SG"},
	"NR": {"at": Vector2i(957, 1183), "ids": ["N-R01-050", "N-BJ-C2", "CR-401"], "scene": "BJSTOP_NR"},
	"YD": {"at": Vector2i(804, 1086), "ids": ["C-034", "CR-401"], "scene": "BJSTOP_YD"}}
const STOP_R := 6.0                                                     ## 초소 우두머리(또는 그 초소 계엄병) 둘레 몇 칸에서 세우나
const STAFF_R := 10.0                                                   ## 초소 자리에서 이만큼 안에 서 있는 계엄군이 있어야 '사람이 있는 초소'
const BACK := 6                                                         ## 회차: 초소 반대쪽으로 물러나는 칸

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var post := ""                                                          ## 지금 세운 초소


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["bjs"] = _cmd


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[초소 정지] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func _hour() -> int:
	return (Clock.abs_min(host.date_text) % 1440) / 60 if host.date_text != "" else 12


## 무엇으로 세우나(P1). post = "SG" · "NR" · "YD"
static func kind(st, post_id: String, hour: int) -> int:
	if int(st.vars.get_v("V_ACT")) < 1:
		return 0
	var aff := int(st.vars.get_v("AFF_BJ"))
	if aff <= -60:
		return 3
	if aff >= 20:
		return 0                                                            # 우호 이상: 등록증을 보고 통과(SD-06)
	var res := int(st.vars.get_v("MQ106_RESULT"))
	if res == 1:
		return 1
	if post_id == "YD" and st.quests.stage("MQ-104") >= 100 and res != 3 and res != 4 \
			and int(st.vars.get_v("MQ104_SEARCH")) != 4 and hour >= 6 and hour < 20:
		return 4                                                            # 여의도 초소 낮 문서 검문(MQ-104 기울기 체감 — 말로 돌려보냈으면 '관리자 후보' 통과)
	return 0


## 그 퀘스트의 검문 · 동행이 무대를 가진 동안은 세우지 않는다(P4)
func _quiet() -> bool:
	if host.busy or host.box.active or host.ev.busy() or host.story_hold or host.pipboy != null:
		return true
	if host.enc_live != null and host.enc_live.chasing():
		return true
	if v("FQ_JH03_PARK") == 1 or v("SQ_S06_JIN") == 1 or v("SQ_S11_ESCORT") == 1:
		return true
	return false


## 그 초소에 서 있는 계엄군 배우(우두머리 먼저) — 없으면 null
func staff(p: String) -> Actor:
	var at := Vector2(POSTS[p]["at"]) * 32.0 + Vector2(16, 16)
	var best: Actor = null
	var best_rank := 99
	for n in host.npcs:
		var a = n["actor"]
		if not is_instance_valid(a) or not a.visible:
			continue
		var rank: int = (POSTS[p]["ids"] as Array).find(str(n["id"]))
		if rank < 0 or a.loco.logical.distance_to(at) > STAFF_R * 32.0:
			continue
		if rank < best_rank:
			best_rank = rank
			best = a
	return best


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.4:
		return
	_t = 0.0
	if host == null or not (host.map is WorldMap) or host.player == null or _quiet():
		return
	var me := host.map.tile_of(host.player.loco.logical)
	for p in POSTS:
		if Vector2(me).distance_to(Vector2(POSTS[p]["at"])) > STAFF_R + STOP_R:
			continue
		if v("BJS_%s_DAY" % p) == day():
			_returned(p)                                                    # 회차당한 날 다시 걸어 들어옴 — 불응으로 친다(재미 검수 ①)
			continue
		if p == "YD" and st.quests.stage("MQ-104") < 100:
			continue                                                        # 벙커 입구 곁 — MQ-104 첫 방문과 겹치지 않게
		var k := kind(st, p, _hour())
		if k == 0:
			continue
		var a := staff(p)
		if a == null or a.loco.logical.distance_to(host.player.loco.logical) > STOP_R * 32.0:
			continue
		_stop(p, k, a)
		return


## 같은 날 회차당한 초소 앞 6칸에 다시 들어옴: 장면 없이 한 줄 + 수배도 +3(초소 · 날마다 한 번)
func _returned(p: String) -> void:
	if v("BJS_%s_BACK" % p) != day() or v("BJS_%s_PEN" % p) == day():
		return
	var a := staff(p)
	if a == null or a.loco.logical.distance_to(host.player.loco.logical) > STOP_R * 32.0:
		return
	st.vars.set_v("BJS_%s_PEN" % p, day())
	st.call_fn("wanted", [3, "bjs"])
	host.combat._pop("회차랬습니다. — 불응, 기록!", a.loco.logical + Vector2(0, -40), Color("E04A35"))
	host.hint("같은 날 되돌아왔다 — 정지 명령 불응으로 적혔다", 4.0)
	_log("%s 되돌아옴 — 불응" % p)


func _stop(p: String, k: int, a: Actor) -> void:
	post = p
	st.vars.set_v("BJS_%s_DAY" % p, day())
	st.vars.set_v("BJS_%s_N" % p, v("BJS_%s_N" % p) + 1)
	st.vars.set_v("BJS_N", v("BJS_%s_N" % p))
	st.vars.set_v("BJS_KIND", k)
	host.player.move(Vector2.ZERO, 0.0)
	a.loco.facing = Locomotion.snap8(host.player.loco.logical - a.loco.logical, 0.0)
	a._show()
	host.ev.balloons.append({"actor": a, "kind": "!", "t": 0.0})          # 초소에서 외친다
	host.ev.queue_redraw()
	host.play_scene(str(POSTS[p]["scene"]))
	_log("%s 정지 %d" % [p, k])


# ---------------------------------------------------------------- 명령(원고 @cmd bjs …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"back":                                                         # 회차: 초소 반대쪽으로 물러난다(암전 사이 — 미끄러지지 않게)
			var mins := int(a[1]) if a.size() > 1 else 0
			if post != "":
				st.vars.set_v("BJS_%s_BACK" % post, day())
			if mins > 0 and v("BJS_COOP") < 3:                              # 손을 들었다 = 협조 기록(느린 길로 딱지를 벗는다 — 세 번까지 BJ +1)
				st.vars.set_v("BJS_COOP", v("BJS_COOP") + 1)
				st.call_fn("aff", ["BJ", 1])
			_back(mins, done)
			return
		"fixed":                                                        # 화술 성공: '경위 정정 — 교전, 선후 불명'(그 뒤 정지는 한 줄로 끝)
			st.vars.set_v("BJS_FIXED", 1)
		"wait":                                                         # 등록번호 대조만(통과)
			var mins2 := int(a[1]) if a.size() > 1 else 30
			host.advance_minutes(mins2)
		"pass":
			pass
		"run":                                                          # 정지 명령 불응 — 초소 · 날마다 수배도 +5(재미 검수 ① — 한 번만이면 두 번째부터 공짜 통과)
			if post != "" and v("BJS_%s_PEN" % post) != day():
				st.vars.set_v("BJS_%s_PEN" % post, day())
				st.call_fn("wanted", [5, "bjs"])
	done.call()


func _back(mins: int, done: Callable) -> void:
	var at := Vector2(POSTS.get(post, POSTS["SG"])["at"])
	var me := Vector2(host.map.tile_of(host.player.loco.logical))
	var dir := (me - at).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var to := Vector2i(-1, -1)
	for n in range(BACK, 1, -1):                                        # 물러설 칸이 막혔으면 가까운 칸으로 · 다 막혔으면 제자리
		var c := Vector2i((me + dir * n).round())
		if not host.map.is_solid(c):
			to = c
			break
	host.busy = true
	host.ev.run("fade_out", ["black", "2"], func() -> void:
		if mins > 0:
			host.advance_minutes(mins)
		if to.x >= 0:
			var w := Vector2(to) * 32.0 + Vector2(16, 16)
			host.player.loco.place(w)
			host.player.position = host.player.loco.render
			host.player.loco.facing = Locomotion.snap8(Vector2(dir), 0.0)
			host.player._show()
			host.cam.position = w.round()
			host.cam.reset_smoothing()
		host.ev.run("fade_in", ["black", "2"], func() -> void:
			host.busy = false
			done.call()))
