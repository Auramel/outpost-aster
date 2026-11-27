class_name AsterTurret
extends Node3D

const MUZZLE := Vector3(0.410, 0.014, -1.617)
const CASE_PORT := Vector3(0.552, 0.077, -0.223)
const LOW_AMMO_FRACTION := 0.18
const STINGER_MUZZLE := Vector3(0, 0.015, -2.61)
const DRAGONFLY_MUZZLE := Vector3(0.72, 0.12, -1.67)
const BULBA_MUZZLE := Vector3(0.61, 0.37, -0.79)
const BULBA_RADIUS := 4.2
const BULBA_SALVO_SIZE := 3
const Type = AsterTurretTuning.Type
const Path = AsterTurretTuning.Path
const MODEL_PARTS := [
	[&"turret_base", &"turret_head", &"turret_emitters"],
	[&"stinger_base", &"stinger_head", &"stinger_barrel"],
	[&"dragonfly_base", &"dragonfly_head", &"dragonfly_guns"],
	[&"bulba_base", &"bulba_head", &"bulba_pods"],
]

var title: String
var hp: float
var max_hp: float
var rounds: int
var has_box := true
var rebuilding := false
var wall: AsterStructure
var direct_ramp := false
var facing := Vector3.BACK
var target: Node3D
var shots_fired := 0
var drone: AsterAmmoDrone
var tuning: AsterTurretTuning
var _game: Node
var _balance: AsterBalance
var _head := Node3D.new()
var _elevation := Node3D.new()
var _carriage := Node3D.new()
var _kit: AsterTurretKit
var _cartridge: MeshInstance3D
var _base_model: MeshInstance3D
var _kick := 0.0
var _complete := Node3D.new()
var _wreck := Node3D.new()
var _damage_light: MeshInstance3D
var _damage_heavy: MeshInstance3D
var _search := 0.0
var _shot_timer := 0.0
var _salvo_left := 0
var _salvo_aim := Vector3.ZERO

func setup(game: Node, name_on_base: String, base_wall: AsterStructure, via_ramp: bool, upgrades: AsterTurretTuning) -> void:
	_game = game
	_balance = game.balance
	tuning = upgrades
	title = name_on_base
	wall = base_wall
	direct_ramp = via_ramp
	if is_instance_valid(wall):
		wall.support = self
		facing = wall.outward
	max_hp = _balance.turret_hp if tuning.type == Type.THRESHER else [0, 270, 225, 290][tuning.type]
	hp = max_hp
	rounds = mini(_balance.turret_start_rounds, capacity()) if tuning.type == Type.THRESHER else capacity()
	add_child(_complete)
	add_child(_wreck)
	_complete.add_child(_head)
	_head.position.y = [0.79, 0.97, 1.04, 0.97][tuning.type]
	_head.add_child(_elevation)
	if tuning.type == Type.BULBA:
		_elevation.rotation.x = deg_to_rad(56.0)
	elif tuning.type == Type.DRAGONFLY:
		_elevation.rotation.x = deg_to_rad(15.0)
	_head.rotation.y = atan2(-facing.x, -facing.z)
	var parts: Array = MODEL_PARTS[tuning.type]
	_base_model = AsterModels.attach(self, parts[0])
	AsterModels.attach(_head, parts[1])
	_elevation.add_child(_carriage)
	AsterModels.attach(_carriage, parts[2])
	if tuning.type == Type.THRESHER:
		_kit = AsterTurretKit.new()
		_kit.setup(_head, _carriage, _complete)
		_kit.update_rank(Path.DRONE, 0, AsterTurretTuning.MAX_LEVEL)
		_damage_light = AsterModels.attach(_head, &"turret_damage_light")
		_damage_heavy = AsterModels.attach(_head, &"turret_damage_heavy")
		AsterTerrain.floodlight(_elevation, Vector3(0, 0.17, -0.71), Vector3(0, 0.0, -8), 2.15, 10.5, 23.0, 0.30)
		tuning.upgraded.connect(_on_upgrade)
		for path in range(tuning.path_count()):
			var level := tuning.upgrade_level(path)
			if level > 0:
				_on_upgrade(path, level)
		AsterArt.collider(self, Vector3(1.74, 1.55, 1.61), Vector3(0, 0.73, 0), AsterArt.TARGET, self, true)
	else:
		_cartridge = AsterModels.attach(_head, &"turret_cartridge", Vector3(0, -0.18, 0.62), Vector3(0.84, 0.84, 0.84))
		AsterArt.collider(self, Vector3(1.86, 1.71, 1.72), Vector3(0, 0.85, 0), AsterArt.TARGET, self, true)
		if not is_instance_valid(wall) and position.y < 1.0:
			AsterArt.collider(self, Vector3(1.74, 0.50, 1.62), Vector3(0, 0.25, 0), AsterArt.SOLID, self)
	AsterModels.attach(_wreck, &"turret_wreck")
	_wreck.hide()
	_refresh_visual()

func setup_drone(supply: Node3D, index: int) -> void:
	drone = AsterAmmoDrone.new()
	add_child(drone)
	drone.setup(self, supply, index)

func _on_upgrade(path: int, level: int) -> void:
	_kit.update_rank(path, level, AsterTurretTuning.MAX_LEVEL)
	_refresh_visual()

func capacity() -> int:
	return roundi(tuning.stat(AsterTurretTuning.Path.CAPACITY))

func needs_drone_ammo() -> bool:
	var load := roundi(tuning.stat(AsterTurretTuning.Path.DRONE))
	if rebuilding:
		return false
	var limit := capacity()
	return not has_box or limit - rounds >= load or rounds <= limit * LOW_AMMO_FRACTION

func receive_drone_ammo(amount: int) -> int:
	if rebuilding or amount <= 0:
		return 0
	var delivered := clampi(capacity() - rounds, 0, amount)
	if delivered > 0:
		has_box = true
		rounds += delivered
		_game.sound.play_service(&"turret_seat", service_position())
	return delivered

func attack_position() -> Vector3:
	return global_position + Vector3.UP * 0.58

func closest_point(point: Vector3) -> Vector3:
	var local := to_local(point)
	return to_global(Vector3(clampf(local.x, -0.87, 0.87), clampf(local.y, 0.0, 1.50), clampf(local.z, -0.80, 0.80)))

func service_position() -> Vector3:
	return global_position - facing * 0.75 + Vector3.UP * 0.77

func ready_to_fire() -> bool:
	return not rebuilding and has_box and rounds > 0

func _mount_ready() -> bool:
	return not is_instance_valid(wall) or (wall.hp >= wall.max_hp and wall.blocking)

func damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		destroy()

func destroy() -> void:
	hp = 0.0
	rebuilding = true
	has_box = false
	rounds = 0
	target = null
	_salvo_left = 0
	_complete.hide()
	if tuning.type != Type.THRESHER:
		_base_model.hide()
	_wreck.show()

func repair(amount: float) -> bool:
	if hp >= max_hp or (rebuilding and not _mount_ready()):
		return false
	hp = minf(max_hp, hp + amount)
	if rebuilding and hp >= max_hp:
		rebuilding = false
		_wreck.hide()
		_complete.show()
		_base_model.show()
	return true

func _refresh_visual() -> void:
	if _kit != null:
		_kit.set_loaded(has_box, float(rounds) / capacity())
		_damage_light.visible = hp < max_hp * 0.83
		_damage_heavy.visible = hp < max_hp * 0.46
	else:
		_cartridge.visible = has_box

func tick(delta: float, enemies: Array) -> void:
	_shot_timer = maxf(-delta, _shot_timer - delta)
	_kick = maxf(0.0, _kick - delta * 2.6)
	_carriage.position.z = _kick
	_carriage.rotation.x = _kick * 0.56
	if is_instance_valid(drone):
		drone.tick(delta)
	_refresh_visual()
	if not ready_to_fire():
		_salvo_left = 0
		return
	if _salvo_left > 0:
		_launch_bulba()
		return
	_search -= delta
	var pivot := _head.global_position
	if _search <= 0.0:
		_search = 0.15
		target = _find_enemy(enemies, pivot)
	if not is_instance_valid(target) or target.hp <= 0.0:
		return
	var current_hit: Vector3 = target.hit_point()
	var indirect := tuning.type == Type.BULBA
	var detection := tuning.stat(AsterTurretTuning.Path.RANGE)
	if pivot.distance_squared_to(current_hit) > detection * detection:
		target = null
		_search = 0.0
		return
	var side := 1.0 if shots_fired % 2 == 0 else -1.0
	var muzzle := _muzzle(side)
	var speed := AsterBallistics.GAUSS_SPEED if tuning.type == Type.STINGER else AsterBallistics.TURRET_SPEED
	var flight_time := AsterBallistics.rocket_duration(pivot, current_hit) * 0.75 if indirect else maxf(0.0, pivot.distance_to(current_hit) + muzzle.z) / speed
	var intercept: Vector3 = current_hit + target.velocity * flight_time
	if indirect:
		intercept.z = maxf(intercept.z, AsterTerrain.FRONT_APPROACH_Z)
		intercept.y = AsterTerrain.surface_height(intercept.x, intercept.z) + 0.20
	var direction := (AsterBallistics.rocket_velocity(pivot, intercept) if indirect else intercept - pivot).normalized()
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := asin(direction.y)
	var turn_speed: float = _balance.turret_turn_speed * [1.0, 0.50, 1.47, 0.68][tuning.type]
	var tolerance := 0.055 if tuning.type == Type.STINGER else 0.16
	_head.rotation.y = rotate_toward(_head.rotation.y, yaw, turn_speed * delta)
	_elevation.rotation.x = move_toward(_elevation.rotation.x, pitch, turn_speed * delta)
	if _shot_timer > 0.0 or absf(angle_difference(_head.rotation.y, yaw)) > tolerance or absf(_elevation.rotation.x - pitch) > tolerance:
		return
	if indirect:
		_salvo_left = mini(BULBA_SALVO_SIZE, rounds)
		_salvo_aim = intercept
		if not _launch_bulba():
			_salvo_left = 0
		return
	var tip := _carriage.to_global(muzzle)
	if not AsterArt.ray(get_world_3d(), pivot, current_hit, AsterArt.SOLID).is_empty() or not AsterArt.ray(get_world_3d(), tip, intercept, AsterArt.SOLID).is_empty():
		return
	var steadiness := 1.0 - tuning.stat(Path.STABILITY)
	var spread: float = [0.008, 0.004, 0.013][tuning.type] * steadiness
	var aim := (intercept - tip).normalized()
	aim = (aim + _head.global_basis.x * randf_range(-spread, spread) + Vector3.UP * randf_range(-spread, spread)).normalized()
	var port := Vector3(side * CASE_PORT.x, CASE_PORT.y, CASE_PORT.z)
	if tuning.type == Type.DRAGONFLY:
		port = Vector3(side * 0.98, 0.22, -0.03)
	_shot_timer += 1.0 / tuning.stat(Path.RATE)
	_record_shot(steadiness, 0.058 if tuning.type == Type.STINGER else 0.13)
	_game.fire_round(tip, aim, detection + 3.0, tuning.stat(Path.DAMAGE), true, _carriage.to_global(port), _carriage.global_basis.x * side, tuning.type)

func _launch_bulba() -> bool:
	var side := 1.0 if shots_fired % 2 == 0 else -1.0
	var tip := _carriage.to_global(_muzzle(side))
	var steadiness := 1.0 - tuning.stat(Path.STABILITY)
	var dispersion := 1.4 * steadiness
	var aim := _salvo_aim + Vector3(randf_range(-dispersion, dispersion), 0, randf_range(0.0, dispersion))
	aim.y = AsterTerrain.surface_height(aim.x, aim.z) + 0.20
	if not _game.fire_rocket(tip, aim, tuning.stat(Path.DAMAGE), BULBA_RADIUS):
		return false
	if _shot_timer <= 0.0:
		_shot_timer = float(_salvo_left) / tuning.stat(Path.RATE)
	_salvo_left -= 1
	_record_shot(steadiness, 0.13)
	return true

func _record_shot(steadiness: float, recoil: float) -> void:
	rounds -= 1
	shots_fired += 1
	_kick = minf(_kick + recoil * steadiness, 0.21)
	_carriage.position.z = _kick
	_carriage.rotation.x = _kick * 0.56

func _muzzle(side: float) -> Vector3:
	match tuning.type:
		Type.STINGER:
			return STINGER_MUZZLE
		Type.DRAGONFLY:
			var row := (shots_fired / 2) % 3
			return Vector3(side * DRAGONFLY_MUZZLE.x, DRAGONFLY_MUZZLE.y + 0.16 * float(row), DRAGONFLY_MUZZLE.z + 0.06 * float(row))
		Type.BULBA:
			var cell := (shots_fired / 2) % 6
			return Vector3(side * BULBA_MUZZLE.x + (0.12 if cell % 2 == 0 else -0.12), BULBA_MUZZLE.y - 0.24 * float(cell / 2), BULBA_MUZZLE.z)
	return Vector3(side * MUZZLE.x, MUZZLE.y, MUZZLE.z)

func _find_enemy(enemies: Array, pivot: Vector3) -> AsterBug:
	var selected: AsterBug
	var detection := tuning.stat(Path.RANGE)
	var limit := detection * detection
	var best_distance := limit
	var best_hp := -INF
	var best_group := -1
	for enemy: AsterBug in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		var flying := enemy is AsterFlyingBug
		if (tuning.type == Type.DRAGONFLY and not flying) or (tuning.type == Type.BULBA and flying):
			continue
		var point := enemy.hit_point()
		var distance := pivot.distance_squared_to(point)
		if distance >= limit:
			continue
		if tuning.type == Type.BULBA:
			if point.z < AsterTerrain.FRONT_APPROACH_Z or enemy.state == &"incoming":
				continue
			var group := 0
			for neighbor: AsterBug in enemies:
				if is_instance_valid(neighbor) and neighbor.hp > 0.0 and not neighbor is AsterFlyingBug and neighbor.global_position.distance_squared_to(enemy.global_position) < BULBA_RADIUS * BULBA_RADIUS:
					group += 1
			if group < best_group or (group == best_group and distance >= best_distance):
				continue
			best_group = group
		else:
			if tuning.type == Type.STINGER:
				if enemy.max_hp < best_hp or (enemy.max_hp == best_hp and distance >= best_distance):
					continue
			elif distance >= best_distance:
				continue
			if not AsterArt.ray(get_world_3d(), pivot, point, AsterArt.SOLID).is_empty():
				continue
		selected = enemy
		best_distance = distance
		best_hp = enemy.max_hp
	return selected
