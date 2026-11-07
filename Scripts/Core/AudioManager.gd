extends Node
## Sound effects and two music beds.
##
## Browsers keep WebAudio suspended until a real gesture, so `kick()` is called
## on the first tap rather than in `_ready`.

const SFX_DIR := "res://Assets/Audio/SFX/"
const MUSIC_DIR := "res://Assets/Audio/Music/"
const SILENT_DB := -60.0

var music_volume := 0.65
var sfx_volume := 0.9

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _mood := ""
var _kicked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(12):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = SILENT_DB
	add_child(_music)
	apply_settings(Save.data.get("settings", {}))


func kick() -> void:
	_kicked = true
	if _mood != "":
		play_music(_mood)


func apply_settings(settings: Dictionary) -> void:
	music_volume = clampf(float(settings.get("music", 0.65)), 0.0, 1.0)
	sfx_volume = clampf(float(settings.get("sfx", 0.9)), 0.0, 1.0)
	if _music != null:
		_music.volume_db = linear_to_db(maxf(0.02, music_volume)) - 6.0 if _music.playing else SILENT_DB


func _stream(path: String) -> AudioStream:
	if _sfx.has(path):
		return _sfx[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	_sfx[path] = stream
	return stream


func _looped(path: String) -> AudioStream:
	var stream := _stream(path)
	if stream is AudioStreamWAV:
		var copy := stream.duplicate() as AudioStreamWAV
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		var bytes := 2 if copy.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels := 2 if copy.stereo else 1
		copy.loop_end = int(copy.data.size() / (bytes * channels))
		return copy
	return stream


func play_sfx(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if sfx_volume <= 0.001:
		return
	var stream := _stream(SFX_DIR + name + ".wav")
	if stream == null:
		return
	var target: AudioStreamPlayer = null
	for player in _players:
		if not player.playing:
			target = player
			break
	if target == null:
		target = _players[0]
	target.stream = stream
	target.pitch_scale = clampf(pitch, 0.55, 1.9)
	target.volume_db = volume_db + linear_to_db(maxf(0.05, sfx_volume))
	target.play()


func ui_click() -> void:
	play_sfx("ui_click", randf_range(0.96, 1.04), -7.0)


func ui_back() -> void:
	play_sfx("ui_back", randf_range(0.95, 1.02), -7.0)


func play_music(mood: String) -> void:
	_mood = mood
	var stream := _looped(MUSIC_DIR + mood + ".wav")
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.volume_db = linear_to_db(maxf(0.02, music_volume)) - 6.0
	if _kicked:
		_music.play()


func stop_music() -> void:
	_mood = ""
	_music.stop()
