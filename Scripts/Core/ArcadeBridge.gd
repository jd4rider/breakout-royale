extends Node
## Bridge between the Godot build and the Little Joy Arcade web SDK.
##
## The browser wrapper (`web/play/arcade-bridge.js`) exposes a deliberately
## small `window.BreakoutRoyale` object on top of the real arcade client. If the
## wrapper is absent — desktop, a plain export, an offline tab — every call is a
## harmless no-op and the game keeps saving locally.

signal status_changed(value: String)
signal identity_changed

var available := false
var status := "local"
var player_label := "Guest"
var signed_in := false
var last_sync_ms := 0

var _platform := "desktop"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_platform = "web"
		var probe: Variant = JavaScriptBridge.eval(
			"typeof window.BreakoutRoyale !== 'undefined'", true)
		available = bool(probe) if probe != null else false
	if not available:
		status = "local"
		return
	status = "connecting"
	_refresh_identity()
	var remote: Variant = pull()
	if typeof(remote) == TYPE_DICTIONARY and not (remote as Dictionary).is_empty():
		_merge_remote(remote)
	on_local_save(Save.data)


## The arcade client finishes signing in after the page boots, so the menu asks
## again when it opens instead of showing a stale "Guest" for the session.
func refresh_identity() -> void:
	if not available:
		identity_changed.emit()
		return
	_refresh_identity()
	identity_changed.emit()


func _refresh_identity() -> void:
	var raw: Variant = _call("JSON.stringify(window.BreakoutRoyale.identity())")
	if raw == null:
		return
	var parsed: Variant = JSON.parse_string(String(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var record: Dictionary = parsed
	signed_in = bool(record.get("signedIn", false))
	player_label = String(record.get("name", "Guest"))
	_set_status(String(record.get("status", "local")))


func _call(code: String) -> Variant:
	if not available:
		return null
	return JavaScriptBridge.eval(code, true)


func _set_status(value: String) -> void:
	var allowed := ["local", "connecting", "synced", "offline", "signed_out", "error", "syncing"]
	status = value if value in allowed else "local"
	status_changed.emit(status)


func on_local_save(payload: Dictionary) -> void:
	if not available:
		return
	var encoded := Marshalls.utf8_to_base64(JSON.stringify(payload))
	_call("window.BreakoutRoyale.pushSave('%s')" % encoded)
	last_sync_ms = Time.get_ticks_msec()
	var reported: Variant = _call("window.BreakoutRoyale.status()")
	if reported != null:
		_set_status(String(reported))


func pull() -> Variant:
	if not available:
		return {}
	var raw: Variant = _call("window.BreakoutRoyale.pullSave()")
	if raw == null:
		return {}
	var text := String(raw)
	if text.is_empty() or text == "null":
		return {}
	return JSON.parse_string(text)


## Newest save wins for progress; achievements are unioned; device settings and
## the local profile name always stay with the device.
func _merge_remote(remote: Dictionary) -> void:
	var remote_stamp := int(remote.get("savedAt", 0))
	var local_stamp := int(Save.data.get("savedAt", 0))
	var merged := false
	if remote_stamp > local_stamp:
		var settings: Dictionary = Save.data.get("settings", {})
		var profile: Dictionary = Save.data.get("profile", {})
		Save.data = remote
		Save.data["settings"] = settings
		Save.data["profile"] = profile
		merged = true
	var remote_achievements: Variant = remote.get("achievements", {})
	if typeof(remote_achievements) == TYPE_DICTIONARY:
		for id in remote_achievements.keys():
			if not Save.data["achievements"].has(id):
				Save.data["achievements"][id] = remote_achievements[id]
				merged = true
	if merged:
		Save.queue_save()
		Save.changed.emit()
		Save.flush()


func achievement(id: String) -> void:
	if not available:
		return
	_call("window.BreakoutRoyale.unlockAchievement('%s')" % id)


func track(event: String, props: Dictionary = {}) -> void:
	if not available:
		return
	var encoded := Marshalls.utf8_to_base64(JSON.stringify({"name": event, "props": props}))
	_call("window.BreakoutRoyale.track('%s')" % encoded)


func sign_in() -> void:
	_call("window.BreakoutRoyale.signIn()")


func open_arcade() -> void:
	if available:
		_call("window.BreakoutRoyale.openArcade()")


func status_text() -> String:
	match status:
		"synced":
			return "Cloud saved · %s" % player_label
		"syncing":
			return "Syncing · %s" % player_label
		"connecting":
			return "Connecting to Little Joy Arcade…"
		"offline":
			return "Offline · saving on this device"
		"error":
			return "Sync hiccup · saving on this device"
		_:
			return "Local save · sign in to sync"
