## 디버그 표시(월드 좌표): 청크 경계·활성 3×3, 적 상태·시야각·경로, 탐지 게이지, 경로 격자 막힌 칸(화면 안만).
class_name DebugOverlay
extends Node2D

var show := {"chunk": false, "ai": false, "detect": false, "nav": false}
var world: ChunkWorld
var enemies: Array = []
var nav: NavGrid
var font: Font
var view_center := Vector2.ZERO
const STATE := ["대기", "의심", "수색", "교전", "놓침", "귀환", "죽음"]


func _ready() -> void:
	z_index = 50
	font = load("res://assets/fonts/Galmuri9.ttf")


func any() -> bool:
	return show.values().has(true)


func _process(_dt: float) -> void:
	visible = any()
	if visible:
		queue_redraw()


func _draw() -> void:
	var cs := float(world.cs) * 32.0
	if show["nav"] and nav != null:
		var c := Vector2i(floori(view_center.x / 32), floori(view_center.y / 32))
		for y in range(c.y - 9, c.y + 10):
			for x in range(c.x - 15, c.x + 16):
				var t := Vector2i(x, y)
				if nav.astar.is_in_boundsv(t) and nav.astar.is_point_solid(t):
					draw_rect(Rect2(Vector2(t) * 32.0 + Vector2(2, 2), Vector2(28, 28)), Color(0.88, 0.29, 0.21, 0.35))
	if show["chunk"]:
		for k in world.loaded:
			var r := Rect2(Vector2(k) * cs, Vector2(cs, cs))
			var active: bool = absi(k.x - world.focus.x) <= 1 and absi(k.y - world.focus.y) <= 1
			draw_rect(r, Color("e8c23a") if active else Color("6e6966"), false, 1.0)
			draw_string(font, r.position + Vector2(4, 12), "C-%02d-%02d" % [k.x, k.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color("e8c23a") if active else Color("8b857d"))
	for e in enemies:
		if e.cmb.dead or e.position.distance_to(view_center) > 640:
			continue
		var p: Vector2 = e.loco.logical
		if show["ai"]:
			var fwd: Vector2 = Locomotion.VEC[e.loco.facing].normalized()
			var half := deg_to_rad(Perception.FOV.get(e.brain.kind, 120.0) / 2.0)
			var rng: float = Perception.sight_range(e.per) * 32.0
			var col := Color(0.91, 0.76, 0.23, 0.5)
			draw_line(p, p + fwd.rotated(half) * rng, col)
			draw_line(p, p + fwd.rotated(-half) * rng, col)
			draw_arc(p, rng, fwd.angle() - half, fwd.angle() + half, 24, col)
			if e._path.size() > 1:
				var pts := PackedVector2Array([p])
				for i in range(e._path_i, e._path.size()):
					pts.append(e._path[i])
				if pts.size() > 1:
					draw_polyline(pts, Color("7fb3d5"), 1.0)
			draw_string(font, p + Vector2(-16, 12), "%s %s" % [STATE[e.brain.state], e._intent.get("goal", "")],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e9e4d8"))
		if show["detect"]:
			var g: float = e.brain.gauge / AIBrain.DETECT_AT
			draw_rect(Rect2(p + Vector2(-12, 16), Vector2(24, 3)), Color("1a181d"))
			draw_rect(Rect2(p + Vector2(-12, 16), Vector2(24.0 * g, 3)), Color("e04a35") if g >= 1.0 else Color("e8c23a"))
