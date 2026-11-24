extends Node2D
## The simplest possible player: a square that moves. (Collisions are a lesson for another day.)
## demo = true walks by itself in a long curve, for recording clips.

const SPEED := 140.0
const FAST := 3.0

var demo := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var dir := Vector2.ZERO
	if demo:
		dir = Vector2(1.0, sin(_t * 0.35) * 0.8).normalized()   # wander east, curving up and down
		position += dir * SPEED * 2.6 * delta
	else:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if Input.is_key_pressed(KEY_A): dir.x -= 1
		if Input.is_key_pressed(KEY_D): dir.x += 1
		if Input.is_key_pressed(KEY_W): dir.y -= 1
		if Input.is_key_pressed(KEY_S): dir.y += 1
		var boost := FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0
		position += dir.limit_length(1.0) * SPEED * boost * delta
	queue_redraw()


func _draw() -> void:
	var s := 18.0
	draw_rect(Rect2(-s / 2 - 2, -s / 2 - 2, s + 4, s + 4), Color("1a1024"))
	draw_rect(Rect2(-s / 2, -s / 2, s, s), Color("f58a1f"))
	draw_rect(Rect2(-5, -3, 3, 5), Color("1a1024"))
	draw_rect(Rect2(2, -3, 3, 5), Color("1a1024"))
