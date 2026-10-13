## 이야기 상태 (SD-19 §6.9): 변수 저장소 + 퀘스트 + 주인공 서류(S.P.E.C.I.A.L.·태그·스킬) + 소지품 + 판정 기록.
## 조건·효과 식(StoryExpr)의 컨텍스트이고, 대화 실행기·이벤트 실행기·UI가 모두 이것 하나를 본다. 노드를 쓰지 않는 순수 객체.
class_name StoryState
extends RefCounted

## S.P.E.C.I.A.L.(SD-10 §2): 코드 → 화면 이름
const STATS := {"ST": "힘", "PE": "인지력", "EN": "지구력", "CH": "카리스마", "IN": "지능", "AG": "민첩성", "LK": "행운"}
## 스킬 13종(SD-10 §3.2): 키 → [화면 이름, 연관 능력치]
const SKILLS := {
	"BARTER": ["물물교환", "CH"], "BIG_GUNS": ["중화기", "EN"], "ENERGY": ["에너지 무기", "PE"], "EXPLOSIVES": ["폭발물", "PE"],
	"LOCKPICK": ["자물쇠 따기", "PE"], "MEDICINE": ["의학", "IN"], "MELEE": ["근접 무기", "ST"], "REPAIR": ["수리", "IN"],
	"SCIENCE": ["과학", "IN"], "SMALL_GUNS": ["소형 화기", "AG"], "SNEAK": ["은신", "AG"], "SPEECH": ["화술", "CH"],
	"UNARMED": ["비무장", "EN"],
}
const SKILL_ORDER := ["BARTER", "BIG_GUNS", "ENERGY", "EXPLOSIVES", "LOCKPICK", "MEDICINE", "MELEE", "REPAIR", "SCIENCE",
	"SMALL_GUNS", "SNEAK", "SPEECH", "UNARMED"]
const KARMA_RANGE := 1000
const AFF_RANGE := 100

var vars := VarStore.new()
var quests: QuestLog
var items := {}                         ## 아이템 ID -> 개수
var failed_checks := {}                 ## 실패한 화술 판정 ID(같은 NPC에게 다시 나오지 않는다)
var check_seed := 0                     ## 판정 고정 씨앗(새 게임 때 정한다)
var npcs := {}                          ## 인물 ID -> 자료(이름·세력·외형 등, game/data/npcs.json)
var names := {}                         ## 아이템·장소 ID -> 이름(\I·\L)
var weapon_out := false
var events: Array = []                  ## 알림: [{"kind": "karma"|"item"|"xp"|"aff"|"caps", ...}]
var fns := {}                           ## 추가 함수(이벤트 실행기 등이 등록): 이름 -> Callable(args: Array) -> Variant
var portrait_alias := {}                ## 인물 ID -> 초상화 키(맵에서 다른 시대 모습으로 선 인물: 2259년 아이 하도윤 등)


func _init() -> void:
	quests = QuestLog.new(vars)
	for c in STATS:
		vars.declare("PC_" + c, "int", 5)
	for i in 3:
		vars.declare("PC_TAG%d" % (i + 1), "str", "")
	for k in SKILLS:
		vars.declare("PC_SKP_" + k, "int", 0)         # 레벨업·책 등으로 더한 영구 증가분
	for k in ["PC_CAPS", "PC_XP", "PC_SEX"]:
		vars.declare(k, "int", 0)
	for k in ["P_SURNAME", "P_GIVEN", "P_FULL", "P_REGNO", "PC_APT"]:   # PC_APT: 적성 평가 답 10개(결과지 다시 보기)
		vars.declare(k, "str", "")
	for kv in [["PC_HAIR", "HR05"], ["PC_HCOL", "H1"], ["PC_SKIN", "S3"]]:   # 외형(SD-10 §8.3). PC_SEX 1 남 · 2 여
		vars.declare(kv[0], "str", kv[1])


## 기본 자료(변수 선언·퀘스트·인물)를 읽는다. 시험은 이 함수를 건너뛰고 직접 선언할 수 있다.
func load_data(dir: String = "res://data/") -> void:
	if FileAccess.file_exists(dir + "vars.json"):
		vars.load_decls(dir + "vars.json")
	if FileAccess.file_exists(dir + "quests.json"):
		quests.load_defs(dir + "quests.json")
	if FileAccess.file_exists(dir + "npcs.json"):
		npcs = JSON.parse_string(FileAccess.get_file_as_string(dir + "npcs.json"))["npcs"]


# ---------------------------------------------------------------- 식 언어 컨텍스트
func get_var(name: String) -> Variant:
	return vars.get_v(name)


func set_var(name: String, v: Variant) -> bool:
	return vars.set_v(name, v)


func call_fn(name: String, args: Array) -> Variant:
	match name:
		"karma":
			var nv := vars.add("V_KARMA", int(args[0]), -KARMA_RANGE, KARMA_RANGE)
			events.append({"kind": "karma", "delta": int(args[0]), "value": nv})
			return nv
		"aff":
			var key := _aff_key(str(args[0]))
			if key == "":
				vars._err("알 수 없는 호감도 대상: " + str(args[0]))
				return null
			var nv := vars.add(key, int(args[1]), -AFF_RANGE, AFF_RANGE)
			events.append({"kind": "aff", "key": key, "delta": int(args[1]), "value": nv})
			return nv
		"quest":
			quests.set_stage(str(args[0]), int(args[1]))
			return quests.stage(str(args[0]))
		"stage":
			return quests.stage(str(args[0]))
		"result":
			vars.set_v(quests.key_of(str(args[0])) + "_RESULT", int(args[1]))
			return int(args[1])
		"give":
			var n := int(args[1]) if args.size() > 1 else 1
			items[str(args[0])] = int(items.get(str(args[0]), 0)) + n
			events.append({"kind": "item", "id": str(args[0]), "delta": n})
			return items[str(args[0])]
		"take":
			var n := int(args[1]) if args.size() > 1 else 1
			var left := maxi(0, int(items.get(str(args[0]), 0)) - n)
			if left == 0:
				items.erase(str(args[0]))
			else:
				items[str(args[0])] = left
			events.append({"kind": "item", "id": str(args[0]), "delta": -n})
			return left
		"has":
			var n := int(args[1]) if args.size() > 1 else 1
			return 1 if int(items.get(str(args[0]), 0)) >= n else 0
		"caps":
			var nv := vars.add("PC_CAPS", int(args[0]), 0)
			events.append({"kind": "caps", "delta": int(args[0]), "value": nv})
			return nv
		"xp":
			var nv := vars.add("PC_XP", int(args[0]), 0)
			events.append({"kind": "xp", "delta": int(args[0]), "value": nv})
			return nv
		"wanted":
			return vars.add("V_WANTED", int(args[0]), 0, 100)
		"stat":
			return stat(str(args[0]))
		"skill":
			return skill(str(args[0]))
		"year":
			return year()
	if fns.has(name):
		return (fns[name] as Callable).call(args)
	vars._err("알 수 없는 함수: %s(%s)" % [name, str(args)])
	return null


## 지금 이야기 연도(프롤로그 시대 구분: 맵의 사람·소품을 고른다). 퀘스트 진행으로 정한다:
## MQ-P1 출생 2258 → 돌잔치(단계 20~) 2259 → MQ-P2 2268 → MQ-P3 2274 → MQ-P4 이후 2277
func year() -> int:
	if quests.stage("MQ-P4") > 0 or quests.stage("MQ-101") > 0:
		return 2277
	if quests.stage("MQ-P3") > 0:
		return 2274
	if quests.stage("MQ-P2") > 0:
		return 2268
	if quests.stage("MQ-P1") >= 20:
		return 2259
	return 2258


func _aff_key(code: String) -> String:
	for k in ["AFF_" + code, "AFF_JC_" + code]:
		if vars.has(k):
			return k
	return ""


# ---------------------------------------------------------------- 주인공 서류
func stat_code(name: String) -> String:
	if STATS.has(name):
		return name
	for c in STATS:
		if STATS[c] == name:
			return c
	return ""


func stat(name: String) -> int:
	var c := stat_code(name)
	return int(vars.get_v("PC_" + c)) if c != "" else 0


func skill_key(name: String) -> String:
	if SKILLS.has(name):
		return name
	for k in SKILLS:
		if SKILLS[k][0] == name:
			return k
	return ""


func tagged(key: String) -> bool:
	for i in 3:
		if vars.get_v("PC_TAG%d" % (i + 1)) == key:
			return true
	return false


## 스킬값(SD-10 §3.3): 초기값 + 태그 15 + 영구 증가분, 표시 상한 100
func skill(name: String) -> int:
	var k := skill_key(name)
	if k == "":
		return 0
	var v := Speech.base_skill(stat(SKILLS[k][1]), stat("LK")) + (15 if tagged(k) else 0) + int(vars.get_v("PC_SKP_" + k))
	return mini(v, 100)


## NPC 대상 화술 성공 확률(SD-10 §3.5.8). 인물 자료에 기본 호감·책임감이 없으면 50·50.
func speech_chance(npc_id: String, diff: String) -> float:
	var n: Dictionary = npcs.get(npc_id, {})
	var fac := 0.0
	var fk := _aff_key(str(n.get("faction", "")))
	if fk != "":
		fac = float(vars.get_v(fk))
	return Speech.chance(stat("CH"), weapon_out, float(n.get("aff", 50)), fac, float(n.get("resp", 50)),
		float(vars.get_v("V_KARMA") if vars.has("V_KARMA") else 0), skill("SPEECH"), diff)


func npc_name(id: String) -> String:
	return str(npcs[id]["name"]) if npcs.has(id) else id


func player_full() -> String:
	return str(vars.get_v("P_SURNAME")) + str(vars.get_v("P_GIVEN"))


# ---------------------------------------------------------------- 저장
func dump() -> Dictionary:
	var it := {}
	var ks := items.keys()
	ks.sort()
	for k in ks:
		it[k] = items[k]
	var fc := failed_checks.keys()
	fc.sort()
	return {"vars": vars.dump(), "items": it, "failed": fc, "seed": check_seed}


func restore(d: Dictionary) -> void:
	vars.restore(d.get("vars", {}))
	items = {}
	for k in d.get("items", {}):
		items[k] = int(d["items"][k])
	failed_checks = {}
	for k in d.get("failed", []):
		failed_checks[k] = true
	check_seed = int(d.get("seed", 0))
