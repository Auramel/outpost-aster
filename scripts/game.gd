extends Node3D

const SPAWN := Vector3(0, 0.09, 7.9)
@export var balance: AsterBalance

var walls: Array[AsterStructure] = []
var turrets: Array[AsterTurret] = []
var turret_tuning: AsterTurretTuning
var core: AsterStructure
var gate: AsterStructure
var supply := Node3D.new()
var rifle_terminal := Node3D.new()
var tuning_terminal := Node3D.new()
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
	turret_tuning = AsterTurretTuning.new(balance)
	_configure_input()
	AsterTerrain.build(self)
	_build_base()
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

func _build_base() -> void:
	core = AsterStructure.new()
	core.position = Vector3(0, 0, -1.1)
	add_child(core)
	core.setup(balance, "Главное здание")
	core.destroyed.connect(_structure_destroyed)
	var section_count := roundi(AsterTerrain.FRONT_HALF_WIDTH * 2.0 / AsterStructure.WALL_LENGTH)
	for slot in range(section_count):
		var lateral := (slot + 0.5) * AsterStructure.WALL_LENGTH - AsterTerrain.FRONT_HALF_WIDTH
		var wall := AsterStructure.new()
		wall.position = Vector3(lateral, 0, AsterTerrain.FRONT_Z)
		add_child(wall)
		var is_gate := slot == 3
		var label := "Главные ворота" if is_gate else "Секция Ю-%02d" % (slot + 1)
		wall.setup(balance, label, Vector3.BACK, is_gate)
		wall.destroyed.connect(_structure_destroyed)
		walls.append(wall)
		if is_gate:
			gate = wall
		if slot in [1, 4]:
			_install_turret(wall.position + Vector3.UP * AsterStructure.WALL_HEIGHT, wall, true)
			AsterTerrain.service_platform(self, wall)
	for slot in [0, 5]:
		var flank := walls[slot]
		_install_turret(flank.position + Vector3.UP * AsterStructure.WALL_HEIGHT, flank)
	AsterTerrain.mark_gate(self, gate.global_position)
	_build_supply()
	_build_terminal(rifle_terminal, Vector3(3.35, 0, 4.55), "ТЮНИНГ АВТОМАТА", AsterArt.CYAN)
	_build_terminal(tuning_terminal, Vector3(-3.35, 0, 5.95), "ТЮНИНГ ТУРЕЛЕЙ", AsterArt.AMBER)
	for i in range(12):
		var marker := AsterArt.box(self, Vector3(0.16, 0.012, 0.48), Vector3(-3.6, 0.009, -4.6 + i * 0.93), AsterArt.PALE)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(5):
		AsterArt.box(self, Vector3(0.20, 0.012, 0.65), Vector3(2.93, 0.009, 2.3 + i), AsterArt.AMBER)

func _install_turret(position_in_yard: Vector3, wall: AsterStructure, direct_ramp := false) -> void:
	var turret := AsterTurret.new()
	turret.position = position_in_yard
	add_child(turret)
	turret.setup(self, "Т%d" % (turrets.size() + 1), wall, direct_ramp)
	turrets.append(turret)

func _build_supply() -> void:
	supply.name = "Supply"
	supply.position = Vector3(-8.65, 0, 2.70)
	add_child(supply)
	AsterArt.collider(supply, Vector3(2.45, 1.30, 1.48), Vector3(0, 0.65, 0), AsterArt.ACCESS | AsterArt.TARGET, supply)
	AsterModels.attach(supply, &"supply")
	AsterArt.lettering(supply, "СКЛАД  /  БОЕПРИПАСЫ", Vector3(0, 1.69, 0.287), 26, AsterArt.AMBER)

func _build_terminal(station: Node3D, position_in_yard: Vector3, label: String, glow: Color) -> void:
	station.position = position_in_yard
	add_child(station)
	AsterArt.collider(station, Vector3(1.32, 1.22, 0.79), Vector3(0, 0.61, 0), AsterArt.ACCESS | AsterArt.TARGET, station)
	AsterModels.attach(station, &"station")
	var screen := Node3D.new()
	station.add_child(screen)
	screen.position = Vector3(0, 1.05, 0)
	screen.rotation.x = -0.61
	for i in range(3):
		AsterArt.box(screen, Vector3(0.55 - i * 0.12, 0.012, 0.025), Vector3(-0.10, 0.119, -0.096 + i * 0.087), glow, true)
	AsterArt.lettering(station, label, Vector3(0, 1.63, 0), 30, glow, true)

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
		defeat("Главное здание уничтожено")
	elif structure == gate:
		notify("Главные ворота разрушены")
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
