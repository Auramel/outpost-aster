class_name AsterSpecialFlyer
extends AsterFlyingBug

const LANDING_SITES := [
	Vector2(-4.9, 4.6), Vector2(-2.3, 2.5), Vector2(0.5, 3.6), Vector2(2.8, 5.4), Vector2(5.6, 2.8),
	Vector2(-5.2, -1.8), Vector2(-2.7, -4.2), Vector2(0.1, -5.4),
]

var _passenger: AsterBug
var _drop_site := Vector3.ZERO
var _scan_left := 0.0
var _grips: Array[Node3D] = []

func setup(game: Node, enemy_kind: Kind, formation_offset: Vector2) -> void:
	super.setup(game, enemy_kind, formation_offset)
	if kind == Kind.KAMIKAZE:
		max_hp = _balance.kamikaze_hp
		_speed = _balance.kamikaze_speed
		_fall_time = 0.12
	else:
		max_hp = _balance.transporter_hp
		_speed = _balance.transporter_speed
	hp = max_hp

func damage(amount: float, hit := Vector3.INF, normal := Vector3.UP) -> void:
	var factor := 1.0 - _balance.transporter_armor if kind == Kind.TRANSPORTER else 1.0
	super.damage(amount * factor, hit, normal)

func _build_hitbox() -> void:
	var body := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.29 if kind == Kind.KAMIKAZE else 0.64
	shape.height = 1.66 if kind == Kind.KAMIKAZE else 2.58
	body.position = Vector3(0, 0.64, 0.26 if kind == Kind.KAMIKAZE else -0.05)
	body.rotation.x = PI * 0.5
	body.shape = shape
	add_child(body)

func _build_shell() -> void:
	var small := kind == Kind.KAMIKAZE
	_shell = AsterModels.attach(_look, &"kamikaze_shell" if small else &"transporter_shell")
	_tail.position = Vector3(0, 0.60, 0.36) if small else Vector3(0, 0.64, 0.91)
	_look.add_child(_tail)
	AsterModels.attach(_tail, &"kamikaze_sac" if small else &"transporter_tail")
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * (0.20 if small else 0.39), 0.76 if small else 0.95, -0.14)
		_look.add_child(wing)
		_wings.append(wing)
		var size := 0.76 if small else 1.64
		AsterModels.attach(wing, &"flyer_wing", Vector3.ZERO, Vector3(side * size, size, size), false)
		AsterModels.attach(wing, &"flyer_wing", Vector3(0.0, -0.065, 0.33),
			Vector3(side * size * 0.77, size * 0.86, size * 0.79), false).rotation.y = -side * 0.48
		if not small:
			for depth: float in [-0.56, 0.34]:
				var grip := Node3D.new()
				grip.position = Vector3(side * 0.43, 0.51, depth)
				_look.add_child(grip)
				_grips.append(grip)
				AsterModels.attach(grip, &"transporter_grip", Vector3.ZERO, Vector3(side, 1, 1))

func _move(delta: float) -> void:
	if kind == Kind.KAMIKAZE or state == &"launch":
		super._move(delta)
		return
	if is_instance_valid(_passenger) and _passenger.hp <= 0.0:
		_passenger.transport = null
		_passenger = null
	if not is_instance_valid(_passenger):
		_scan_left -= delta
		if _scan_left <= 0.0:
			_scan_left = 0.6
			_select_passenger()
	if not is_instance_valid(_passenger):
		state = &"transport_search"
		var ahead := Vector3(global_position.x, 7.0, AsterTerrain.FRONT_APPROACH_Z + 18.0)
		_cruise(ahead, delta)
		return
	if _passenger.state == &"carried":
		_deliver(delta)
	else:
		_pick_up(delta)

func _dive(victim: Node3D, point: Vector3, delta: float) -> void:
	var offset := point - hit_point()
	var contact := offset.length_squared() < (0.67 if victim is AsterPlayer else 0.78) ** 2
	if not contact:
		if _flight_left <= 0.0 or not _clear_to(point, victim):
			_recover(point)
			return
		_fly_toward(point - Vector3.UP * 0.64, _speed * 1.25, delta)
		for index in range(get_slide_collision_count()):
			var collider := get_slide_collision(index).get_collider() as CollisionObject3D
			if collider != null and AsterArt.hit_target(collider) == victim:
				contact = true
				break
	if contact:
		awards_kill = false
		damage(hp)

func _select_passenger() -> void:
	var nearest := INF
	for bug: AsterBug in _game.assault.enemies:
		if bug.kind != Kind.GROUND or bug.hp <= 0.0 or is_instance_valid(bug.transport):
			continue
		if bug.state not in [&"front", &"approach"] or bug.global_position.z < AsterTerrain.FRONT_Z + 1.3:
			continue
		var distance := global_position.distance_squared_to(bug.global_position)
		if distance < nearest:
			nearest = distance
			_passenger = bug
	if is_instance_valid(_passenger):
		_passenger.transport = self

func _pick_up(delta: float) -> void:
	state = &"transport_pickup"
	var passenger_point := _passenger.global_position + Vector3.UP * 1.40
	var offset := passenger_point - global_position
	if offset.length_squared() < 0.55 and _clear_to(_passenger.hit_point()):
		_passenger.begin_carry()
		_drop_site = _choose_drop_site()
		return
	if AsterArt.horizontal(offset).length_squared() > 10.0 or not _clear_to(passenger_point):
		_cruise(passenger_point + Vector3.UP * 2.4, delta)
	else:
		_fly_toward(passenger_point, _speed * 0.84, delta)

func _choose_drop_site() -> Vector3:
	var first := randi_range(0, LANDING_SITES.size() - 1)
	for attempt in range(LANDING_SITES.size()):
		var site: Vector2 = LANDING_SITES[(first + attempt) % LANDING_SITES.size()]
		var point := Vector3(site.x, AsterTerrain.surface_height(site.x, site.y), site.y)
		var floor_hit := AsterArt.ray(get_world_3d(), point + Vector3.UP * 7.0, point - Vector3.UP * 0.5, COVER)
		if not floor_hit.is_empty() and floor_hit.position.y < point.y + 0.13 and floor_hit.normal.y > 0.86:
			return floor_hit.position
	return Vector3(0, 0, 3.6)

func _deliver(delta: float) -> void:
	state = &"transport_delivery"
	var goal := _drop_site + Vector3.UP * 5.6
	var wall_clearance := AsterStructure.WALL_HEIGHT + 2.65
	var outside := global_position.z > AsterTerrain.FRONT_Z - 0.55
	if outside:
		goal.y = maxf(goal.y, wall_clearance + 0.16)
	if outside and global_position.y < wall_clearance:
		_fly_toward(Vector3(global_position.x, wall_clearance + 0.45, global_position.z), _speed * 0.6, delta)
	else:
		_cruise(goal, delta)
	_passenger.global_position = global_position + Vector3.DOWN * 1.43 + global_basis.z * 0.05
	_passenger.rotation.y = rotation.y
	if AsterArt.horizontal(goal - global_position).length_squared() < 0.44 and absf(goal.y - global_position.y) < 0.72:
		_release(0.10)

func _release(stun: float) -> void:
	if not is_instance_valid(_passenger):
		return
	if _passenger.hp > 0.0 and _passenger.state == &"carried":
		var momentum := AsterArt.horizontal(velocity).limit_length(3.1) if stun > 1.0 else Vector3.ZERO
		_passenger.release_from_transport(momentum, stun)
	else:
		_passenger.transport = null
	_passenger = null

func _on_death() -> void:
	if kind == Kind.KAMIKAZE:
		var point := hit_point()
		_game.effects.kamikaze_impact(point, _balance.kamikaze_radius)
		_game.sound.artillery(point, 1.22)
		_game.bug_blast(point, _balance.kamikaze_damage, _balance.kamikaze_radius, false)
		_look.hide()
	else:
		_release(randf_range(1.0, 2.0))

func _update_pose(delta: float) -> void:
	super._update_pose(delta)
	if kind == Kind.KAMIKAZE:
		var pulse := 1.0 + sin(_phase * 2.8) * 0.055 + (0.07 if state == &"dive" else 0.0)
		_tail.scale = Vector3.ONE * pulse
	else:
		for index in range(_grips.size()):
			var side := -1.0 if index < 2 else 1.0
			var open := 0.28 if state != &"transport_delivery" else -0.12
			_grips[index].rotation.z = lerpf(_grips[index].rotation.z, side * open, minf(delta * 8.0, 1.0))
