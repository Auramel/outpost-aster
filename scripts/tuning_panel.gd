class_name AsterTuningPanel
extends ColorRect

const TITLES := ["Скорострельность", "Урон", "Обнаружение", "Ёмкость", "Дрон снабжения", "Стабилизация"]
const PATH_NOTES := [
	"Темп огня · боковые блоки привода",
	"Урон попадания · кольца на стволах",
	"Радиус поиска · блок оптики",
	"Боезапас · новые ящики, два с третьего уровня",
	"Скорость и груз · дрон и посадочная площадка",
	"Меньше подброс и разброс · амортизаторы",
]

const RIFLE_TITLES := ["Скорострельность", "Урон", "Точность", "Компенсация отдачи"]
const RIFLE_NOTES := [
	"Темп огня · усиленный привод",
	"Урон попадания · новый дульный блок",
	"Меньше разброс · боковой блок юстировки",
	"Меньше подброс · амортизатор приклада",
]

var _game: Node
var _appearance
var _funds: Label
var _status: Label
var _heading: Label
var _cards: Array[PanelContainer] = []
var _card_titles: Array[Label] = []
var _card_notes: Array[Label] = []
var _ranks: Array[Label] = []
var _values: Array[Label] = []
var _buy: Array[Button] = []
var _close: Button

func setup(game: Node, appearance: Control) -> void:
	_game = game
	_appearance = appearance
	color = Color("#090f1bdc")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 1130
	panel.add_theme_stylebox_override(&"panel", _appearance._style(Color("#152335"), Color("#61788d"), 1, 0, 27))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 13)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_heading = _appearance._label(header, "", 29, _appearance.INK)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_funds = _appearance._label(header, "", 25, _appearance.AMBER)
	_funds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status = _appearance._label(content, "", 17, _appearance.MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 10)
	content.add_child(grid)
	for path in range(TITLES.size()):
		_add_card(grid, path)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	var hint: Label = _appearance._label(footer, "Esc · Возврат на базу", 16, _appearance.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_close = _appearance._button(footer, "Закрыть")
	_close.custom_minimum_size = Vector2(175, 44)
	_close.pressed.connect(func() -> void: _game.set_tuning(false))
	hide()

func _add_card(grid: GridContainer, path: int) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 509
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(&"panel", _appearance._style(Color("#1b2d42"), Color("#415b73"), 1, 0, 12))
	grid.add_child(card)
	_cards.append(card)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override(&"separation", 5)
	card.add_child(contents)
	var top := HBoxContainer.new()
	contents.add_child(top)
	var title: Label = _appearance._label(top, "", 21, _appearance.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_titles.append(title)
	_ranks.append(_appearance._label(top, "", 16, _appearance.ACTIVE))
	_card_notes.append(_appearance._label(contents, "", 14, _appearance.MUTED))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 8)
	contents.add_child(bottom)
	var info: Label = _appearance._label(bottom, "", 17, _appearance.INK)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_values.append(info)
	var button: Button = _appearance._button(bottom, "")
	button.custom_minimum_size = Vector2(134, 41)
	button.add_theme_font_size_override(&"font_size", 17)
	button.pressed.connect(_buy_upgrade.bind(path))
	_buy.append(button)

func show_menu() -> void:
	var rifle: bool = _game.rifle_tuning_open
	_heading.text = "ТЮНИНГ АВТОМАТА" if rifle else "ТЮНИНГ ТУРЕЛЕЙ"
	var titles: Array = RIFLE_TITLES if rifle else TITLES
	var notes: Array = RIFLE_NOTES if rifle else PATH_NOTES
	for path in range(_cards.size()):
		_cards[path].visible = path < titles.size()
		if path < titles.size():
			_card_titles[path].text = titles[path]
			_card_notes[path].text = notes[path]
	show()
	refresh()
	_close.grab_focus()

func _target() -> Variant:
	return _game.player.rifle_tuning if _game.rifle_tuning_open else _game.turret_tuning

func _buy_upgrade(path: int) -> void:
	_game.purchase_tuning(_target(), path)
	refresh()

func refresh() -> void:
	var rifle: bool = _game.rifle_tuning_open
	var target: Variant = _target()
	_funds.text = "%d БОЕВЫХ ОЧКОВ" % _game.combat_points
	if rifle:
		_status.text = "АВТОМАТ АСТЕР   ·   Магазин  %d/%d   ·   Резерв  %d" % [_game.player.magazine, _game.balance.rifle_magazine, _game.player.reserve]
	else:
		_status.text = "Каждая покупка улучшает все %d турели" % _game.turrets.size()
	var count := RIFLE_TITLES.size() if rifle else TITLES.size()
	var cap := AsterRifleTuning.MAX_LEVEL if rifle else AsterTurretTuning.MAX_LEVEL
	for path in range(count):
		var level: int = target.upgrade_level(path)
		var price: int = target.upgrade_price(path)
		_ranks[path].text = "УР. %d/%d" % [level, cap]
		_values[path].text = _describe_rifle(target, path, level) if rifle else _describe(target, path, level)
		var button := _buy[path]
		button.text = "%d очк." % price if price > 0 else "МАКС."
		button.disabled = price == 0 or price > _game.combat_points

func _describe_rifle(rifle: AsterRifleTuning, path: int, level: int) -> String:
	var current := rifle.stat(path, level)
	var next := rifle.stat(path, level + 1)
	var maxed := level == AsterRifleTuning.MAX_LEVEL
	match path:
		AsterRifleTuning.Path.RATE:
			return "%.1f выстр./с" % current if maxed else "%.1f → %.1f выстр./с" % [current, next]
		AsterRifleTuning.Path.DAMAGE:
			return "%.1f за выстрел" % current if maxed else "%.1f → %.1f за выстрел" % [current, next]
		_:
			return "%d%%" % -roundi(current * 100.0) if maxed else "%d%% → %d%%" % [-roundi(current * 100.0), -roundi(next * 100.0)]

func _describe(tuning: AsterTurretTuning, path: int, level: int) -> String:
	var current := tuning.stat(path, level)
	var next := tuning.stat(path, level + 1)
	var maxed := level == AsterTurretTuning.MAX_LEVEL
	match path:
		AsterTurretTuning.Path.RATE:
			return "%.1f выстр./с" % current if maxed else "%.1f → %.1f выстр./с" % [current, next]
		AsterTurretTuning.Path.DAMAGE:
			return "%.1f за выстрел" % current if maxed else "%.1f → %.1f за выстрел" % [current, next]
		AsterTurretTuning.Path.RANGE:
			return "%.1f м" % current if maxed else "%.1f → %.1f м" % [current, next]
		AsterTurretTuning.Path.CAPACITY:
			return "%d патр." % roundi(current) if maxed else "%d → %d патр." % [roundi(current), roundi(next)]
		AsterTurretTuning.Path.DRONE:
			var rate_now := tuning.drone_speed(level)
			var rate_next := tuning.drone_speed(level + 1)
			if level == 0:
				return "Установить · %d патр. за рейс · %.1f м/с" % [roundi(next), rate_next]
			if maxed:
				return "%d патр. за рейс · %.1f м/с" % [roundi(current), rate_now]
			return "%d → %d патр. за рейс · %.1f → %.1f м/с" % [roundi(current), roundi(next), rate_now, rate_next]
		AsterTurretTuning.Path.STABILITY:
			return "%d%% отдачи и разброса" % -roundi(current * 100.0) if maxed else "%d%% → %d%%" % [-roundi(current * 100.0), -roundi(next * 100.0)]
	return ""
