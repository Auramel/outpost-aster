extends AsterOutpost

const MAIN_MENU := "res://scenes/main_menu.tscn"
const INK := Color("#f1f5f8")
const MUTED := Color("#aebdc9")
const PIN_LIFT := Vector3(0, 0.33, 0)

var _camera := Camera3D.new()
var _picker := AsterMapPicker.new()
var _notes := AsterMapNotes.new()
var _pins: Array[Node3D] = []
var _preview: Node3D
var _draft: Dictionary = {}
var _editing := -1
var _flying := false
var _load_error := OK
var _list_panel: VBoxContainer
var _edit_panel: VBoxContainer
var _list: ItemList
var _empty: Label
var _point: Label
var _comment: TextEdit
var _save: Button
var _status: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AsterSettings.load_from_disk()
	_build_map()
	for structure in walls + [core]:
		structure.status_tag.hide()
		structure.status_tag.set_process(false)
	for turret in turrets:
		turret.status_tag.hide()
		turret.status_tag.set_process(false)
	_picker.setup(self)
	add_child(_camera)
	_camera.position = Vector3(19, 18, 35)
	_camera.fov = balance.hip_fov
	_camera.far = 500.0
	_camera.look_at(Vector3(0, 2, 6))
	_camera.make_current()
	_build_interface()
	_load_error = _notes.load_notes()
	if _load_error != OK:
		_set_status("Не удалось прочитать заметки (%s)" % error_string(_load_error))
	for note in _notes.notes:
		_pins.append(_pin(note, _pins.size(), AsterArt.AMBER))
	_refresh_list()
	get_window().focus_exited.connect(_end_flight)

func _process(delta: float) -> void:
	if not _flying:
		return
	var axis := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0.0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var height := float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
	var direction := _camera.global_basis * axis + Vector3.UP * height
	var speed := 32.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 9.0
	_camera.position += direction.limit_length() * speed * delta

func _input(event: InputEvent) -> void:
	if not _flying:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed) or event.is_action_pressed(&"ui_cancel"):
		_end_flight()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var scale := AsterSettings.sensitivity
		_camera.rotation.x = clampf(_camera.rotation.x - event.relative.y * scale, -1.55, 1.55)
		_camera.rotation.y = wrapf(_camera.rotation.y - event.relative.x * scale, -PI, PI)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		AsterSettings.fullscreen = get_window().mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
		AsterSettings.apply_display(get_window())
		AsterSettings.save()
		get_viewport().set_input_as_handled()
	if _editing >= 0 or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_flying = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.button_index == MOUSE_BUTTON_LEFT and not _flying:
		_pick_point(event.position)

func _end_flight() -> void:
	if _flying:
		_flying = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _pick_point(screen: Vector2) -> void:
	var origin := _camera.project_ray_origin(screen)
	var direction := _camera.project_ray_normal(screen)
	var hit := _picker.pick(origin, origin + direction * _camera.far)
	var depth := _camera.far if hit.is_empty() else origin.distance_to(hit.position)
	var nearest := 17.0
	var selected := -1
	for index in range(_pins.size()):
		var position := _pins[index].global_position
		for spot: Vector3 in [position, position + PIN_LIFT]:
			if _camera.is_position_behind(spot) or (spot - origin).dot(direction) > depth + 0.08:
				continue
			var distance := screen.distance_to(_camera.unproject_position(spot))
			if distance < nearest:
				nearest = distance
				selected = index
	if selected >= 0:
		_open_note(selected, false)
		return
	if hit.is_empty() or _load_error != OK:
		return
	hit["camera_position"] = _camera.position
	hit["camera_rotation_degrees"] = _camera.rotation_degrees
	hit["comment"] = ""
	_preview = _pin(hit, _notes.notes.size(), AsterArt.CYAN)
	_begin_edit(_notes.notes.size(), hit)

func _pin(note: Dictionary, index: int, color: Color) -> Node3D:
	var pin := Node3D.new()
	pin.position = note.position + note.normal * 0.12
	add_child(pin)
	AsterArt.primitive(pin, "orb", Vector3.ONE * 0.23, Vector3.ZERO, color, true)
	var label := AsterArt.lettering(pin, str(index + 1), PIN_LIFT, 35, color, true)
	label.fixed_size = true
	label.pixel_size = 0.00125
	label.outline_size = 8
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pin

func _open_note(index: int, restore_view: bool) -> void:
	var note := _notes.notes[index]
	if restore_view:
		_camera.position = note.camera_position
		_camera.rotation_degrees = note.camera_rotation_degrees
	_begin_edit(index, note.duplicate())

func _begin_edit(index: int, note: Dictionary) -> void:
	_editing = index
	_draft = note
	_set_status("")
	var position: Vector3 = note.position
	_point.text = "Метка %d   ·   X %.1f   Y %.1f   Z %.1f" % [index + 1, position.x, position.y, position.z]
	_list_panel.hide()
	_edit_panel.show()
	_comment.text = note.comment
	_update_save()
	_comment.grab_focus()

func _save_note() -> void:
	var comment := _comment.text.strip_edges()
	if _editing < 0 or comment.is_empty():
		return
	_draft["comment"] = comment
	var error := _notes.save_note(_editing, _draft)
	if error != OK:
		_set_status("Файл изменился. Скопируйте текст и откройте разметку заново." if error == ERR_BUSY else "Не удалось сохранить заметку (%s)" % error_string(error))
		return
	if _editing == _pins.size():
		_pins.append(_pin(_draft, _editing, AsterArt.AMBER))
	_close_edit()
	_set_status("Метка сохранена")
	_refresh_list()

func _close_edit() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null
	_editing = -1
	_draft = {}
	_set_status("")
	_edit_panel.hide()
	_list.deselect_all()
	_list_panel.show()

func _refresh_list() -> void:
	_list.clear()
	for index in range(_notes.notes.size()):
		var comment: String = _notes.notes[index].comment
		var preview := comment.get_slice("\n", 0)
		if preview.length() > 43:
			preview = preview.left(43) + "…"
		_list.add_item("%d   %s" % [index + 1, preview])
		_list.set_item_tooltip(index, comment)
	_empty.visible = _list.item_count == 0 and _load_error == OK
	_list.visible = _list.item_count > 0

func _update_save() -> void:
	_save.disabled = _comment.text.strip_edges().is_empty()

func _set_status(words: String) -> void:
	_status.text = words
	_status.visible = not words.is_empty()

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hints := _panel(layer)
	hints.position = Vector2(28, 28)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guide := VBoxContainer.new()
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_child(guide)
	_label(guide, "РАЗМЕТКА КАРТЫ", 22, AsterArt.AMBER)
	_label(guide, "Удерж. ПКМ · Обзор и полёт     WASD · Движение\nПробел / Ctrl · Вверх / вниз     Shift · Быстрее\nЛКМ · Поставить или открыть метку", 18, INK)
	var panel := _panel(layer)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -446
	panel.offset_right = -28
	panel.offset_top = 28
	panel.offset_bottom = 28
	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 10)
	panel.add_child(content)
	_list_panel = VBoxContainer.new()
	_list_panel.add_theme_constant_override(&"separation", 10)
	content.add_child(_list_panel)
	_label(_list_panel, "Метки", 25, INK)
	_empty = _label(_list_panel, "Пока нет меток.", 18, MUTED)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list = ItemList.new()
	_list.custom_minimum_size.y = 220.0
	_list.add_theme_font_size_override(&"font_size", 19)
	_list.add_theme_constant_override(&"v_separation", 10)
	_list.item_selected.connect(_open_note.bind(true))
	_list_panel.add_child(_list)
	_button(_list_panel, "Главное меню").pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_MENU)
	)
	_edit_panel = VBoxContainer.new()
	_edit_panel.add_theme_constant_override(&"separation", 10)
	content.add_child(_edit_panel)
	_point = _label(_edit_panel, "", 20, AsterArt.AMBER)
	_comment = TextEdit.new()
	_comment.custom_minimum_size.y = 155.0
	_comment.placeholder_text = "Комментарий к месту"
	_comment.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_comment.add_theme_font_size_override(&"font_size", 20)
	_edit_panel.add_child(_comment)
	var actions := HBoxContainer.new()
	_edit_panel.add_child(actions)
	_save = _button(actions, "Сохранить")
	_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save.add_theme_color_override(&"font_color", AsterArt.AMBER)
	_save.pressed.connect(_save_note)
	_button(actions, "Отмена").pressed.connect(_close_edit)
	_comment.text_changed.connect(_update_save)
	_edit_panel.hide()
	_status = _label(content, "", 18, AsterArt.AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.hide()

func _panel(parent: CanvasLayer) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14202bea")
	style.border_color = Color("#a98463")
	style.border_width_left = 3
	style.border_width_bottom = 1
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override(&"panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Control, words: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", points)
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Control, words: String) -> Button:
	var button := Button.new()
	button.text = words
	button.custom_minimum_size.y = 42
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override(&"font_size", 20)
	parent.add_child(button)
	return button
