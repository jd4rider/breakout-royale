class_name BreakoutMath
extends RefCounted
## Deterministic, engine-independent collision and aiming maths.
##
## The ball's authoritative position lives on a 2D plane. Rendering adds the
## depth, so nothing here touches nodes and the headless tests can exercise the
## exact rules the game runs at 120 Hz.

const EPS := 0.000001


## Swept circle against an axis-aligned box, in normalised time (0..1).
## Returns { hit, t, normal } — `normal` points out of the box face that was hit.
static func swept_circle_box(center: Vector2, radius: float, motion: Vector2,
		box_center: Vector2, box_size: Vector2) -> Dictionary:
	var half := box_size * 0.5 + Vector2(radius, radius)
	var lo := box_center - half
	var hi := box_center + half
	var t_enter := 0.0
	var t_exit := 1.0
	var axis := -1
	var sign_axis := 0.0

	if absf(motion.x) < EPS:
		if center.x < lo.x or center.x > hi.x:
			return {"hit": false, "t": 0.0, "normal": Vector2.ZERO}
	else:
		var t1 := (lo.x - center.x) / motion.x
		var t2 := (hi.x - center.x) / motion.x
		var s := -1.0
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
			s = 1.0
		if t1 > t_enter:
			t_enter = t1
			axis = 0
			sign_axis = s
		t_exit = minf(t_exit, t2)

	if absf(motion.y) < EPS:
		if center.y < lo.y or center.y > hi.y:
			return {"hit": false, "t": 0.0, "normal": Vector2.ZERO}
	else:
		var t1 := (lo.y - center.y) / motion.y
		var t2 := (hi.y - center.y) / motion.y
		var s := -1.0
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
			s = 1.0
		if t1 > t_enter:
			t_enter = t1
			axis = 1
			sign_axis = s
		t_exit = minf(t_exit, t2)

	if t_enter > t_exit or t_enter > 1.0 or t_exit < 0.0:
		return {"hit": false, "t": 0.0, "normal": Vector2.ZERO}

	var normal := Vector2.ZERO
	if axis == 0:
		normal.x = sign_axis
	elif axis == 1:
		normal.y = sign_axis
	else:
		# Already overlapping on entry: push out along the shallowest axis.
		var overlap_x := minf(center.x - lo.x, hi.x - center.x)
		var overlap_y := minf(center.y - lo.y, hi.y - center.y)
		if overlap_x < overlap_y:
			normal.x = -1.0 if center.x < box_center.x else 1.0
		else:
			normal.y = -1.0 if center.y < box_center.y else 1.0
	return {"hit": true, "t": maxf(0.0, t_enter), "normal": normal}


static func reflect(velocity: Vector2, normal: Vector2) -> Vector2:
	if normal == Vector2.ZERO:
		return velocity
	return velocity - 2.0 * velocity.dot(normal) * normal


## Off-centre paddle hits aim the ball: centre leaves near-vertical, the very
## edge leaves near-horizontal. The floor of 0.17 rad stops a rally from
## turning into a horizontal ping-pong that never comes back down.
static func paddle_bounce(normalized_offset: float, speed: float) -> Vector2:
	var offset := clampf(normalized_offset, -1.0, 1.0)
	if absf(offset) < 0.02:
		return Vector2(0, 1) * speed
	var angle := offset * 1.02
	if absf(angle) < 0.17:
		angle = 0.17 * (1.0 if angle >= 0.0 else -1.0)
	return Vector2(sin(angle), cos(angle)) * speed


static func clamp_ball_angle(velocity: Vector2) -> Vector2:
	var speed := velocity.length()
	if speed < EPS:
		return velocity
	var dir := velocity / speed
	# Reject near-horizontal directions after a bounce so rallies stay alive.
	if absf(dir.y) < 0.22:
		dir.y = 0.22 * (1.0 if dir.y >= 0.0 else -1.0)
		dir = dir.normalized()
	return dir * speed


static func stars_for(score: int, par: int) -> int:
	if par <= 0:
		return 1
	if score >= int(par * 1.45):
		return 3
	if score >= par:
		return 2
	return 1


static func format_score(value: int) -> String:
	var text := str(maxi(0, value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
