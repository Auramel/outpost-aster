extends AsterOutpost

const SPAWN := Vector3(0, 0.09, 7.9)
const ROCKET_LAUNCH_GAP := 0.27

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
var turret_tuning_tab := AsterTurretTuning.Type.THRESHER
var respawn_left := 0.0
var lost := false
var paused := false
var loss_reason := ""
var message := ""
var message_left := 0.0
var automated := false
var _rocket_launch_wait := 0.0

func _ready() -> void:
	automated = OS.get_cmdline_user_args().has("--automated")
	points = balance.respawn_points
	_configure_input()
	_build_map()
	core.destroyed.connect(func(_structure: AsterStructure) -> void: defeat("Ворота бункера уничтожены"))
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
	apply_view_distance()
	assault.bug_defeated.connect(_award_combat_points)
	var interface := CanvasLayer.new()
	add_child(interface)
	hud = AsterHUD.new()
	hud.game = self
	interface.add_child(hud)
	if not automated and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_window().focus_exited.connect(_window_blurred)

func apply_view_distance() -> void:
	player.eye.far = AsterSettings.view_distance
	daylight.set_view_distance(AsterSettings.view_distance)

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
	daylight.advance(delta)
	message_left = maxf(0.0, message_left - delta)
	for wall in walls:
		wall.tick(delta)
	core.tick(delta)
	_rocket_launch_wait = maxf(0.0, _rocket_launch_wait - delta)
	ballistics.tick(delta)
	dust.march(delta, assault.enemies, player.eye.global_position)
	for turret in turrets:
		turret.tick(delta, assault.enemies)
	for artillery in dreadnoughts:
		artillery.tick(delta, assault.enemies)
	if player.alive and player.hp < balance.player_hp and player.global_position.distance_squared_to(field_hospital.global_position + Vector3.BACK) < 9.0:
		player.hp = minf(balance.player_hp, player.hp + balance.hospital_heal_rate * delta)
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
	if opening and (not player.alive or not player.interaction.can_reach(tuning_terminal)):
		return
	tuning_open = opening
	rifle_tuning_open = opening and rifle
	if opening:
		turret_tuning_tab = AsterTurretTuning.Type.THRESHER
	player.clear_aim()
	get_tree().paused = opening
	if not automated:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opening else Input.MOUSE_MODE_CAPTURED
	hud.show_tuning(opening)

func purchase_tuning(target: Variant, path: int) -> bool:
	if not tuning_open or lost or not player.alive:
		return false
	var selected: Variant = player.rifle_tuning if rifle_tuning_open else turret_tunings[turret_tuning_tab]
	if target != selected:
		return false
	var price: int = target.upgrade_price(path)
	if price <= 0 or price > combat_points or not target.apply_upgrade(path):
		return false
	combat_points -= price
	sound.play(&"lock")
	return true

func purchase_support(index: int) -> bool:
	if not tuning_open or lost or not player.alive or index < 0 or index >= dreadnoughts.size() or combat_points < AsterDreadnought.PRICE:
		return false
	if not dreadnoughts[index].call_salvos(assault.enemies):
		return false
	combat_points -= AsterDreadnought.PRICE
	set_tuning(false)
	return true

func notify(text: String) -> void:
	message = text
	message_left = 3.8

func repair_beam(from: Vector3, target: Vector3) -> void:
	effects.repair_beam(from, target)
	sound.play(&"repair")

func fire_round(origin: Vector3, direction: Vector3, distance: float, damage: float, heavy: bool, port: Vector3, ejection: Vector3, type := AsterTurretTuning.Type.THRESHER) -> void:
	var gauss := type == AsterTurretTuning.Type.STINGER
	ballistics.fire(origin, direction, distance, damage, heavy, port, ejection, 0.0, gauss)
	if gauss:
		effects.gauss_flash(origin, direction)
		sound.gauss(origin)
		return
	var dragonfly := type == AsterTurretTuning.Type.DRAGONFLY
	if heavy:
		effects.flash(origin, direction, 0.70 if dragonfly else 1.0)
	sound.fire_at(heavy, origin, 1.29 if dragonfly else 1.0)

func fire_artillery(origin: Vector3, direction: Vector3, damage: float, radius: float, distance: float) -> void:
	ballistics.fire(origin, direction, distance, damage, true, Vector3.ZERO, Vector3.ZERO, radius)
	effects.artillery_flash(origin, direction)

func fire_rocket(origin: Vector3, target: Vector3, damage: float, radius: float) -> bool:
	if _rocket_launch_wait > 0.0:
		return false
	_rocket_launch_wait = ROCKET_LAUNCH_GAP
	var launch := ballistics.fire_rocket(origin, target, damage, radius)
	effects.rocket_flash(origin, launch.normalized())
	sound.artillery(origin, 1.38)
	return true

func artillery_impact(point: Vector3, normal: Vector3, damage: float, radius: float, rocket := false) -> void:
	if rocket:
		effects.rocket_impact(point, normal, radius)
		sound.artillery(point, 0.96)
	else:
		effects.artillery_impact(point, normal)
	dust.artillery(point)
	for bug: AsterBug in assault.enemies.duplicate():
		var distance := bug.hit_point().distance_to(point)
		if distance < radius and AsterArt.ray(get_world_3d(), point + normal * 0.08, bug.hit_point(), AsterArt.SOLID).is_empty():
			var outward := (bug.hit_point() - point).normalized()
			bug.damage(damage * lerpf(1.0, 0.36, distance / radius), bug.hit_point(), -outward)

func projectile_impact(point: Vector3, normal: Vector3) -> void:
	effects.impact(point, normal)
	dust.impact(point)

func nearest_building(point: Vector3, include_core := true) -> Node3D:
	var chosen: Node3D
	var nearest := INF
	for building: Node3D in [core] + walls + turrets:
		if (not include_core and building == core) or building.hp <= 0.0 or (building is AsterTurret and building.rebuilding):
			continue
		var distance := point.distance_squared_to(building.closest_point(point))
		if distance < nearest:
			nearest = distance
			chosen = building
	return chosen

func bug_blast(point: Vector3, amount: float, radius: float, hurts_bugs: bool) -> void:
	var player_distance := (player.global_position + Vector3.UP * 0.8).distance_to(point)
	if player.alive and player_distance < radius:
		player.damage(amount * lerpf(1.0, 0.42, player_distance / radius))
	for building: Node3D in [core] + walls + turrets:
		var distance := point.distance_to(building.closest_point(point))
		if building.hp > 0.0 and distance < radius:
			building.damage(amount * lerpf(1.0, 0.42, distance / radius))
	if hurts_bugs:
		for bug: AsterBug in assault.enemies.duplicate():
			var contact := bug.hit_point()
			var distance := point.distance_to(contact)
			if distance < radius:
				bug.damage(amount * lerpf(1.0, 0.42, distance / radius), contact, (contact - point).normalized())

func throw_rock(origin: Vector3, target: Vector3, source: AsterBug) -> void:
	var rock := AsterBugProjectile.new()
	add_child(rock)
	rock.launch_rock(self, source, origin, target)

func fire_quill(origin: Vector3, target: Vector3, source: AsterBug) -> void:
	var quill := AsterBugProjectile.new()
	add_child(quill)
	quill.launch_quill(self, source, origin, target)

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
	player.clear_aim()
	if not automated:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_loss()

func set_paused(value: bool) -> void:
	if lost or tuning_open or paused == value:
		return
	paused = value
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
