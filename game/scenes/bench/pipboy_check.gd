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
	var k := args.size() > 1 and args[1] == "k"                         # 1-12k: 1막 봉천 · 등록 카드 단계 3(코드 줄 `20 27`) · 원경 표식 넷 · 월드 지도(랜드마크 실루엣)
	if k:
		CharDocs.write_name(host.st, "윤", "서진")
		host.st.vars.set_v("P_REGNO", CharDocs.REGNO)
		for q in ["MQ-P2", "MQ-P3", "MQ-P4"]:
			host.st.quests.set_stage(q, 100)
		host.st.vars.set_v("V_ACT", 1)
		host.st.vars.set_v("V_REGCARD", 3)
		host.st.quests.set_stage("MQ-102", 10)
		host.st.vars.set_v("LM_SEEN", 1 + 2 + 4 + 512)
		host.st.places.raise("L-R01-09", PlaceLog.FOUND)
		host.body = "adult"
		host.enter("X-BC", "from_X-S07")
		host.date_text = "2277. 10. 25.  10:00"
		var pk := host.open_pipboy()
		pk.t_open = 1.0
		if args.size() > 0:
			var ak := args[0].split(",")
			pk.open_at(int(ak[0]), int(ak[1]))
			if ak.size() > 2:
				pk.sel = int(ak[2])
			if ak.size() > 3:                                           # 넷째 = 지도 확대 단계(0 전도 · 1 권역 · 2 구역 · 3 정밀)
				pk.map = PipMap.new(pk)
				pk.map.zoom = int(ak[3])
		return
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
