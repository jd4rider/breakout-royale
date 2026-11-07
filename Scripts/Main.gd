extends Node
## App shell: title, campaign map, level grid, HUD, results, trophies, settings.
## Gameplay itself lives in `GameField`; this script owns navigation and saves.

const INK := Color("#f7f2ff")
const MUTED := Color("#a99fc4")
const DIM := Color("#6f6786")
const GOLD := Color("#ffd166")
const PINK := Color("#ff3fd8")
const CYAN := Color("#00e5ff")
const PANEL := Color("#171128")
const PANEL_HI := Color("#211838")
const DANGER := Color("#ff5c5c")

var _world_root: Node3D
var _ui: CanvasLayer
var _screen_root: Control
var _field: GameField
var _mode := "campaign"
var _level_id := 1
var _screen := "title"
var _paused := false
var _result_open := false
var _session_start_ms := 0
var _account_button: Button
var _debug_timer := 0.0

var _score_label: Label
var _lives_label: Label
var _meta_label: Label
var _effect_label: Label
var _hint_label: Label
var _boss_bar: ProgressBar
var _boss_name: Label


func _ready() -> void:
	_world_root = Node3D.new()
	_world_root.name = "World"
	add_child(_world_root)
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	Audio.play_music("menu")
	Save.achievement_unlocked.connect(_on_achievement)
	Arcade.identity_changed.connect(_refresh_account)
	_show_title()
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval(
			"typeof location !== 'undefined' ? location.search : ''", true)
		var search := String(query) if query != null else ""
		if search.contains("autostart"):
			var mode := "campaign"
			if search.contains("mode=endless"):
				mode = "endless"
			elif search.contains("mode=bossrush"):
				mode = "bossrush"
			_start_game(mode, 10 if mode == "bossrush" else 1)


func _input(event: InputEvent) -> void:
	if _screen != "game" or _result_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			_toggle_pause()


# --------------------------------------------------------------------------
# shared UI helpers
# --------------------------------------------------------------------------

func _clear_screen(background := true) -> Control:
	if _screen_root != null and is_instance_valid(_screen_root):
		_screen_root.queue_free()
	_screen_root = Control.new()
	_screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui.add_child(_screen_root)
	if not background:
		return _screen_root
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#1c0b33"))
	gradient.set_color(1, Color("#070510"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.2, 0.0)
	texture.fill_to = Vector2(0.8, 1.0)
	texture.width = 8
	texture.height = 256
	var back := TextureRect.new()
	back.texture = texture
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_root.add_child(back)
	return _screen_root


func _label(text: String, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _box(color: Color, radius := 22, border := Color.TRANSPARENT, pad := 18) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if border.a > 0.0:
		box.border_width_left = 2
		box.border_width_right = 2
		box.border_width_top = 2
		box.border_width_bottom = 2
		box.border_color = border
	return box


func _button(text: String, size: int, height: int, color: Color, on_press: Callable,
		text_color := Color("#0b0714"), pad := 16) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_stylebox_override("normal", _box(color, 22, Color.TRANSPARENT, pad))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.08), 22, Color.TRANSPARENT, pad))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.12), 22, Color.TRANSPARENT, pad))
	button.add_theme_stylebox_override("disabled", _box(Color("#241d38"), 22, Color.TRANSPARENT, pad))
	button.pressed.connect(func() -> void:
		Audio.ui_click()
		on_press.call())
	return button


func _ghost_button(text: String, on_press: Callable, height := 78, size := 24, pad := 16) -> Button:
	var button := _button(text, size, height, Color("#241c3b"), on_press, INK, pad)
	button.add_theme_stylebox_override("normal", _box(Color("#241c3b"), 20, Color("#3b2f5c"), pad))
	button.add_theme_stylebox_override("hover", _box(Color("#2e2449"), 20, PINK, pad))
	return button


func _page(margins := 34) -> VBoxContainer:
	var screen := _clear_screen()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", margins)
	margin.add_theme_constant_override("margin_right", margins)
	margin.add_theme_constant_override("margin_top", margins + 14)
	margin.add_theme_constant_override("margin_bottom", margins)
	screen.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	return column


func _header(column: VBoxContainer, title: String, back: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var back_button := _button("‹", 30, 62, Color("#241c3b"), back, INK)
	back_button.custom_minimum_size.x = 68
	back_button.add_theme_stylebox_override("normal", _box(Color("#241c3b"), 18, Color("#3b2f5c")))
	back_button.add_theme_stylebox_override("hover", _box(Color("#2e2449"), 18, PINK))
	row.add_child(back_button)
	var heading := _label(title, 34, INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(heading)


## The built-in font has no star glyph, so the score stars are ASCII on
## purpose: a missing glyph would render as a tofu box.
func _stars_text(stars: int) -> String:
	return "*".repeat(clampi(stars, 0, 3)) + "-".repeat(clampi(3 - stars, 0, 3))


# --------------------------------------------------------------------------
# title
# --------------------------------------------------------------------------

func _show_title() -> void:
	_screen = "title"
	Audio.play_music("menu")
	Arcade.refresh_identity()
	var column := _page(32)

	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 0)
	column.add_child(top)
	top.add_child(_label("BREAKOUT", 58, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(_label("ROYALE 3D", 58, INK, HORIZONTAL_ALIGNMENT_CENTER))
	var tagline := _label("20 worlds. 1,000 walls. Break them all.",
			20, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(tagline)

	_account_button = Button.new()
	_account_button.text = Arcade.status_text()
	_account_button.custom_minimum_size.y = 56
	_account_button.add_theme_font_size_override("font_size", 18)
	_account_button.add_theme_color_override("font_color", MUTED)
	_account_button.add_theme_stylebox_override("normal", _box(Color("#150f26"), 16, Color("#2e2444")))
	_account_button.add_theme_stylebox_override("hover", _box(Color("#1e1633"), 16, CYAN))
	_account_button.pressed.connect(func() -> void:
		if Arcade.available:
			Arcade.sign_in()
		else:
			Arcade.open_arcade())
	column.add_child(_account_button)

	var progress := _label("STARS %d   |   %d / %d LEVELS   |   %d CREDITS" % [
			Save.total_stars(), Save.completed_levels(), Campaign.LEVEL_COUNT, Save.credits()],
			17, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(progress)

	var next_id := Save.next_level()
	var continue_button := _button("CONTINUE  ·  %s" % Campaign.level_name(next_id),
			27, 96, PINK, _continue)
	column.add_child(continue_button)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	var entries := [
		["CAMPAIGN", func() -> void: _show_campaign()],
		["ENDLESS", func() -> void: _start_game("endless", 1)],
		["SURVIVAL", func() -> void: _start_game("survival", 1)],
		["BOSS RUSH", func() -> void: _start_game("bossrush", 10)],
		["DAILY", _start_daily],
		["ZEN PATROL", func() -> void: _start_game("zen", 1)],
		["ARCADE", func() -> void: _start_game("arcade", 1)],
		["TROPHIES", func() -> void: _show_trophies()],
	]
	for entry in entries:
		var text: String = entry[0]
		var action: Callable = entry[1]
		grid.add_child(_ghost_button(text, action, 76, 20, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var settings := _ghost_button("SETTINGS", func() -> void: _show_settings(), 64, 20)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(settings)
	var arcade := _ghost_button("THE ARCADE", func() -> void: Arcade.open_arcade(), 64, 20)
	arcade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(arcade)

	var foot := _label("1,000 LEVELS  /  20 WORLDS  /  20 BOSSES  /  40 POWER-UPS",
			14, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(foot)
	_refresh_account()


func _refresh_account() -> void:
	if _screen != "title":
		return
	if _account_button != null and is_instance_valid(_account_button):
		_account_button.text = Arcade.status_text()


func _continue() -> void:
	var id := Save.next_level()
	_start_game("campaign", id)


func _start_daily() -> void:
	var id := (Save.daily_seed() % Campaign.LEVEL_COUNT) + 1
	_start_game("daily", id)
	Audio.play_sfx("combo", 1.2, -4.0)


# --------------------------------------------------------------------------
# campaign
# --------------------------------------------------------------------------

func _show_campaign() -> void:
	_screen = "campaign"
	var column := _page(30)
	_header(column, "CAMPAIGN", _show_title)
	column.add_child(_label("STARS %d / %d  -  clear ten levels of a world to open the next" % [
			Save.total_stars(), Campaign.LEVEL_COUNT * 3], 16, MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for w in range(Campaign.WORLD_COUNT):
		var data: Dictionary = Campaign.WORLDS[w]
		var unlocked := Save.is_world_unlocked(w)
		var cleared := Save.completed_in_world(w)
		var stars := Save.stars_in_world(w)
		var text := "%02d   %s\n%s   -   %d/50 cleared   -   STARS %d/150" % [
			w + 1, String(data["name"]), "OPEN" if unlocked else "LOCKED", cleared, stars]
		var card := _button(text, 21, 104,
				Color(String(data["accent"])) if unlocked else Color("#241d38"),
				(func() -> void: _show_world(w)) if unlocked else (func() -> void: pass),
				Color("#0b0714") if unlocked else DIM)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_constant_override("h_separation", 10)
		list.add_child(card)


func _show_world(world_index: int) -> void:
	_screen = "world"
	var column := _page(26)
	var data: Dictionary = Campaign.WORLDS[world_index]
	_header(column, String(data["name"]), _show_campaign)
	column.add_child(_label(String(data["tagline"]), 18, MUTED))
	var first := world_index * Campaign.LEVELS_PER_WORLD + 1
	column.add_child(_label("STARS %d / 150   -   every 10th level is a boss" % Save.stars_in_world(world_index),
			16, GOLD))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for local in range(1, Campaign.LEVELS_PER_WORLD + 1):
		var id := first + local - 1
		var stars := Save.level_stars(id)
		var open := local == 1 or Save.is_level_complete(id - 1)
		if not Save.is_world_unlocked(world_index):
			open = false
		var label := "%02d\n%s" % [local, _stars_text(stars)]
		var button := _button(label, 17, 84,
				Color(String(data["accent"])) if open else Color("#211a33"),
				(func() -> void: _start_game("campaign", id)) if open else (func() -> void: pass),
				Color("#0b0714") if open else DIM)
		if Campaign.is_boss_level(id):
			button.add_theme_color_override("font_color", GOLD if open else DIM)
		button.disabled = not open
		grid.add_child(button)


# --------------------------------------------------------------------------
# game
# --------------------------------------------------------------------------

func _start_game(mode: String, level_id: int) -> void:
	_mode = mode
	_level_id = Campaign.clamp_level(level_id)
	_screen = "game"
	_paused = false
	_result_open = false
	_session_start_ms = Time.get_ticks_msec()
	if _field != null and is_instance_valid(_field):
		_field.queue_free()
		_field = null
	Audio.kick()
	_clear_screen(false)
	_build_hud()

	_field = GameField.new()
	_field.name = "GameField"
	_world_root.add_child(_field)
	_field.setup(_mode, _level_id)
	_field.finished.connect(_on_finished)
	_field.power_caught.connect(_on_power)
	_field.ball_lost_signal.connect(_on_ball_lost)
	_meta_label.text = _meta_text()
	Audio.play_music("game")


func _meta_text() -> String:
	match _mode:
		"endless":
			return "ENDLESS  -  level %d" % maxi(1, _field.stage if _field != null else 1)
		"survival":
			return "SURVIVAL  -  wave %d" % maxi(1, _field.stage if _field != null else 1)
		"bossrush":
			return "BOSS RUSH  -  boss %d" % maxi(1, _field.bosses_beaten + 1 if _field != null else 1)
		"daily":
			return "DAILY  -  %s" % Save.daily_date_key()
		"zen":
			return "ZEN PATROL  -  board %d" % maxi(1, _field.stage if _field != null else 1)
		"arcade":
			return "ARCADE CLASSIC  -  no power-ups"
		_:
			return "%s  -  %s" % [Campaign.level_name(_level_id), "BOSS" if Campaign.is_boss_level(_level_id) else "WAVE"]


func _build_hud() -> void:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_root.add_child(hud)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stack.offset_left = 22
	stack.offset_right = -22
	stack.offset_top = 22
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stack)
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 62
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top)
	var pause := _button("II", 22, 58, Color("#241c3b"), _toggle_pause, INK)
	pause.custom_minimum_size.x = 58
	pause.add_theme_stylebox_override("normal", _box(Color("#241c3b"), 16, Color("#3b2f5c")))
	pause.add_theme_stylebox_override("hover", _box(Color("#2e2449"), 16, PINK))
	pause.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_child(pause)

	_score_label = _label("0", 34, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_score_label)

	_lives_label = _label("LIVES 3", 22, Color("#ff8fb1"), HORIZONTAL_ALIGNMENT_RIGHT)
	_lives_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_lives_label.custom_minimum_size.x = 118
	top.add_child(_lives_label)

	_meta_label = _label("", 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(_meta_label)

	_boss_name = _label("", 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(_boss_name)

	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size.y = 16
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	var fill := _box(PINK, 8)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	_boss_bar.add_theme_stylebox_override("fill", fill)
	var back := _box(Color("#2a2140"), 8)
	back.content_margin_top = 0
	back.content_margin_bottom = 0
	_boss_bar.add_theme_stylebox_override("background", back)
	stack.add_child(_boss_bar)

	_hint_label = _label("TAP TO LAUNCH", 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_bottom = -118
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_hint_label)

	_effect_label = _label("", 16, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_effect_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_effect_label.offset_bottom = -46
	_effect_label.offset_left = 24
	_effect_label.offset_right = -24
	hud.add_child(_effect_label)


func _process(delta: float) -> void:
	_debug_timer += delta
	if _debug_timer > 0.4:
		_debug_timer = 0.0
		_publish_state()
	if _screen != "game" or _field == null or not is_instance_valid(_field):
		return
	if _result_open:
		return
	var hud: Dictionary = _field.hud()
	_score_label.text = BreakoutMath.format_score(int(hud["score"]))
	var lives := int(hud["lives"])
	_lives_label.text = "LIVES -" if _mode == "zen" else "LIVES %d" % lives
	_meta_label.text = _meta_text()
	var boss := float(hud["boss"])
	if boss > 0.0:
		_boss_bar.visible = true
		_boss_bar.value = boss
		_boss_name.text = String(hud["boss_name"])
	else:
		_boss_bar.visible = false
		_boss_name.text = ""
	var parts: Array = []
	if int(hud["saves"]) > 0:
		parts.append("SAVES %d" % int(hud["saves"]))
	if int(hud["drones"]) > 0:
		parts.append("DRONES %d" % int(hud["drones"]))
	if int(hud["mult"]) > 1:
		parts.append("SCORE x%d" % int(hud["mult"]))
	for entry in hud["effects"]:
		var id := String(entry["id"])
		var item := PowerUps.by_id(id)
		parts.append("%s %.0fs" % [String(item.get("name", id)).to_upper(), float(entry["time"])])
	_effect_label.text = "   |   ".join(parts)
	_hint_label.visible = bool(hud.get("stuck", false))
	if _hint_label.visible:
		_hint_label.modulate.a = 0.65 + sin(Time.get_ticks_msec() * 0.006) * 0.35


## A tiny read-out for the browser smoke test. It only reports; it never
## changes gameplay, so shipping it is harmless.
func _publish_state() -> void:
	if not OS.has_feature("web"):
		return
	var payload := {
		"screen": _screen,
		"mode": _mode,
		"paused": _paused,
		"score": 0,
		"lives": 0,
		"bricks": 0,
	}
	if _field != null and is_instance_valid(_field):
		var hud: Dictionary = _field.hud()
		payload["score"] = int(hud["score"])
		payload["lives"] = int(hud["lives"])
		payload["bricks"] = int(hud["bricks"])
		payload["boss"] = float(hud["boss"])
		payload["stuck"] = bool(hud["stuck"])
		payload["ball"] = _field.debug_ball()
	var literal := JSON.stringify(JSON.stringify(payload))
	JavaScriptBridge.eval("window.__breakoutState = " + literal, true)


func _toggle_pause() -> void:
	if _field == null or _result_open:
		return
	_paused = not _paused
	_field.set_paused(_paused)
	Audio.ui_click()
	if _paused:
		_build_pause()
	else:
		_clear_overlay()


var _overlay: Control


func _clear_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _build_pause() -> void:
	_clear_overlay()
	_overlay = _overlay_base()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	panel.add_child(_label("PAUSED", 40, INK, HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_label(Campaign.level_name(_level_id), 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_button("RESUME", 26, 82, PINK, _toggle_pause))
	panel.add_child(_ghost_button("RESTART", func() -> void:
		_clear_overlay()
		_start_game(_mode, _level_id)))
	panel.add_child(_ghost_button("QUIT TO MENU", _quit_to_menu))


func _overlay_base() -> Control:
	var base := Control.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen_root.add_child(base)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.add_child(dim)
	return base


func _quit_to_menu() -> void:
	_clear_overlay()
	if _field != null and is_instance_valid(_field):
		_field.abandon()
		_field.queue_free()
		_field = null
	_result_open = false
	_paused = false
	_screen_root = null
	_show_title()


func _on_ball_lost() -> void:
	pass


func _on_power(id: String) -> void:
	var item := PowerUps.by_id(id)
	if not item.is_empty():
		_toast(String(item.get("name", id)), Color(String(item.get("tint", "#ffd166"))))


var _toast_label: Label
var _toast_tween: Tween


func _toast(text: String, color: Color) -> void:
	if _screen_root == null or not is_instance_valid(_screen_root):
		return
	if _toast_label == null or not is_instance_valid(_toast_label):
		_toast_label = _label("", 20, color, HORIZONTAL_ALIGNMENT_CENTER)
		_toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_toast_label.offset_bottom = -150
		_screen_root.add_child(_toast_label)
	_toast_label.text = text.to_upper()
	_toast_label.modulate = Color(1, 1, 1, 1)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.7)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func _on_achievement(id: String) -> void:
	for entry in Save.ACHIEVEMENTS:
		if String(entry["id"]) == id:
			_toast("Trophy: %s" % String(entry["name"]), GOLD)
			return


# --------------------------------------------------------------------------
# results
# --------------------------------------------------------------------------

func _on_finished(result: Dictionary) -> void:
	if _result_open:
		return
	_result_open = true
	var win := bool(result["win"])
	var mode := String(result["mode"])
	var stars := int(result["stars"])
	var score := int(result["score"])
	var unlocked: Array = []
	if win:
		match mode:
			"campaign":
				unlocked = Save.complete_level(int(result["level_id"]), stars, score,
						int(result["bricks"]), bool(result["no_hit"]))
			"daily":
				Save.record_daily(score)
				unlocked = Save.check_achievements()
			"arcade":
				Save.record_mode("arcade", score)
			"bossrush":
				Save.record_mode("bossrush", int(result["bosses"]))
			_:
				pass
	else:
		match mode:
			"endless":
				Save.record_mode("endless", score)
				Save.record_mode("endless_level", int(result["stage"]))
			"survival":
				Save.record_mode("survival", int(result["stage"]))
			"bossrush":
				Save.record_mode("bossrush", int(result["bosses"]))
			"arcade":
				Save.record_mode("arcade", score)
			_:
				pass
	Save.add_play_time((Time.get_ticks_msec() - _session_start_ms) / 1000.0)

	var base := _overlay_base()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.add_child(center)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(panel)

	var title := "BOARD CLEARED" if win else "RUN ENDED"
	if not win and mode == "campaign":
		title = "HULL BREACH"
	panel.add_child(_label(title, 38, GOLD if win else Color("#ff8fb1"), HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_label(_meta_text(), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if win and (mode == "campaign" or mode == "daily"):
		panel.add_child(_label(_stars_text(stars), 52, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_label(BreakoutMath.format_score(score), 46, INK, HORIZONTAL_ALIGNMENT_CENTER))
	var detail := "Bricks %d   |   Power-ups %d   |   Lives %d" % [
			int(result["bricks"]), int(result["powers"]), int(result["lives"])]
	if mode == "endless" or mode == "survival" or mode == "zen":
		detail = "Reached level %d   |   Bricks %d   |   Power-ups %d" % [
				int(result["stage"]), int(result["bricks"]), int(result["powers"])]
	elif mode == "bossrush":
		detail = "Bosses beaten %d   |   Score %s" % [
				int(result["bosses"]), BreakoutMath.format_score(score)]
	panel.add_child(_label(detail, 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if bool(result["no_hit"]) and win:
		panel.add_child(_label("FLAWLESS — no ball lost", 18, CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked.is_empty():
		panel.add_child(_label("Trophy unlocked", 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	panel.add_child(spacer)

	var next_id := Save.next_level()
	if win and mode == "campaign":
		panel.add_child(_button("NEXT  -  %s" % Campaign.level_name(next_id), 24, 84, PINK,
				func() -> void: _start_game("campaign", next_id)))
	elif win and mode == "daily":
		panel.add_child(_button("BACK TO MENU", 24, 84, PINK, _quit_to_menu))
	else:
		panel.add_child(_button("TRY AGAIN", 24, 84, PINK,
				func() -> void: _start_game(mode, _level_id)))
	panel.add_child(_ghost_button("LEVEL MAP" if mode == "campaign" else "MENU", _quit_to_menu, 74))


# --------------------------------------------------------------------------
# trophies + settings
# --------------------------------------------------------------------------

func _show_trophies() -> void:
	_screen = "trophies"
	var column := _page(30)
	_header(column, "TROPHIES", _show_title)
	var earned := (Save.data["achievements"] as Dictionary).size()
	column.add_child(_label("%d / %d earned  -  %d campaign stars" % [
			earned, Save.ACHIEVEMENTS.size(), Save.total_stars()], 16, GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in Save.ACHIEVEMENTS:
		var unlocked := Save.has_achievement(String(entry["id"]))
		var card := PanelContainer.new()
		var style := _box(Color("#171128"), 18, Color("#3b2f5c") if unlocked else Color("#2a2140"))
		card.add_theme_stylebox_override("panel", style)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var name := _label(("*  " if unlocked else "-  ") + String(entry["name"]),
				21, GOLD if unlocked else INK)
		row.add_child(name)
		row.add_child(_label(String(entry["hint"]), 16, MUTED))
		card.add_child(row)
		list.add_child(card)


func _show_settings() -> void:
	_screen = "settings"
	var column := _page(34)
	_header(column, "SETTINGS", _show_title)

	column.add_child(_label("Music", 20, INK))
	var music := HSlider.new()
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = float(Save.get_setting("music", 0.65))
	music.custom_minimum_size.y = 44
	music.value_changed.connect(func(value: float) -> void:
		Save.set_setting("music", value)
		Audio.apply_settings(Save.data["settings"]))
	column.add_child(music)

	column.add_child(_label("Sound effects", 20, INK))
	var sfx := HSlider.new()
	sfx.min_value = 0.0
	sfx.max_value = 1.0
	sfx.step = 0.05
	sfx.value = float(Save.get_setting("sfx", 0.9))
	sfx.custom_minimum_size.y = 44
	sfx.value_changed.connect(func(value: float) -> void:
		Save.set_setting("sfx", value)
		Audio.apply_settings(Save.data["settings"]))
	column.add_child(sfx)

	var shake := CheckButton.new()
	shake.text = "Screen shake"
	shake.button_pressed = bool(Save.get_setting("screen_shake", true))
	shake.add_theme_font_size_override("font_size", 20)
	shake.toggled.connect(func(value: bool) -> void:
		Save.set_setting("screen_shake", value)
		if _field != null:
			_field._reduced_motion = not value)
	column.add_child(shake)

	var reduce := CheckButton.new()
	reduce.text = "Reduced motion"
	reduce.button_pressed = bool(Save.get_setting("reduced_motion", false))
	reduce.add_theme_font_size_override("font_size", 20)
	reduce.toggled.connect(func(value: bool) -> void: Save.set_setting("reduced_motion", value))
	column.add_child(reduce)

	column.add_child(_label("Progress", 22, MUTED))
	column.add_child(_ghost_button("RESET CAMPAIGN PROGRESS", func() -> void:
		_confirm_reset(), 70, 20))

	var about := _label(
			"Breakout Royale 3D — a Little Joy Arcade original.\n" +
			"1,000 levels across 20 worlds, 20 bosses, 40 power-ups.\n" +
			"Built with Godot 4 and Blender.",
			16, DIM)
	column.add_child(about)
	column.add_child(_label(Arcade.status_text(), 17, MUTED))


func _confirm_reset() -> void:
	_clear_overlay()
	_overlay = _overlay_base()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	panel.add_child(_label("Reset all progress?", 30, INK, HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_label("Stars, records and trophies are removed from this device.",
			17, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(_button("YES, RESET", 24, 76, DANGER, func() -> void:
		Save.reset_progress()
		_clear_overlay()
		_show_title()))
	panel.add_child(_ghost_button("CANCEL", func() -> void:
		_clear_overlay()
		_show_settings()))
