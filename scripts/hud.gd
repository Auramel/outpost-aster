class_name AsterHUD
extends Control

const INK := Color("#f1f5f8")
const MUTED := Color("#aebdc9")
const DIM := Color("#121e2ad9")
const FRAME := Color("#536b81")
const ACTIVE := Color("#8cddff")
const AMBER := Color("#ffad64")
const DANGER := Color("#ff807d")

var game: Node
var _fps: Label
var _phase: Label
var _score: Label
var _tuning: AsterTuningPanel
var _objective: Label
var _operator: Label
var _weapon: Label
var _rifle: Label
var _cargo: Label
var _warning: Label
var _notice: Label
var _context: Label
var _service: ProgressBar
var _overlay: ColorRect
var _menu_title: Label
var _menu_detail: Label
var _menu_controls: Label
var _sensitivity: HSlider
var _sensitivity_caption: Label
var _resume: Button
var _restart: Button
var _main_menu: Button
var _refresh := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fps = _label(self, "", 17, ACTIVE)
	_fps.position = Vector2(40, 33)
	_fps.hide()
	var phase := _card(Vector2(0.5, 0), Vector2(-264, 30), 528, AMBER)
	_phase = _label(phase, "", 25, INK)
	_objective = _label(phase, "", 17, MUTED)
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var score_panel := _card(Vector2(1, 0), Vector2(-255, 30), 219, AMBER)
	_label(score_panel, "БОЕВЫЕ ОЧКИ", 15, AMBER)
	_score = _label(score_panel, "", 28, INK)
	var operator_panel := _card(Vector2(0, 1), Vector2(36, -139), 273, ACTIVE)
	_label(operator_panel, "ЗДОРОВЬЕ", 15, ACTIVE)
	_operator = _label(operator_panel, "", 31, INK)
	_cargo = _label(operator_panel, "", 16, MUTED)
	var rifle_panel := _card(Vector2(1, 1), Vector2(-306, -139), 270, ACTIVE)
	_weapon = _label(rifle_panel, "", 16, ACTIVE)
	_rifle = _label(rifle_panel, "", 32, INK)
	var hints := _card(Vector2(0.5, 1), Vector2(-300, -146), 600)
	_context = _label(hints, "", 20, INK)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_service = ProgressBar.new()
	_service.custom_minimum_size.y = 7
	_service.max_value = 1.0
	_service.show_percentage = false
	_service.add_theme_stylebox_override(&"background", _style(Color("#2c4054"), Color.TRANSPARENT, 0, 2))
	_service.add_theme_stylebox_override(&"fill", _style(ACTIVE, Color.TRANSPARENT, 0, 2))
	hints.add_child(_service)
	var alerts := _card(Vector2(0.5, 0), Vector2(-308, 119), 616)
	_warning = _label(alerts, "", 19, DANGER)
	_notice = _label(alerts, "", 17, AMBER)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_overlay()
	_tuning = AsterTuningPanel.new()
	add_child(_tuning)
	_tuning.setup(game, self)
	_update()

func _card(anchor: Vector2, offset: Vector2, min_width: float, accent: Color = Color.TRANSPARENT) -> VBoxContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.anchor_left = anchor.x
	box.anchor_top = anchor.y
	box.anchor_right = anchor.x
	box.anchor_bottom = anchor.y
	box.offset_left = offset.x
	box.offset_top = offset.y
	box.offset_right = offset.x + min_width
	box.offset_bottom = offset.y
	var trim := FRAME if accent == Color.TRANSPARENT else accent
	var style := _style(DIM, trim, 0, 0, 19)
	style.border_width_left = 3 if accent != Color.TRANSPARENT else 0
	style.border_width_bottom = 1
	box.add_theme_stylebox_override(&"panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	box.add_child(column)
	return column

func _style(background: Color, border: Color, width: int, radius: int, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.69
	style.content_margin_bottom = padding * 0.69
	return style

func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var line := Label.new()
	line.text = text
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override(&"font_size", font_size)
	line.add_theme_color_override(&"font_color", color)
	parent.add_child(line)
	return line

func _make_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color("#0b1523d9")
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 650
	panel.add_theme_stylebox_override(&"panel", _style(Color("#172333"), FRAME, 1, 0, 36))
	center.add_child(panel)
	var options := VBoxContainer.new()
	options.add_theme_constant_override(&"separation", 18)
	panel.add_child(options)
	_label(options, "АСТЕР  /  ФОРПОСТ", 17, ACTIVE)
	_menu_title = _label(options, "", 51, INK)
	_menu_detail = _label(options, "", 24, AMBER)
	_menu_controls = _label(options, "WASD · Движение     Пробел · Прыжок\nCtrl · Присесть     Shift · Спринт вперёд\nМышь · Обзор     ПКМ · Прицеливание автоматом\nЛКМ · Стрельба или ремонт     E · Взаимодействие     Удерж. E · Обслуживание\n1 / 2 · Смена инструмента     R · Перезарядка\nF3 · Частота кадров     F11 · Полный экран", 21, MUTED)
	_sensitivity_caption = _label(options, "Чувствительность мыши", 20, MUTED)
	_sensitivity = HSlider.new()
	_sensitivity.min_value = 0.0006
	_sensitivity.max_value = 0.008
	_sensitivity.step = 0.00005
	_sensitivity.value = game.player.sensitivity
	_sensitivity.value_changed.connect(_change_sensitivity)
	options.add_child(_sensitivity)
	_resume = _button(options, "Продолжить")
	_resume.pressed.connect(func() -> void: game.set_paused(false))
	_restart = _button(options, "Начать заново")
	_restart.pressed.connect(func() -> void: game.restart())
	_main_menu = _button(options, "Главное меню")
	_main_menu.pressed.connect(func() -> void: game.return_to_main_menu())
	_overlay.hide()

func _change_sensitivity(value: float) -> void:
	game.player.sensitivity = value
	AsterSettings.sensitivity = value
	_sensitivity_caption.text = "Чувствительность мыши   ·   %d%%" % roundi(value / 0.00255 * 100.0)

func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override(&"font_size", 22)
	button.add_theme_color_override(&"font_color", INK)
	button.add_theme_stylebox_override(&"normal", _style(Color("#293d52"), FRAME, 1, 0, 13))
	button.add_theme_stylebox_override(&"hover", _style(Color("#36556e"), AMBER, 2, 0, 13))
	button.add_theme_stylebox_override(&"pressed", _style(Color("#1d3147"), AMBER, 2, 0, 13))
	parent.add_child(button)
	return button

func show_tuning(value: bool) -> void:
	if value:
		_tuning.show_menu()
	else:
		_tuning.hide()

func show_pause(value: bool) -> void:
	_overlay.visible = value
	if value:
		_menu_title.text = "Пауза"
		_menu_detail.text = "Esc · Вернуться к обороне"
		_menu_controls.show()
		_sensitivity.show()
		_sensitivity_caption.show()
		_resume.show()
		_restart.hide()
		_resume.grab_focus()

func show_loss() -> void:
	_overlay.show()
	_menu_title.text = "Форпост потерян"
	_menu_detail.text = "%s\nОборона: %s  ·  Уничтожено: %d" % [game.loss_reason, _time_label(game.assault.elapsed), game.kills]
	_menu_controls.hide()
	_sensitivity.hide()
	_sensitivity_caption.hide()
	_resume.hide()
	_restart.show()
	_restart.grab_focus()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if game.lost:
				return
			if game.tuning_open:
				game.set_tuning(false)
			else:
				game.set_paused(not game.paused)
		KEY_F3:
			_fps.visible = not _fps.visible
		KEY_F11:
			var window := get_window()
			var is_fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
			AsterSettings.fullscreen = not is_fullscreen
			AsterSettings.apply_display(window)
			AsterSettings.save()
		_:
			return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.06
		_update()
	queue_redraw()

func _update() -> void:
	var player: AsterPlayer = game.player
	var assault: AsterAssault = game.assault
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	_phase.text = "%s   /   %s" % ["ПОРАЖЕНИЕ" if game.lost else "ОСАДА", _time_label(assault.elapsed)]
	_phase.add_theme_color_override(&"font_color", AMBER if assault.pressure() >= 0.7 else INK)
	_objective.text = "Уничтожено: %d   ·   На поле: %d/%d" % [game.kills, assault.enemies.size(), assault.active_cap()]
	_score.text = str(game.combat_points)
	_operator.text = "%03d   ·   %d ВОЗВР." % [ceili(player.hp), game.points]
	_operator.add_theme_color_override(&"font_color", DANGER if player.hp <= game.balance.player_hp * 0.30 else INK)
	_cargo.visible = player.carrying
	_cargo.text = "ЯЩИК   ·   СКОРОСТЬ %d%%" % roundi(player.move_speed() / game.balance.player_speed * 100.0)
	_weapon.text = "01  /  АВТОМАТ" if player.tool == 1 else "02  /  РЕМКОМПЛЕКТ"
	_rifle.visible = player.tool == 1
	_rifle.text = "%02d   /   %03d" % [player.magazine, player.reserve]
	if player.reload_left > 0.0:
		_weapon.text = "ПЕРЕЗАРЯДКА   ·   %.1f С" % player.reload_left
	_rifle.add_theme_color_override(&"font_color", AMBER if player.magazine <= 6 else INK)
	_context.text = _local_context(player)
	var replaced := player.interaction.stage != &"" and player.alive
	_service.visible = replaced
	if replaced:
		_service.value = player.interaction.elapsed / player.interaction.duration
	_context.get_parent().get_parent().visible = not _context.text.is_empty()
	_warning.text = "Главное здание атакуют" if game.core.attacked > 0.0 else ""
	_notice.text = game.message if game.message_left > 0.0 else ""
	_warning.visible = not _warning.text.is_empty()
	_notice.visible = not _notice.text.is_empty()
	_warning.get_parent().get_parent().visible = _warning.visible or _notice.visible

func _time_label(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]

func _local_context(player: AsterPlayer) -> String:
	if game.lost:
		return ""
	if not player.alive:
		return "Возрождение через %.1f с" % game.respawn_left
	var interaction := player.interaction
	if interaction.stage != &"":
		var action := "1/2  ·  Снятие старого ящика" if interaction.stage == &"remove" else "2/2  ·  Установка ящика"
		return "%s   %s   ·   %.1f с\nУдерживайте E" % [interaction.station.title, action, maxf(0.0, interaction.duration - interaction.elapsed)]
	var target := interaction.aimed
	if target is AsterStructure or target is AsterTurret:
		if target.hp < target.max_hp and (player.tool == 2 or target != interaction.usable):
			return target.repair_hint()
	return interaction.action_hint()

func _draw() -> void:
	if not is_instance_valid(game) or game.lost or game.paused or game.tuning_open:
		return
	var player: AsterPlayer = game.player
	if player.damage_flash > 0.0:
		var tint := Color(0.91, 0.18, 0.25, player.damage_flash * 0.24)
		draw_rect(Rect2(Vector2.ZERO, size), tint, false, 23)
	if not player.alive:
		return
	var middle := size * 0.5
	var tone := ACTIVE if player.tool == 2 else INK
	if player.hit_flash > 0.0:
		for direction: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
			draw_line(middle + direction * 6, middle + direction * 12, AMBER, 2.1, true)
	elif player.aim_amount < 0.92:
		var fade := 1.0 - smoothstep(0.1, 0.92, player.aim_amount)
		var gap := lerpf(7.5, 3.0, player.aim_amount)
		if player.tool == 1:
			gap *= 1.0 - 0.46 * player.rifle_tuning.stat(AsterRifleTuning.Path.ACCURACY)
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(middle + direction * gap, middle + direction * (gap + 5.0), Color(0.05, 0.09, 0.13, fade * 0.9), 3.4, true)
			draw_line(middle + direction * gap, middle + direction * (gap + 5.0), Color(tone, fade), 1.65, true)
	if player.aim_amount > 0.85:
		tone = AMBER
	draw_circle(middle, 1.45, tone)
