## 지하시장 확인 장면(단계 1-4): 1막 진행 상태로 실내 맵 하나를 연다. 인자 "맵 표지 [x,y 주인공 자리] [진행]"
## 진행: 0 막 들어옴 · 1 둥지 맡음(박춘삼 고용) · 2 둥지 비움 · 3 마영식 해독 뒤.
## 실행: godot --path game res://scenes/bench/jm_check.tscn --write-movie out.png --fixed-fps 2 --quit-after 4 -- J-02 from_J-01 40,8
extends Node

var host: InteriorHost


func _ready() -> void:
	host = InteriorHost.new()
	add_child(host)
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		host.st.quests.set_stage(q, 100)
	host.st.quests.set_stage("MQ-101", 100)
	host.st.vars.set_v("V_ACT", 1)
	host.st.vars.set_v("PC_CAPS", 400)
	host.body = "adult"
	host.date_text = "2277. 10. 25.  13:10"
	var a := OS.get_cmdline_user_args()
	var mid := a[0] if a.size() > 0 else "J-02"
	var mark := a[1] if a.size() > 1 else "from_J-01"
	var prog := int(a[3]) if a.size() > 3 else 0
	if prog >= 1:
		host.st.quests.set_stage("MQ-103", 20)
		host.st.vars.set_v("MQ103_JOB", 1)
	if prog >= 2:
		host.st.vars.set_v("MQ103_JOB", 2)
		host.st.vars.set_v("MQ103_NEST", 1)
	if prog >= 3:
		host.st.quests.set_stage("MQ-103", 30)
		host.st.vars.set_v("K_CODE", 1)
	host.st.vars.set_v("MQ103_GATE", 1)
	host.enter(mid, mark)
	if a.size() > 2 and a[2] != "-":
		var p := a[2].split(",")
		host.player.loco.place(Vector2(int(p[0]) * 32 + 16, int(p[1]) * 32 + 16))
		host.player.position = host.player.loco.render
