## 헤드리스 단위 시험 실행기 (SD-19 §6.17).
## godot --headless --path game -s res://tests/run_tests.gd
## tests/unit/test_*.gd 의 test_ 로 시작하는 함수를 모두 부른다(TEST_ONLY = 함수 이름 조각 · TEST_FILES = 파일 이름 조각 쉼표 목록 · TEST_VERBOSE = 진행 찍기). 각 시험 스크립트는 RefCounted를 상속하고
## 실패 시 fail(msg)을 부르는 대신, 이 실행기가 넘겨주는 T 객체의 eq/ok를 쓴다.
## 시험이 도는 동안 난 SCRIPT ERROR(null 호출 · 없는 함수 등 — 함수가 그 자리에서 끊긴다)와 스크립트가 일으킨 엔진 ERROR(역추적이 붙은 것 —
## 같은 시그널 두 번 잇기 · push_error 등)도 그 시험의 실패로 센다(장부 D-412 — 전엔 끊긴 시험이 '실패 0'으로 지나갔고, 배포판은 같은 null 호출에서 죽는다).
## 일부러 오류를 내는 시험은 t.expect_errors(n)으로 그 수를 미리 밝힌다. 경고(push_warning)는 실패가 아니라 끝에 수만 찍는다.
extends SceneTree


## 엔진 기록을 엿듣는다(Godot 4.5+ Logger) — 다른 스레드에서도 불린다
class Errs extends Logger:
	var mu := Mutex.new()
	var errors: Array[String] = []
	var warnings := 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _notify: bool, error_type: int,
			script_backtraces: Array[ScriptBacktrace]) -> void:
		mu.lock()
		if error_type == ERROR_TYPE_SCRIPT or (error_type == ERROR_TYPE_ERROR and not script_backtraces.is_empty()):
			var at := ""
			for bt in script_backtraces:
				if bt.get_frame_count() > 0:
					at = "%s:%d" % [bt.get_frame_file(0), bt.get_frame_line(0)]
					break
			errors.append("%s %s%s (%s)" % ["SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT else "ERROR", code, (" — " + rationale) if rationale != "" else "",
				at if at != "" else "%s:%d %s" % [file, line, function]])
		elif error_type == ERROR_TYPE_WARNING:
			warnings += 1
		mu.unlock()

	func take() -> Array[String]:
		mu.lock()
		var out := errors.duplicate()
		errors.clear()
		mu.unlock()
		return out

class T:
	var failures: Array[String] = []
	var checks := 0
	var where := ""
	var allowed := 0                                                     ## 이 시험이 일부러 내는 오류 수(expect_errors)

	## 오류 경로를 시험할 때: 이 시험에서 일부러 n개의 오류가 난다고 밝힌다(그 수까지는 실패가 아니다)
	func expect_errors(n: int) -> void:
		allowed += n

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
	var errs := Errs.new()
	OS.add_logger(errs)
	var n_err := 0
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
				t.allowed = 0
				errs.take()                                                    # 앞 시험 정리 중에 난 것은 앞 시험 몫(아래에서 이미 셈)
				inst.call(name, t)
				n_tests += 1
				var got := errs.take()
				if got.size() > t.allowed:
					n_err += got.size() - t.allowed
					for e in got.slice(0, 3):
						t.failures.append("%s: %s" % [t.where, e])
					if got.size() > 3:
						t.failures.append("%s: … 오류 %d개 더" % [t.where, got.size() - 3])
				for hh in InteriorHost.made:
					if is_instance_valid(hh) and not hh.is_inside_tree():
						hh.free()
				InteriorHost.made.clear()
	OS.remove_logger(errs)
	print("단위 시험: 파일 %d, 시험 %d, 확인 %d, 실패 %d(그 가운데 오류 %d) · 경고 %d" % [files.size(), n_tests, t.checks, t.failures.size(), n_err, errs.warnings])
	for msg in t.failures:
		printerr("  FAIL " + msg)
	quit(1 if t.failures.size() > 0 else 0)
