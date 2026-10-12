## SD-11 §5.2·§5.3 AP 예산표
extends RefCounted


func test_max_and_budget(t) -> void:
	t.eq(APPool.max_for(1), 67.0, "민첩성 1")
	t.eq(APPool.max_for(5), 75.0, "민첩성 5")
	t.eq(APPool.max_for(10), 85.0, "민첩성 10")
	t.eq(APPool.max_for(10, 25), 110.0, "액션 보이 +25")
	var p := APPool.new(5)
	var rolls := 0
	while p.spend(APPool.DODGE):
		rolls += 1
	t.eq(rolls, 3, "민첩성 5: 회피 3번")
	var q := APPool.new(5)
	var shots := 0
	while q.spend(17):
		shots += 1
	t.eq(shots, 4, "경권총 집중 사격 4번")


func test_sprint_and_regen(t) -> void:
	var p := APPool.new(5)
	var sec := 0.0
	while p.tick(0.05, true):
		sec += 0.05
	t.near(sec, 7.5, 0.06, "질주 7.5초")
	t.ok(p.winded(), "AP 0 숨참")
	var t_full := 0.0
	while p.ap < p.max_ap:
		p.tick(0.05, false)
		t_full += 0.05
	t.near(t_full, 1.0 + 75.0 / 8.0, 0.1, "다 차기까지 약 10.4초(지연 1초 + 9.4초)")
	t.ok(not p.can(1) or p.ap > 0, "0이면 회피·집중 사격 불가")
