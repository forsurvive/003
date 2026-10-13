## 핍-보이 확인 장면(단계 0-7): MQ-P2 사격장 직후 상태로 핍-보이를 연다. 인자 "탭,하위,줄"로 화면을 고른다.
## 실행: godot --path game res://scenes/bench/pipboy_check.tscn --write-movie out.png --fixed-fps 2 --quit-after 3 -- 1,0
extends Node
func _ready() -> void:
	var host := InteriorHost.new()
	add_child(host)
	host.st.quests.set_stage("MQ-P1", 100)
	host.st.quests.set_stage("MQ-P2", 50)
	host.body = "kid"
	host.enter("V-09", "from_V-01")
	for kv in [["W-065", 1], ["BB탄", 150], ["I-001", 2], ["M-201", 1], ["W-067", 1], ["A-001", 1]]:
		host.st.call_fn("give", kv)
	host.combat.equip("W-065", host.st)
	host.date_text = "2268. 03. 02.  13:40"
	var p := host.open_pipboy()
	p.t_open = 1.0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var a := args[0].split(",")
		p.open_at(int(a[0]), int(a[1]))
		if a.size() > 2:
			p.sel = int(a[2])
