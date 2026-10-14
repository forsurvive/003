## 단말·해킹 확인 장면(단계 1-4): 단말 하나를 연다. 인자 "단말ID 모드 [고르기 수] [과학]" — 모드 hack(덤프) · menu · read(첫 항목).
## 고르기 수 n이면 해킹 화면에서 오답 n개를 골라 둔다(기록창·시도 표시 확인). 과학 기본 50.
## 실행: godot --path game res://scenes/bench/terminal_check.tscn --write-movie out.png --fixed-fps 4 --quit-after 12 -- TM-J04 hack 2
extends Node

var scr: TerminalScreen


func _ready() -> void:
	var st := StoryState.new()
	st.load_data()
	var args := OS.get_cmdline_user_args()
	var tid := args[0] if args.size() > 0 else "TM-J04"
	var mode := args[1] if args.size() > 1 else "hack"
	var wrong := int(args[2]) if args.size() > 2 else 0
	st.vars.set_v("PC_SKP_SCIENCE", int(args[3]) - st.skill("SCIENCE") if args.size() > 3 else 50 - st.skill("SCIENCE"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terminals.json"))["terms"][tid]
	scr = TerminalScreen.new().setup(st, tid, data, mode == "hack", 777)
	add_child(scr)
	scr.closed.connect(func(ok: bool) -> void: print("단말 닫힘 ", ok))
	if mode == "hack":
		var bad := 0
		for wi in scr.hack.words.size():
			if bad >= wrong:
				break
			if scr.hack.words[wi] != scr.hack.answer:
				scr.pick(scr.hack.starts[wi])
				bad += 1
		for i in Hack.TOTAL:                                          # 커서를 첫 단어 위에(강조 확인)
			if scr.hack.target_at(i)[2] == "word" and scr.hack.removed.size() == 0 and i > 60:
				scr.cur = i
				break
		print("정답 ", scr.hack.answer, " · 단어 ", scr.hack.words)
	elif mode == "read":
		scr._open_entry(0)
