extends Node
## Headless regression suite. Every check prints a failure and the run exits
## non-zero, so CI refuses to publish a broken build.

var checks := 0
var failures: Array = []


func _ready() -> void:
	print("Breakout Royale 3D — headless suite")
	_test_math()
	_test_campaign()
	_test_bosses()
	_test_powerups()
	_test_stars()
	_test_save()
	_test_daily()
	_test_assets()
	print("checks: %d   failures: %d" % [checks, failures.size()])
	if failures.is_empty():
		print("TESTS OK")
		get_tree().quit(0)
	else:
		for failure in failures.slice(0, 40):
			printerr("FAIL: " + String(failure))
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_math() -> void:
	# A stationary ball inside a box reports a hit with a push-out normal.
	var overlap := BreakoutMath.swept_circle_box(Vector2(0, 0), 0.2, Vector2.ZERO,
			Vector2(0, 0), Vector2(1, 1))
	check(bool(overlap["hit"]), "overlapping ball must register a hit")

	# A ball travelling straight at a brick hits it at the expected time.
	var brick := BreakoutMath.swept_circle_box(Vector2(0, 0), 0.2, Vector2(0, 6),
			Vector2(0, 4), Vector2(1, 1))
	check(bool(brick["hit"]), "ball aimed at a brick must hit it")
	check(absf(float(brick["t"]) - 0.55) < 0.01, "hit time should be 0.55, got %s" % brick["t"])
	check((brick["normal"] as Vector2).y < -0.9, "brick hit from below should push down")

	# A fast ball must not tunnel through a thin brick.
	var fast := BreakoutMath.swept_circle_box(Vector2(0, -2), 0.15, Vector2(0, 9),
			Vector2(0, 2), Vector2(0.9, 0.44))
	check(bool(fast["hit"]), "a 9 m/frame ball must not tunnel through a brick")
	check(float(fast["t"]) < 1.0, "tunnelling guard must report t inside the step")

	# Missing the brick laterally is a clean miss.
	var miss := BreakoutMath.swept_circle_box(Vector2(3, 0), 0.2, Vector2(0, 3),
			Vector2(0, 4), Vector2(1, 1))
	check(not bool(miss["hit"]), "a ball to the side must not hit")

	# Reflection flips only the normal component.
	var bounced := BreakoutMath.reflect(Vector2(1, -2), Vector2.UP)
	check(absf(bounced.x - 1.0) < 0.001, "reflection must keep the tangential part")
	check(absf(bounced.y - 2.0) < 0.001, "reflection must flip the normal part")

	# Paddle aiming: centre is steep, edges are wide, and neither is horizontal.
	var centre := BreakoutMath.paddle_bounce(0.0, 10.0)
	check(absf(centre.length() - 10.0) < 0.001, "paddle bounce must preserve speed")
	check(absf(centre.x) < 0.001, "centre hit must go straight up")
	check(centre.y > 9.0, "centre hit must be steep")
	var edge := BreakoutMath.paddle_bounce(1.0, 10.0)
	check(edge.x > 7.0, "edge hit must angle wide")
	check(edge.y > 3.0, "edge hit must still travel up")
	check(absf(edge.length() - 10.0) < 0.001, "edge hit must preserve speed")

	# A near-horizontal bounce gets nudged back into play.
	var flat := BreakoutMath.clamp_ball_angle(Vector2(10, 0.2))
	check(absf(flat.y) > 1.9, "near-horizontal ball must be steepened")
	check(absf(flat.length() - Vector2(10, 0.2).length()) < 0.01, "steepening keeps speed")

	check(BreakoutMath.format_score(1234567) == "1,234,567", "score grouping")
	check(BreakoutMath.format_score(999) == "999", "score grouping below 1000")


func _test_campaign() -> void:
	check(Campaign.LEVEL_COUNT == 1000, "campaign must have 1000 levels")
	check(Campaign.WORLDS.size() == 20, "campaign must have 20 worlds")
	check(Campaign.BOSSES.size() == 20, "campaign must have 20 bosses")
	var ids := {}
	var boss_levels := 0
	var pattern_counts := {}
	var first: Dictionary = Campaign.generate(1)
	for id in range(1, Campaign.LEVEL_COUNT + 1):
		var level := Campaign.generate(id)
		ids[id] = true
		for problem in Campaign.validate(level):
			failures.append(problem)
			checks += 1
		checks += 1
		var brick_count := (level["bricks"] as Array).size()
		if bool(level["boss"]):
			boss_levels += 1
			check(brick_count == 0, "boss board %d should start empty" % id)
		else:
			check(brick_count >= 12, "level %d has only %d bricks" % [id, brick_count])
			check(brick_count <= Campaign.COLS * Campaign.ROWS,
					"level %d exceeds the grid" % id)
			for brick in level["bricks"]:
				var x := (float(brick["c"]) - (Campaign.COLS - 1) * 0.5) * 0.92
				var y := 7.8 - float(brick["r"]) * 0.5
				check(absf(x) + 0.43 <= 4.2 + 0.001, "brick %d/%d leaves the arena" % [id, brick["c"]])
				check(y > -1.0 and y < 9.0, "brick row %d is off the field" % brick["r"])
		check(int(level["par"]) > 0, "level %d has no par score" % id)
		check(int(level["world"]) == Campaign.world_index(id) + 1, "world mapping for %d" % id)
		check(int(level["local"]) == ((id - 1) % 50) + 1, "local mapping for %d" % id)
		var pattern := String(level["pattern"])
		pattern_counts[pattern] = int(pattern_counts.get(pattern, 0)) + 1
		# Determinism: the same id regenerates an identical record.
		if id % 97 == 0:
			var again := Campaign.generate(id)
			check(JSON.stringify(again) == JSON.stringify(level), "level %d is not deterministic" % id)
	check(ids.size() == 1000, "level ids must be unique")
	check(boss_levels == 100, "there must be 100 boss levels (found %d)" % boss_levels)
	check(pattern_counts.size() >= 8, "at least eight layout shapes should appear")
	check(Campaign.is_boss_level(10) and not Campaign.is_boss_level(11), "boss cadence")
	check(Campaign.local_level(51) == 1, "level 51 opens world 2")
	check(String(first["name"]).begins_with("Neon Docks"), "world 1 name")
	check((first["bricks"] as Array).size() >= 12, "the first board must be playable")
	check(Campaign.level_name(1000) == "Royale Core 50", "last level name")

	# Every non-boss board must be completable: at least one breakable brick.
	for id in [1, 2, 25, 50, 51, 199, 500, 777, 999, 1000]:
		var level := Campaign.generate(id)
		var breakable := 0
		for brick in level["bricks"]:
			if String(brick["t"]) != "steel":
				breakable += 1
		check(breakable > 0 or bool(level["boss"]), "level %d must be breakable" % id)


func _test_bosses() -> void:
	var names := {}
	for i in range(Campaign.BOSSES.size()):
		var boss: Dictionary = Campaign.BOSSES[i]
		var name := String(boss["name"])
		check(not names.has(name), "boss names must be unique: %s" % name)
		names[name] = true
		check(int(boss["shots"]) >= 1, "%s must fire at least one shot" % name)
		check(float(boss["speed"]) > 0.0, "%s must have shot speed" % name)
		check(float(boss["period"]) > 0.5, "%s must not fire continuously" % name)

	for world in range(20):
		var id := world * 50 + 10
		var level := Campaign.generate(id)
		check(bool(level["boss"]), "level %d should be a boss" % id)
		var data: Dictionary = level["boss_data"]
		check(int(data["hp"]) > 0, "boss %d needs health" % id)
		check(int(data["phases"]) >= 3, "boss %d needs three phases" % id)
		check(int(data["index"]) == world + 1, "boss index mapping for world %d" % (world + 1))
		check(int(Campaign.boss_for(id)["hp"]) >= 26, "boss %d hp floor" % id)

	var hp_early := int(Campaign.boss_for(10)["hp"])
	var hp_late := int(Campaign.boss_for(1000)["hp"])
	check(hp_late > hp_early, "later bosses should have more health")


func _test_powerups() -> void:
	check(PowerUps.count() == 40, "there must be exactly 40 power-ups")
	var seen := {}
	var hazards := 0
	for item in PowerUps.ITEMS:
		var id := String(item["id"])
		check(not seen.has(id), "duplicate power-up id: %s" % id)
		seen[id] = true
		check(String(item["name"]).length() > 0, "power-up %s needs a name" % id)
		check(String(item["glyph"]).length() > 0, "power-up %s needs a glyph" % id)
		var tint := String(item["tint"])
		check(tint.begins_with("#") and tint.length() == 7, "power-up %s needs a colour" % id)
		var rarity := String(item["rarity"])
		check(rarity in ["common", "uncommon", "rare", "epic"], "power-up %s rarity" % id)
		if bool(item["hazard"]):
			hazards += 1
		check(PowerUps.has(id), "lookup for %s" % id)
		check(not PowerUps.by_id(id).is_empty(), "by_id for %s" % id)
	check(hazards >= 4, "there should be at least four risky pickups")

	# Every id must have a real handler in the gameplay layer, not just a card.
	var source := FileAccess.get_file_as_string("res://Scripts/Game/GameField.gd")
	check(source.length() > 1000, "gameplay source must be readable")
	for item in PowerUps.ITEMS:
		var id := String(item["id"])
		check(source.contains("\"%s\"" % id), "power-up %s has no gameplay handler" % id)

	# The drop table is deterministic and only returns known ids.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var picks := {}
	for i in range(400):
		var id := PowerUps.roll(rng, 0.5)
		check(PowerUps.has(id), "roll returned an unknown power-up: %s" % id)
		picks[id] = true
	check(picks.size() >= 20, "the drop table should reach most of the catalogue")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 777
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 777
	var same := true
	for i in range(80):
		if PowerUps.roll(rng2, 0.4) != PowerUps.roll(rng3, 0.4):
			same = false
	check(same, "drop table must be seed-deterministic")


func _test_stars() -> void:
	check(BreakoutMath.stars_for(0, 1000) == 1, "a clear always earns one star")
	check(BreakoutMath.stars_for(1000, 1000) == 2, "par earns two stars")
	check(BreakoutMath.stars_for(1450, 1000) == 3, "145% of par earns three stars")
	check(BreakoutMath.stars_for(5000, 0) == 1, "a zero par must not divide by zero")


func _test_save() -> void:
	var defaults := Save._defaults()
	check(int(defaults["schema"]) == 1, "save schema version")
	check(defaults.has("progress") and defaults.has("records"), "save has progress and records")
	var round_trip: Variant = JSON.parse_string(JSON.stringify(defaults))
	check(typeof(round_trip) == TYPE_DICTIONARY, "save must survive JSON")
	if typeof(round_trip) == TYPE_DICTIONARY:
		var merged := Save._merge(round_trip, defaults)
		check(merged.has("settings"), "merge keeps settings")
		check(int(merged["schema"]) == 1, "merge keeps schema")

	# A save from an older build is filled in, not thrown away.
	var old := {"schema": 1, "progress": {"stars": {"1": 3}}}
	var healed := Save._merge(old, Save._defaults())
	check(healed["progress"]["stars"].has("1"), "old stars survive a merge")
	check(healed.has("achievements"), "missing keys are restored")

	check(Save.ACHIEVEMENTS.size() >= 20, "at least twenty trophies")
	var trophy_ids := {}
	for entry in Save.ACHIEVEMENTS:
		var id := String(entry["id"])
		check(not trophy_ids.has(id), "duplicate trophy id %s" % id)
		trophy_ids[id] = true
		check(String(entry["hint"]).length() > 5, "trophy %s needs a hint" % id)

	# Save data loaded at boot is usable by the menu.
	check(Save.data.has("settings"), "live save data must be initialised")
	check(Save.next_level() >= 1, "next level must be valid")
	check(Save.is_world_unlocked(0), "world one is always open")


func _test_daily() -> void:
	var key := Save.daily_date_key()
	check(key.length() == 10 and key[4] == "-", "daily key format: %s" % key)
	var seed_a := Save.daily_seed()
	var seed_b := Save.daily_seed()
	check(seed_a == seed_b, "the daily seed must be stable within a day")
	check(seed_a > 0, "daily seed must be positive")
	var id := (seed_a % Campaign.LEVEL_COUNT) + 1
	check(id >= 1 and id <= 1000, "daily level id must be in range")


func _test_assets() -> void:
	for name in ["paddle", "ball", "brick", "brick_armor", "brick_steel", "brick_bomb",
			"brick_crystal", "capsule", "boss_core", "arena", "portal", "crystal"]:
		check(ResourceLoader.exists("res://Assets/Models/props/%s.glb" % name),
				"missing model: %s" % name)
	for name in ["paddle", "brick", "brick_break", "power", "level_clear", "level_fail"]:
		check(ResourceLoader.exists("res://Assets/Audio/SFX/%s.wav" % name),
				"missing sound: %s" % name)
	check(ResourceLoader.exists("res://Assets/Audio/Music/game.wav"), "missing music bed")
