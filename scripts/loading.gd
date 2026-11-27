extends Control

const MAIN_MENU := "res://scenes/main_menu.tscn"
const MINIMUM_TIME := 0.45

@export_file("*.tscn") var target_scene := MAIN_MENU
@export var loading_text := "Загрузка меню"

@onready var _status: Label = $Content/Status
@onready var _progress: ProgressBar = $Content/Progress
@onready var _actions: HBoxContainer = $Content/Actions
@onready var _retry: Button = $Content/Actions/Retry
@onready var _back: Button = $Content/Actions/Back
var _elapsed := 0.0

func _ready() -> void:
	if target_scene == MAIN_MENU:
		AsterSettings.load_from_disk()
		if not OS.get_cmdline_user_args().has("--automated"):
			AsterSettings.apply_display(get_window())
	_back.text = "Выход" if target_scene == MAIN_MENU else "Главное меню"
	_back.pressed.connect(_leave)
	_retry.pressed.connect(_load)
	_load()

func _load() -> void:
	_elapsed = 0.0
	_status.text = loading_text
	_progress.show()
	_actions.hide()
	if ResourceLoader.load_threaded_request(target_scene) != OK:
		_show_error()
		return
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	match ResourceLoader.load_threaded_get_status(target_scene):
		ResourceLoader.THREAD_LOAD_LOADED:
			if _elapsed < MINIMUM_TIME:
				return
			set_process(false)
			var scene := ResourceLoader.load_threaded_get(target_scene) as PackedScene
			if scene == null or get_tree().change_scene_to_packed(scene) != OK:
				_show_error()
		ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(target_scene)
			_show_error()
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_error()

func _show_error() -> void:
	set_process(false)
	_status.text = "Не удалось загрузить меню" if target_scene == MAIN_MENU else "Не удалось загрузить форпост"
	_progress.hide()
	_actions.show()
	_retry.grab_focus()

func _leave() -> void:
	if target_scene == MAIN_MENU:
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU)
