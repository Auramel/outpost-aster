class_name AsterFlyingBug
extends AsterBug

const FLIGHT_HEIGHT := 4.8
const DIVE_RANGE := 6.0
const DIVE_REACH := 1.42
const DIVE_TIME := 2.2
const RECOVERY_TIME := 1.2
const COVER := AsterArt.SOLID | AsterArt.ACCESS

var _wings: Array[Node3D] = []
var _flight_left := 0.0
var _recovery_point := Vector3.ZERO
var _turn_side := 1.0
var _victim: Node3D
var _nest_top := Vector3.ZERO
var _launch_wait := 0.0

func setup(game: Node, enemy_kind: Kind, formation_offset: Vector2) -> void:
	super.setup(game, enemy_kind, formation_offset)
	max_hp = _balance.flyer_hp
	hp = max_hp
	_power = _balance.flyer_damage
	_speed = _balance.flyer_speed
	_fall_time = 1.65
	_turn_side = -1.0 if get_instance_id() % 2 == 0 else 1.0
	motion_mode = MOTION_MODE_FLOATING
	collision_mask = COVER
	state = &"cruise"

func _build_hitbox() -> void:
	var hitbox := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.45
	hitbox.shape = capsule
	hitbox.position = Vector3(0, 0.64, -0.08)
	hitbox.rotation.x = PI * 0.5
	add_child(hitbox)

func _build_shell() -> void:
	_shell = AsterModels.attach(_look, &"flyer")
	_tail.position = Vector3(0, 0.63, 0.52)
	_look.add_child(_tail)
	AsterModels.attach(_tail, &"flyer_tail", Vector3.ZERO, Vector3.ONE, false)
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.22, 0.80, -0.06)
		_look.add_child(wing)
		_wings.append(wing)
		AsterModels.attach(wing, &"flyer_wing", Vector3.ZERO, Vector3(side, 1.0, 1.0), false)

func launch_from_nest() -> void:
	state = &"launch"
	_nest_top = global_position + Vector3.UP * 4.1 + Vector3.FORWARD * 2.45
	_launch_wait = randf_range(0.18, 0.52)

func _move(delta: float) -> void:
	if state == &"launch":
		_launch(delta)
		return
	var victim := _choose_victim()
	if not is_instance_valid(victim):
		return
	if victim != _victim:
		_victim = victim
		state = &"cruise"
	_flight_left = maxf(0.0, _flight_left - delta)
	var point := _aim_position(victim)
	match state:
		&"dive":
			_dive(victim, point, delta)
		&"recover":
			_cruise(_recovery_point, delta)
			if _flight_left <= 0.0:
				state = &"cruise"
		_:
			var offset := point - hit_point()
			if AsterArt.horizontal(offset).length_squared() <= DIVE_RANGE * DIVE_RANGE and absf(offset.y) < 7.0 and _clear_to(point, victim):
				state = &"dive"
				_flight_left = DIVE_TIME
				_dive(victim, point, delta)
			else:
				_cruise(point + Vector3.UP * FLIGHT_HEIGHT, delta)

func _launch(delta: float) -> void:
	_launch_wait -= delta
	if _launch_wait <= 0.0:
		_fly_toward(_nest_top, _speed * 0.62, delta)
		if global_position.y > _nest_top.y - 0.32:
			state = &"cruise"

func _choose_victim() -> Node3D:
	var player: AsterPlayer = _game.player
	if player.alive:
		return player
	var selected: Node3D
	var nearest := INF
	for mount: AsterTurret in _game.turrets:
		if mount.hp > 0.0 and not mount.rebuilding:
			var distance := global_position.distance_squared_to(mount.global_position)
			if distance < nearest:
				selected = mount
				nearest = distance
	if selected != null:
		return selected
	for structure: AsterStructure in [_game.core] + _game.walls:
		if structure.hp > 0.0:
			var distance := global_position.distance_squared_to(structure.global_position)
			if distance < nearest:
				selected = structure
				nearest = distance
	return selected

func _aim_position(victim: Node3D) -> Vector3:
	if victim is AsterPlayer:
		return victim.global_position + Vector3.UP * 0.90
	if victim is AsterTurret:
		return victim.attack_position()
	var structure := victim as AsterStructure
	var local := structure.to_local(global_position)
	if structure.is_core:
		return structure.to_global(Vector3(clampf(local.x, -1.85, 1.85), 1.7, AsterStructure.CORE_HALF.z + 0.12))
	var outside := local.z >= AsterStructure.WALL_CENTER
	var face := AsterStructure.OUTER_FACE if outside else AsterStructure.OUTER_FACE - AsterStructure.WALL_DEPTH
	if structure.is_gate:
		face = AsterStructure.GATE_PANEL_DEPTH * (0.5 if local.z >= 0.0 else -0.5)
	return structure.to_global(Vector3(clampf(local.x, -1.72, 1.72), 1.86, face + (0.22 if outside else -0.22)))

func _dive(victim: Node3D, point: Vector3, delta: float) -> void:
	if _flight_left <= 0.0 or not _clear_to(point, victim):
		_recover(point)
		return
	if hit_point().distance_squared_to(point) > DIVE_REACH * DIVE_REACH:
		_fly_toward(point - Vector3.UP * 0.23, _speed * 1.18, delta)
		return
	velocity = Vector3.ZERO
	_turn(AsterArt.horizontal(point - global_position), delta)
	_hit(victim)
	if _strike_left > 0.0:
		_recover(point)

func _recover(point: Vector3) -> void:
	var away := AsterArt.horizontal(global_position - point).normalized()
	if away.is_zero_approx():
		away = global_basis.z
	_recovery_point = global_position + away * 2.6 + away.cross(Vector3.UP) * (_turn_side * 2.1)
	_recovery_point.y = maxf(global_position.y + 1.8, point.y + FLIGHT_HEIGHT)
	_turn_side = -_turn_side
	_flight_left = RECOVERY_TIME
	state = &"recover"

func _cruise(point: Vector3, delta: float) -> void:
	var forward := AsterArt.horizontal(point - global_position).limit_length(5.0)
	if not forward.is_zero_approx():
		var ahead := hit_point() + forward
		if not _clear_to(ahead):
			point = global_position + Vector3.UP * 2.8
		elif point.y < global_position.y:
			ahead.y = maxf(ahead.y - 2.2, point.y + 0.64)
			if not _clear_to(ahead):
				point.y = global_position.y
	_fly_toward(point, _speed, delta)

func _clear_to(point: Vector3, victim: Node3D = null) -> bool:
	var hit := AsterArt.ray(get_world_3d(), hit_point(), point, COVER)
	return hit.is_empty() or (victim != null and AsterArt.hit_target(hit.collider) == victim)

func _fly_toward(point: Vector3, speed: float, delta: float) -> void:
	var offset := point - global_position
	var desired := (AsterArt.horizontal(offset) * 3.2).limit_length(speed)
	desired.y = clampf(offset.y * 3.6, -6.4, 7.0)
	velocity = velocity.move_toward(desired, delta * 33.0)
	_turn(AsterArt.horizontal(velocity), delta)
	move_and_slide()

func _update_pose(delta: float) -> void:
	_phase += delta * 5.2
	var swing := sin(_phase * 7.5)
	if state == &"launch" and _launch_wait > 0.0:
		swing = -0.65
	var strike := smoothstep(0.0, 1.0, _strike_left / STRIKE_TIME)
	_look.position.y = sin(_phase) * 0.064
	_look.rotation.x = lerpf(_look.rotation.x, clampf(velocity.y * 0.054, -0.35, 0.29) - strike * 0.16, minf(delta * 10.0, 1.0))
	_look.rotation.z = lerpf(_look.rotation.z, clampf(global_basis.x.dot(velocity) * 0.042, -0.26, 0.26), minf(delta * 8.0, 1.0))
	_tail.rotation.x = sin(_phase - 0.8) * 0.12 + strike * 0.48
	_tail.rotation.y = sin(_phase * 0.68) * 0.08
	_wings[0].rotation = Vector3(0.055 * swing, -0.08 * swing, -0.20 - swing * 0.58)
	_wings[1].rotation = Vector3(0.055 * swing, 0.08 * swing, 0.20 + swing * 0.58)

func _update_fall(delta: float) -> void:
	velocity *= maxf(0.0, 1.0 - delta * 1.5)
	velocity.y -= 23.0 * delta
	move_and_slide()
	_look.rotation.z = move_toward(_look.rotation.z, 1.4, delta * 2.8)
	_look.rotation.x = move_toward(_look.rotation.x, -0.66, delta * 2.4)
	_tail.rotation.x = move_toward(_tail.rotation.x, 0.48, delta * 2.8)
	_wings[0].rotation.z = move_toward(_wings[0].rotation.z, 1.0, delta * 4.2)
	_wings[1].rotation.z = move_toward(_wings[1].rotation.z, -1.0, delta * 4.2)
