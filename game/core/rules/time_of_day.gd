## 하루 시각 → 바깥 화면 색조와 시간대(단계 1-T1, SD-16 §4.7 상황 필터 1~5 · SD-14 §2 시간대 표기 · SD-05 §6.3 밤 20~05).
## 색조는 [R, G, B, 회색] 가산(night_tone 셰이더와 같은 식). 키프레임 사이는 선형 — 필터 표의 '게임 내 1시간에 걸쳐' 전환.
##   새벽 05~06(안개빛 푸름) · 낮 07~17 · 노을 18~19(주황) · 밤 20~01 · 깊은 밤 01~04(무월광 — 핍-보이 조명 반경 96px).
## 실내는 시각과 무관(조명 켜진 방은 색조 없음 · 전기가 끊긴 지하 암거는 '실내 정전' 필터 11 + 핍-보이 조명) — 포켓몬 골드처럼 바깥 하늘은 실내에 들어오지 않는다.
class_name TimeOfDay
extends RefCounted

const TONES := {
	"낮": Vector4(0, 0, 0, 0),
	"새벽": Vector4(-20, -10, 10, 20),
	"노을": Vector4(30, 0, -25, 10),
	"밤": Vector4(-70, -55, -20, 40),
	"깊은 밤": Vector4(-100, -85, -40, 60),
	"실내 정전": Vector4(-60, -60, -50, 80),
}
## [분, 필터] — 하루(0~1440)를 덮는다. 같은 필터가 이어지는 구간은 머문다, 다른 필터 사이는 1시간 동안 섞인다
const KEYS := [[0, "밤"], [60, "깊은 밤"], [240, "깊은 밤"], [300, "새벽"], [360, "새벽"], [420, "낮"],
	[1020, "낮"], [1080, "노을"], [1140, "노을"], [1200, "밤"], [1440, "밤"]]
const PIP_R := 96.0                                   ## 핍-보이 조명 반경(px, SD-16 §4.7 깊은 밤 · 실내 정전)


## 하루 안의 분(0~1439)
static func minute(date_text: String) -> int:
	var t := Clock.parse(date_text)
	if t.is_empty():
		return 13 * 60
	return int(t[3]) * 60 + int(t[4])


## 그 분의 화면 색조(키프레임 사이 선형)
static func tone(m: int) -> Vector4:
	m = posmod(m, 1440)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if m >= int(a[0]) and m <= int(b[0]):
			var k := 0.0 if int(b[0]) == int(a[0]) else float(m - int(a[0])) / float(int(b[0]) - int(a[0]))
			return (TONES[a[1]] as Vector4).lerp(TONES[b[1]], k)
	return TONES["밤"]


## 시간대 이름(대사 · 시험 · 핍-보이 시계 옆 글자): 새벽 05~07 · 낮 07~17 · 노을 17~20 · 밤 20~01 · 깊은 밤 01~05
static func band(m: int) -> String:
	m = posmod(m, 1440)
	if m >= 300 and m < 420:
		return "새벽"
	if m >= 420 and m < 1020:
		return "낮"
	if m >= 1020 and m < 1200:
		return "노을"
	if m >= 60 and m < 300:
		return "깊은 밤"
	return "밤"


## 빛 원판의 세기(0 낮 ~ 1 밤): 어두운 만큼 불 드럼 · 경광이 보인다
static func light_k(m: int) -> float:
	return clampf(-tone(m).x / 70.0, 0.0, 1.0)


## 핍-보이 조명(주인공 둘레 96px)이 켜지는 정도(0~1): 깊은 밤으로 갈수록
static func pip_k(m: int) -> float:
	return clampf((-tone(m).x - 70.0) / 30.0, 0.0, 1.0)


## 새벽 지면 안개 세기(0~1, SD-16 §4.7 필터 2 덧씌우기 25%): 04~05 차오름 · 05~06 가득 · 06~07 걷힘
static func fog_k(m: int) -> float:
	m = posmod(m, 1440)
	if m < 240 or m >= 420:
		return 0.0
	if m < 300:
		return float(m - 240) / 60.0
	if m < 360:
		return 1.0
	return float(420 - m) / 60.0


## 색조가 있나(층을 켤지)
static func is_dark(v: Vector4) -> bool:
	return absf(v.x) + absf(v.y) + absf(v.z) + absf(v.w) > 0.5
