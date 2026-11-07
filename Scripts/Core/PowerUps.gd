class_name PowerUps
extends RefCounted
## Forty pickups, each with a colour, a glyph, a rarity and a real effect.
## The gameplay layer switches on `id`; nothing here is decorative.

const ITEMS: Array = [
	{"id": "multi_ball", "name": "Multi Ball", "glyph": "3", "tint": "#ffd166", "rarity": "rare", "duration": 0.0, "hazard": false, "note": "Splits into three balls."},
	{"id": "giant_ball", "name": "Giant Ball", "glyph": "O", "tint": "#ff9d6b", "rarity": "uncommon", "duration": 14.0, "hazard": false, "note": "A much bigger ball hits more brick."},
	{"id": "tiny_ball", "name": "Tiny Ball", "glyph": "o", "tint": "#ff5c5c", "rarity": "common", "duration": 12.0, "hazard": true, "note": "Hard to see, hard to catch."},
	{"id": "fire_ball", "name": "Fire Ball", "glyph": "F", "tint": "#ff7a3d", "rarity": "rare", "duration": 12.0, "hazard": false, "note": "Burns straight through ordinary brick."},
	{"id": "explosive_ball", "name": "Explosive Ball", "glyph": "X", "tint": "#ff4d4d", "rarity": "rare", "duration": 12.0, "hazard": false, "note": "Every hit blasts its neighbours."},
	{"id": "heavy_ball", "name": "Heavy Ball", "glyph": "H", "tint": "#c9a26b", "rarity": "uncommon", "duration": 14.0, "hazard": false, "note": "Double brick damage, slightly slower."},
	{"id": "slow_ball", "name": "Slow Ball", "glyph": "S", "tint": "#8bfff2", "rarity": "common", "duration": 15.0, "hazard": false, "note": "Calms the rally down."},
	{"id": "fast_ball", "name": "Fast Ball", "glyph": "!", "tint": "#ff5c5c", "rarity": "common", "duration": 12.0, "hazard": true, "note": "Faster scoring, far less forgiving."},
	{"id": "chaos_ball", "name": "Chaos Ball", "glyph": "?", "tint": "#d06bff", "rarity": "rare", "duration": 10.0, "hazard": true, "note": "Bounces wander off the angle you set."},
	{"id": "magnet_ball", "name": "Magnet Ball", "glyph": "M", "tint": "#57ffb0", "rarity": "rare", "duration": 14.0, "hazard": false, "note": "Curves toward the nearest brick."},
	{"id": "chain_ball", "name": "Chain Ball", "glyph": "C", "tint": "#9fd8ff", "rarity": "epic", "duration": 12.0, "hazard": false, "note": "Arc lightning into two more bricks."},
	{"id": "wide_paddle", "name": "Wide Paddle", "glyph": "W", "tint": "#37e6b0", "rarity": "common", "duration": 16.0, "hazard": false, "note": "Half again as much paddle."},
	{"id": "narrow_paddle", "name": "Narrow Paddle", "glyph": "n", "tint": "#ff5c5c", "rarity": "common", "duration": 12.0, "hazard": true, "note": "A much smaller catch."},
	{"id": "magnet_paddle", "name": "Magnet Paddle", "glyph": "U", "tint": "#57ffb0", "rarity": "uncommon", "duration": 16.0, "hazard": false, "note": "Sticks the ball for a chosen launch."},
	{"id": "laser_paddle", "name": "Laser Paddle", "glyph": "L", "tint": "#ff3fd8", "rarity": "rare", "duration": 14.0, "hazard": false, "note": "Fires twin bolts while active."},
	{"id": "shield_floor", "name": "Shield Floor", "glyph": "_", "tint": "#6bb8ff", "rarity": "uncommon", "duration": 0.0, "hazard": false, "note": "One save at the bottom."},
	{"id": "sticky_paddle", "name": "Sticky Paddle", "glyph": "=", "tint": "#ffd75c", "rarity": "uncommon", "duration": 14.0, "hazard": false, "note": "Every catch holds for a moment."},
	{"id": "mirror_paddle", "name": "Mirror Paddle", "glyph": "R", "tint": "#e0d2ff", "rarity": "rare", "duration": 16.0, "hazard": false, "note": "Boss shots bounce back as score."},
	{"id": "turret_paddle", "name": "Turret Paddle", "glyph": "T", "tint": "#ffb0a0", "rarity": "uncommon", "duration": 14.0, "hazard": false, "note": "Side cannons cover the corners."},
	{"id": "extra_life", "name": "Extra Life", "glyph": "+", "tint": "#ff8fb1", "rarity": "epic", "duration": 0.0, "hazard": false, "note": "One more ball in reserve."},
	{"id": "score_x2", "name": "Double Score", "glyph": "x2", "tint": "#ffd166", "rarity": "common", "duration": 18.0, "hazard": false, "note": "Every point counts twice."},
	{"id": "score_x3", "name": "Triple Score", "glyph": "x3", "tint": "#ffcf3d", "rarity": "rare", "duration": 14.0, "hazard": false, "note": "Every point counts three times."},
	{"id": "coin_rush", "name": "Coin Rush", "glyph": "$", "tint": "#ffd75c", "rarity": "uncommon", "duration": 0.0, "hazard": false, "note": "A burst of credits."},
	{"id": "bomb", "name": "Screen Bomb", "glyph": "*", "tint": "#ff7a3d", "rarity": "rare", "duration": 0.0, "hazard": false, "note": "Damages every brick on the board."},
	{"id": "row_laser", "name": "Row Laser", "glyph": "-", "tint": "#ff3fd8", "rarity": "uncommon", "duration": 0.0, "hazard": false, "note": "Cuts the lowest brick row apart."},
	{"id": "column_laser", "name": "Column Laser", "glyph": "|", "tint": "#ff3fd8", "rarity": "uncommon", "duration": 0.0, "hazard": false, "note": "Cuts a column apart."},
	{"id": "drone", "name": "Drone", "glyph": "d", "tint": "#8bfff2", "rarity": "rare", "duration": 0.0, "hazard": false, "note": "A companion that chips a brick every few seconds."},
	{"id": "twin_drone", "name": "Twin Drones", "glyph": "dd", "tint": "#8bfff2", "rarity": "epic", "duration": 0.0, "hazard": false, "note": "Two companions, twice the chip."},
	{"id": "drone_upgrade", "name": "Drone Upgrade", "glyph": "D", "tint": "#57ffb0", "rarity": "uncommon", "duration": 0.0, "hazard": false, "note": "Drones fire twice as fast."},
	{"id": "time_slow", "name": "Time Slow", "glyph": "t", "tint": "#9fd8ff", "rarity": "rare", "duration": 8.0, "hazard": false, "note": "The whole arena eases off."},
	{"id": "boss_freeze", "name": "Boss Freeze", "glyph": "Z", "tint": "#7fe3ff", "rarity": "epic", "duration": 6.0, "hazard": false, "note": "The boss stops firing."},
	{"id": "invulnerability", "name": "Invulnerability", "glyph": "V", "tint": "#e0d2ff", "rarity": "rare", "duration": 8.0, "hazard": false, "note": "Nothing can cost you a life."},
	{"id": "magnet_field", "name": "Magnet Field", "glyph": "G", "tint": "#57ffb0", "rarity": "common", "duration": 18.0, "hazard": false, "note": "Capsules drift to the paddle."},
	{"id": "lucky_drop", "name": "Lucky Drop", "glyph": "%", "tint": "#ffd75c", "rarity": "uncommon", "duration": 0.0, "hazard": false, "note": "Three more capsules fall at once."},
	{"id": "overdrive", "name": "Overdrive", "glyph": "O+", "tint": "#ff7a3d", "rarity": "epic", "duration": 10.0, "hazard": false, "note": "Extra damage, speed and score."},
	{"id": "starfall", "name": "Starfall", "glyph": "Y", "tint": "#fff1ad", "rarity": "epic", "duration": 0.0, "hazard": false, "note": "Meteors rake the whole board."},
	{"id": "reflect_shots", "name": "Reflect Shots", "glyph": "K", "tint": "#e0d2ff", "rarity": "rare", "duration": 14.0, "hazard": false, "note": "Boss fire can be knocked away."},
	{"id": "barrier_wall", "name": "Barrier Wall", "glyph": "B", "tint": "#6bb8ff", "rarity": "uncommon", "duration": 14.0, "hazard": false, "note": "Side walls keep the rally in."},
	{"id": "repair_shield", "name": "Repair Shield", "glyph": "s", "tint": "#8bfff2", "rarity": "rare", "duration": 0.0, "hazard": false, "note": "Two saves at the bottom."},
	{"id": "hyper_paddle", "name": "Hyper Paddle", "glyph": "P", "tint": "#ff3fd8", "rarity": "epic", "duration": 12.0, "hazard": false, "note": "Bigger and quicker, all at once."},
]

const RARITY_WEIGHT := {"common": 10.0, "uncommon": 6.0, "rare": 2.8, "epic": 1.0}


static func count() -> int:
	return ITEMS.size()


static func by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if String(item["id"]) == id:
			return item
	return {}


static func has(id: String) -> bool:
	return not by_id(id).is_empty()


static func is_hazard(id: String) -> bool:
	return bool(by_id(id).get("hazard", false))


## Weighted pick. `luck` (0..1) biases the table toward rarer capsules.
static func roll(rng: RandomNumberGenerator, luck := 0.0) -> String:
	var total := 0.0
	var weights: Array = []
	for item in ITEMS:
		var rarity := String(item["rarity"])
		var base := float(RARITY_WEIGHT.get(rarity, 1.0))
		if rarity == "rare":
			base *= 1.0 + luck * 1.6
		elif rarity == "epic":
			base *= 1.0 + luck * 3.2
		weights.append(base)
		total += base
	var pick := rng.randf() * total
	for i in range(ITEMS.size()):
		pick -= float(weights[i])
		if pick <= 0.0:
			return String(ITEMS[i]["id"])
	return String(ITEMS[ITEMS.size() - 1]["id"])


static func duration(id: String) -> float:
	return float(by_id(id).get("duration", 0.0))
