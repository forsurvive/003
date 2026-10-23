## 레벨업 한 판(단계 1-12p, SD-10 §4.2): 스킬 배분 → 퍽 고르기 → 확정. 레벨 차례대로(PC_LV_DONE + 1).
##   넣던 것은 저장하지 않는다(P10 — 끊기면 미배분 그대로). 앱이 켜져 있는 동안만 StoryState.lv_draft에 남아 핍-보이를 다시 열면 이어진다(재미 검수 ②).
##   배분은 이번 레벨에 넣은 것만 뺄 수 있다 · 표시값 100인 스킬엔 못 넣는다 · 다 넣어야 퍽으로 · 선행 학습(PK-008)은 태그 스킬 4점마다 +1.
class_name LevelDraft
extends RefCounted

var st
var lv := 2                                         ## 지금 배분하는 레벨
var pts := 0                                        ## 이번 레벨 스킬 포인트
var add := {}                                       ## 스킬 → 이번 레벨에 넣은 점수
var step := 0                                       ## 0 스킬 · 1 퍽 · 2 인텐스 트레이닝 능력치
var perk := ""                                      ## 고른 퍽
var stat_pick := ""                                 ## 인텐스 트레이닝으로 올릴 능력치
var start := {}                                     ## 시작할 때 스킬값(문턱 한 마디)


static func begin(state) -> LevelDraft:
	var d := LevelDraft.new()
	d.st = state
	d.lv = maxi(1, int(state.vars.get_v("PC_LV_DONE"))) + 1
	d.pts = Perks.skill_points(state)
	for k in StoryState.SKILL_ORDER:
		d.start[k] = state.skill(k)
	return d


## 지금 쓰는 판이 저장 상태와 맞나(불러오기 · 다른 경로로 배분이 끝났으면 버린다)
func fresh() -> bool:
	return st != null and Perks.pending(st) > 0 and lv == maxi(1, int(st.vars.get_v("PC_LV_DONE"))) + 1


func used() -> int:
	var n := 0
	for k in add:
		n += int(add[k])
	return n


func left() -> int:
	return pts - used()


## 선행 학습: 태그 스킬에 넣은 4점마다 +1(그 레벨 안에서 셈)
func bonus(k: String) -> int:
	if Perks.rank(st, "PK-008") <= 0 or not st.tagged(k):
		return 0
	return int(add.get(k, 0)) / 4


## 화면에 보이는 값(이번 레벨에 넣은 것 · 선행 학습 덤 포함, 상한 100)
func shown(k: String) -> int:
	return mini(100, st.skill(k) + int(add.get(k, 0)) + bonus(k))


func can_add(k: String) -> bool:
	return left() > 0 and shown(k) < 100


func inc(k: String, d: int) -> bool:
	if d > 0:
		if not can_add(k):
			return false
		add[k] = int(add.get(k, 0)) + 1
		return true
	if int(add.get(k, 0)) <= 0:
		return false
	add[k] = int(add[k]) - 1
	if int(add[k]) == 0:
		add.erase(k)
	return true


## 태그 스킬에 고루(터치 · 빠른 배분 — 남은 점수를 태그 스킬에 차례로 하나씩, 100이면 건너뜀). 태그가 다 차면 낮은 스킬부터
func spread_tags() -> void:
	var tags: Array = []
	for k in StoryState.SKILL_ORDER:
		if st.tagged(k):
			tags.append(k)
	var guard := 0
	while left() > 0 and guard < 400:
		guard += 1
		var moved := false
		for k in tags:
			if left() > 0 and inc(k, 1):
				moved = true
		if not moved:
			var low := ""
			for k in StoryState.SKILL_ORDER:
				if can_add(k) and (low == "" or shown(k) < shown(low)):
					low = k
			if low == "" or not inc(low, 1):
				break


## 문턱 한 마디(재미 검수 ②): 이번 배분으로 넘은 자물쇠 · 단말 등급, 예전에 막혔던 자리가 기억나면 그 자리
func thresholds() -> Array:
	var out: Array = []
	for pair in [["LOCKPICK", Lockpick.REQ, Lockpick.NAMES, "자물쇠"], ["SCIENCE", Hack.REQ, Hack.GRADES, "단말"]]:
		var k: String = pair[0]
		var a := int(start.get(k, 0))
		var b := shown(k)
		var req: Array = pair[1]
		for i in req.size():
			if a < int(req[i]) and b >= int(req[i]):
				var line := "이제 '%s' %s도 손댈 수 있다." % [pair[2][i], pair[3]]
				var past := tried_lock(k, int(req[i]))
				if past != "":
					line = "%s %s — 이번엔 될 것 같다." % [line, past]
				out.append(line)
	return out


## 예전에 손을 못 댄 자물쇠 · 단말(StoryState.boxes["tried"]) 가운데 이 등급으로 열리는 것 하나의 자리 이름
func tried_lock(skill_key: String, req: int) -> String:
	var tr: Array = (st.boxes.get("tried", {}) as Dictionary).get(skill_key, [])
	for i in range(tr.size() - 1, -1, -1):
		var e: Dictionary = tr[i]
		if int(e.get("req", 999)) <= req and int(e.get("req", 999)) > int(start.get(skill_key, 0)):
			return str(e.get("where", ""))
	return ""


func pick_ok(id: String) -> bool:
	return Perks.lacks(st, id, lv).is_empty()


## 확정: 포인트 → PC_SKP_ · 퍽 랭크 · 즉시 효과 · PC_LV_DONE. 돌려줌 = 안내 줄들
func confirm() -> Array:
	if left() > 0 or perk == "" or not pick_ok(perk) or (perk == "PK-004" and stat_pick == ""):
		return []
	var notes: Array = []
	for k in add:
		st.vars.set_v("PC_SKP_" + str(k), int(st.vars.get_v("PC_SKP_" + str(k))) + int(add[k]) + bonus(str(k)))
	notes.append_array(thresholds())
	var key := Perks.var_of(perk)
	st.vars.set_v(key, int(st.vars.get_v(key)) + 1)
	notes.append("퍽: %s%s" % [Perks.perk_name(perk), (" (%d랭크)" % Perks.rank(st, perk)) if int(Perks.db.get(perk, {}).get("ranks", 1)) > 1 else ""])
	notes.append_array(_instant(perk))
	st.vars.set_v("PC_LV_DONE", lv)
	return notes


## 즉시형 효과(인텐스 트레이닝 · 히어 앤드 나우 · 카르마 셋 · 노 위크니스 · 올모스트 퍼펙트)
func _instant(id: String) -> Array:
	var out: Array = []
	match id:
		"PK-004":
			out.append_array(_raise({stat_pick: st.stat_raw(stat_pick) + 1}))   # 10을 넘으면 내부값으로 기록(SD-10 §2.1 — 표시는 10)
		"PK-047":
			var nx := Perks.xp_at(Perks.level(st) + 1)
			st.vars.set_v("PC_XP", maxi(int(st.vars.get_v("PC_XP")), nx))
			st.events.append({"kind": "level", "value": Perks.level(st), "from": Perks.level(st) - 1})
		"PK-092":
			st.vars.set_v("V_KARMA", -1000)
		"PK-093":
			st.vars.set_v("V_KARMA", 1000)
		"PK-094":
			st.vars.set_v("V_KARMA", 0)
		"PK-095", "PK-102":
			var to := 5 if id == "PK-095" else 9
			var up := {}
			for c in Perks.STAT_NAMES:
				if st.stat_raw(c) < to:
					up[c] = to                                           # 올모스트 퍼펙트: 기저값에 9 − 기저값(이미 9 이상이면 그대로, §2.7)
			out.append_array(_raise(up))
	return out


## 영구 능력치를 올린다 — 생활기록부 담임 의견이 바뀌면 한 줄(재미 검수 질문 2)
func _raise(up: Dictionary) -> Array:
	var out: Array = []
	for c in up:
		var before := CharDocs.comment(str(c), clampi(st.stat_base(str(c)), 1, 10))
		st.vars.set_v("PC_" + str(c), int(up[c]))
		var after := CharDocs.comment(str(c), clampi(st.stat_base(str(c)), 1, 10))
		if after != before and after != "":
			out.append("생활기록부 %s 칸 문구가 바뀌었다." % Perks.STAT_NAMES[str(c)])
	return out
