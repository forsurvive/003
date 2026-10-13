## 전투 이펙트 시트(SD-16 §10.1, tools/pipeline/fx_export.py): 탄환·총구 화염·공기총 분출·맞은 자리 불꽃.
## 16방향 사전 회전 — 실행 중 회전은 쓰지 않는다(SD-16 §3.5). 열 = 방향(0 = 동, 22.5°씩 시계 방향 — 화면 y 아래),
## 행 = 세트 × 컷. 세트마다 기준점(탄 머리·총구·맞은 점)을 그 자리에 맞춰 찍는다. 컷은 2틱(60분의 1초 × 2)씩.
class_name CombatFx
extends RefCounted

const PATH := "res://assets/fx/combat_fx"
const TICK := 1.0 / 60.0
static var _meta: Dictionary
static var _tex: Texture2D


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(PATH + ".json"))
	return _meta


static func sheet() -> Texture2D:
	if _tex == null:
		_tex = load(PATH + ".png")
	return _tex


static func has_set(set_name: String) -> bool:
	return set_name != "" and meta()["sets"].has(set_name)


## 무기마다 다른 총구 효과(SD-16 §10.1 '계열 공용 세트의 색 교체'): 소음(공기총) → 분출, 근접 → 없음, 그 밖 → 권총 화염
static func flash_for(weapon: Dictionary) -> String:
	match str(weapon.get("sound", "pistol")):
		"suppressed":
			return "flash_air"
		"melee":
			return ""
	return "flash_pistol"


static func col(angle_deg: float) -> int:
	var n := int(meta()["dirs"])
	return posmod(roundi(angle_deg / (360.0 / n)), n)


static func region(set_name: String, angle_deg: float, frame: int) -> Rect2:
	var s: Dictionary = meta()["sets"][set_name]
	var c := float(meta()["cell"])
	return Rect2(col(angle_deg) * c, (int(s["row"]) + frame) * c, c, c)


## 그 자리(at)에 기준점을 맞춘 그림 왼쪽 위(정수 화소)
static func top_left(set_name: String, at: Vector2) -> Vector2:
	var a: Array = meta()["sets"][set_name]["anchor"]
	return (at - Vector2(a[0], a[1])).round()


## 나온 지 age초 된 이펙트의 컷. 끝났으면 -1.
static func frame_at(set_name: String, age: float) -> int:
	var s: Dictionary = meta()["sets"][set_name]
	var f := int(age / (float(s["ticks"]) * TICK) + 0.001)
	return f if f < int(s["frames"]) else -1
