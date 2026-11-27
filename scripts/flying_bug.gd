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

func setup(game: Node, kind: Kind, formation_offset: Vector2) -> void:
	super.setup(game, kind, formation_offset)
	hp = _balance.flyer_hp
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

func _move(delta: float) -> void:
	var player: AsterPlayer = _game.player
	if not player.alive:
		state = &"cruise"
		var orbit := Vector3(sin(_phase * 0.16) * 5.0, FLIGHT_HEIGHT, AsterTerrain.FRONT_APPROACH_Z + 8.0 + cos(_phase * 0.16) * 4.0)
		_cruise(orbit, delta)
		return
	_flight_left = maxf(0.0, _flight_left - delta)
	match state:
		&"dive":
			_dive(player, delta)
		&"recover":
			_cruise(_recovery_point, delta)
			if _flight_left <= 0.0:
				state = &"cruise"
		_:
			var point := player.global_position
			var offset := point - global_position
			if AsterArt.horizontal(offset).length_squared() <= DIVE_RANGE * DIVE_RANGE and absf(offset.y) < 7.0 and _clear_to(point + Vector3.UP * 0.9):
				state = &"dive"
				_flight_left = DIVE_TIME
				_dive(player, delta)
			else:
				_cruise(point + Vector3.UP * FLIGHT_HEIGHT, delta)

func _dive(player: AsterPlayer, delta: float) -> void:
	var target := player.global_position + Vector3.UP * 0.9
	if _flight_left <= 0.0 or not _clear_to(target):
		_recover(player.global_position)
		return
	if hit_point().distance_squared_to(target) > DIVE_REACH * DIVE_REACH:
		_fly_toward(player.global_position + Vector3.UP * 0.67, _speed * 1.18, delta)
		return
	velocity = Vector3.ZERO
	_turn(AsterArt.horizontal(target - global_position), delta)
	_hit(player)
	if _strike_left > 0.0:
		_recover(player.global_position)

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

func _clear_to(point: Vector3) -> bool:
	return AsterArt.ray(get_world_3d(), hit_point(), point, COVER).is_empty()

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
