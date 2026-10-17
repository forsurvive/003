## 던전 체계(1-D0, SD-14 §11.3 · 설계안 docs/seoul-fallout/_plans/1-D_dungeons_plan.md): 쓰러뜨린 맵 자리는 72게임시간(3일) 비어 있다 ·
## 우두머리는 다시 서지 않는다 · 기록은 저장(st.boxes)에 남는다
extends RefCounted


func test_kill_respawn(t) -> void:
	var h := InteriorHost.new()
	h._ready()
	h.body = "adult"
	h.st.quests.set_stage("MQ-P4", 100)
	h.st.vars.set_v("GAME_DAY", 5)
	var mid := ""
	for f in InteriorMap.gen_ids():
		var m: Dictionary = InteriorMap.read_data(f)
		if (m["enemies"] as Array).size() >= 2:
			mid = str(f)
			break
	t.ok(mid != "", "적이 둘 이상인 생성 실내")
	h.enter(mid, "from_W")
	var n0 := h.combat.alive_enemies()
	var e: Enemy = h.combat.enemies[0]
	e.cmb.last_by = "player"
	e.cmb.take({"hp": 99999.0}, e.loco.logical)
	t.eq(h.combat.alive_enemies(), n0 - 1, "하나를 쓰러뜨렸다")
	h.enter(mid, "from_W")
	t.eq(h.combat.alive_enemies(), n0 - 1, "다시 들어가도 쓰러뜨린 자리는 비어 있다")
	h.st.vars.set_v("GAME_DAY", 7)
	h.enter(mid, "from_W")
	t.eq(h.combat.alive_enemies(), n0 - 1, "이틀 뒤에도 비어 있다")
	h.st.vars.set_v("GAME_DAY", 8)
	h.enter(mid, "from_W")
	t.eq(h.combat.alive_enemies(), n0, "사흘(72게임시간)이 지나면 다시 선다(SD-14 §11.3)")
	h.st.boxes["kill:X:1,1"] = {"day": 1, "boss": true}
	h.st.vars.set_v("GAME_DAY", 99)
	t.ok(not InteriorCombat.respawn_due(h.st, "kill:X:1,1"), "우두머리는 다시 서지 않는다")
	h.free()
