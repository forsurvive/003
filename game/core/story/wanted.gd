## 수배도(단계 1-3, SD-12 §9.7 변수·등급·표시 · SD-03a §6.5 진입 시점·막별 하한·메인 증감 · SD-15 §5.7 현상금·해소 비용).
## 변수 `V_WANTED` 0~100 → 등급 0 미등재 · 1 소문(1~29) · 2 수배 공고(30~59) · 3 지명 수배(60~79) · 4 총력 수배(80~100).
## 하한: 1막 등급 1 이상(값 1) · 2~3막 2(30) · 4막은 비상 ≤ −20이면 3(60) · 5~7막은 비상 ≤ −20이면 4(80). 비상정부 신뢰(+50) 이상이면
## 공고 철회 = 0 고정(하한 무시). 하루 상한: 계엄군 사살(목격) +2 하루 +10 · 관리자 인증 +3 하루 +9(비상 신뢰 이상이면 0).
## 등급이 바뀌면 이야기 상태 알림(kind "wanted")을 남긴다 — HUD가 `수배 등급이 올라갔습니다: 수배 공고`.
class_name Wanted
extends RefCounted

const NAMES := ["미등재", "소문", "수배 공고", "지명 수배", "총력 수배"]
const LOWS := [0, 1, 30, 60, 80]
const BOUNTY := [0, 0, 500, 1500, 3000]
const EXECUTE_BOUNTY := 5000                     ## 처단 공고: 등급 4 + 비상정부 적대 + MQ-402 이후(SD-15 §5.7.1)
const DAY_CAP := {"kill": [2, 10], "auth": [3, 9]}   ## 원인 -> [한 번, 하루 상한]
## 엔진 변수(기획서 변수표 밖 — 저장된다): 하루 누계와 그날 번호, 공고 인상착의(마지막으로 목격된 몸통 의복)
const VARS := {"WANTED_DAY": "int", "WANTED_KILL_SUM": "int", "WANTED_AUTH_SUM": "int", "WANTED_LOOK": "str"}


static func declare(st: StoryState) -> void:
	for k in VARS:
		if not st.vars.has(k):
			st.vars.declare(k, VARS[k])


static func value(st: StoryState) -> int:
	return int(st.vars.get_v("V_WANTED"))


static func grade_of(v: int) -> int:
	for g in range(4, -1, -1):
		if v >= LOWS[g]:
			return g if v > 0 or g == 0 else 0
	return 0


static func grade(st: StoryState) -> int:
	return grade_of(value(st))


static func bj(st: StoryState) -> int:
	return int(st.vars.get_v("AFF_BJ")) if st.vars.has("AFF_BJ") else 0


## 공고 철회(비상정부 신뢰 이상)
static func withdrawn(st: StoryState) -> bool:
	return bj(st) >= 50


## 지금 막의 최저 값(SD-03a §6.5 표)
static func floor_value(st: StoryState) -> int:
	if withdrawn(st):
		return 0
	var act := st.quests.cur_act()
	if act <= 0:
		return 0
	if act == 1:
		return LOWS[1]
	if act <= 3:
		return LOWS[2]
	if act == 4:
		return LOWS[3] if bj(st) <= -20 else LOWS[2]
	if act <= 7:
		return LOWS[4] if bj(st) <= -20 else LOWS[2]
	return 0


## 값을 바꾼다(하한·철회 반영). reason = "kill"·"auth"면 하루 상한을 센다. 반환: 새 값
static func add(st: StoryState, delta: int, reason := "") -> int:
	declare(st)
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 0
	if int(st.vars.get_v("WANTED_DAY")) != day:
		st.vars.set_v("WANTED_DAY", day)
		st.vars.set_v("WANTED_KILL_SUM", 0)
		st.vars.set_v("WANTED_AUTH_SUM", 0)
	if DAY_CAP.has(reason):
		if reason == "auth" and withdrawn(st):
			return value(st)
		var key := "WANTED_KILL_SUM" if reason == "kill" else "WANTED_AUTH_SUM"
		var used := int(st.vars.get_v(key))
		delta = clampi(delta, 0, maxi(0, int(DAY_CAP[reason][1]) - used))
		st.vars.set_v(key, used + delta)
	return set_value(st, value(st) + delta)


static func set_value(st: StoryState, v: int) -> int:
	var before := grade(st)
	var nv := 0 if withdrawn(st) else clampi(maxi(v, floor_value(st)), 0, 100)
	st.vars.set_v("V_WANTED", nv)
	var after := grade_of(nv)
	if after != before:
		st.events.append({"kind": "wanted", "grade": after, "up": after > before, "value": nv})
	return nv


## 막이 바뀌었거나 호감도가 움직였을 때 하한을 다시 건다
static func refresh(st: StoryState) -> void:
	set_value(st, value(st))


## 공고 금액(핍-보이 '수배' 칸·전단). 등급 0·1은 공고 없음
static func bounty(st: StoryState) -> int:
	var g := grade(st)
	if g == 4 and bj(st) <= -60 and st.quests.stage("MQ-402") >= 100:
		return EXECUTE_BOUNTY
	return BOUNTY[g]


## 공고 문안 한 줄(SD-03a §6.5: 비상정부 호감도가 오르면 부드러워진다 — 경계 '도주 관리자' · 중립 '관리자 후보, 출두 바람' · 우호 '보호 중')
static func notice(st: StoryState) -> String:
	var g := grade(st)
	if g == 0:
		return "공고 없음."
	if g == 1:
		return "새벽인력 전령이 정착지 게시판에 인상착의 쪽지를 붙였다."
	var b := bj(st)
	var head := "도주 관리자" if b <= -20 else ("관리자 후보, 출두 바람" if b < 20 else "관리자 후보 보호 중, 신고 불요")
	return "%s — %s." % [head, look_text(st)]


## 인상착의: 마지막으로 목격된 몸통 의복 + 나이(SD-12 §9.7 예 `볼트 S-07 작업복 차림, 19세가량`)
static func look_text(st: StoryState, items_db: Dictionary = {}) -> String:
	declare(st)
	var id := str(st.vars.get_v("WANTED_LOOK"))
	var nm := "볼트 S-07 작업복"                                    # 첫 공고(공보방송 '볼트에서 나온 관리 후보')의 문구 — 점프슈트(A-001)
	if id != "" and id != "A-001" and items_db.has(id):
		nm = str(items_db[id].get("name", nm))
	elif id != "" and id != "A-001" and st.names.has(id):
		nm = str(st.names[id])
	return "%s 차림, 19세가량" % nm


## 계엄군·추적대가 주인공을 봤다: 지금 입은 몸통 의복으로 공고를 고친다
static func seen_wearing(st: StoryState, worn: String) -> void:
	declare(st)
	st.vars.set_v("WANTED_LOOK", worn)


## 변장: 지금 입은 옷이 공고와 다르면 무명 NPC 알아보기 확률 절반(SD-12 §9.7)
static func disguised(st: StoryState, worn: String) -> bool:
	declare(st)
	var id := str(st.vars.get_v("WANTED_LOOK"))
	return worn != (id if id != "" else "A-001")
