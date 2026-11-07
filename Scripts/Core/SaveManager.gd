extends Node
## Local-first save data for Breakout Royale 3D.
##
## Written to `user://` immediately after a meaningful event, then mirrored to
## the Little Joy Arcade cloud save when a player is signed in. The schema is
## versioned, merged with defaults on load, and a corrupt file is backed up
## rather than deleted.

signal changed
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://breakout_royale_save.json"
const BACKUP_PATH := "user://breakout_royale_save.corrupt.json"
const SCHEMA_VERSION := 1

const ACHIEVEMENTS: Array = [
	{"id": "first_break", "name": "First Break", "hint": "Clear your first board."},
	{"id": "first_boss", "name": "Wallbreaker", "hint": "Beat a world boss."},
	{"id": "ten_levels", "name": "Getting Warm", "hint": "Clear ten levels."},
	{"id": "fifty_levels", "name": "Regular", "hint": "Clear fifty levels."},
	{"id": "hundred_levels", "name": "Century", "hint": "Clear one hundred levels."},
	{"id": "five_hundred", "name": "Halfway to Royale", "hint": "Clear five hundred levels."},
	{"id": "thousand", "name": "Royale", "hint": "Clear all one thousand levels."},
	{"id": "perfect_board", "name": "Untouched", "hint": "Clear a board without losing a ball."},
	{"id": "three_stars", "name": "Clean Sweep", "hint": "Earn three stars on any level."},
	{"id": "stars_100", "name": "Star Collector", "hint": "Earn one hundred stars."},
	{"id": "stars_1000", "name": "Constellation", "hint": "Earn one thousand stars."},
	{"id": "boss_5", "name": "Regicide", "hint": "Beat five different world bosses."},
	{"id": "boss_20", "name": "All Crowns", "hint": "Beat all twenty world bosses."},
	{"id": "endless_10", "name": "Deep Endless", "hint": "Reach level ten in Endless."},
	{"id": "endless_30", "name": "No Floor", "hint": "Reach level thirty in Endless."},
	{"id": "survival_5", "name": "Held On", "hint": "Survive five waves."},
	{"id": "rush_3", "name": "Rush Hour", "hint": "Beat three bosses in Boss Rush."},
	{"id": "daily_done", "name": "Same Day", "hint": "Finish a Daily Challenge."},
	{"id": "arcade_clear", "name": "Old School", "hint": "Clear an Arcade Classic board."},
	{"id": "zen_10", "name": "Still Water", "hint": "Clear ten Zen boards."},
	{"id": "bricks_1000", "name": "Brick Layer", "hint": "Break one thousand bricks."},
	{"id": "power_25", "name": "Collector", "hint": "Catch twenty-five capsules."},
]

var data: Dictionary = {}
var _dirty := false
var _timer: Timer
var _writing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.7
	_timer.timeout.connect(flush)
	add_child(_timer)
	load_data()


func _defaults() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"created": int(Time.get_unix_time_from_system()),
		"savedAt": 0,
		"profile": {"name": "Pilot", "paddle": "royale"},
		"settings": {
			"music": 0.65,
			"sfx": 0.9,
			"reduced_motion": false,
			"screen_shake": true,
			"tutorial_done": false,
		},
		"progress": {
			"stars": {},
			"credits": 0,
			"levels_cleared": 0,
			"no_hit": [],
		},
		"records": {
			"endless_best": 0,
			"endless_level": 0,
			"survival_best": 0,
			"bossrush_best": 0,
			"arcade_best": 0,
			"zen_cleared": 0,
			"daily": {},
			"daily_streak": 0,
			"runs": 0,
		},
		"achievements": {},
		"stats": {
			"bricks": 0,
			"bosses": [],
			"powers": 0,
			"balls_lost": 0,
			"score": 0,
			"play_seconds": 0,
		},
	}


func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		queue_save()
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup_corrupt(text)
		queue_save()
		return
	data = _merge(parsed, _defaults())
	_migrate()
	changed.emit()


func _backup_corrupt(text: String) -> void:
	push_warning("Breakout Royale save could not be parsed; keeping a backup.")
	var file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


func _migrate() -> void:
	var schema := int(data.get("schema", 1))
	if schema < 1:
		data["schema"] = 1
	data["schema"] = SCHEMA_VERSION


func _merge(target: Dictionary, defaults: Dictionary) -> Dictionary:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key]
		elif typeof(target[key]) == TYPE_DICTIONARY and typeof(defaults[key]) == TYPE_DICTIONARY:
			_merge(target[key], defaults[key])
	return target


func queue_save() -> void:
	_dirty = true
	if _timer and _timer.is_inside_tree():
		_timer.start()


func flush() -> void:
	if _writing:
		return
	_writing = true
	data["savedAt"] = int(Time.get_unix_time_from_system() * 1000.0)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.flush()
		file.close()
		_dirty = false
		if has_node("/root/Arcade"):
			get_node("/root/Arcade").on_local_save(data)
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_settings(data["settings"])
	_writing = false


func get_setting(key: String, fallback: Variant = null) -> Variant:
	if data.has("settings") and data["settings"].has(key):
		return data["settings"][key]
	return fallback


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	queue_save()
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_settings(data["settings"])
	changed.emit()


func level_stars(id: int) -> int:
	return int(data["progress"]["stars"].get(str(id), 0))


func is_level_complete(id: int) -> bool:
	return level_stars(id) > 0


func total_stars() -> int:
	var total := 0
	for value in data["progress"]["stars"].values():
		total += int(value)
	return total


func completed_levels() -> int:
	var total := 0
	for value in data["progress"]["stars"].values():
		if int(value) > 0:
			total += 1
	return total


func stars_in_world(world_index: int) -> int:
	var total := 0
	var first := world_index * Campaign.LEVELS_PER_WORLD + 1
	for id in range(first, first + Campaign.LEVELS_PER_WORLD):
		total += level_stars(id)
	return total


func completed_in_world(world_index: int) -> int:
	var total := 0
	var first := world_index * Campaign.LEVELS_PER_WORLD + 1
	for id in range(first, first + Campaign.LEVELS_PER_WORLD):
		if is_level_complete(id):
			total += 1
	return total


## A world opens once ten levels of the previous world are cleared, so a player
## is never forced into a perfect run to keep moving forward.
func is_world_unlocked(world_index: int) -> bool:
	if world_index <= 0:
		return true
	return completed_in_world(world_index - 1) >= 10


func highest_unlocked_world() -> int:
	var best := 0
	for w in range(Campaign.WORLD_COUNT):
		if is_world_unlocked(w):
			best = w
	return best


func next_level() -> int:
	var cleared := completed_levels()
	for id in range(1, Campaign.LEVEL_COUNT + 1):
		if not is_level_complete(id):
			if Campaign.world_index(id) == 0 or is_world_unlocked(Campaign.world_index(id)):
				return id
	return Campaign.LEVEL_COUNT


func credits() -> int:
	return int(data["progress"]["credits"])


func add_credits(amount: int) -> void:
	data["progress"]["credits"] = maxi(0, credits() + amount)
	queue_save()


## Records a finished board. Returns newly unlocked achievement ids.
func complete_level(id: int, stars: int, score: int, bricks: int, no_hit: bool) -> Array:
	var key := str(id)
	var previous := level_stars(id)
	if stars > previous:
		data["progress"]["stars"][key] = stars
	if no_hit and not (data["progress"]["no_hit"] as Array).has(key):
		(data["progress"]["no_hit"] as Array).append(key)
	data["progress"]["levels_cleared"] = completed_levels()
	data["progress"]["credits"] = int(data["progress"]["credits"]) + 20 + stars * 15
	data["stats"]["bricks"] = int(data["stats"]["bricks"]) + bricks
	data["stats"]["score"] = int(data["stats"]["score"]) + score
	data["records"]["runs"] = int(data["records"]["runs"]) + 1
	if Campaign.is_boss_level(id):
		var beaten: Array = data["stats"]["bosses"]
		var boss_key := str(Campaign.boss_index(id))
		if not beaten.has(boss_key):
			beaten.append(boss_key)
	var unlocked := check_achievements()
	queue_save()
	changed.emit()
	return unlocked


func record_mode(mode: String, value: int) -> void:
	match mode:
		"endless":
			data["records"]["endless_best"] = maxi(int(data["records"]["endless_best"]), value)
		"endless_level":
			data["records"]["endless_level"] = maxi(int(data["records"]["endless_level"]), value)
		"survival":
			data["records"]["survival_best"] = maxi(int(data["records"]["survival_best"]), value)
		"bossrush":
			data["records"]["bossrush_best"] = maxi(int(data["records"]["bossrush_best"]), value)
		"arcade":
			data["records"]["arcade_best"] = maxi(int(data["records"]["arcade_best"]), value)
		"zen":
			data["records"]["zen_cleared"] = int(data["records"]["zen_cleared"]) + 1
	data["records"]["runs"] = int(data["records"]["runs"]) + 1
	check_achievements()
	queue_save()
	changed.emit()


func daily_date_key() -> String:
	var now := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]


func daily_seed() -> int:
	var key := daily_date_key()
	var value := 0
	for i in range(key.length()):
		value = (value * 31 + key.unicode_at(i)) % 2147483647
	return value


func record_daily(score: int) -> Array:
	var key := daily_date_key()
	var entry: Dictionary = data["records"]["daily"].get(key, {"best": 0, "attempts": 0, "done": false})
	entry["best"] = maxi(int(entry.get("best", 0)), score)
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	entry["done"] = true
	data["records"]["daily"][key] = entry
	data["records"]["daily_streak"] = _streak()
	var unlocked := check_achievements()
	queue_save()
	return unlocked


func _streak() -> int:
	var streak := 0
	var now := int(Time.get_unix_time_from_system())
	for i in range(90):
		var stamp := now - i * 86400
		var d := Time.get_datetime_dict_from_unix_time(stamp)
		var key := "%04d-%02d-%02d" % [d.year, d.month, d.day]
		var entry: Variant = data["records"]["daily"].get(key)
		if typeof(entry) != TYPE_DICTIONARY or not bool(entry.get("done", false)):
			if i == 0:
				continue
			break
		streak += 1
	return streak


func has_achievement(id: String) -> bool:
	return data["achievements"].has(id)


func unlock_achievement(id: String) -> bool:
	if data["achievements"].has(id):
		return false
	data["achievements"][id] = int(Time.get_unix_time_from_system())
	queue_save()
	achievement_unlocked.emit(id)
	if has_node("/root/Arcade"):
		get_node("/root/Arcade").achievement(id)
	return true


func check_achievements() -> Array:
	var unlocked: Array = []
	var levels := completed_levels()
	var bosses: Array = data["stats"]["bosses"]
	var check := {
		"first_break": levels >= 1,
		"first_boss": bosses.size() >= 1,
		"ten_levels": levels >= 10,
		"fifty_levels": levels >= 50,
		"hundred_levels": levels >= 100,
		"five_hundred": levels >= 500,
		"thousand": levels >= 1000,
		"perfect_board": (data["progress"]["no_hit"] as Array).size() > 0,
		"three_stars": total_stars() >= 3,
		"stars_100": total_stars() >= 100,
		"stars_1000": total_stars() >= 1000,
		"boss_5": bosses.size() >= 5,
		"boss_20": bosses.size() >= 20,
		"endless_10": int(data["records"]["endless_level"]) >= 10,
		"endless_30": int(data["records"]["endless_level"]) >= 30,
		"survival_5": int(data["records"]["survival_best"]) >= 5,
		"rush_3": int(data["records"]["bossrush_best"]) >= 3,
		"daily_done": (data["records"]["daily"] as Dictionary).size() > 0,
		"arcade_clear": int(data["records"]["arcade_best"]) > 0,
		"zen_10": int(data["records"]["zen_cleared"]) >= 10,
		"bricks_1000": int(data["stats"]["bricks"]) >= 1000,
		"power_25": int(data["stats"]["powers"]) >= 25,
	}
	for id in check.keys():
		if check[id] and unlock_achievement(String(id)):
			unlocked.append(id)
	return unlocked


func count_power() -> void:
	data["stats"]["powers"] = int(data["stats"]["powers"]) + 1
	check_achievements()
	queue_save()


func count_ball_lost() -> void:
	data["stats"]["balls_lost"] = int(data["stats"]["balls_lost"]) + 1
	queue_save()


func add_play_time(seconds: float) -> void:
	data["stats"]["play_seconds"] = int(data["stats"]["play_seconds"]) + int(seconds)
	queue_save()


func reset_progress() -> void:
	var profile: Dictionary = data["profile"]
	var settings: Dictionary = data["settings"]
	var created: Variant = data["created"]
	data = _defaults()
	data["profile"] = profile
	data["settings"] = settings
	data["created"] = created
	queue_save()
	changed.emit()
