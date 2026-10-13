## 조준·탄도 확인 장면(단계 0-7 고침): 보안과 사격장(V-09)에서 열 살 주인공이 BB총으로
##   ① 조준 없이 사대를 걷는다(무기를 들고 있어도 걷는 쪽을 본다 — 뒷걸음 없음): 남쪽 2칸 → 동쪽 5칸
##   ② 제자리에서 16방향으로 쏜다(탄도 360°, 그림은 가까운 8방향, 탄·총구 효과는 16방향 시트)
##   ③ 동쪽 표적을 조준한 채 서쪽으로 걷는다(설계된 뒷걸음: 하체는 조준 쪽, 걸음 역재생, 85% 속도 — SD-11 §2.4).
##      서쪽 벽에 닿으면 그 걸음을 떼지 않고 선다(벽 비비기 없음).
## 단계 전환은 시간이 아니라 자리로 한다 — 녹화 fps(30·10)가 달라도 같은 길을 걷는다.
## 실행: godot --path game res://scenes/bench/aim_check.tscn [--write-movie out.png --fixed-fps 30]
extends Node

const ROW := 18                                                       # 사대 18행: 서쪽 27열이 벽(16·17행은 복도로 이어진다)
const STAND_X := 35                                                   # ②를 쏘는 자리(35, 18)
const ROUTE := [Vector2i(30, ROW), Vector2i(STAND_X, ROW)]            # ①: 남쪽 2칸 → 동쪽 5칸

var host: InteriorHost
var t := 0.0
var phase := 0
var shot_i := 0
var wp := 0
var aim_at := Vector2.INF


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	host = InteriorHost.new()
	add_child(host)
	host.use_keyboard = false
	var st := host.st
	CharDocs.write_name(st, "윤", "서진")
	st.quests.set_stage("MQ-P1", 100)
	st.quests.set_stage("MQ-P2", 50)
	host.body = "kid"
	host.pipboy_ok = true
	host.hud_on = true
	host.enter("V-09", "range_line")
	host.banner_t = 0.0
	st.call_fn("give", ["W-065"])
	st.call_fn("give", ["BB탄", 200])
	host.combat.equip("W-065", st)
	host.combat.bot = {"walk": true}
	host.hint("① 조준 없이 걷기 — 무기를 들어도 걷는 쪽을 본다", 4.0)


## 칸 중심 좌표
static func _c(tx: int, ty: int) -> Vector2:
	return Vector2(tx * 32 + 16, ty * 32 + 16)


## 한 축씩(세로 먼저) 목표로 걷는다. 도착하면 true(보폭 단위로 서므로 8px 안이면 도착).
func _go(to: Vector2) -> bool:
	var me := host.player.loco.logical
	var d := to - me
	if absf(d.y) > 8.0:
		host.input_vec = Vector2(0, signf(d.y))
	elif absf(d.x) > 8.0:
		host.input_vec = Vector2(signf(d.x), 0)
	else:
		host.input_vec = Vector2.ZERO
		return true
	return false


func _process(dt: float) -> void:
	t += dt
	var c := host.combat
	var me := host.player.loco.logical
	match phase:
		0:                                                            # 남쪽 → 동쪽으로 사대를 따라 걷기(조준 없음)
			c.bot = {"walk": true}
			if wp < ROUTE.size():
				if _go(_c(ROUTE[wp].x, ROUTE[wp].y)):
					wp += 1
			elif host.player.loco.motion == "idle" and t > 1.0:
				phase = 1
				t = 0.0
				host.hints.clear()
				host.hint("② 제자리에서 16방향 — 탄은 조준한 각으로 난다(360°)", 5.4)
		1:                                                            # 0.3초마다 22.5°씩 돌며 한 발(북쪽부터 시계 방향)
			host.input_vec = Vector2.ZERO
			var k := int(t / 0.3)
			var ang := deg_to_rad(-90.0 + 22.5 * float(shot_i))
			var aim := me + Vector2(0, -14) + Vector2.RIGHT.rotated(ang) * 120.0
			if k > shot_i and shot_i < 16:
				shot_i += 1
				c.cool = 0.0
				c.bot = {"aim": aim, "fire": true, "aimed": true}
			else:
				c.bot = {"aim": aim}
			if t > 5.6:
				phase = 2
				t = 0.0
				host.hints.clear()
				host.hint("③ 표적을 조준한 채 반대로 걸으면 뒷걸음(85%) — 설계된 동작", 5.0)
		2:                                                            # 정동쪽에 가장 가까이 선 표적을 겨눈 채 서쪽 벽까지
			if aim_at == Vector2.INF:
				var best := INF
				for x in c.targets:
					if x["kind"] == "target" and not x["down"]:
						var d: Vector2 = x["cmb"].pos() - me
						if d.x > 0.0 and absf(d.angle()) < best:
							best = absf(d.angle())
							aim_at = x["cmb"].pos() + Vector2(0, -4)
			if aim_at != Vector2.INF:
				c.bot = {"aim": aim_at}
			host.input_vec = Vector2(-1, 0) if t < 4.0 else Vector2.ZERO
			if t > 5.0:
				get_tree().quit()
