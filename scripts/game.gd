extends AsterOutpost

const SPAWN := Vector3(0, 0.09, 7.9)

var player := AsterPlayer.new()
var assault := AsterAssault.new()
var sound := AsterSound.new()
var effects := AsterEffects.new()
var bug_fx := AsterBugFX.new()
var ballistics := AsterBallistics.new()
var dust := AsterBattleDust.new()
var hud: AsterHUD
var points: int
var combat_points := 0
var kills := 0
var tuning_open := false
var rifle_tuning_open := false
var respawn_left := 0.0
var lost := false
var paused := false
var loss_reason := ""
var message := ""
var message_left := 0.0
var automated := false

func _ready() -> void:
	automated = OS.get_cmdline_user_args().has("--automated")
	points = balance.respawn_points
	_configure_input()
	_build_map()
	core.destroyed.connect(_structure_destroyed)
	for wall in walls:
		wall.destroyed.connect(_structure_destroyed)
	add_child(sound)
	add_child(effects)
	add_child(bug_fx)
	add_child(ballistics)
	ballistics.setup(self)
	add_child(dust)
	add_child(assault)
	assault.setup(self)
	add_child(player)
	player.setup(self, SPAWN)
	player.sensitivity = AsterSettings.sensitivity
	assault.bug_defeated.connect(_award_combat_points)
	var interface := CanvasLayer.new()
	add_child(interface)
	hud = AsterHUD.new()
	hud.game = self
	interface.add_child(hud)
	if not automated and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_window().focus_exited.connect(_window_blurred)

func _configure_input() -> void:
	var bindings := {
		&"forward": KEY_W, &"left": KEY_A, &"back": KEY_S, &"right": KEY_D,
		&"jump": KEY_SPACE, &"crouch": KEY_CTRL, &"sprint": KEY_SHIFT, &"reload": KEY_R, &"rifle": KEY_1, &"repair": KEY_2, &"interact": KEY_E,
	}
	for action: StringName in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)
	var mouse_bindings := {&"fire": MOUSE_BUTTON_LEFT, &"aim": MOUSE_BUTTON_RIGHT}
	for action: StringName in mouse_bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var click := InputEventMouseButton.new()
			click.button_index = mouse_bindings[action]
			InputMap.action_add_event(action, click)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.alive and not lost and not tuning_open:
		player.look(event.relative)

func _physics_process(delta: float) -> void:
	if lost:
		return
	message_left = maxf(0.0, message_left - delta)
	for wall in walls:
		wall.tick(delta)
	core.tick(delta)
	ballistics.tick(delta)
	dust.march(delta, assault.enemies, player.eye.global_position)
	for turret in turrets:
		turret.tick(delta, assault.enemies)
	if not player.alive and respawn_left > 0.0:
		respawn_left = maxf(0.0, respawn_left - delta)
		if respawn_left == 0.0 and not lost:
			points -= 1
			player.respawn(SPAWN)
			notify("Связь восстановлена")

func _award_combat_points(point: Vector3) -> void:
	kills += 1
	var bonus := 10 if kills % 10 == 0 else 0
	combat_points += balance.combat_points_per_kill + bonus
	if bonus > 0:
		notify("Уничтожено: %d  ·  +%d бонусных очков" % [kills, bonus])
	dust.defeated(point)

func set_tuning(opening: bool, rifle := false) -> void:
	if opening == tuning_open or lost or paused:
		return
	var terminal := rifle_terminal if rifle else tuning_terminal
	if opening and (not player.alive or not player.interaction.can_reach(terminal)):
		return
	tuning_open = opening
	rifle_tuning_open = opening and rifle
	player.clear_aim()
	player.interaction.cancel()
	get_tree().paused = opening
	if not automated:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opening else Input.MOUSE_MODE_CAPTURED
	hud.show_tuning(opening)

func purchase_tuning(target: Variant, path: int) -> bool:
	if not tuning_open or lost or not player.alive:
		return false
	var selected: Variant = player.rifle_tuning if rifle_tuning_open else turret_tuning
	if target != selected:
		return false
	var price: int = target.upgrade_price(path)
	if price <= 0 or price > combat_points or not target.apply_upgrade(path):
		return false
	combat_points -= price
	sound.play(&"lock")
	return true

func notify(text: String) -> void:
	message = text
	message_left = 3.8

func repair_beam(from: Vector3, target: Vector3) -> void:
	effects.repair_beam(from, target)
	sound.play(&"repair")

func fire_round(origin: Vector3, direction: Vector3, distance: float, damage: float, heavy: bool, port: Vector3, ejection: Vector3) -> void:
	ballistics.fire(origin, direction, distance, damage, heavy, port, ejection)
	if heavy:
		effects.flash(origin, direction)
	sound.fire_at(heavy, origin)

func projectile_impact(point: Vector3, normal: Vector3) -> void:
	effects.impact(point, normal)
	dust.impact(point)

func _structure_destroyed(structure: AsterStructure) -> void:
	if structure.is_core:
		defeat("Ворота бункера уничтожены")
	elif structure == gate:
		notify("Ворота периметра разрушены")
	else:
		notify("Пробит периметр · " + structure.title)

func player_died() -> void:
	if points <= 0:
		defeat("Очки возрождения исчерпаны")
	else:
		respawn_left = balance.respawn_delay
		sound.play(&"hit")

func defeat(reason: String) -> void:
	if lost:
		return
	lost = true
	loss_reason = reason
	respawn_left = 0.0
	player.interaction.cancel()
	player.clear_aim()
	if not automated:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_loss()

func set_paused(value: bool) -> void:
	if lost or tuning_open or paused == value:
		return
	paused = value
	player.interaction.cancel()
	if value:
		player.clear_aim()
	get_tree().paused = value
	if not value:
		AsterSettings.save()
	if not automated:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	hud.show_pause(value)

func _window_blurred() -> void:
	if not automated and not lost:
		set_paused(true)

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func return_to_main_menu() -> void:
	AsterSettings.save()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
