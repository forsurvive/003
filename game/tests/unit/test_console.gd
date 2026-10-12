## 디버그 콘솔 명령 해석(엔진 무관 부분)
extends RefCounted


func test_parse(t) -> void:
	t.eq(Array(DebugConsole.parse("tp L-R01-01")["args"]), ["L-R01-01"], "장소 ID")
	t.eq(DebugConsole.parse("  TP 179 175 ")["cmd"], "tp", "대소문자·공백")
	t.ok(not DebugConsole.parse("tp a b")["ok"], "tp 두 인자는 정수")
	t.ok(DebugConsole.parse("set hp max")["ok"], "set max")
	t.ok(DebugConsole.parse("set ap 12.5")["ok"], "set 숫자")
	t.ok(not DebugConsole.parse("set luck 9")["ok"], "모르는 변수")
	t.ok(not DebugConsole.parse("set hp lots")["ok"], "숫자 아님")
	t.ok(DebugConsole.parse("show detect")["ok"], "show")
	t.ok(not DebugConsole.parse("show everything")["ok"], "모르는 표시")
	t.ok(not DebugConsole.parse("skip soon")["ok"], "skip 숫자")
	t.ok(not DebugConsole.parse("god now")["ok"], "인자 수")
	t.eq(DebugConsole.parse("")["err"], "", "빈 줄은 조용히")
	t.ok((DebugConsole.parse("fly")["err"] as String).begins_with("모르는 명령"), "모르는 명령")
