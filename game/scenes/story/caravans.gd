## 순회 상인 일정(단계 1-8d, SD-15 §4.3): 시각·날짜로 정류장에 서고 떠난다. 맵의 인물 cond가 아래 변수를 본다.
## · V54 고개길 수송대(연보경 · 호위 둘 · 짐소 CR-091): 남부 고개길 봉천 → 사당 → 노들섬 남단 → 봉천, 정류장 12시간 + 이동 6시간 = 54시간 한 바퀴.
##   1막엔 봉천 정류장만 있다 — CARAVAN_V54 = 1이면 봉천 아랫문 안 마당에 선다(나머지 42시간은 다른 정류장·길 위).
## · V56 순회 의료반(소윤희): 7일 주기 — 0~1일째 봉천 · 2~3일째 영등포 지하상가 북쪽 출구 · 나머지는 강 건너(탱크마을·뚝섬). MEDIC_AT 1·2·0.
## 정류장에 있는 동안 그 맵에 들어와 있으면 인물을 바로 세우고 치운다(refresh_npcs). 같은 인물은 한 곳에만(SD-20 P3).
class_name Caravans
extends Node

const V54_CYCLE_H := 54
const V54_STAY_H := 12
const V54_OFFSET_H := 30                ## 1막 첫날(10월 23일 14시 무렵)엔 아직 다른 정류장 — 다음 날 저녁 봉천에 처음 온다
const MEDIC_CYCLE := 7

var host: InteriorHost
var st: StoryState
var _t := 0.0


func setup(h: InteriorHost) -> void:
	host = h
	st = h.st


static func v54_at(abs_min: int) -> int:
	var hh := (abs_min / 60 + V54_OFFSET_H) % V54_CYCLE_H
	return 1 if hh < V54_STAY_H else 0


static func medic_at(day: int) -> int:
	var d := posmod(day, MEDIC_CYCLE)
	return 1 if d <= 1 else (2 if d <= 3 else 0)


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	tick()


## 지금 시각으로 두 변수를 맞추고, 바뀌었으면 지금 맵의 인물을 다시 세운다
func tick() -> void:
	if host.date_text == "" or not st.vars.has("CARAVAN_V54"):
		return
	var a := v54_at(Clock.abs_min(host.date_text))
	var b := medic_at(int(st.vars.get_v("GAME_DAY")))
	if a == int(st.vars.get_v("CARAVAN_V54")) and b == int(st.vars.get_v("MEDIC_AT")):
		return
	st.vars.set_v("CARAVAN_V54", a)
	st.vars.set_v("MEDIC_AT", b)
	if host.map != null and not host.box.active and not host.ev.busy():
		host.refresh_npcs()
