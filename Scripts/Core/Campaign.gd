class_name Campaign
extends RefCounted
## The whole campaign is data generated from a seed: 20 worlds, 50 levels each,
## a boss every tenth level. Nothing is hand-placed, so a level is identical on
## every device and can be regenerated for validation.

const WORLD_COUNT := 20
const LEVELS_PER_WORLD := 50
const LEVEL_COUNT := WORLD_COUNT * LEVELS_PER_WORLD
const COLS := 9
const ROWS := 8
const BOSS_EVERY := 10

## World palettes are used by both the menu cards and the live 3D arena.
const WORLDS: Array = [
	{"name": "Neon Docks", "tagline": "Where the harbour lights never sleep.", "from": "#0b2b3a", "to": "#071018", "accent": "#2ee6d6", "glow": "#8bfff2"},
	{"name": "Ember Foundry", "tagline": "Pouring steel over a dying star.", "from": "#3a1206", "to": "#150603", "accent": "#ff7a3d", "glow": "#ffc38a"},
	{"name": "Crystal Reach", "tagline": "A field of frozen harmonics.", "from": "#25103f", "to": "#0a0616", "accent": "#a37bff", "glow": "#e0d2ff"},
	{"name": "Verdant Ruins", "tagline": "Stone, moss, and old machines.", "from": "#0e2f1f", "to": "#050f0a", "accent": "#5ce48b", "glow": "#c9ffd8"},
	{"name": "Solar Flare", "tagline": "Too close to the furnace.", "from": "#3a2405", "to": "#140b02", "accent": "#ffcf3d", "glow": "#fff1ad"},
	{"name": "Deep Void", "tagline": "The quiet between galaxies.", "from": "#100d33", "to": "#04030d", "accent": "#6f7bff", "glow": "#c3c8ff"},
	{"name": "Chrome Spire", "tagline": "A tower of polished light.", "from": "#1b2733", "to": "#070b10", "accent": "#9fd8ff", "glow": "#eaf7ff"},
	{"name": "Coral Abyss", "tagline": "Pressure, colour, and teeth.", "from": "#2a0f2c", "to": "#0c040f", "accent": "#ff6fb5", "glow": "#ffd0e8"},
	{"name": "Frost Vault", "tagline": "Everything here is preserved.", "from": "#0b2233", "to": "#040b12", "accent": "#7fe3ff", "glow": "#e0fbff"},
	{"name": "Magma Core", "tagline": "The planet's molten heart.", "from": "#33100a", "to": "#0f0403", "accent": "#ff4d4d", "glow": "#ffb0a0"},
	{"name": "Aurora Fields", "tagline": "A sky that moves like water.", "from": "#08302c", "to": "#050d1c", "accent": "#57ffb0", "glow": "#c6ffe8"},
	{"name": "Sandstorm Citadel", "tagline": "Walls worn thin by wind.", "from": "#33260d", "to": "#120d05", "accent": "#e8b45c", "glow": "#ffe6b0"},
	{"name": "Quantum Garden", "tagline": "Every path is also another.", "from": "#250d3a", "to": "#0a0514", "accent": "#d06bff", "glow": "#b6ff7a"},
	{"name": "Storm Engine", "tagline": "A machine built from weather.", "from": "#152a3a", "to": "#060d14", "accent": "#6bb8ff", "glow": "#d6ecff"},
	{"name": "Obsidian Court", "tagline": "A throne room with no king.", "from": "#1d0b2a", "to": "#08040d", "accent": "#b07bff", "glow": "#e6d2ff"},
	{"name": "Biolume Swamp", "tagline": "Something down there is glowing.", "from": "#0d2a20", "to": "#04100b", "accent": "#7bff9e", "glow": "#d6ffe2"},
	{"name": "Orbital Wreck", "tagline": "Salvage at the edge of orbit.", "from": "#2a1c14", "to": "#0d0906", "accent": "#ff9d6b", "glow": "#ffd8c2"},
	{"name": "Prism Cascade", "tagline": "Light, folded and refolded.", "from": "#221033", "to": "#080814", "accent": "#ff6bd6", "glow": "#9ff3ff"},
	{"name": "Null Sector", "tagline": "Nothing here answers back.", "from": "#1a1a1e", "to": "#050506", "accent": "#ff5c5c", "glow": "#d8d8de"},
	{"name": "Royale Core", "tagline": "The last wall in the galaxy.", "from": "#33240a", "to": "#120c03", "accent": "#ffd75c", "glow": "#fff8dc"},
]

const BOSSES: Array = [
	{"name": "Tidebreaker", "title": "Harbour Colossus", "shots": 1, "spread": 0.0, "period": 2.2, "speed": 6.2},
	{"name": "Forgeheart", "title": "Furnace Tyrant", "shots": 2, "spread": 0.32, "period": 2.1, "speed": 6.6},
	{"name": "Prism Warden", "title": "Keeper of Facets", "shots": 3, "spread": 0.42, "period": 2.0, "speed": 7.0},
	{"name": "Thorn Colossus", "title": "Root of the Ruins", "shots": 2, "spread": 0.55, "period": 1.9, "speed": 7.2},
	{"name": "Sunspot Tyrant", "title": "Crown of Fire", "shots": 3, "spread": 0.5, "period": 1.8, "speed": 7.6},
	{"name": "Null Harbinger", "title": "The Quiet Signal", "shots": 2, "spread": 0.24, "period": 1.7, "speed": 7.8},
	{"name": "Chrome Sentinel", "title": "Spire Guardian", "shots": 4, "spread": 0.62, "period": 1.9, "speed": 8.0},
	{"name": "Reef Matriarch", "title": "Mother of Tides", "shots": 3, "spread": 0.7, "period": 1.8, "speed": 8.2},
	{"name": "Glacier Regent", "title": "Preserved Sovereign", "shots": 4, "spread": 0.48, "period": 1.7, "speed": 8.4},
	{"name": "Magma Behemoth", "title": "Heart of the Core", "shots": 3, "spread": 0.8, "period": 1.6, "speed": 8.6},
	{"name": "Aurora Sphinx", "title": "Riddler of Skies", "shots": 5, "spread": 0.58, "period": 1.7, "speed": 8.8},
	{"name": "Dune Pharaoh", "title": "The Worn Crown", "shots": 4, "spread": 0.66, "period": 1.6, "speed": 9.0},
	{"name": "Entangler", "title": "Both Answers at Once", "shots": 5, "spread": 0.74, "period": 1.6, "speed": 9.2},
	{"name": "Thunder Rig", "title": "Engine of Storms", "shots": 4, "spread": 0.9, "period": 1.5, "speed": 9.4},
	{"name": "Obsidian Duke", "title": "Court of One", "shots": 5, "spread": 0.68, "period": 1.5, "speed": 9.6},
	{"name": "Spore Queen", "title": "Bloom of the Deep", "shots": 4, "spread": 1.0, "period": 1.45, "speed": 9.8},
	{"name": "Wreck Admiral", "title": "Last of the Line", "shots": 6, "spread": 0.8, "period": 1.45, "speed": 10.0},
	{"name": "Spectrum Prime", "title": "All Colours, One Blade", "shots": 5, "spread": 1.1, "period": 1.4, "speed": 10.2},
	{"name": "Void Auditor", "title": "It Has Counted You", "shots": 6, "spread": 0.95, "period": 1.35, "speed": 10.4},
	{"name": "Royale Sovereign", "title": "The Last Wall", "shots": 7, "spread": 1.2, "period": 1.3, "speed": 10.8},
]

const PATTERNS: Array = [
	"rows", "pyramid", "diamond", "columns", "checker",
	"fortress", "arch", "wave", "hourglass", "butterfly",
]


static func clamp_level(id: int) -> int:
	return clampi(id, 1, LEVEL_COUNT)


static func world_index(id: int) -> int:
	return clampi(int((clamp_level(id) - 1) / LEVELS_PER_WORLD), 0, WORLD_COUNT - 1)


static func world(id: int) -> Dictionary:
	return WORLDS[world_index(id)]


static func local_level(id: int) -> int:
	return ((clamp_level(id) - 1) % LEVELS_PER_WORLD) + 1


static func is_boss_level(id: int) -> bool:
	return local_level(id) % BOSS_EVERY == 0


static func boss_index(id: int) -> int:
	return world_index(id)


static func level_name(id: int) -> String:
	var w := world(id)
	return "%s %02d" % [String(w["name"]), local_level(id)]


static func level_seed(id: int) -> int:
	return clamp_level(id) * 7919 + 104729


static func boss_hp(id: int) -> int:
	var base := 26 + world_index(id) * 9
	var step := int((local_level(id) - 1) / BOSS_EVERY)
	return base + step * 6


static func boss_for(id: int) -> Dictionary:
	var entry: Dictionary = BOSSES[boss_index(id)].duplicate()
	entry["hp"] = boss_hp(id)
	entry["phases"] = 3
	entry["index"] = boss_index(id) + 1
	return entry


## A level is a compact record so it can be regenerated, logged and validated.
static func generate(id: int) -> Dictionary:
	var level_id := clamp_level(id)
	var boss := is_boss_level(level_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed(level_id)
	var bricks: Array = []
	if boss:
		bricks = []
	else:
		bricks = _layout(level_id, rng)
	var breakable := 0
	var total_hp := 0
	for brick in bricks:
		var kind := String(brick["t"])
		if kind != "steel":
			breakable += 1
			total_hp += int(brick["hp"])
	var par := breakable * 90 + total_hp * 10
	if boss:
		par = 900 + boss_hp(level_id) * 22
	return {
		"id": level_id,
		"world": world_index(level_id) + 1,
		"local": local_level(level_id),
		"name": level_name(level_id),
		"boss": boss,
		"boss_data": boss_for(level_id) if boss else {},
		"bricks": bricks,
		"breakable": breakable,
		"par": par,
		"seed": level_seed(level_id),
		"pattern": "boss" if boss else _pattern_for(level_id),
	}


static func _pattern_for(id: int) -> String:
	# The opening boards teach the game: full rows first, then a pyramid.
	if id <= 3:
		return "rows"
	if id <= 6:
		return "pyramid"
	return PATTERNS[(id * 7 + world_index(id) * 3) % PATTERNS.size()]


static func _layout(id: int, rng: RandomNumberGenerator) -> Array:
	var pattern := _pattern_for(id)
	var local := local_level(id)
	var wi := world_index(id)
	# Early levels use fewer rows, so the very first board is a gentle one.
	var row_cap := clampi(4 + int(local / 9.0) + int(wi / 5.0), 4, ROWS)
	var cells := {}
	for r in range(row_cap):
		for c in range(COLS):
			var keep := false
			match pattern:
				"rows":
					keep = true
				"pyramid":
					var reach := mini(c, COLS - 1 - c)
					keep = (row_cap - 1 - r) >= reach
				"diamond":
					var centre := (COLS - 1) * 0.5
					var dx := absf(c - centre)
					var dy := absf(r - (row_cap - 1) * 0.5)
					keep = dx / (centre + 0.5) + dy / (row_cap * 0.55) <= 1.05
				"columns":
					keep = c % 2 == 0
				"checker":
					keep = (c + r) % 2 == 0
				"fortress":
					var edge := c == 0 or c == COLS - 1 or r == 0 or r == row_cap - 1
					keep = edge or (r >= 2 and r <= row_cap - 3 and c >= 3 and c <= 5)
				"arch":
					var centre := (COLS - 1) * 0.5
					var dx := absf(c - centre)
					keep = dx <= 1.6 or r == 0
				"wave":
					var offset := int(round(sin(r * 0.9) * 1.6))
					keep = c >= 2 + offset and c <= COLS - 3 + offset
				"hourglass":
					var centre := (COLS - 1) * 0.5
					var dx := absf(c - centre)
					var mid := absf(r - (row_cap - 1) * 0.5)
					keep = dx <= (COLS * 0.5 - mid * 0.9)
				"butterfly":
					var centre := (COLS - 1) * 0.5
					var dx := absf(c - centre)
					keep = int(dx) % 2 == (r % 2) or dx <= 0.6
				_:
					keep = true
			if keep:
				if rng.randf() < 0.05 + wi * 0.006:
					continue
				cells["%d:%d" % [c, r]] = true

	if cells.is_empty():
		for c in range(COLS):
			cells["%d:2" % c] = true

	var keys := cells.keys()
	keys.sort()
	var bricks: Array = []
	for key in keys:
		var parts := String(key).split(":")
		var c := int(parts[0])
		var r := int(parts[1])
		var kind := _kind_for(id, r, rng)
		var hp := 1
		match kind:
			"tough":
				hp = 2
			"armor":
				hp = 3
			"steel":
				hp = 999
			"bomb":
				hp = 1
			"crystal":
				hp = 1
		bricks.append({"c": c, "r": r, "t": kind, "hp": hp})

	# A board must always be breakable: convert steel if the layout is too mean.
	var breakable := 0
	for brick in bricks:
		if String(brick["t"]) != "steel":
			breakable += 1
	if breakable < 12:
		for brick in bricks:
			if breakable >= 12:
				break
			if String(brick["t"]) == "steel":
				brick["t"] = "tough"
				brick["hp"] = 2
				breakable += 1
	return bricks


static func _kind_for(id: int, row: int, rng: RandomNumberGenerator) -> String:
	var wi := world_index(id)
	var local := local_level(id)
	var roll := rng.randf()
	var tough := 0.06 + wi * 0.014 + local * 0.0015
	var armor := clampf((wi - 3) * 0.035 + local * 0.0015, 0.0, 0.18)
	var steel := 0.0
	if wi >= 5:
		steel = 0.02 + wi * 0.004
	var bomb := 0.035 if wi >= 2 else 0.0
	var crystal := 0.06 if wi >= 4 else 0.02
	if roll < steel:
		return "steel"
	if roll < steel + armor:
		return "armor"
	if roll < steel + armor + tough:
		return "tough"
	if roll < steel + armor + tough + bomb:
		return "bomb"
	if roll < steel + armor + tough + bomb + crystal:
		return "crystal"
	return "std"


## Structural validation used by the headless suite and the CI gate.
static func validate(level: Dictionary) -> Array:
	var problems: Array = []
	var id := int(level.get("id", 0))
	if id < 1 or id > LEVEL_COUNT:
		problems.append("level id out of range: %d" % id)
	if not level.has("bricks"):
		return problems
	var seen := {}
	var breakable := 0
	var boss := bool(level.get("boss", false))
	for brick in level["bricks"]:
		var c := int(brick.get("c", -1))
		var r := int(brick.get("r", -1))
		if c < 0 or c >= COLS or r < 0 or r >= ROWS:
			problems.append("%s: brick out of grid (%d,%d)" % [level_name(id), c, r])
		var key := "%d:%d" % [c, r]
		if seen.has(key):
			problems.append("%s: duplicate brick at %s" % [level_name(id), key])
		seen[key] = true
		if String(brick.get("t", "")) != "steel":
			breakable += 1
	if not boss and breakable < 12:
		problems.append("%s: only %d breakable bricks" % [level_name(id), breakable])
	if boss and level.get("bricks", []).size() > 0:
		problems.append("%s: boss arena must not start with bricks" % level_name(id))
	if boss:
		var data: Dictionary = level.get("boss_data", {})
		if int(data.get("hp", 0)) <= 0:
			problems.append("%s: boss has no health" % level_name(id))
		if int(data.get("phases", 0)) < 2:
			problems.append("%s: boss has no phases" % level_name(id))
	return problems
