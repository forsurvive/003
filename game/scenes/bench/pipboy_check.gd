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
	var k := args.size() > 1 and args[1] in ["k", "m", "s", "lv"]                  # 1-12k: 1막 봉천 · 등록 카드 단계 3(코드 줄 `20 27`) · 원경 표식 넷 · 월드 지도(랜드마크 실루엣)
	var m := args.size() > 1 and args[1] == "m"                         # 1-12m: 판도가 몇 군데 기운 1막(가산 새벽 · 신림 공백 · 영등포 지하시장 지배 · 국회 BJ) + 세력 기록
	if m:
		var st := host.st
		st.vars.set_v("PD_R01_6", 10)
		st.vars.set_v("SQ_S02_CAMP", 1)
		st.quests.set_stage("MQ-103", 100)
		st.vars.set_v("PD_R02_KH", 1)
		st.vars.set_v("AFF_JH", 24)
		st.vars.set_v("AFF_JC_BC", 18)
		st.vars.set_v("AFF_BJ", -22)
		st.vars.set_v("GAME_DAY", 1)
		st.turf.day(st, 1)
		for tl in [Vector2i(849, 1428), Vector2i(892, 1362), Vector2i(959, 1503), Vector2i(1081, 1389), Vector2i(882, 1182), Vector2i(720, 1149), Vector2i(789, 1098)]:
			st.turf.see(st, tl)
		st.vars.set_v("GAME_DAY", 3)
		st.turf.see(st, Vector2i(660, 1460))
		for lid in ["L-R01-09", "L-R01-18", "L-R01-19", "L-R01-23", "L-R02-11", "L-R02-19"]:
			st.places.raise(lid, PlaceLog.FOUND)
		var base := Clock.abs_min("2277. 10. 24.  09:00")
		for h in [["JC_BC", "삼성산 상류 밸브를 되찾아 봉천 배수지에 물이 돌아왔다", 0], ["JC_BC", "남부순환 패거리 두목 삽자루가 죽었다 — 밸브 캠프가 빈다", 1500],
				["JH", "영등포 지하 둥지를 비웠다", 2900], ["SB", "가산 아울렛 작업복 상자를 인솔조에 넘겼다", 3100], ["BJ", "사당 고개 검문소에서 회차 지시를 받았다", 3300]]:
			st.deeds.heard.push_front({"fac": h[0], "what": h[1], "at": base + int(h[2]), "route": "목격", "tag": ""})
	if args.size() > 1 and args[1] == "s":                             # 1-12o: 숨겨 둔 자리 셋(그대로 · 방울 · 털린 줄 앎) + 맡긴 자리(옥탑방)
		var at0 := Clock.abs_min("2277. 10. 23.  18:00")
		host.st.vars.set_v("GAME_DAY", 3)
		host.st.boxes["stash"] = {"n": 1, "qb": 1, "seen": {}, "bundles": [{"id": 1, "key": "c", "state": "held", "who": "crew", "dest": "G-1-1", "day": 3, "items": {}}],
			"spots": {
				"a": {"name": "서류함", "room": "세탁소 뒷방", "wx": 884, "wy": 1352, "since": 1, "since_at": at0, "th": 1, "lock": 0, "kind": "cabinet",
					"seen": {"day": 1, "at": at0, "items": {"W-013": 1, "I-001": 2, "M-001": 140}, "risk": "잠기지 않는 서류함. 사람이 자주 드나드는 동네다.", "p": 0.03},
					"log": [{"at": at0, "text": "삼음"}]},
				"b": {"name": "금고", "room": "빈 살림집", "wx": 905, "wy": 1340, "since": 1, "since_at": at0, "th": 2, "lock": 50, "kind": "safe",
					"seen": {"day": 2, "at": at0 + 1440, "items": {"A-012": 1, "I-030": 3}, "bell": true, "risk": "단단히 잠기는 금고. 가끔 사람이 지나간다. 방울 줄을 매 두었다.", "p": 0.004},
					"log": [{"at": at0, "text": "삼음"}, {"at": at0 + 1440, "text": "방울 맴"}]},
				"c": {"name": "설비 상자", "room": "길가", "wx": 870, "wy": 1371, "since": 1, "since_at": at0, "th": 2, "lock": 0, "kind": "crate",
					"seen": {"day": 3, "at": at0 + 2880, "items": {"I-022": 2}, "risk": "잠기지 않는 설비 상자. 길가라 누구나 지나간다.", "p": 0.018},
					"known": {"day": 3, "at": at0 + 2880, "b": 1, "lost": {"W-013": 1, "I-001": 1}, "left": {"I-022": 2}, "text": "안이 털렸다. 자물쇠 둘레에 쇠지레 자국, 문설주에 분필 'X 털었음'. 군화 자국 셋이 북동쪽으로 골목 몇 개 건너."},
					"log": [{"at": at0, "text": "삼음"}, {"at": at0 + 2880, "text": "털림 — 자물쇠 둘레에 쇠지레 자국, 문설주에 분필 'X 털었음'"}]}},
			"safe": {"B-01|h": {"map": "B-01", "name": "철제 사물함", "seen": {"day": 2, "at": at0 + 1440, "items": {"W-002": 1, "10mm 탄": 24}}}}}
		for lid in ["L-R01-09"]:
			host.st.places.raise(lid, PlaceLog.FOUND)
	var lvm := args.size() > 1 and args[1] == "lv"                      # 1-12p: 레벨업 화면 — 셋째 인자 = 단계(0 스킬 · 1 퍽 · 3 확인), Lv5(미배분 3) · 퍽 둘
	if lvm:
		CharDocs.write_tags(host.st, ["LOCKPICK", "SPEECH", "SMALL_GUNS"])
		host.st.vars.set_v("PC_XP", 1750)
		host.st.vars.set_v("PC_LV_DONE", 2)
		host.st.vars.set_v("PK_006", 1)
		host.st.vars.set_v("PK_003", 1)
		host.st.vars.set_v("PC_SKP_LOCKPICK", 5)
		host.st.boxes["tried"] = {"LOCKPICK": [{"req": 50, "where": "봉천 계단마을의 그 철문", "day": 1}]}
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
			if lvm and ak.size() > 2 and int(ak[2]) < 0:               # 목록(퍽 칸 · 가진 퍽)만
				pk.sel = 0
			elif lvm and ak.size() > 2:
				LevelTab.start(pk)
				var d: LevelDraft = host.st.lv_draft
				for i in 15:
					d.inc("LOCKPICK", 1)                               # 자물쇠 문턱(50)을 넘겨 문턱 한 마디가 찍히게
				pk.sel = 4
				if int(ak[2]) >= 1:
					d.spread_tags()
					d.step = 1
					pk.sel = 1
				if int(ak[2]) >= 3:
					d.perk = "PK-007"
					d.step = 3
			if ak.size() > 4 and not lvm:                               # 다섯째 = 판도 레이어(L) · 강조 세력(L:JH)
				pk.map.layer = true
				pk.map.focus = ak[4].substr(2) if ak[4].length() > 2 else ""
				pk.map.cursor = Vector2(800, 1330)
				pk.map.center = pk.map.cursor
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
