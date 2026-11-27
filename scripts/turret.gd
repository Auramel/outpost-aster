class_name AsterTurret
extends Node3D

const MUZZLE := Vector3(0.410, 0.014, -1.617)
const CASE_PORT := Vector3(0.552, 0.077, -0.223)
const OPERATING_TAG_Y := 1.94
const LOW_AMMO_FRACTION := 0.18

var title: String
var hp: float
var max_hp: float
var rounds: int
var has_box := true
var rebuilding := false
var service: StringName = &""
var wall: AsterStructure
var direct_ramp := false
var facing := Vector3.BACK
var status_tag: AsterStatusTag
var target: Node3D
var shots_fired := 0
var drone: AsterAmmoDrone
var tuning: AsterTurretTuning
var _game: Node
var _balance: AsterBalance
var _head := Node3D.new()
var _elevation := Node3D.new()
var _carriage := Node3D.new()
var _kit := AsterTurretKit.new()
var _kick := 0.0
var _complete := Node3D.new()
var _wreck := Node3D.new()
var _indicator: MeshInstance3D
var _search := 0.0
var _shot_timer := 0.0
var _indicator_on := true

func setup(game: Node, name_on_base: String, base_wall: AsterStructure, via_ramp := false) -> void:
	_game = game
	_balance = game.balance
	tuning = game.turret_tuning
	title = name_on_base
	wall = base_wall
	direct_ramp = via_ramp
	if is_instance_valid(wall):
		wall.support = self
		facing = wall.outward
	max_hp = _balance.turret_hp
	hp = max_hp
	rounds = mini(_balance.turret_start_rounds, capacity())
	add_child(_complete)
	add_child(_wreck)
	_complete.add_child(_head)
	_head.position.y = 0.79
	_head.add_child(_elevation)
	_head.rotation.y = atan2(-facing.x, -facing.z)
	AsterModels.attach(self, &"turret_base")
	AsterModels.attach(_head, &"turret_head")
	_elevation.add_child(_carriage)
	AsterModels.attach(_carriage, &"turret_emitters")
	_kit.setup(_head, _carriage, _complete)
	AsterModels.attach(_wreck, &"turret_wreck")
	_indicator = AsterArt.box(_head, Vector3(0.132, 0.027, 0.014), Vector3(0.172, 0.179, 0.517), AsterArt.CYAN, true)
	if is_instance_valid(wall):
		wall.status_tag.position.x = -0.90
	status_tag = AsterStatusTag.new()
	status_tag.position.y = OPERATING_TAG_Y
	add_child(status_tag)
	status_tag.setup(title, true)
	_refresh_tag()
	tuning.upgraded.connect(_on_upgrade)
	for path in range(AsterTurretTuning.BASE_PRICES.size()):
		var level := tuning.upgrade_level(path)
		if level > 0:
			_on_upgrade(path, level)
	AsterArt.collider(self, Vector3(1.74, 1.55, 1.61), Vector3(0, 0.73, 0), AsterArt.TARGET, self, true)
	_wreck.hide()

func _on_upgrade(path: int, level: int) -> void:
	_kit.update_rank(path, level, AsterTurretTuning.MAX_LEVEL)
	if path == AsterTurretTuning.Path.DRONE and drone == null:
		drone = AsterAmmoDrone.new()
		add_child(drone)
		drone.setup(self, _game.supply)
		drone.visible = not rebuilding
	_refresh_tag()

func capacity() -> int:
	return roundi(tuning.stat(AsterTurretTuning.Path.CAPACITY))

func needs_drone_ammo() -> bool:
	var load := roundi(tuning.stat(AsterTurretTuning.Path.DRONE))
	if load <= 0 or rebuilding or service != &"":
		return false
	var limit := capacity()
	return not has_box or limit - rounds >= load or rounds <= limit * LOW_AMMO_FRACTION

func receive_drone_ammo(amount: int) -> int:
	if rebuilding or service != &"" or amount <= 0:
		return 0
	var delivered := mini(amount, capacity() - rounds)
	if delivered > 0:
		has_box = true
		rounds += delivered
		_game.sound.play_service(&"turret_seat", service_position())
	return delivered

func attack_position() -> Vector3:
	return global_position + Vector3.UP * 0.58

func service_position() -> Vector3:
	return global_position - facing * 0.75 + Vector3.UP * 0.77

func ready_to_fire() -> bool:
	return not rebuilding and has_box and rounds > 0 and service == &""

func status() -> String:
	if rebuilding:
		return "ВОССТАНОВЛЕНИЕ" if hp > 0.0 else "УНИЧТОЖЕНА"
	if service != &"":
		return "ЗАМЕНА"
	if not has_box:
		return "НЕТ ЯЩИКА"
	if rounds == 0:
		return "БОЕЗАПАС ИСЧЕРПАН"
	return "РАБОТАЕТ"

func _mount_ready() -> bool:
	return not is_instance_valid(wall) or (wall.hp >= wall.max_hp and wall.blocking)

func repair_hint() -> String:
	if rebuilding and not _mount_ready():
		return "Сначала полностью восстановите опорную стену"
	if hp < max_hp:
		return "2 · Ремкомплект   ЛКМ · Ремонт"
	return "Прочность полная"

func damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		destroy()

func destroy() -> void:
	var alert := not rebuilding or hp > 0.0
	hp = 0.0
	rebuilding = true
	has_box = false
	rounds = 0
	service = &""
	target = null
	_complete.hide()
	_wreck.show()
	if alert:
		_game.notify(title + " уничтожена")

func repair(amount: float) -> bool:
	if hp >= max_hp or (rebuilding and not _mount_ready()):
		return false
	hp = minf(max_hp, hp + amount)
	if rebuilding and hp >= max_hp:
		rebuilding = false
		_wreck.hide()
		_complete.show()
	return true

func try_service(carrying: bool) -> StringName:
	if rebuilding or service != &"":
		return &""
	if has_box:
		service = &"remove"
		_game.sound.play_service(&"turret_unlatch", service_position())
	elif carrying:
		service = &"insert"
		_game.sound.play_service(&"turret_insert", service_position())
	return service

func cancel_service() -> void:
	service = &""

func finish_service(stage: StringName, carrying: bool) -> bool:
	if stage == &"" or service != stage or rebuilding:
		return false
	service = &""
	if stage == &"remove" and has_box:
		has_box = false
		rounds = 0
		_game.sound.play_service(&"turret_remove", service_position())
		return true
	if stage == &"insert" and not has_box and carrying:
		has_box = true
		rounds = capacity()
		_game.sound.play_service(&"turret_seat", service_position())
		return true
	return false

func _refresh_tag() -> void:
	_kit.set_loaded(has_box)
	var warning := ""
	if not ready_to_fire():
		warning = "БЕЗ ПАТРОНОВ" if has_box and rounds == 0 and service == &"" else status()
	elif rounds <= capacity() * LOW_AMMO_FRACTION:
		warning = "МАЛО ПАТРОНОВ"
	status_tag.position.y = 0.98 if rebuilding else OPERATING_TAG_Y
	status_tag.set_values(hp / max_hp, float(rounds) / capacity(), warning)

func tick(delta: float, enemies: Array) -> void:
	_shot_timer = maxf(-delta, _shot_timer - delta)
	_kick = maxf(0.0, _kick - delta * 2.6)
	_carriage.position.z = _kick
	_carriage.rotation.x = _kick * 0.56
	if is_instance_valid(drone):
		drone.tick(delta)
	_refresh_tag()
	var active := ready_to_fire()
	if _indicator_on != active:
		_indicator_on = active
		_indicator.material_override = AsterArt.material(AsterArt.CYAN if active else AsterArt.RED, true)
	if not active:
		return
	_search -= delta
	var pivot := _head.global_position
	if _search <= 0.0:
		_search = 0.15
		target = _find_enemy(enemies, pivot)
	if not is_instance_valid(target) or target.hp <= 0.0:
		return
	var current_hit: Vector3 = target.hit_point()
	var detection := tuning.stat(AsterTurretTuning.Path.RANGE)
	if pivot.distance_squared_to(current_hit) > detection * detection:
		target = null
		_search = 0.0
		return
	var flight_time := maxf(0.0, pivot.distance_to(current_hit) + MUZZLE.z) / AsterBallistics.TURRET_SPEED
	var intercept: Vector3 = current_hit + target.velocity * flight_time
	var direction := (intercept - pivot).normalized()
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := asin(direction.y)
	_head.rotation.y = rotate_toward(_head.rotation.y, yaw, _balance.turret_turn_speed * delta)
	_elevation.rotation.x = move_toward(_elevation.rotation.x, pitch, _balance.turret_turn_speed * delta)
	if _shot_timer > 0.0 or absf(angle_difference(_head.rotation.y, yaw)) > 0.16 or absf(_elevation.rotation.x - pitch) > 0.16:
		return
	var side := 1.0 if shots_fired % 2 == 0 else -1.0
	var tip := _carriage.to_global(Vector3(side * MUZZLE.x, MUZZLE.y, MUZZLE.z))
	var hit := intercept
	if not AsterArt.ray(get_world_3d(), pivot, current_hit, AsterArt.SOLID).is_empty() or not AsterArt.ray(get_world_3d(), tip, hit, AsterArt.SOLID).is_empty():
		return
	var steadiness := 1.0 - tuning.stat(AsterTurretTuning.Path.STABILITY)
	var spread := 0.008 * steadiness
	var aim := (hit - tip).normalized()
	aim = (aim + _head.global_basis.x * randf_range(-spread, spread) + Vector3.UP * randf_range(-spread, spread)).normalized()
	var port := _carriage.to_global(Vector3(side * CASE_PORT.x, CASE_PORT.y, CASE_PORT.z))
	_shot_timer += 1.0 / tuning.stat(AsterTurretTuning.Path.RATE)
	rounds -= 1
	shots_fired += 1
	_kick = minf(_kick + 0.13 * steadiness, 0.21)
	_carriage.position.z = _kick
	_carriage.rotation.x = _kick * 0.56
	_game.fire_round(tip, aim, detection + 3.0, tuning.stat(AsterTurretTuning.Path.DAMAGE), true, port, _carriage.global_basis.x * side)

func _find_enemy(enemies: Array, pivot: Vector3) -> Node3D:
	var selected: Node3D
	var detection := tuning.stat(AsterTurretTuning.Path.RANGE)
	var limit := detection * detection
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0.0:
			continue
		var point: Vector3 = enemy.hit_point()
		var distance := pivot.distance_squared_to(point)
		if distance < limit and AsterArt.ray(get_world_3d(), pivot, point, AsterArt.SOLID).is_empty():
			selected = enemy
			limit = distance
	return selected
