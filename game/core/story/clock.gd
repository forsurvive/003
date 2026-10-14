## 게임 시각 글(진행기 date_text, 'YYYY. MM. DD.  HH:MM')에 시간을 더한다(단계 1-2 빠른 이동 · 대기). 날이 바뀌면 GAME_DAY +1.
## 낮밤·시각 체계 전체(조명·일과·72시간 리스폰)는 1-3 이후에 이 글을 대신한다.
class_name Clock
extends RefCounted

const DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


## 글을 [연, 월, 일, 시, 분]으로. 못 읽으면 빈 배열
static func parse(s: String) -> Array:
	var r := RegEx.create_from_string("(\\d+)\\.\\s*(\\d+)\\.\\s*(\\d+)\\.\\s+(\\d+):(\\d+)")
	var m := r.search(s)
	if m == null:
		return []
	return [int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(4)), int(m.get_string(5))]


static func fmt(t: Array) -> String:
	return "%d. %02d. %02d.  %02d:%02d" % t


static func add_hours(s: String, h: int, st: StoryState = null) -> String:
	var t := parse(s)
	if t.is_empty():
		return s
	t[3] += h
	while t[3] >= 24:
		t[3] -= 24
		t[2] += 1
		if st != null and st.vars.has("GAME_DAY"):
			st.vars.set_v("GAME_DAY", int(st.vars.get_v("GAME_DAY")) + 1)
		var dm: int = DAYS[t[1] - 1] + (1 if t[1] == 2 and t[0] % 4 == 0 else 0)
		if t[2] > dm:
			t[2] = 1
			t[1] += 1
			if t[1] > 12:
				t[1] = 1
				t[0] += 1
	return fmt(t)
