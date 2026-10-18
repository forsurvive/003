## 헤드리스 단위 시험 실행기 (SD-19 §6.17).
## godot --headless --path game -s res://tests/run_tests.gd
## tests/unit/test_*.gd 의 test_ 로 시작하는 함수를 모두 부른다(TEST_ONLY = 함수 이름 조각 · TEST_FILES = 파일 이름 조각 쉼표 목록 · TEST_VERBOSE = 진행 찍기). 각 시험 스크립트는 RefCounted를 상속하고
## 실패 시 fail(msg)을 부르는 대신, 이 실행기가 넘겨주는 T 객체의 eq/ok를 쓴다.
extends SceneTree

class T:
	var failures: Array[String] = []
	var checks := 0
	var where := ""

	func ok(cond: bool, msg: String = "") -> void:
		checks += 1
		if not cond:
			failures.append("%s: %s" % [where, msg])

	func eq(a: Variant, b: Variant, msg: String = "") -> void:
		checks += 1
		if not (typeof(a) == typeof(b) and a == b):
			failures.append("%s: %s  expected <%s> got <%s>" % [where, msg, str(b), str(a)])

	func near(a: float, b: float, eps: float, msg: String = "") -> void:
		checks += 1
		if absf(a - b) > eps:
			failures.append("%s: %s  expected %f±%f got %f" % [where, msg, b, eps, a])


func _init() -> void:
	var t := T.new()
	var dir := DirAccess.open("res://tests/unit")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var only_files := OS.get_environment("TEST_FILES")                   # 쉼표로 나눈 파일 이름 조각 — 그 파일만(시험 사이 영향 찾기)
	if only_files != "":
		var keep: Array[String] = []
		for f in files:
			for part in only_files.split(","):
				if part != "" and f.contains(part):
					keep.append(f)
					break
		files = keep
	var n_tests := 0
	InteriorHost.track = true                                             # 시험마다 남은 host(트리 밖)를 치운다 — 누수가 쌓여 OOM(2026-10-18)
	for f in files:
		var script: GDScript = load("res://tests/unit/" + f)
		if script == null or not script.can_instantiate():              # 문법 오류: 멈추지 말고 실패로 센다
			t.failures.append("%s: 시험 파일을 불러오지 못했다(문법 오류)" % f)
			continue
		var inst = script.new()
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if name.begins_with("test_") and (OS.get_environment("TEST_ONLY") == "" or name.contains(OS.get_environment("TEST_ONLY"))):
				t.where = "%s::%s" % [f, name]
				if OS.get_environment("TEST_VERBOSE") != "":
					print("… ", t.where)
				inst.call(name, t)
				n_tests += 1
				for hh in InteriorHost.made:
					if is_instance_valid(hh) and not hh.is_inside_tree():
						hh.free()
				InteriorHost.made.clear()
	print("단위 시험: 파일 %d, 시험 %d, 확인 %d, 실패 %d" % [files.size(), n_tests, t.checks, t.failures.size()])
	for msg in t.failures:
		printerr("  FAIL " + msg)
	quit(1 if t.failures.size() > 0 else 0)
