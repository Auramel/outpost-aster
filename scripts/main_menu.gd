extends Control

const OUTPOST := "res://scenes/outpost.tscn"
const MAP_REVIEW := "res://scenes/map_review.tscn"
const LOADING := "res://scenes/loading.tscn"
const BACKDROP := preload("res://assets/art/menu_outpost.jpg")
const INK := Color("#f4e7d4")
const MUTED := Color("#c1b7a9")
const AMBER := Color("#f2ac68")

var _home: VBoxContainer
var _settings: VBoxContainer
var _start: Button
var _map_review: Button
var _options: Button
var _exit: Button
var _back: Button
var _volume: HSlider
var _mouse: HSlider
var _fullscreen: CheckButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AsterSettings.load_from_disk()
	if not OS.get_cmdline_user_args().has("--automated"):
		AsterSettings.apply_display(get_window())
	_make_backdrop()
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 117)
	margin.add_theme_constant_override(&"margin_right", 64)
	_home = _column(margin)
	_settings = _column(margin)
	_make_home()
	_make_settings()
	_show_settings(false)

func _make_backdrop() -> void:
	var view := TextureRect.new()
	view.texture = BACKDROP
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.46, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color("#0b111af7"), Color("#111921ed"), Color("#161c24a6"), Color("#191c2237"), Color("#1b1e2628")])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.width = 512
	wash.height = 4
	var shade := TextureRect.new()
	shade.texture = wash
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _column(parent: Container) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 455.0
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override(&"separation", 15)
	parent.add_child(column)
	return column

func _make_home() -> void:
	_rule(_home)
	var title := _label(_home, "ФОРПОСТ\nАСТЕР", 95, INK)
	title.add_theme_constant_override(&"line_spacing", -16)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Arial", "Helvetica Neue"])
	title_font.font_weight = 800
	title.add_theme_font_override(&"font", title_font)
	_spacer(_home, 20.0)
	_start = _button(_home, "Начать игру", true)
	_start.pressed.connect(_start_game)
	_map_review = _button(_home, "Разметка карты")
	_map_review.pressed.connect(_open_map_review)
	_options = _button(_home, "Настройки")
	_options.pressed.connect(_show_settings.bind(true))
	_exit = _button(_home, "Выход")
	_exit.pressed.connect(_quit_game)

func _make_settings() -> void:
	_rule(_settings)
	_label(_settings, "Настройки", 54, INK)
	_spacer(_settings, 12.0)
	var volume_caption := _label(_settings, "", 21, MUTED)
	_volume = _slider(_settings, 0.0, 1.0, 0.01, AsterSettings.volume)
	_volume.value_changed.connect(func(value: float) -> void:
		AsterSettings.volume = value
		AsterSettings.apply_volume()
		volume_caption.text = "Громкость   %d%%" % roundi(value * 100.0)
	)
	volume_caption.text = "Громкость   %d%%" % roundi(AsterSettings.volume * 100.0)
	var mouse_caption := _label(_settings, "", 21, MUTED)
	_mouse = _slider(_settings, 0.0006, 0.008, 0.00005, AsterSettings.sensitivity)
	_mouse.value_changed.connect(func(value: float) -> void:
		AsterSettings.sensitivity = value
		mouse_caption.text = "Чувствительность мыши   %d%%" % _sensitivity_percent(value)
	)
	mouse_caption.text = "Чувствительность мыши   %d%%" % _sensitivity_percent(AsterSettings.sensitivity)
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Полноэкранный режим"
	_fullscreen.button_pressed = AsterSettings.fullscreen
	_fullscreen.custom_minimum_size.y = 58
	_fullscreen.add_theme_font_size_override(&"font_size", 23)
	_settings.add_child(_fullscreen)
	_fullscreen.toggled.connect(func(value: bool) -> void:
		AsterSettings.fullscreen = value
		AsterSettings.apply_display(get_window())
		AsterSettings.save()
	)
	_spacer(_settings, 12.0)
	_back = _button(_settings, "Назад", true)
	_back.pressed.connect(_back_to_home)

func _start_game() -> void:
	AsterSettings.save()
	var loading := (load(LOADING) as PackedScene).instantiate()
	loading.target_scene = OUTPOST
	loading.loading_text = "Загрузка форпоста"
	get_tree().change_scene_to_node(loading)

func _open_map_review() -> void:
	get_tree().change_scene_to_file(MAP_REVIEW)

func _quit_game() -> void:
	AsterSettings.save()
	get_tree().quit()

func _back_to_home() -> void:
	AsterSettings.save()
	_show_settings(false)
	_options.grab_focus()

func _show_settings(show_options: bool) -> void:
	_home.visible = not show_options
	_settings.visible = show_options
	if show_options:
		_volume.grab_focus()
	else:
		_start.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_fullscreen.button_pressed = not _fullscreen.button_pressed
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and _settings.visible:
		_back_to_home()
		get_viewport().set_input_as_handled()

func _sensitivity_percent(value: float) -> int:
	return roundi(value / AsterSettings.DEFAULT_SENSITIVITY * 100.0)

func _rule(parent: Control) -> void:
	var mark := ColorRect.new()
	mark.color = AMBER
	mark.custom_minimum_size = Vector2(73, 5)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mark)

func _spacer(parent: Control, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	parent.add_child(space)

func _label(parent: Control, words: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override(&"font_size", points)
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label

func _slider(parent: Control, low: float, high: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.y = 34
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			AsterSettings.save()
	)
	parent.add_child(slider)
	return slider

func _button(parent: Control, words: String, primary := false) -> Button:
	var button := Button.new()
	button.text = words
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(455, 69)
	button.add_theme_font_size_override(&"font_size", 27)
	button.add_theme_color_override(&"font_color", Color("#171a1e") if primary else INK)
	button.add_theme_color_override(&"font_hover_color", Color("#14181e") if primary else INK)
	button.add_theme_color_override(&"font_focus_color", Color("#171a1e") if primary else INK)
	button.add_theme_color_override(&"font_pressed_color", Color("#171a1e") if primary else INK)
	button.add_theme_stylebox_override(&"normal", _button_style(AMBER if primary else Color("#19232bdc"), Color("#846759"), 1))
	button.add_theme_stylebox_override(&"hover", _button_style(Color("#ffd4a2") if primary else Color("#343d43"), AMBER, 2))
	button.add_theme_stylebox_override(&"pressed", _button_style(Color("#c9884e") if primary else Color("#222d33"), AMBER, 1))
	var focus := _button_style(Color.TRANSPARENT, Color("#ffe0b5"), 2)
	focus.draw_center = false
	button.add_theme_stylebox_override(&"focus", focus)
	parent.add_child(button)
	return button

func _button_style(fill: Color, edge: Color, thickness: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(thickness)
	style.border_width_left = maxi(3, thickness)
	style.content_margin_left = 25
	style.content_margin_right = 18
	return style
