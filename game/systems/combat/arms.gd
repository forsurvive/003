## 무기 계열(SD-11 §3 · SD-13 §3.2, 단계 1-9a): 계열 = 모션·사격 방식, 스킬 = 수치.
## data/weapons.json의 family·proj·pellets·blast·dot… 필드를 읽고, 없으면(옛 자료·제작 무기) 레이어·이름으로 채운다.
## 순수 함수만(전투 모듈·적 AI·시험이 같이 쓴다).
class_name Arms
extends RefCounted

const T := 32.0
## 투사체 속도(타일/초, SD-11 §3.3). 레이저는 히트스캔(한 프레임에 끝까지 간다)
const SPEED := {"bullet": 40.0, "pellet": 35.0, "plasma": 14.0, "dart": 25.0, "nail": 30.0, "missile": 10.0, "missile_max": 18.0,
	"junk": 22.0, "flare": 25.0, "net": 20.0, "shock": 25.0, "tesla": 16.0, "flame": 6.0, "acid": 12.0}
## 충돌 반지름(타일): 실탄 0.05 · 플라스마 0.15 · 미사일 0.2 · 화염 입자 0.3
const RADIUS := {"plasma": 0.15, "missile": 0.2, "tesla": 0.2, "flame": 0.3, "nail": 0.08, "junk": 0.12, "acid": 0.15}
## 곡사(SD-11 §3.3 '곡사탄'): 비행 0.6~1.2초, 가짜 높이. 핵 투사기 최소 사거리 6t
const ARC_MIN_T := {"nuke": 6.0, "grenade": 1.5}
## 폭발 반경(타일, 내부 / 외부) — SD-11 §9.2 표 + 정합(유탄 = 파편 수류탄, 미사일 1.0/3.0, 방전포 0.8/2.0)
const BLAST_R := {"grenade": [0.8, 2.5], "missile": [1.0, 3.0], "tesla": [0.8, 2.0], "nuke": [2.0, 5.0], "mine": [0.6, 1.8], "capmine": [0.8, 2.2],
	"emp": [1.0, 3.0], "car": [1.5, 4.0], "drum": [0.8, 2.5], "gas": [1.0, 2.0], "robot": [0.5, 1.5]}
## ↑ 지뢰 0.6/1.8 · 병뚜껑 지뢰 0.8/2.2 · 펄스(수류탄·지뢰) 1.0/3.0(§9.2 표) · 1-9c 환경 폭발: 원자력 차량 1.5/4 · 드럼·가스통 0.8/2.5 · 가스 누출 1.0/2.0 · 로봇 0.5/1.5(§9.3)
## 근접 호(반각°)·최대 인원(SD-11 §3.4): 한손 90°·3명, 양손 140°·4명, 비무장 70°·2명
const MELEE := {"melee1": [45.0, 3], "melee2": [70.0, 4], "unarmed": [35.0, 2]}
const POWER_HOLD_S := 0.5                         ## 길게 누르면 파워 공격(피해 ×2, 0.6t 전진)
const POWER_LUNGE_T := 0.6
const FIST := "W-052"                            ## 맨주먹(무기 레이어 없음)


static func fam(w: Dictionary) -> String:
	var f := str(w.get("family", ""))
	if f != "":
		return f
	var l := str(w.get("layer", ""))
	match l.substr(0, 1):
		"P": return "pistol"
		"R": return "rifle"
		"S": return "shotgun"
		"H": return "heavy"
		"M": return "melee1"
		"T": return "melee2"
		"U": return "unarmed"
		"X": return "mine" if l == "X02" else "thrown"
	if str(w.get("kind", "")) in ["thrown", "mine"]:
		return str(w["kind"])
	return "unarmed" if str(w.get("kind", "")) == "unarmed" else ("melee1" if str(w.get("kind", "")) == "melee" else "pistol")


static func proj(w: Dictionary) -> String:
	var p := str(w.get("proj", ""))
	if p != "" or str(w.get("kind", "ranged")) != "ranged":
		return p
	return "pellet" if fam(w) == "shotgun" else "bullet"


## 스킬 키(StoryState.skill이 한글 이름도 받는다)
static func skill_name(w: Dictionary) -> String:
	var s := str(w.get("skill", ""))
	if s != "":
		return s
	return {"melee1": "근접 무기", "melee2": "근접 무기", "unarmed": "비무장", "heavy": "중화기"}.get(fam(w), "소형 화기")


## 페이퍼돌 손 무기(chibi.gun 종류)
static func doll(w: Dictionary) -> String:
	var l := str(w.get("layer", ""))
	var p := proj(w)
	match fam(w):
		"pistol":
			return "pistol"
		"rifle":
			if l == "R03":
				return "smg"
			return "laser" if p in ["laser", "plasma"] else "rifle"
		"shotgun":
			return "shotgun"
		"heavy":
			if p == "flame":
				return "flamer"
			return "minigun" if p in ["bullet", "laser"] else "launcher"
		"melee1":
			return "baton" if l in ["M03", "M04"] else "knife"
		"melee2":
			return "sledge" if l in ["T03", "T04", "T05"] else "bat"
		"thrown":
			return "grenade"                                      # X01 투척 손 · X02 설치는 맨손(SD-13 §3.2)
	return ""


## 총구 효과 세트(CombatFx): 계열·투사체별
static func flash(w: Dictionary) -> String:
	if str(w.get("sound", "")) == "suppressed":
		return "flash_air"
	match proj(w):
		"laser": return "flash_laser"
		"plasma", "tesla": return "flash_plasma"
		"flame": return "flash_flame"
		"": return ""
	match fam(w):
		"shotgun": return "flash_shotgun"
		"heavy": return "flash_heavy"
	return "flash_pistol"


## 투사체 그림 세트
static func sprite(p: String) -> String:
	return {"pellet": "pellet", "plasma": "plasma", "tesla": "tesla", "missile": "missile", "grenade": "shell", "nuke": "shell",
		"nail": "nail", "dart": "dart", "junk": "junk", "flame": "flame", "acid": "acid"}.get(p, "bullet")


static func speed(p: String) -> float:
	return float(SPEED.get(p, 40.0)) * T


static func radius(p: String) -> float:
	return float(RADIUS.get(p, 0.05)) * T


static func is_arc(p: String) -> bool:
	return p in ["grenade", "nuke"]


static func blast_r(p: String) -> Array:
	return BLAST_R.get(p, [0.8, 2.5])


## 탄 1발이 쓰는 탄약 수(쌍열 산탄총 2)
static func per_shot(w: Dictionary) -> int:
	return maxi(1, int(w.get("ammo_per_shot", 1)))


static func pellets(w: Dictionary) -> int:
	return maxi(1, int(w.get("pellets", 9 if fam(w) == "shotgun" else 1)))


## 펠릿 원뿔 반각(°): 자료에 없으면 9°
static func cone(w: Dictionary) -> float:
	var c := float(w.get("cone", 0.0))
	if c <= 0.0 and fam(w) == "shotgun":
		c = 9.0
	return c


## 정조준 자세 배수: 중화기는 허리 거치라 ×0.75(SD-11 §3.4)
static func aim_stance(w: Dictionary, aiming: bool, crouch: bool) -> String:
	if aiming and fam(w) == "heavy":
		return "heavy_aim"
	return ("crouch_aim" if aiming else "crouch") if crouch else ("aim" if aiming else "stand")


static func melee_arc(w: Dictionary) -> float:
	return deg_to_rad(float(MELEE.get(fam(w), MELEE["melee1"])[0]))


static func melee_max(w: Dictionary) -> int:
	return int(MELEE.get(fam(w), MELEE["melee1"])[1])


## 근접 넉백(타일, SD-11 §3.4): 양손 0.3 / 파워 1.0(+경직) · 한손 파워 0.3 · 그 밖 0
static func knockback(w: Dictionary, power: bool) -> float:
	match fam(w):
		"melee2": return 1.0 if power else 0.3
		"melee1", "unarmed": return 0.3 if power else 0.0
	return 0.0


## 저격 계열(스코프 안정 · 집중 사격 38 AP, SD-11 §3.4): 소총 계열 중 유효 사거리 14t 이상
static func is_sniper(w: Dictionary) -> bool:
	return fam(w) == "rifle" and float(w.get("range_eff", 0.0)) >= 14.0

