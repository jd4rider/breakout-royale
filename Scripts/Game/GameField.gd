class_name GameField
extends Node3D
## Authoritative gameplay: paddle, balls, bricks, capsules, boss and effects.
##
## The simulation runs on a 2D plane in fixed 1/120 s steps. Everything visible
## is 3D, but nothing visual is consulted for a collision, so the same board
## plays identically on every device.

signal finished(result: Dictionary)
signal power_caught(id: String)
signal ball_lost_signal
signal shake_requested(amount: float)

const FIELD_HALF := 4.2
const TOP_WALL := 9.0
const FLOOR := -9.0
const PADDLE_Y := -7.5
const PADDLE_HALF := 1.45
const PADDLE_HEIGHT := 0.34
const BALL_RADIUS := 0.24
const BRICK_WIDTH := 0.86
const BRICK_HEIGHT := 0.44
const BRICK_DEPTH := 0.4
const GRID_X := 0.92
const GRID_Y := 0.5
const TOP_BRICK_Y := 7.8
const BOSS_Y := 5.9
const BOSS_SIZE := Vector2(4.4, 2.7)
const MAX_BALLS := 9
const STEP := 1.0 / 120.0

const MODE_CONFIG := {
	"campaign": {"lives": 3, "drops": true, "endless": false, "boss_rush": false},
	"endless": {"lives": 3, "drops": true, "endless": true, "boss_rush": false},
	"survival": {"lives": 1, "drops": true, "endless": true, "boss_rush": false},
	"bossrush": {"lives": 3, "drops": false, "endless": false, "boss_rush": true},
	"daily": {"lives": 3, "drops": true, "endless": false, "boss_rush": false},
	"zen": {"lives": 999, "drops": true, "endless": true, "boss_rush": false},
	"arcade": {"lives": 3, "drops": false, "endless": false, "boss_rush": false},
}

var mode := "campaign"
var level_id := 1
var level: Dictionary = {}
var running := false
var paused := false
var ended := false

var score := 0
var lives := 3
var bricks_broken := 0
var powers_caught := 0
var balls_dropped := 0
var elapsed := 0.0
var stage := 1
var bosses_beaten := 0

var _config: Dictionary = MODE_CONFIG["campaign"]
var _world: Dictionary = {}
var _accent := Color("#2ee6d6")
var _glow := Color("#8bfff2")
var _speed := 9.0

var _paddle: Node3D
var _paddle_light: OmniLight3D
var _paddle_x := 0.0
var _paddle_scale := 1.0
var _pointer_held := false

var _balls: Array = []
var _bricks: Array = []
var _capsules: Array = []
var _boss_shots: Array = []
var _boss: Dictionary = {}
var _shards: Array = []

var _effects: Dictionary = {}   # id -> remaining seconds
var _saves := 0
var _drones := 0
var _drone_timer := 0.0
var _laser_timer := 0.0
var _turret_timer := 0.0
var _score_mult := 1
var _accumulator := 0.0

var _camera: Camera3D
var _camera_base := Vector3.ZERO
var _shake_power := 0.0
var _reduced_motion := false

var _rng := RandomNumberGenerator.new()
var _brick_root: Node3D
var _fx_root: Node3D
var _ball_root: Node3D


# --------------------------------------------------------------------------
# setup
# --------------------------------------------------------------------------

func setup(p_mode: String, p_level_id: int) -> void:
	mode = p_mode if MODE_CONFIG.has(p_mode) else "campaign"
	_config = MODE_CONFIG[mode]
	level_id = Campaign.clamp_level(p_level_id)
	_world = Campaign.world(level_id)
	_accent = Color(String(_world.get("accent", "#2ee6d6")))
	_glow = Color(String(_world.get("glow", "#8bfff2")))
	_rng.seed = Campaign.level_seed(level_id)
	_reduced_motion = not bool(Save.get_setting("screen_shake", true))

	_build_environment()
	_build_arena()
	_load_level(level_id)
	lives = int(_config["lives"])
	_score_mult = 1
	_attach_ball()
	running = true
	Audio.play_music("game")


func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(String(_world.get("to", "#080512")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _accent.lerp(Color("#cdd9ff"), 0.45)
	env.ambient_light_energy = 0.62
	environment.environment = env
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff4e2")
	key.light_energy = 2.3
	key.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-28.0), 0)
	add_child(key)

	var fill := OmniLight3D.new()
	fill.light_color = _accent
	fill.light_energy = 7.0
	fill.omni_range = 26.0
	fill.position = Vector3(0, 4.5, 9)
	add_child(fill)

	var rim := OmniLight3D.new()
	rim.light_color = _glow
	rim.light_energy = 3.4
	rim.omni_range = 18.0
	rim.position = Vector3(0, -7, 7)
	add_child(rim)

	# A complement-coloured side light is what stops the arena reading as a
	# single flat tint: one side of every brick catches a different hue.
	var side := OmniLight3D.new()
	side.light_color = Color.from_hsv(fposmod(_accent.h + 0.5, 1.0), 0.85, 1.0)
	side.light_energy = 4.6
	side.omni_range = 21.0
	side.position = Vector3(-7.5, 2.0, 6.5)
	add_child(side)

	var backdrop := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(48, 40)
	backdrop.mesh = quad
	backdrop.position = Vector3(0, 1.5, -14)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform vec4 glow_color : source_color;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(bottom_color.rgb, top_color.rgb, smoothstep(0.0, 1.0, uv.y));
	float band = smoothstep(0.13, 0.0, abs(uv.y - 0.58));
	col += glow_color.rgb * band * 0.28;
	float nebula = smoothstep(0.15, 0.0, abs(uv.x - 0.5 - sin(uv.y * 3.1) * 0.09));
	col += glow_color.rgb * nebula * 0.16;
	float horizon = smoothstep(0.24, 0.0, abs(uv.y - 0.18));
	col += glow_color.rgb * horizon * 0.08;
	float star = step(0.9976, fract(sin(dot(floor(uv * vec2(230.0, 360.0)), vec2(12.9898, 78.233))) * 43758.5453));
	col += vec3(star) * 0.7;
	float vignette = smoothstep(0.95, 0.25, length(uv - vec2(0.5, 0.55)));
	col *= mix(0.55, 1.0, vignette);
	ALBEDO = col;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("top_color", Color(String(_world.get("from", "#0b2b3a"))))
	material.set_shader_parameter("bottom_color", Color(String(_world.get("to", "#071018"))))
	material.set_shader_parameter("glow_color", _accent)
	backdrop.material_override = material
	add_child(backdrop)

	# Loose glowing debris drifting behind the wall, so the empty air between
	# the paddle and the bricks reads as depth instead of a flat field.
	for i in range(16):
		var mote := MeshInstance3D.new()
		var shape := BoxMesh.new()
		var size := randf_range(0.06, 0.19)
		shape.size = Vector3(size, size, size)
		mote.mesh = shape
		mote.material_override = Models.glow_material(_glow, randf_range(0.5, 1.4))
		mote.position = Vector3(
			randf_range(-7.5, 7.5),
			randf_range(-9.0, 8.5),
			randf_range(-11.0, -3.0))
		mote.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(mote)

	# A distant ring behind the playfield gives the arena real depth.
	for i in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 4.2 + i * 2.2
		torus.outer_radius = 4.3 + i * 2.2
		torus.rings = 56
		torus.ring_segments = 6
		ring.mesh = torus
		ring.position = Vector3(0, 3.2 - i * 1.3, -11.0 - i * 2.0)
		ring.material_override = Models.glow_material(_accent, 0.5 if i == 0 else 0.3)
		add_child(ring)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 22.4
	# Framed a little high so the wall clears the HUD and the paddle sits low in
	# the thumb zone, while the tilt still shows the top face of every brick.
	_camera.position = Vector3(0, 3.1, 26)
	_camera.rotation = Vector3(deg_to_rad(-10.0), 0, 0)
	_camera_base = _camera.position
	add_child(_camera)
	_camera.current = true

	_brick_root = Node3D.new()
	add_child(_brick_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_ball_root = Node3D.new()
	add_child(_ball_root)


func _build_arena() -> void:
	var arena := Models.spawn("arena", _accent)
	if arena != null:
		Models.paint(arena, Color("#3c2d5c"), 0.05)
		add_child(arena)
	for side in [-1, 1]:
		var crystal := Models.spawn("crystal", _accent)
		if crystal != null:
			crystal.position = Vector3(side * 5.6, -8.6, -2.4)
			crystal.scale = Vector3.ONE * 0.6
			Models.paint(crystal, _accent.darkened(0.35), 0.25)
			add_child(crystal)

	_paddle = Models.spawn("paddle", _glow)
	if _paddle == null:
		_paddle = Node3D.new()
	Models.paint(_paddle, Color("#dbeeff"), 0.4)
	_paddle.position = Vector3(0, PADDLE_Y, 0)
	add_child(_paddle)

	# The paddle carries its own light, so the player's craft glows on the board
	# instead of blending into the floor.
	_paddle_light = OmniLight3D.new()
	_paddle_light.light_color = _glow
	_paddle_light.light_energy = 3.2
	_paddle_light.omni_range = 6.5
	_paddle_light.position = Vector3(0, PADDLE_Y, 1.2)
	add_child(_paddle_light)


func _load_level(id: int) -> void:
	for brick in _bricks:
		if is_instance_valid(brick["node"]):
			brick["node"].queue_free()
	_bricks.clear()
	for capsule in _capsules:
		if is_instance_valid(capsule["node"]):
			capsule["node"].queue_free()
	_capsules.clear()
	_clear_boss()

	level = Campaign.generate(id)
	_boss = {}
	if bool(level["boss"]):
		_spawn_boss(level)
	else:
		for entry in level["bricks"]:
			_spawn_brick(entry)
	_update_speed()


func _update_speed() -> void:
	var wi := Campaign.world_index(level_id)
	var local := Campaign.local_level(level_id)
	_speed = 8.4 + wi * 0.14 + minf(local * 0.012, 1.4) + float(stage - 1) * 0.55
	if mode == "arcade":
		_speed = 9.2
	if mode == "zen":
		_speed *= 0.86


# --------------------------------------------------------------------------
# entities
# --------------------------------------------------------------------------

func _spawn_brick(entry: Dictionary) -> void:
	var kind := String(entry["t"])
	var row := int(entry["r"])
	var paint_color := _row_color(row) if _color_for(kind) == _accent else _color_for(kind)
	var node := Models.spawn(_model_for(kind), paint_color)
	var emission := 0.34
	match kind:
		"steel":
			paint_color = Color("#59607a")
			emission = 0.0
		"bomb":
			emission = 0.55
		"crystal":
			emission = 0.6
		"armor":
			emission = 0.3
	Models.paint(node, paint_color, emission)
	node.position = _brick_position(int(entry["c"]), int(entry["r"]))
	_brick_root.add_child(node)
	_bricks.append({
		"c": int(entry["c"]),
		"r": int(entry["r"]),
		"kind": kind,
		"hp": int(entry["hp"]),
		"max_hp": int(entry["hp"]),
		"node": node,
		"pos": Vector2(node.position.x, node.position.y),
		"alive": true,
	})


func _model_for(kind: String) -> String:
	match kind:
		"armor":
			return "brick_armor"
		"steel":
			return "brick_steel"
		"bomb":
			return "brick_bomb"
		"crystal":
			return "brick_crystal"
		_:
			return "brick"


func _color_for(kind: String) -> Color:
	match kind:
		"armor":
			return Color("#ffcf3d")
		"steel":
			return Color("#9aa3b8")
		"bomb":
			return Color("#ff5c5c")
		"crystal":
			return Color("#c7b0ff")
		_:
			return _accent


## Ordinary bricks walk the hue wheel a little per row, so the wall reads as a
## colourful stack rather than one flat slab of the world accent.
func _row_color(row: int) -> Color:
	var hue := fposmod(_accent.h + float(row) * 0.058, 1.0)
	var saturation := clampf(_accent.s * 1.08 + 0.2, 0.0, 1.0)
	var value := clampf(_accent.v * 1.04 + 0.1, 0.0, 1.0)
	return Color.from_hsv(hue, saturation, value)


func _brick_position(c: int, r: int) -> Vector3:
	var x := (float(c) - (Campaign.COLS - 1) * 0.5) * GRID_X
	var y := TOP_BRICK_Y - float(r) * GRID_Y
	return Vector3(x, y, 0)


func _spawn_boss(data: Dictionary) -> void:
	var node := Models.spawn("boss_core", _accent)
	if node == null:
		node = Node3D.new()
	Models.paint(node, _accent.darkened(0.15), 0.4)
	node.position = Vector3(0, BOSS_Y, 0)
	node.scale = Vector3.ONE * 1.15
	add_child(node)
	_boss = {
		"node": node,
		"hp": int(data["hp"]),
		"max_hp": int(data["hp"]),
		"phase": 1,
		"pos": Vector2(0, BOSS_Y),
		"timer": 1.4,
		"alive": true,
		"data": data,
		"drift": 0.0,
		"frozen": 0.0,
	}


func _clear_boss() -> void:
	if not _boss.is_empty() and is_instance_valid(_boss.get("node")):
		_boss["node"].queue_free()
	_boss = {}
	for shot in _boss_shots:
		if is_instance_valid(shot["node"]):
			shot["node"].queue_free()
	_boss_shots.clear()


func _attach_ball() -> void:
	if _balls.size() > 0:
		return
	var node := _make_ball_node()
	var ball := {
		"pos": Vector2(_paddle_x, PADDLE_Y + 0.75),
		"vel": Vector2.ZERO,
		"radius": BALL_RADIUS,
		"node": node,
		"stuck": true,
		"age": 0.0,
	}
	_balls.append(ball)


func _make_ball_node() -> Node3D:
	var node := Models.spawn("ball", _glow)
	if node == null:
		node = Node3D.new()
	Models.paint(node, Color("#fff6d8"), 1.6)
	node.scale = Vector3.ONE
	_ball_root.add_child(node)
	return node


func _spawn_ball(pos: Vector2, vel: Vector2, radius := BALL_RADIUS) -> void:
	if _balls.size() >= MAX_BALLS:
		return
	var node := _make_ball_node()
	_balls.append({
		"pos": pos,
		"vel": vel,
		"radius": radius,
		"node": node,
		"stuck": false,
		"age": 0.0,
	})


func _sync_ball(ball: Dictionary) -> void:
	var node: Node3D = ball["node"]
	if not is_instance_valid(node):
		return
	node.position = Vector3(ball["pos"].x, ball["pos"].y, 0)
	var radius := float(ball["radius"])
	node.scale = Vector3.ONE * (radius / BALL_RADIUS)


# --------------------------------------------------------------------------
# input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not running or paused or ended:
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_set_pointer(drag.position.x)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pointer_held = true
			_set_pointer(touch.position.x)
		else:
			_pointer_held = false
			_launch()
	elif event is InputEventMouseMotion:
		_set_pointer((event as InputEventMouseMotion).position.x)
	elif event is InputEventMouseButton and event.pressed:
		_set_pointer((event as InputEventMouseButton).position.x)
		_launch()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE, KEY_ENTER:
				_launch()
			KEY_LEFT, KEY_A:
				_paddle_x -= 0.42
			KEY_RIGHT, KEY_D:
				_paddle_x += 0.42


func _set_pointer(screen_x: float) -> void:
	var width := maxf(1.0, get_viewport().get_visible_rect().size.x)
	var ratio := (screen_x / width) * 2.0 - 1.0
	_paddle_x = clampf(ratio * (FIELD_HALF + 0.35), -FIELD_HALF + 0.2, FIELD_HALF - 0.2)


func _launch() -> void:
	var released := false
	for ball in _balls:
		if bool(ball["stuck"]):
			ball["stuck"] = false
			ball["vel"] = Vector2(randf_range(-0.35, 0.35), 1.0).normalized() * _current_speed()
			released = true
	if released:
		Audio.play_sfx("launch")


func _current_speed() -> float:
	var speed := _speed
	if _effects.has("slow_ball"):
		speed *= 0.78
	if _effects.has("fast_ball"):
		speed *= 1.2
	if _effects.has("heavy_ball"):
		speed *= 0.9
	if _effects.has("overdrive"):
		speed *= 1.05
	return speed


# --------------------------------------------------------------------------
# simulation
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not running or paused:
		return
	_accumulator += delta
	var steps := 0
	while _accumulator >= STEP and steps < 6:
		_step(STEP)
		_accumulator -= STEP
		steps += 1
	if steps == 6:
		_accumulator = 0.0
	_animate(delta)


func _step(dt: float) -> void:
	if ended:
		return
	elapsed += dt
	var time_scale := 1.0
	if _effects.has("time_slow"):
		time_scale = 0.56
	_tick_effects(dt)
	_tick_paddle(dt)
	_tick_balls(dt * time_scale)
	_tick_capsules(dt * time_scale)
	_tick_boss(dt * time_scale)
	_tick_boss_shots(dt * time_scale)
	_tick_assists(dt)
	_check_stage()


func _tick_effects(dt: float) -> void:
	if _effects.is_empty():
		return
	for id in _effects.keys():
		_effects[id] = float(_effects[id]) - dt
		if float(_effects[id]) <= 0.0:
			_effects.erase(id)
			_on_effect_end(String(id))


func _on_effect_end(id: String) -> void:
	match id:
		"giant_ball", "tiny_ball":
			for ball in _balls:
				ball["radius"] = BALL_RADIUS
		"score_x2", "score_x3", "overdrive":
			_score_mult = 1
		"laser_paddle":
			_laser_timer = 0.0


func _tick_paddle(dt: float) -> void:
	_paddle_scale = 1.0
	if _effects.has("wide_paddle"):
		_paddle_scale = 1.5
	if _effects.has("narrow_paddle"):
		_paddle_scale = 0.62
	if _effects.has("hyper_paddle"):
		_paddle_scale *= 1.28
	_paddle_x = clampf(_paddle_x, -FIELD_HALF + 0.2, FIELD_HALF - 0.2)
	_paddle.position = Vector3(_paddle_x, PADDLE_Y, 0)
	var target := Vector3(_paddle_scale, 1.0, 1.0)
	_paddle.scale = _paddle.scale.lerp(target, clampf(dt * 14.0, 0.0, 1.0))
	for ball in _balls:
		if bool(ball["stuck"]) and _balls.size() == 1:
			ball["pos"] = Vector2(_paddle_x, PADDLE_Y + 0.72)


func _tick_balls(dt: float) -> void:
	for ball in _balls.duplicate():
		if not _balls.has(ball):
			continue
		if bool(ball["stuck"]):
			_sync_ball(ball)
			continue
		_move_ball(ball, dt)
		_sync_ball(ball)


func _move_ball(ball: Dictionary, dt: float) -> void:
	var remaining := dt
	var iterations := 0
	while remaining > 0.00005 and iterations < 4:
		iterations += 1
		var pos: Vector2 = ball["pos"]
		var vel: Vector2 = ball["vel"]
		if vel.length() < 0.001:
			vel = Vector2(0, -1) * _current_speed()
		if _effects.has("magnet_ball"):
			vel = _bend_toward_brick(pos, vel, remaining)
			ball["vel"] = vel

		var motion := vel * remaining
		var hit := _earliest_hit(pos, float(ball["radius"]), motion, ball)
		if hit.is_empty():
			ball["pos"] = pos + motion
			break

		var t := clampf(float(hit["t"]), 0.0, 1.0)
		ball["pos"] = pos + motion * t
		remaining *= (1.0 - t)
		var normal: Vector2 = hit["normal"]
		var kind := String(hit.get("kind", "wall"))
		_handle_hit(ball, hit, normal)
		if kind == "floor":
			return

		# The paddle sets its own aim from where the ball landed; every other
		# surface reflects off the face that was hit.
		var next_vel: Vector2 = ball["vel"] if kind == "paddle" else BreakoutMath.reflect(vel, normal)
		if _effects.has("chaos_ball"):
			next_vel = next_vel.rotated(randf_range(-0.22, 0.22))
		next_vel = BreakoutMath.clamp_ball_angle(next_vel)
		ball["vel"] = next_vel.normalized() * _current_speed()
		ball["pos"] = ball["pos"] + normal * 0.012

		if kind == "paddle" and (_effects.has("sticky_paddle") or _effects.has("magnet_paddle")):
			ball["stuck"] = true
			ball["vel"] = Vector2.ZERO
			_contain_ball(ball)
			return
	_contain_ball(ball)
	if ball["pos"].y < FLOOR:
		_lose_ball(ball)


## Last line of defence: if a step ever ends outside the arena, put the ball
## back and point it inward instead of letting it escape along the wall.
func _contain_ball(ball: Dictionary) -> void:
	var pos: Vector2 = ball["pos"]
	var vel: Vector2 = ball["vel"]
	var radius := float(ball["radius"])
	var limit := FIELD_HALF - radius
	if pos.x < -limit:
		pos.x = -limit
		vel.x = absf(vel.x)
	elif pos.x > limit:
		pos.x = limit
		vel.x = -absf(vel.x)
	if pos.y > TOP_WALL - radius:
		pos.y = TOP_WALL - radius
		vel.y = -absf(vel.y)
	ball["pos"] = pos
	ball["vel"] = vel


func _bend_toward_brick(pos: Vector2, vel: Vector2, dt: float) -> Vector2:
	var target := Vector2.ZERO
	var best := INF
	for brick in _bricks:
		if not bool(brick["alive"]):
			continue
		var distance := pos.distance_squared_to(brick["pos"])
		if distance < best:
			best = distance
			target = brick["pos"]
	if best == INF:
		return vel
	var desired := (target - pos).normalized()
	return vel.normalized().lerp(desired, clampf(dt * 1.6, 0.0, 0.5)).normalized() * vel.length()


func _earliest_hit(pos: Vector2, radius: float, motion: Vector2, ball: Dictionary) -> Dictionary:
	var best := {}
	var best_t := 2.0

	# Walls and ceiling. The test is on where the edge *will* be after this
	# step, otherwise a ball that lands a fraction past the line can never
	# reflect (its crossing time is already negative) and it escapes.
	if motion.x < 0.0 and pos.x + motion.x - radius <= -FIELD_HALF:
		var t := clampf((-FIELD_HALF + radius - pos.x) / motion.x, 0.0, 1.0)
		if t < best_t:
			best_t = t
			best = {"t": t, "normal": Vector2.RIGHT, "kind": "wall"}
	elif motion.x > 0.0 and pos.x + motion.x + radius >= FIELD_HALF:
		var t := clampf((FIELD_HALF - radius - pos.x) / motion.x, 0.0, 1.0)
		if t < best_t:
			best_t = t
			best = {"t": t, "normal": Vector2.LEFT, "kind": "wall"}
	if motion.y > 0.0 and pos.y + motion.y + radius >= TOP_WALL:
		var t := clampf((TOP_WALL - radius - pos.y) / motion.y, 0.0, 1.0)
		if t < best_t:
			best_t = t
			best = {"t": t, "normal": Vector2.DOWN, "kind": "wall"}

	# Paddle.
	var paddle_size := Vector2(PADDLE_HALF * 2.0 * _paddle_scale, PADDLE_HEIGHT * 2.0)
	var paddle_hit := BreakoutMath.swept_circle_box(pos, radius, motion,
			Vector2(_paddle_x, PADDLE_Y), paddle_size)
	if bool(paddle_hit["hit"]) and float(paddle_hit["t"]) < best_t and motion.y < 0.0:
		best_t = float(paddle_hit["t"])
		best = {"t": best_t, "normal": Vector2.UP, "kind": "paddle",
			"offset": clampf((pos.x + motion.x * best_t - _paddle_x) / (PADDLE_HALF * _paddle_scale), -1.0, 1.0)}

	# Bricks.
	for brick in _bricks:
		if not bool(brick["alive"]):
			continue
		var box_hit := BreakoutMath.swept_circle_box(pos, radius, motion, brick["pos"],
				Vector2(BRICK_WIDTH, BRICK_HEIGHT))
		if bool(box_hit["hit"]) and float(box_hit["t"]) < best_t:
			best_t = float(box_hit["t"])
			best = {"t": best_t, "normal": box_hit["normal"], "kind": "brick", "brick": brick}

	# Boss body.
	if not _boss.is_empty() and bool(_boss.get("alive", false)):
		var boss_hit := BreakoutMath.swept_circle_box(pos, radius, motion, _boss["pos"], BOSS_SIZE)
		if bool(boss_hit["hit"]) and float(boss_hit["t"]) < best_t:
			best_t = float(boss_hit["t"])
			best = {"t": best_t, "normal": boss_hit["normal"], "kind": "boss"}

	# Floor.
	if motion.y < 0.0 and pos.y + motion.y - radius <= FLOOR:
		var t := clampf((FLOOR + radius - pos.y) / motion.y, 0.0, 1.0)
		if t < best_t:
			best_t = t
			best = {"t": t, "normal": Vector2.UP, "kind": "floor"}
	return best


func _handle_hit(ball: Dictionary, hit: Dictionary, normal: Vector2) -> void:
	match String(hit["kind"]):
		"wall":
			Audio.play_sfx("wall", randf_range(0.95, 1.06), -8.0)
		"paddle":
			Audio.play_sfx("paddle", randf_range(0.96, 1.05), -3.0)
			var offset := float(hit.get("offset", 0.0))
			var speed := _current_speed()
			ball["vel"] = BreakoutMath.paddle_bounce(offset, speed)
			_shake(0.06)
		"brick":
			_damage_brick(hit["brick"], 1 + (1 if _effects.has("heavy_ball") else 0) + (1 if _effects.has("overdrive") else 0))
		"boss":
			_damage_boss(1 + (1 if _effects.has("heavy_ball") else 0) + (1 if _effects.has("overdrive") else 0))
		"floor":
			_lose_ball(ball)


func _damage_brick(brick: Dictionary, amount: int) -> void:
	if not bool(brick["alive"]):
		return
	var kind := String(brick["kind"])
	if kind == "steel":
		Audio.play_sfx("steel", randf_range(0.92, 1.02), -3.0)
		_shake(0.05)
		return
	var damage := amount
	if _effects.has("fire_ball"):
		damage = 99
	brick["hp"] = int(brick["hp"]) - damage
	if int(brick["hp"]) > 0:
		Audio.play_sfx("brick", randf_range(0.95, 1.08), -4.0)
		_flash(brick["node"], brick["kind"])
		_shake(0.03)
		return
	_destroy_brick(brick)


func _destroy_brick(brick: Dictionary) -> void:
	if not bool(brick["alive"]):
		return
	brick["alive"] = false
	Audio.play_sfx("brick_break", randf_range(0.94, 1.06), -2.0)
	var node: Node3D = brick["node"]
	_spawn_shards(Vector2(node.position.x, node.position.y), _color_for(String(brick["kind"])))
	node.queue_free()
	bricks_broken += 1
	_score_mult = _current_mult()
	score += 60 * _score_mult
	if String(brick["kind"]) == "crystal":
		_drop_capsule(node.position, true)
	elif String(brick["kind"]) == "bomb":
		_explode_brick(brick, 1.7, 2)
	elif _config["drops"] and randf() < 0.07:
		_drop_capsule(node.position, false)
	if _effects.has("explosive_ball"):
		_explode_brick(brick, 1.6, 1)
	if _effects.has("chain_ball"):
		_chain_from(brick, 2)



func _explode_brick(source: Dictionary, radius: float, damage: int) -> void:
	var origin: Vector2 = source["pos"]
	for brick in _bricks:
		if not bool(brick["alive"]) or brick == source:
			continue
		if origin.distance_to(brick["pos"]) <= radius:
			_damage_brick(brick, damage)


func _chain_from(source: Dictionary, count: int) -> void:
	var origin: Vector2 = source["pos"]
	var candidates: Array = []
	for brick in _bricks:
		if bool(brick["alive"]) and brick != source:
			candidates.append([origin.distance_to(brick["pos"]), brick])
	candidates.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for i in range(mini(count, candidates.size())):
		var brick: Dictionary = candidates[i][1]
		_damage_brick(brick, 2)
		_spawn_bolt(origin, brick["pos"])


func _current_mult() -> int:
	var mult := 1
	if _effects.has("score_x2"):
		mult = maxi(mult, 2)
	if _effects.has("score_x3"):
		mult = maxi(mult, 3)
	if _effects.has("overdrive"):
		mult = maxi(mult, 2)
	return mult


func _damage_boss(amount: int) -> void:
	if _boss.is_empty() or not bool(_boss.get("alive", false)):
		return
	_boss["hp"] = int(_boss["hp"]) - amount
	Audio.play_sfx("boss_hit", randf_range(0.9, 1.06), -2.0)
	_shake(0.09)
	score += 25 * _current_mult()
	var ratio := float(_boss["hp"]) / float(_boss["max_hp"])
	var phase := 1
	if ratio <= 0.34:
		phase = 3
	elif ratio <= 0.67:
		phase = 2
	if phase != int(_boss["phase"]):
		_boss["phase"] = phase
		_boss["timer"] = 0.5
		Audio.play_sfx("combo", 0.8, -2.0)
		_shake(0.16)
	if int(_boss["hp"]) <= 0:
		_boss["alive"] = false
		var node: Node3D = _boss["node"]
		_spawn_shards(Vector2(node.position.x, node.position.y), _accent, 18)
		node.queue_free()
		score += 1200 * _current_mult()
		bosses_beaten += 1
		Audio.play_sfx("boss_die", 1.0, 0.0)
		_shake(0.4)


func _lose_ball(ball: Dictionary) -> void:
	if not _balls.has(ball):
		return
	_balls.erase(ball)
	if is_instance_valid(ball["node"]):
		ball["node"].queue_free()
	if _saves > 0 and not _effects.has("invulnerability"):
		_saves -= 1
		var speed := _current_speed()
		_spawn_ball(Vector2(_paddle_x, PADDLE_Y + 1.2), Vector2(0.35, 1).normalized() * speed)
		Audio.play_sfx("power", 1.2, -2.0)
		return
	if _balls.size() > 0:
		return
	if _effects.has("invulnerability") or mode == "zen":
		var speed := _current_speed()
		_spawn_ball(Vector2(_paddle_x, PADDLE_Y + 1.2), Vector2(0.3, 1).normalized() * speed)
		return
	lives -= 1
	balls_dropped += 1
	Save.count_ball_lost()
	Audio.play_sfx("life_lost", 1.0, -1.0)
	_shake(0.25)
	ball_lost_signal.emit()
	if lives <= 0:
		_finish(false)
		return
	_attach_ball()


func _finish(win: bool) -> void:
	if ended:
		return
	ended = true
	running = false
	var par := int(level.get("par", 1000))
	if mode == "endless" or mode == "survival" or mode == "bossrush":
		par = maxi(1000, int(1400 * stage))
	if mode == "zen":
		par = maxi(600, int(900 * stage))
	var stars := BreakoutMath.stars_for(score, par) if win else 0
	if win:
		Audio.play_sfx("level_clear", 1.0, 0.0)
	else:
		Audio.play_sfx("level_fail", 1.0, 0.0)
	finished.emit({
		"win": win,
		"score": score,
		"stars": stars,
		"bricks": bricks_broken,
		"powers": powers_caught,
		"no_hit": balls_dropped == 0,
		"lives": lives,
		"stage": stage,
		"bosses": bosses_beaten,
		"mode": mode,
		"level_id": level_id,
		"duration": elapsed,
	})


func _check_stage() -> void:
	if ended:
		return
	if _config["boss_rush"]:
		if not _boss.is_empty() and not bool(_boss.get("alive", true)):
			_next_boss_rush()
		return
	var remaining := 0
	for brick in _bricks:
		if bool(brick["alive"]) and String(brick["kind"]) != "steel":
			remaining += 1
	if not _boss.is_empty():
		if not bool(_boss.get("alive", false)):
			_complete_stage()
		return
	if remaining == 0 and _bricks.size() > 0:
		_complete_stage()


func _complete_stage() -> void:
	if _config["endless"]:
		stage += 1
		score += 250
		_next_endless_level()
		return
	_finish(true)


func _next_endless_level() -> void:
	var next_id := level_id + 1
	if mode == "survival":
		next_id = 1 + (stage * 7) % Campaign.LEVEL_COUNT
	elif mode == "zen":
		next_id = 1 + (stage * 3) % 200
	level_id = Campaign.clamp_level(next_id)
	_world = Campaign.world(level_id)
	_clear_balls()
	_load_level(level_id)
	_clear_projectiles()
	_attach_ball()
	Audio.play_sfx("combo", 0.9, -3.0)


func _next_boss_rush() -> void:
	stage += 1
	lives = mini(lives + 1, 5)
	var boss_number := (bosses_beaten) % Campaign.BOSSES.size()
	var fake_id := boss_number * Campaign.LEVELS_PER_WORLD + 10
	level_id = Campaign.clamp_level(fake_id)
	_world = Campaign.world(level_id)
	level = Campaign.generate(level_id)
	_spawn_boss(level["boss_data"])
	var hp := int(level["boss_data"]["hp"]) + bosses_beaten * 10
	_boss["hp"] = hp
	_boss["max_hp"] = hp
	score += 400
	_clear_balls()
	_attach_ball()


func _clear_balls() -> void:
	for ball in _balls:
		if is_instance_valid(ball["node"]):
			ball["node"].queue_free()
	_balls.clear()


func _clear_projectiles() -> void:
	for capsule in _capsules:
		if is_instance_valid(capsule["node"]):
			capsule["node"].queue_free()
	_capsules.clear()
	for shot in _boss_shots:
		if is_instance_valid(shot["node"]):
			shot["node"].queue_free()
	_boss_shots.clear()


# --------------------------------------------------------------------------
# boss attacks
# --------------------------------------------------------------------------

func _tick_boss(dt: float) -> void:
	if _boss.is_empty() or not bool(_boss.get("alive", false)):
		return
	var phase := int(_boss["phase"])
	_boss["drift"] = float(_boss["drift"]) + dt * (0.55 + phase * 0.22)
	var span := 2.2
	var x := sin(float(_boss["drift"])) * span
	_boss["pos"] = Vector2(x, BOSS_Y + sin(float(_boss["drift"]) * 1.7) * 0.28)
	var node: Node3D = _boss["node"]
	node.position = Vector3(_boss["pos"].x, _boss["pos"].y, 0)
	node.rotation.y = sin(float(_boss["drift"]) * 0.6) * 0.4

	if _effects.has("boss_freeze"):
		return
	_boss["timer"] = float(_boss["timer"]) - dt
	if float(_boss["timer"]) > 0.0:
		return
	var data: Dictionary = _boss["data"]
	var base_period := float(data.get("period", 2.0))
	_boss["timer"] = maxf(0.65, base_period - phase * 0.18)
	var shots := int(data.get("shots", 1)) + (phase - 1)
	var spread := float(data.get("spread", 0.0)) + (phase - 1) * 0.14
	var speed := float(data.get("speed", 7.0)) + phase * 0.6
	_fire_boss_shots(shots, spread, speed)
	Audio.play_sfx("boss_shot", randf_range(0.92, 1.05), -6.0)


func _fire_boss_shots(count: int, spread: float, speed: float) -> void:
	var origin: Vector2 = _boss["pos"] + Vector2(0, -1.3)
	for i in range(count):
		var t := 0.0
		if count > 1:
			t = (float(i) / float(count - 1)) * 2.0 - 1.0
		var direction := Vector2(sin(t * spread), -1.0).normalized()
		var node := Models.spawn("ball", Color("#ff5c8a"))
		if node == null:
			node = Node3D.new()
		node.scale = Vector3.ONE * 0.62
		node.position = Vector3(origin.x, origin.y, 0)
		_fx_root.add_child(node)
		_boss_shots.append({
			"pos": origin,
			"vel": direction * speed,
			"node": node,
			"radius": 0.19,
		})


func _tick_boss_shots(dt: float) -> void:
	var paddle_size := Vector2(PADDLE_HALF * 2.0 * _paddle_scale, PADDLE_HEIGHT * 2.0)
	for shot in _boss_shots.duplicate():
		shot["pos"] = shot["pos"] + shot["vel"] * dt
		var pos: Vector2 = shot["pos"]
		var node: Node3D = shot["node"]
		if is_instance_valid(node):
			node.position = Vector3(pos.x, pos.y, 0)
			node.rotation.x += dt * 3.0

		if _effects.has("mirror_paddle") or _effects.has("reflect_shots"):
			if pos.y < PADDLE_Y + 1.2 and absf(pos.x - _paddle_x) < PADDLE_HALF * _paddle_scale + 0.4:
				_reflect_shot(shot)
				continue

		if absf(pos.x - _paddle_x) < PADDLE_HALF * _paddle_scale + 0.12 \
				and absf(pos.y - PADDLE_Y) < 0.55:
			_boss_shots.erase(shot)
			if is_instance_valid(node):
				node.queue_free()
			if _effects.has("invulnerability") or mode == "zen":
				continue
			lives -= 1
			balls_dropped += 0
			Audio.play_sfx("life_lost", 0.9, -2.0)
			_shake(0.2)
			ball_lost_signal.emit()
			if lives <= 0:
				_finish(false)
			continue

		if pos.y < FLOOR - 1.0:
			_boss_shots.erase(shot)
			if is_instance_valid(node):
				node.queue_free()


func _reflect_shot(shot: Dictionary) -> void:
	_boss_shots.erase(shot)
	if is_instance_valid(shot["node"]):
		shot["node"].queue_free()
	if _boss.is_empty() or not bool(_boss.get("alive", false)):
		return
	_damage_boss(2)
	score += 40 * _current_mult()
	Audio.play_sfx("combo", 1.1, -4.0)


# --------------------------------------------------------------------------
# capsules
# --------------------------------------------------------------------------

func _drop_capsule(at: Vector3, guaranteed: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(elapsed * 1000.0) + bricks_broken * 17 + (1000 if guaranteed else 0)
	var id := PowerUps.roll(rng, clampf(bricks_broken / 40.0, 0.0, 1.0))
	var item := PowerUps.by_id(id)
	var node := Models.spawn("capsule", Color(String(item.get("tint", "#ffd166"))))
	if node == null:
		node = Node3D.new()
	Models.paint(node, Color(String(item.get("tint", "#ffd166"))), 0.7)
	node.position = at
	var label := Label3D.new()
	label.text = String(item.get("glyph", "?"))
	label.font_size = 96
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#0b0b12")
	label.outline_modulate = Color("#ffffff")
	label.outline_size = 12
	label.position = Vector3(0, 0.1, 0.35)
	node.add_child(label)
	_fx_root.add_child(node)
	_capsules.append({
		"id": id,
		"pos": Vector2(at.x, at.y),
		"node": node,
		"speed": 3.2,
	})


func _tick_capsules(dt: float) -> void:
	for capsule in _capsules.duplicate():
		var pos: Vector2 = capsule["pos"]
		var speed := float(capsule["speed"])
		if _effects.has("magnet_field"):
			var target := Vector2(_paddle_x, PADDLE_Y)
			var direction := (target - pos).normalized()
			pos += direction * maxf(speed, 5.5) * dt
		else:
			pos.y -= speed * dt
		capsule["pos"] = pos
		var node: Node3D = capsule["node"]
		if is_instance_valid(node):
			node.position = Vector3(pos.x, pos.y, 0)
			node.rotation.y += dt * 2.2

		var reach := PADDLE_HALF * _paddle_scale + 0.42
		if pos.y <= PADDLE_Y + 0.6 and pos.y > PADDLE_Y - 0.9 and absf(pos.x - _paddle_x) < reach:
			_capsules.erase(capsule)
			if is_instance_valid(node):
				node.queue_free()
			_apply_power(String(capsule["id"]))
			continue
		if pos.y < FLOOR - 0.6:
			_capsules.erase(capsule)
			if is_instance_valid(node):
				node.queue_free()


func _apply_power(id: String) -> void:
	var item := PowerUps.by_id(id)
	if item.is_empty():
		return
	powers_caught += 1
	Save.count_power()
	power_caught.emit(id)
	if bool(item.get("hazard", false)):
		Audio.play_sfx("hazard", 1.0, -2.0)
	else:
		Audio.play_sfx("power", 1.0, -2.0)
	var duration := float(item.get("duration", 0.0))

	match id:
		"multi_ball":
			_split_balls()
		"giant_ball":
			for ball in _balls:
				ball["radius"] = 0.42
			_effects[id] = duration
		"tiny_ball":
			for ball in _balls:
				ball["radius"] = 0.13
			_effects[id] = duration
		"heavy_ball", "slow_ball", "fast_ball", "chaos_ball", "magnet_ball", "chain_ball", "fire_ball", "explosive_ball", "wide_paddle", "narrow_paddle", "magnet_paddle", "sticky_paddle", "mirror_paddle", "time_slow", "magnet_field", "reflect_shots", "barrier_wall", "hyper_paddle", "boss_freeze":
			_effects[id] = duration
		"score_x2", "score_x3":
			_effects.erase("score_x2")
			_effects.erase("score_x3")
			_effects[id] = duration
			_score_mult = _current_mult()
		"overdrive":
			_effects[id] = duration
			_score_mult = _current_mult()
		"laser_paddle":
			_effects[id] = duration
			_laser_timer = 0.0
		"turret_paddle":
			_effects[id] = duration
			_turret_timer = 0.0
		"shield_floor":
			_saves += 1
		"repair_shield":
			_saves = maxi(_saves, 2)
		"extra_life":
			lives += 1
		"coin_rush":
			Save.add_credits(150)
			score += 300
		"bomb":
			_damage_all(1)
		"row_laser":
			_damage_lowest_row(99)
		"column_laser":
			_damage_column(randi() % Campaign.COLS, 99)
		"drone":
			_drones = mini(_drones + 1, 4)
			_drone_timer = 0.0
		"twin_drone":
			_drones = mini(_drones + 2, 4)
			_drone_timer = 0.0
		"drone_upgrade":
			_drones = maxi(_drones, 1)
			_effects["drone_upgrade"] = 999.0
		"lucky_drop":
			for i in range(3):
				var offset := Vector3(clampf(_paddle_x + (i - 1) * 0.9, -FIELD_HALF + 0.6, FIELD_HALF - 0.6), 3.0 + i * 0.5, 0)
				_drop_capsule(offset, true)
		"invulnerability":
			_effects[id] = duration
		"starfall":
			for i in range(6):
				var alive: Array = _bricks.filter(func(b): return bool(b["alive"]) and String(b["kind"]) != "steel")
				if alive.is_empty():
					break
				var brick: Dictionary = alive[randi() % alive.size()]
				_damage_brick(brick, 3)
				_spawn_shard_burst(brick["pos"], _glow)


func _split_balls() -> void:
	var existing := _balls.duplicate()
	for ball in existing:
		if _balls.size() >= MAX_BALLS:
			break
		var vel: Vector2 = ball["vel"]
		if vel.length() < 0.1:
			vel = Vector2(0, 1) * _current_speed()
		for angle in [-0.42, 0.42]:
			if _balls.size() >= MAX_BALLS:
				break
			_spawn_ball(ball["pos"], vel.rotated(angle).normalized() * _current_speed())


func _damage_all(amount: int) -> void:
	for brick in _bricks:
		if bool(brick["alive"]):
			_damage_brick(brick, amount)


func _damage_column(column: int, amount: int) -> void:
	for brick in _bricks:
		if int(brick["c"]) == column and bool(brick["alive"]):
			_damage_brick(brick, amount)


func _damage_lowest_row(amount: int) -> void:
	var lowest := -1
	for brick in _bricks:
		if bool(brick["alive"]):
			lowest = maxi(lowest, int(brick["r"]))
	if lowest < 0:
		return
	for brick in _bricks:
		if int(brick["r"]) == lowest and bool(brick["alive"]):
			_damage_brick(brick, amount)


func _tick_assists(dt: float) -> void:
	if _effects.has("laser_paddle"):
		_laser_timer = float(_laser_timer) - dt
		if _laser_timer <= 0.0:
			_laser_timer = 0.42
			_fire_side_lasers()
	if _effects.has("turret_paddle"):
		_turret_timer = float(_turret_timer) - dt
		if _turret_timer <= 0.0:
			_turret_timer = 0.85
			_damage_column(0, 1)
			_damage_column(Campaign.COLS - 1, 1)

	if _drones > 0:
		_drone_timer = float(_drone_timer) - dt
		var rate := 3.4
		if _effects.has("drone_upgrade"):
			rate = 1.8
		if _drone_timer <= 0.0:
			_drone_timer = rate
			_drone_strike()


func _fire_side_lasers() -> void:
	var alphas: Array = _bricks.filter(func(b): return bool(b["alive"]) and String(b["kind"]) != "steel")
	if alphas.is_empty():
		return
	for brick in alphas:
		if absf(float(brick["node"].position.x) - _paddle_x) < 0.4:
			_damage_brick(brick, 2)
			_spawn_bolt(Vector2(_paddle_x, PADDLE_Y), brick["pos"])
			break


func _drone_strike() -> void:
	var alphas: Array = _bricks.filter(func(b): return bool(b["alive"]) and String(b["kind"]) != "steel")
	if alphas.is_empty():
		return
	var brick: Dictionary = alphas[randi() % alphas.size()]
	_damage_brick(brick, 1)
	_spawn_bolt(Vector2(sin(elapsed * 2.0) * 2.4, -1.0), brick["pos"])


# --------------------------------------------------------------------------
# visual effects
# --------------------------------------------------------------------------

func _spawn_shards(pos: Vector2, color: Color, count := 7) -> void:
	_spawn_shard_burst(pos, color, count)


func _spawn_shard_burst(pos: Vector2, color: Color, count := 7) -> void:
	for i in range(count):
		if _shards.size() > 90:
			break
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var size := randf_range(0.09, 0.2)
		mesh.size = Vector3(size, size, size)
		node.mesh = mesh
		node.material_override = Models.glow_material(color, 1.4)
		node.position = Vector3(pos.x, pos.y, randf_range(-0.1, 0.4))
		_fx_root.add_child(node)
		_shards.append({
			"node": node,
			"vel": Vector3(randf_range(-4.0, 4.0), randf_range(-4.6, 3.4), randf_range(-2.0, 2.0)),
			"life": 0.0,
			"ttl": randf_range(0.5, 0.9),
		})


func _spawn_bolt(from: Vector2, to: Vector2) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 1.0)
	node.mesh = mesh
	node.material_override = Models.glow_material(_glow, 2.6)
	var mid := (from + to) * 0.5
	node.position = Vector3(mid.x, mid.y, 0.4)
	var length := from.distance_to(to)
	node.scale = Vector3(1, 1, length)
	node.rotation.z = (to - from).angle() - PI * 0.5
	_fx_root.add_child(node)
	_shards.append({"node": node, "vel": Vector3.ZERO, "life": 0.0, "ttl": 0.16})


func _flash(node: Node, kind: String) -> void:
	if not is_instance_valid(node):
		return
	var mesh_instances := (node as Node).find_children("*", "MeshInstance3D", true, false)
	for child in mesh_instances:
		var mesh_instance := child as MeshInstance3D
		mesh_instance.scale = Vector3.ONE * 1.08
		var tween := create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.12)


func _shake(amount: float) -> void:
	if _reduced_motion:
		return
	_shake_power = maxf(_shake_power, amount)
	shake_requested.emit(amount)


func _animate(delta: float) -> void:
	# Shards, bolts and capsule sparkle share one cheap pool.
	for shard in _shards.duplicate():
		shard["life"] = float(shard["life"]) + delta
		var node: Node3D = shard["node"]
		if not is_instance_valid(node):
			_shards.erase(shard)
			continue
		if float(shard["life"]) >= float(shard["ttl"]):
			node.queue_free()
			_shards.erase(shard)
			continue
		var vel: Vector3 = shard["vel"]
		vel.y -= 14.0 * delta
		node.position += vel * delta
		node.rotation.x += delta * 6.0
		node.rotation.z += delta * 5.0
		shard["vel"] = vel

	if _shake_power > 0.0:
		_shake_power = maxf(0.0, _shake_power - delta * 1.6)
		var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_power * 0.35
		_camera.position = _camera_base + offset
	else:
		_camera.position = _camera_base

	if _paddle != null:
		var target_roll := clampf((_paddle_x - _paddle.position.x) * -0.4, -0.3, 0.3)
		_paddle.rotation.z = lerpf(_paddle.rotation.z, target_roll, clampf(delta * 8.0, 0.0, 1.0))
		_paddle.position.y = PADDLE_Y + sin(elapsed * 2.2) * 0.03
		if _paddle_light != null:
			_paddle_light.position = Vector3(_paddle.position.x, PADDLE_Y + 0.2, 1.2)


# --------------------------------------------------------------------------
# external controls / readouts
# --------------------------------------------------------------------------

func set_paused(value: bool) -> void:
	paused = value
	if value:
		_pointer_held = false


func abandon() -> void:
	running = false
	ended = true


func debug_ball() -> Dictionary:
	if _balls.is_empty():
		return {}
	var ball: Dictionary = _balls[0]
	return {
		"x": float(ball["pos"].x),
		"y": float(ball["pos"].y),
		"vx": float(ball["vel"].x),
		"vy": float(ball["vel"].y),
		"stuck": bool(ball["stuck"]),
		"count": _balls.size(),
	}


func hud() -> Dictionary:
	var boss_ratio := 0.0
	var boss_name := ""
	if not _boss.is_empty():
		boss_ratio = clampf(float(_boss["hp"]) / maxf(1.0, float(_boss["max_hp"])), 0.0, 1.0)
		boss_name = String(_boss["data"].get("name", "Boss"))
	var timers: Array = []
	for id in _effects.keys():
		if float(_effects[id]) > 0.0 and float(_effects[id]) < 900.0:
			timers.append({"id": id, "time": float(_effects[id])})
	timers.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	var stuck := false
	for ball in _balls:
		if bool(ball["stuck"]):
			stuck = true
	return {
		"score": score,
		"lives": lives,
		"stuck": stuck,
		"stage": stage,
		"bricks": bricks_broken,
		"boss": boss_ratio,
		"boss_name": boss_name,
		"effects": timers,
		"saves": _saves,
		"drones": _drones,
		"mult": _current_mult(),
	}
