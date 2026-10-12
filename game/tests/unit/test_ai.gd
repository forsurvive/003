## SD-11 §7.2·§7.3 인지와 상태 머신
extends RefCounted


func test_sight(t) -> void:
	for r in [[3, 9.8], [5, 11.0], [8, 12.8], [10, 14.0]]:
		t.near(Perception.sight_range(r[0]), r[1], 0.001, "시야 거리 인지력 %d" % r[0])


func test_doc_example(t) -> void:
	# 은신 50, 웅크려 천천히, 인지력 5 약탈자, 6t, 밝음 -> 초당 19.3, 의심 약 2초, 발각 약 5초
	var ctx := {"posture": "crouch", "sneak_skill": 50.0, "movement": "sneak", "light": "bright"}
	var rate := Perception.detect_rate(6.0, 5.0, ctx)
	t.near(rate, 19.3, 0.25, "초당 증가(문서는 중간값 0.60·0.67을 반올림해 19.3, 정확값 19.11)")
	t.near(40.0 / rate, 2.0, 0.15, "의심까지")
	t.near(100.0 / rate, 5.0, 0.3, "발각까지")
	var dark := Perception.detect_rate(6.0, 5.0, {"posture": "crouch", "sneak_skill": 50.0, "movement": "sneak", "light": "dark"})
	t.near(40.0 / dark, 3.5, 0.15, "어두우면 의심까지 3.5초")


func test_fov_and_sound(t) -> void:
	t.ok(Perception.in_fov(Vector2.RIGHT, Vector2(1, 0.5), "human"), "정면 쪽")
	t.ok(not Perception.in_fov(Vector2.RIGHT, Vector2(-1, 0), "human"), "등 뒤 안 보임")
	t.ok(Perception.in_fov(Vector2.RIGHT, Vector2(-0.5, -1), "insect"), "곤충 240°: 뒤쪽 116°도 보임")
	t.eq(Perception.sound_gain("pistol", 10.0), 60.0, "권총 12t")
	t.eq(Perception.sound_gain("pistol", 10.0, 1), 0.0, "벽 1장이면 6t")
	t.eq(Perception.sound_gain("melee", 2.0), 40.0, "근접 3t")


func test_state_flow(t) -> void:
	var b := AIBrain.new(Vector2(0, 0))
	var seen := {"sees": true, "rate": 20.0, "target": Vector2(100, 0)}
	var dt := 0.1
	var tt := 0.0
	while b.state == AIBrain.S.IDLE and tt < 10.0:
		b.tick(dt, seen); tt += dt
	t.eq(b.state, AIBrain.S.SUSPICIOUS, "게이지 40 -> 의심")
	t.near(tt, 2.0, 0.11, "초당 20이면 2초")
	while b.state != AIBrain.S.COMBAT and tt < 20.0:
		b.tick(dt, seen); tt += dt
	t.eq(b.state, AIBrain.S.COMBAT, "게이지 100 -> 교전")
	for i in 41:
		b.tick(dt, {"sees": false})
	t.eq(b.state, AIBrain.S.LOST, "시야 이탈 4초 -> 놓침")
	var intent := b.tick(dt, {"sees": false})
	t.eq(intent["goal"], "walk_to", "마지막 목격 위치로")
	t.eq(intent["at"], Vector2(100, 0), "마지막 목격 위치")
	for i in 81:
		b.tick(dt, {"sees": false})
	t.eq(b.state, AIBrain.S.RETURN, "놓침 8초 -> 귀환")
	b.tick(dt, {"sees": false, "at_home": true})
	t.eq(b.state, AIBrain.S.IDLE, "도착 -> 대기")


func test_hit_and_sound(t) -> void:
	var b := AIBrain.new()
	b.tick(0.1, {"hit": true})
	t.eq(b.state, AIBrain.S.COMBAT, "피격 -> 즉시 교전")
	var c := AIBrain.new()
	c.tick(0.1, {"sound": Perception.sound_gain("pistol", 5.0), "sound_at": Vector2(5, 5)})
	t.eq(c.state, AIBrain.S.SUSPICIOUS, "총성 -> 의심")
	for i in 11:
		c.tick(0.1, {})
	t.eq(c.state, AIBrain.S.SEARCH, "의심 1초 -> 수색")
	for i in 121:
		c.tick(0.1, {})
	t.eq(c.state, AIBrain.S.RETURN, "수색 12초 -> 귀환")
	c.tick(0.1, {"dead": true})
	t.eq(c.state, AIBrain.S.DEAD, "사망")
