class_name AsterSettings
extends RefCounted

const FILE := "user://settings.cfg"
const DEFAULT_SENSITIVITY := 0.00255
const MIN_VIEW_DISTANCE := 120
const MAX_VIEW_DISTANCE := 240
const DEFAULT_VIEW_DISTANCE := 180
const VIEW_DISTANCE_STEP := 10

static var sensitivity := DEFAULT_SENSITIVITY
static var volume := 1.0
static var fullscreen := true
static var view_distance := DEFAULT_VIEW_DISTANCE

static func load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(FILE) == OK:
		sensitivity = clampf(float(config.get_value("controls", "sensitivity", DEFAULT_SENSITIVITY)), 0.0006, 0.008)
		volume = clampf(float(config.get_value("audio", "volume", 1.0)), 0.0, 1.0)
		fullscreen = bool(config.get_value("display", "fullscreen", true))
		view_distance = clampi(snappedi(int(config.get_value("display", "view_distance", DEFAULT_VIEW_DISTANCE)), VIEW_DISTANCE_STEP), MIN_VIEW_DISTANCE, MAX_VIEW_DISTANCE)
	apply_volume()

static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "sensitivity", sensitivity)
	config.set_value("audio", "volume", volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "view_distance", view_distance)
	config.save(FILE)

static func apply_volume() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))

static func apply_display(window: Window) -> void:
	if DisplayServer.get_name() == "headless":
		return
	window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
