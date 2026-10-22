## 랜드마크 원경 표식(1-12k, SD-08 §5.2 랜드마크 21 · §12.1 ① · §12.2 등급과 가시 반경, SD-12 §4.3 방위 링). 사실은 변수 한 곳(P1):
##   LM_SEEN 비트(ROWS 차례) — S 둘은 전망바위 픽처를 본 순간(vista) · 나머지는 반경 안에 처음 들어간 순간(tick) 등록.
## 가시 반경(청크): S 전역 · A 16(10~20) · B 7(6~8) · C 4(3~5) — 밤엔 빛나는 것(glow)만 ×1.5. 링엔 가까운 순 3 + S 2(visible).
class_name Landmarks
extends RefCounted

## [열쇠, 이름, tx, ty, 등급, 밤 빛] — 아이콘 열(assets/ui/landmark_icons.png)은 이 차례
const ROWS := [
	["NAMSAN", "남산 송신탑", 1112, 941, "S", true], ["SEJIN", "세진전자 타워", 1657, 1172, "S", true],
	["GOLD", "여의도 금탑", 883, 1129, "A", false], ["DOME", "무너진 국회 돔", 758, 1057, "B", false],
	["DANGIN", "당인리 굴뚝", 792, 977, "B", false], ["NANJI", "난지도 메탄 불꽃", 620, 838, "B", true],
	["TANK", "탱크마을 탱크", 661, 820, "C", false], ["SANGAM", "상암 경기장", 696, 838, "B", false],
	["JAMSIL", "잠실 종합경기장", 1517, 1158, "B", false], ["RADAR", "관악 레이더 돔", 990, 1561, "A", false],
	["INSU", "북한산 인수봉", 1087, 276, "A", false], ["JAUN", "도봉산 자운봉", 1241, 56, "A", false],
	["DDP", "동대문 미래관", 1214, 849, "C", false], ["OLYMPIC", "올림픽대교 주탑", 1665, 1044, "B", false],
	["GONGNEUNG", "공릉 연구로 돔", 1593, 474, "C", false], ["VENT", "청계산 환기탑", 1369, 1584, "C", false],
	["GIMPO", "김포 크레이터 연기", 170, 898, "A", false], ["UMYEON", "우면 크레이터", 1264, 1470, "B", false],
	["ICHON", "이촌 폭심", 1035, 1149, "C", false], ["SPEAKER", "광화문 확성기탑", 1058, 819, "C", false],
	["DOGOK", "도곡 주상복합 3탑", 1421, 1320, "A", false]]
const CHUNKS := {"S": 0, "A": 16, "B": 7, "C": 4}
const CHUNK := 40.0
const NEAR := 3
const VAR := "LM_SEEN"


static func index(key: String) -> int:
	for i in ROWS.size():
		if ROWS[i][0] == key:
			return i
	return -1


## 가시 반경(타일). S는 전역(INF)
static func radius(i: int, night: bool) -> float:
	var g: String = ROWS[i][4]
	if g == "S":
		return INF
	var r := float(CHUNKS[g]) * CHUNK
	return r * 1.5 if night and bool(ROWS[i][5]) else r


static func dist(i: int, me: Vector2i) -> float:
	return Vector2(int(ROWS[i][2]) - me.x, int(ROWS[i][3]) - me.y).length()


static func seen(st, i: int) -> bool:
	return st.vars.has(VAR) and (int(st.vars.get_v(VAR)) >> i) & 1 == 1


## 등록. 새로 등록했으면 true
static func register(st, i: int) -> bool:
	if not st.vars.has(VAR) or seen(st, i):
		return false
	st.vars.set_v(VAR, int(st.vars.get_v(VAR)) | (1 << i))
	return true


## 전망 지점 픽처를 본 순간(SD-08 §12.2 'MQ-P4 관악산 전망바위 픽처를 본 순간'): S등급을 모두 등록 → 새로 등록한 이름들
static func vista(st) -> Array:
	var out: Array = []
	for i in ROWS.size():
		if ROWS[i][4] == "S" and register(st, i):
			out.append(str(ROWS[i][1]))
	return out


## 칸이 바뀔 때(월드): 반경 안에 처음 들어간 랜드마크를 등록 → 새로 등록한 이름들(S는 vista로만)
static func tick(st, me: Vector2i, night: bool) -> Array:
	var out: Array = []
	for i in ROWS.size():
		if ROWS[i][4] == "S" or seen(st, i):
			continue
		if dist(i, me) <= radius(i, night) and register(st, i):
			out.append(str(ROWS[i][1]))
	return out


## 지금 링에 보일 것: 등록됐고 반경 안인 것 중 가까운 순 NEAR + S등급 → [{i, name, dir(단위 벡터), d}]
static func visible(st, me: Vector2i, night: bool) -> Array:
	var near: Array = []
	var out: Array = []
	for i in ROWS.size():
		if not seen(st, i):
			continue
		var d := dist(i, me)
		if d < 2.0 or d > radius(i, night):
			continue
		var row := {"i": i, "name": str(ROWS[i][1]), "dir": Vector2(int(ROWS[i][2]) - me.x, int(ROWS[i][3]) - me.y).normalized(), "d": d}
		if ROWS[i][4] == "S":
			out.append(row)
		else:
			near.append(row)
	near.sort_custom(func(a, b): return a["d"] < b["d"])
	for k in mini(NEAR, near.size()):
		out.append(near[k])
	return out
