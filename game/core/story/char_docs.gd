## 캐릭터 생성 서류의 규칙 (SD-10 §2.6·§3.3·§3.4·§8, SD-03a §7.1~7.4, SD-18 §9.1.4). 화면(systems/ui/documents)과 떨어진
## 순수 규칙이라 단위 시험이 직접 부른다. 자료는 파이프라인이 기획서 표에서 뽑은 data/documents.json.
##   이름: 성 1~2자 · 이름 1~4자 · KS X 1001 완성형만 · 금칙 명칭과 같으면 거부. 기본 성 '윤', 이름은 P1 풀에서 성별별 무작위.
##   S.P.E.C.I.A.L.: 기본 5씩 + 5점 = 합계 40, 1~10. 남은 점수가 0이어야 확정.
##   적성: 답마다 그 스킬 1점, 동점이면 더 나중 문항에서 점수를 얻은 스킬이 앞선다. 10-④는 점수 없음. 상위 3 = 추천 태그.
class_name CharDocs
extends RefCounted

const ORDER := ["ST", "PE", "EN", "CH", "IN", "AG", "LK"]
const TOTAL := 40
const REGNO := "S07-2258-0031"
const SEX_M := 1
const SEX_F := 2
## 외형(SD-07b §3, 페이퍼돌 v2가 가진 범위): 머리 12 · 머리색 8 · 피부 6
const HAIRS := ["HR00", "HR01", "HR02", "HR03", "HR04", "HR05", "HR06", "HR07", "HR08", "HR09", "HR10", "HR11"]
const HAIR_NAMES := ["민머리", "짧은 스포츠", "가르마", "짧은 커트", "낮게 묶음", "단발", "긴 생머리", "올림 묶음", "덥수룩",
	"꽁지 묶음", "옆머리 민 머리", "파마"]
const HCOLS := ["H1", "H2", "H3", "H4", "H5", "H6", "H7", "H8"]
const HCOL_NAMES := ["검정", "짙은 갈색", "갈색", "회색", "흰색", "탈색 금발", "붉은 갈색", "청록 염색"]
const SKINS := ["S1", "S2", "S3", "S4", "S5", "S6"]
const DEFAULT_LOOK := {SEX_M: {"hair": "HR03", "hcol": "H1", "skin": "S3"}, SEX_F: {"hair": "HR05", "hcol": "H1", "skin": "S3"}}

static var data: Dictionary


static func load_data(path: String = "res://data/documents.json") -> Dictionary:
	if data.is_empty() and FileAccess.file_exists(path):
		data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data


# ---------------------------------------------------------------- 이름 (SD-18 §9.1.4)
## 잘못이면 화면에 띄울 문장, 맞으면 ""
static func check_name(surname: String, given: String) -> String:
	load_data()
	if surname.length() < 1 or surname.length() > 2:
		return "성은 한 글자나 두 글자로 적습니다."
	if given.length() < 1 or given.length() > 4:
		return "이름은 한 글자에서 네 글자까지 적습니다."
	var allowed: String = data.get("ksx1001", "")
	for ch in surname + given:
		if not allowed.contains(ch):
			return "한글 완성형 글자만 등록할 수 있습니다."
	var banned: Array = data.get("banned", [])
	if (surname + given) in banned or given in banned:
		return "등록할 수 없는 이름입니다."
	return ""


static func random_given(sex: int, rng: RandomNumberGenerator) -> String:
	load_data()
	var pool: Array = data["names"]["female" if sex == SEX_F else "male"]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func default_surname() -> String:
	load_data()
	return data.get("names", {}).get("default_surname", "윤")


# ---------------------------------------------------------------- S.P.E.C.I.A.L. (SD-10 §2.6)
static func points_left(stats: Dictionary) -> int:
	var s := 0
	for c in ORDER:
		s += int(stats[c])
	return TOTAL - s


static func can_raise(stats: Dictionary, c: String) -> bool:
	return int(stats[c]) < 10 and points_left(stats) > 0


static func can_lower(stats: Dictionary, c: String) -> bool:
	return int(stats[c]) > 1


static func default_stats() -> Dictionary:
	var d := {}
	for c in ORDER:
		d[c] = 5
	return d


## 담임 의견(값 1~2 / 3~4 / 5~6 / 7~8 / 9~10)
static func comment(c: String, v: int) -> String:
	load_data()
	for r in data.get("record", []):
		if r["stat"] == c:
			return r["comments"][clampi((v - 1) / 2, 0, 4)]
	return ""


static func record_item(c: String) -> String:
	load_data()
	for r in data.get("record", []):
		if r["stat"] == c:
			return r["item"]
	return c


## 파생 수치 미리보기(SD-10 §2.3): 최대 HP·AP, 소지 한도, 탐지 반경(타일), 레벨업 스킬 포인트
static func derived(stats: Dictionary, level: int = 1) -> Dictionary:
	return {"hp": 90 + int(stats["EN"]) * 20 + level * 10, "ap": 65 + int(stats["AG"]) * 2, "carry": 150 + int(stats["ST"]) * 10,
		"detect": 8 + int(stats["PE"]), "skill_pts": 10 + int(stats["IN"])}


## 스킬 13종 초기값(태그 전, SD-10 §3.3)
static func base_skills(stats: Dictionary) -> Dictionary:
	var out := {}
	for k in StoryState.SKILL_ORDER:
		out[k] = Speech.base_skill(int(stats[StoryState.SKILLS[k][1]]), int(stats["LK"]))
	return out


# ---------------------------------------------------------------- 적성 평가 (SD-03a §7.3)
## answers: 문항 순서대로 1~4(0 = 아직). 돌려줌: 스킬 → {"score", "last"(마지막으로 점수를 얻은 문항 번호)}
static func score(answers: Array) -> Dictionary:
	load_data()
	var out := {}
	var qs: Array = data.get("aptitude", [])
	for i in mini(answers.size(), qs.size()):
		var a := int(answers[i])
		if a < 1 or a > 4:
			continue
		var sk: String = qs[i]["opts"][a - 1]["skill"]
		if sk == "":
			continue                                                   # 10-④: 점수 없음
		var e: Dictionary = out.get(sk, {"score": 0, "last": 0})
		e["score"] += 1
		e["last"] = int(qs[i]["n"])
		out[sk] = e
	return out


## 점수 순위(스킬 키 13개 전부). 점수 → 더 나중 문항 → 스킬 목록 순서(점수 0끼리)
static func ranking(answers: Array) -> Array:
	var sc := score(answers)
	var keys: Array = StoryState.SKILL_ORDER.duplicate()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ea: Dictionary = sc.get(a, {"score": 0, "last": 0})
		var eb: Dictionary = sc.get(b, {"score": 0, "last": 0})
		if ea["score"] != eb["score"]:
			return ea["score"] > eb["score"]
		if ea["last"] != eb["last"]:
			return ea["last"] > eb["last"]
		return StoryState.SKILL_ORDER.find(a) < StoryState.SKILL_ORDER.find(b))
	return keys


static func recommend(answers: Array) -> Array:
	return ranking(answers).slice(0, 3)


static func job(skill: String) -> Dictionary:
	load_data()
	return data.get("jobs", {}).get(skill, {"job": "", "line": ""})


# ---------------------------------------------------------------- 이야기 상태에 적기
static func stats_of(st: StoryState) -> Dictionary:
	var d := {}
	for c in ORDER:
		d[c] = int(st.vars.get_v("PC_" + c))
	return d


static func write_stats(st: StoryState, stats: Dictionary) -> void:
	for c in ORDER:
		st.vars.set_v("PC_" + c, int(stats[c]))


static func tags_of(st: StoryState) -> Array:
	var out := []
	for i in 3:
		var k: String = st.vars.get_v("PC_TAG%d" % (i + 1))
		if k != "":
			out.append(k)
	return out


static func write_tags(st: StoryState, tags: Array) -> void:
	for i in 3:
		st.vars.set_v("PC_TAG%d" % (i + 1), tags[i] if i < tags.size() else "")


static func write_name(st: StoryState, surname: String, given: String) -> void:
	st.vars.set_v("P_SURNAME", surname)
	st.vars.set_v("P_GIVEN", given)
	st.vars.set_v("P_FULL", surname + given)
	st.vars.set_v("P_REGNO", REGNO)


static func look_of(st: StoryState) -> Dictionary:
	var sex := int(st.vars.get_v("PC_SEX"))
	if sex == 0:
		sex = SEX_F
	return {"sex": sex, "hair": st.vars.get_v("PC_HAIR"), "hcol": st.vars.get_v("PC_HCOL"), "skin": st.vars.get_v("PC_SKIN")}


static func write_look(st: StoryState, look: Dictionary) -> void:
	st.vars.set_v("PC_SEX", int(look["sex"]))
	st.vars.set_v("PC_HAIR", look["hair"])
	st.vars.set_v("PC_HCOL", look["hcol"])
	st.vars.set_v("PC_SKIN", look["skin"])


## 페이퍼돌 외형(볼트 작업복 T01)
static func paperdoll_look(look: Dictionary) -> Dictionary:
	return {"body": "F1" if int(look["sex"]) == SEX_F else "M1", "torso": "T01", "skin": look["skin"], "hair_color": look["hcol"],
		"hair": look["hair"], "gear": "", "eyes": "", "weapon": "", "faction": ""}


static func write_aptitude(st: StoryState, answers: Array) -> void:
	st.vars.set_v("PC_APT", ",".join(answers.map(func(a): return str(a))))
	if answers.size() >= 10:
		st.vars.set_v("V_Q10", int(answers[9]))


static func aptitude_of(st: StoryState) -> Array:
	var s: String = st.vars.get_v("PC_APT")
	return Array(s.split(",")).map(func(x): return int(x)) if s != "" else []
