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


## 시각 글 → 절대 분(2277년 1월 1일 0시 = 0 근처, 비교·72시간 계산용). 못 읽으면 0
static func abs_min(s: String) -> int:
	var t := parse(s)
	if t.is_empty():
		return 0
	var days := (int(t[0]) - 2277) * 365 + (int(t[0]) - 2277) / 4
	for i in int(t[1]) - 1:
		days += DAYS[i] + (1 if i == 1 and int(t[0]) % 4 == 0 else 0)
	days += int(t[2]) - 1
	return days * 1440 + int(t[3]) * 60 + int(t[4])


## 절대 분 → 'MM. DD.'(abs_min의 거꾸로 — 세력 기록 날짜, 1-12m). 0 이하면 빈 글
static func md(a: int) -> String:
	if a <= 0:
		return ""
	var days := a / 1440
	var y := 2277
	while true:
		var n := 365 + (1 if y % 4 == 0 else 0)
		if days < n:
			break
		days -= n
		y += 1
	var m := 0
	while m < 12:
		var dm: int = DAYS[m] + (1 if m == 1 and y % 4 == 0 else 0)
		if days < dm:
			break
		days -= dm
		m += 1
	return "%02d. %02d." % [m + 1, days + 1]


## 요일(0 월 ~ 6 일): 2277. 1. 1.이 월요일(1-12h UQ-10 — 대방 덤 수거는 목요일). 못 읽으면 0(월)
static func weekday(s: String) -> int:
	return (abs_min(s) / 1440) % 7


## 시(0~23). 못 읽으면 12
static func hour(s: String) -> int:
	var t := parse(s)
	return int(t[3]) if not t.is_empty() else 12


## 밤(20~05시, SD-05 §5.1 '밤')
static func is_night(s: String) -> bool:
	var h := hour(s)
	return h >= 20 or h < 6


static func add_hours(s: String, h: int, st: StoryState = null) -> String:
	return add_minutes(s, h * 60, st)


## 분을 더한다(1-3 시각 흐름: 실시간 1초 = 게임 30초, SD-11 §1). 날이 바뀌면 GAME_DAY +1
static func add_minutes(s: String, m: int, st: StoryState = null) -> String:
	var t := parse(s)
	if t.is_empty() or m <= 0:
		return s
	t[4] += m
	t[3] += t[4] / 60
	t[4] = t[4] % 60
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
