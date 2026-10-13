## 핍-보이 확인 장면(단계 0-7): MQ-P2 사격장 직후 상태로 핍-보이를 연다. 인자 "탭,하위,줄"로 화면을 고른다.
## 둘째 인자 p3이면 MQ-P3 결과지 직후(2274, 등록 카드 단계 1 · 특별 퍽, 단계 0-8).
## 실행: godot --path game res://scenes/bench/pipboy_check.tscn --write-movie out.png --fixed-fps 2 --quit-after 3 -- 1,0 [p3]
extends Node
func _ready() -> void:
	var host := InteriorHost.new()
	add_child(host)
	host.st.quests.set_stage("MQ-P1", 100)
	host.st.quests.set_stage("MQ-P2", 50)
	host.body = "kid"
	var args := OS.get_cmdline_user_args()
	var p3 := args.size() > 1 and args[1] == "p3"
	if p3:
		CharDocs.write_name(host.st, "윤", "서진")
		host.st.vars.set_v("P_REGNO", CharDocs.REGNO)
		host.st.quests.set_stage("MQ-P2", 100)
		host.st.quests.set_stage("MQ-P3", 100)
		host.st.vars.set_v("V_REGCARD", 1)
		CharDocs.write_tags(host.st, ["MELEE", "REPAIR", "SMALL_GUNS"])
		host.body = "adult"
	host.enter("V-09" if not p3 else "V-03", "from_V-01")
	for kv in [["W-065", 1], ["BB탄", 150], ["I-001", 2], ["M-201", 1], ["W-067", 1], ["A-001", 1]]:
		host.st.call_fn("give", kv)
	host.combat.equip("W-065", host.st)
	host.date_text = "2268. 03. 02.  13:40" if not p3 else "2274. 09. 02.  11:20"
	var p := host.open_pipboy()
	p.t_open = 1.0
	if args.size() > 0:
		var a := args[0].split(",")
		p.open_at(int(a[0]), int(a[1]))
		if a.size() > 2:
			p.sel = int(a[2])
