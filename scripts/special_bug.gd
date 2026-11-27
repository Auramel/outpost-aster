class_name AsterSpecialBug
extends AsterBug

const DIG_TIME := 1.25
const THROW_TIME := 0.44
const RAM_WINDUP := 0.46
const RAM_BACKUP := 4.8
const SHOOT_WINDUP := 0.41
const TANK_RADIUS := 0.90
const TANK_LENGTH := 2.80
const TANK_CAVE_RADIUS := 0.68
const TANK_CAVE_LENGTH := 2.24
const TANK_CAVE_CLEARANCE := 14.3
const LIMB_SHADOW_DISTANCE := 16.0

var _armor := 0.0
var _target: Node3D
var _action_left := 0.0
var _cooldown := 0.0
var _cover := Vector3.INF
var _firing_position := Vector3.INF
var _shot_point := Vector3.ZERO
var _march_state: StringName = &"front"
var _charge_direction := Vector3.ZERO
var _charge_speed := 0.0
var _rock: MeshInstance3D
var _scoop_socket: Node3D
var _quills: MeshInstance3D
var _tank_body: CollisionShape3D
var _tank_in_cave := false
var _limb_meshes: Array[MeshInstance3D] = []
var _limb_shadows := true

func setup(game: Node, enemy_kind: Kind, formation_offset: Vector2) -> void:
	super.setup(game, enemy_kind, formation_offset)
	match kind:
		Kind.TANK:
			max_hp = _balance.tank_hp
			_speed = _balance.tank_speed
			_power = _balance.tank_damage
			_armor = _balance.tank_armor
			collision_layer |= AsterArt.TANK
		Kind.RAM:
			max_hp = _balance.ram_hp
			_speed = _balance.ram_speed
			_power = _balance.ram_damage
			_armor = _balance.ram_armor
			collision_mask |= AsterArt.ACCESS
		Kind.CATAPULT:
			max_hp = _balance.catapult_hp
			_speed = _balance.catapult_speed
			_armor = _balance.catapult_armor
		Kind.SHOOTER:
			max_hp = _balance.shooter_hp
			_armor = _balance.shooter_armor
	hp = max_hp

func damage(amount: float, hit := Vector3.INF, normal := Vector3.UP) -> void:
	super.damage(amount * (1.0 - _armor), hit, normal)

func _build_hitbox() -> void:
	if kind == Kind.RAM:
		var body := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.49
		capsule.height = 2.36
		body.shape = capsule
		body.position = Vector3(0.0, 0.55, -0.20)
		body.rotation.x = PI * 0.5
		add_child(body)
		return
	if kind != Kind.TANK:
		super._build_hitbox()
		return
	var shape := CapsuleShape3D.new()
	_tank_body = CollisionShape3D.new()
	_tank_body.shape = shape
	_tank_body.rotation.x = PI * 0.5
	add_child(_tank_body)
	_fit_tank(false)

func _build_shell() -> void:
	if kind == Kind.SHOOTER:
		super._build_shell()
		_quills = AsterModels.attach(_look, &"shooter_quills")
		return
	var shell_parts: Dictionary = {Kind.TANK: &"tank_shell", Kind.RAM: &"ram_shell", Kind.CATAPULT: &"catapult_shell"}
	_shell = AsterModels.attach(_look, shell_parts[kind])
	_shell.lod_bias = 0.69
	var body_scale := Vector3.ONE
	match kind:
		Kind.TANK:
			body_scale = Vector3(2.4, 1.71, 1.83)
		Kind.RAM:
			body_scale = Vector3(1.34, 1.13, 1.12)
		Kind.CATAPULT:
			body_scale = Vector3(1.02, 0.99, 1.04)
	for side: float in [-1.0, 1.0]:
		var sockets: Array[Vector3] = [Vector3(0.29, 0.52, -0.51), Vector3(0.39, 0.52, -0.09), Vector3(0.35, 0.51, 0.47)]
		for index in range(sockets.size()):
			var joint := Node3D.new()
			joint.position = sockets[index] * body_scale * Vector3(side, 1.0, 1.0)
			_look.add_child(joint)
			_legs.append(joint)
			var part := &"siege_claw" if index == 0 else &"siege_leg"
			var limb := AsterModels.attach(joint, part, Vector3.ZERO, body_scale * Vector3(side, 1.0, 1.0))
			limb.lod_bias = 0.55
			_limb_meshes.append(limb)
	_tail.position = Vector3(0, 0.55, 0.56) * body_scale
	_look.add_child(_tail)
	_sting = Node3D.new()
	_tail.add_child(_sting)
	if kind == Kind.CATAPULT:
		_sting.position = Vector3(0, 0.53, 0.92)
		AsterModels.attach(_tail, &"catapult_tail")
		AsterModels.attach(_sting, &"catapult_scoop")
		_scoop_socket = Node3D.new()
		_scoop_socket.position = Vector3(0, 0.19, 0.18)
		_sting.add_child(_scoop_socket)
		_rock = AsterModels.attach(_look, &"bug_rock", Vector3.ZERO, Vector3.ONE * 0.56)
		_rock.hide()

func hit_point() -> Vector3:
	return global_position + Vector3.UP * (1.04 if kind == Kind.TANK else 0.64)

func set_entry_path(points: PackedVector3Array) -> void:
	super.set_entry_path(points)
	if kind == Kind.TANK and not points.is_empty():
		var approach := points[0] - global_position
		rotation.y = atan2(-approach.x, -approach.z)
		_fit_tank(true)

func _fit_tank(in_cave: bool) -> void:
	_tank_in_cave = in_cave
	var collider := _tank_body.shape as CapsuleShape3D
	collider.radius = TANK_CAVE_RADIUS if in_cave else TANK_RADIUS
	collider.height = TANK_CAVE_LENGTH if in_cave else TANK_LENGTH
	_tank_body.position = Vector3(0.0, collider.radius + 0.02, 0.04)

func _follow_entry(delta: float) -> void:
	super._follow_entry(delta)
	if _tank_in_cave and (state != &"incoming" or global_position.distance_squared_to(_entry[0]) > TANK_CAVE_CLEARANCE * TANK_CAVE_CLEARANCE):
		_fit_tank(false)

func _melee_reach() -> float:
	return 2.35 if kind == Kind.TANK else super._melee_reach()

func _wall_standoff() -> float:
	return 2.06 if kind == Kind.TANK else super._wall_standoff()

func _turn(direction: Vector3, delta: float) -> void:
	if kind == Kind.TANK and direction.length_squared() > 0.0001:
		var turn_speed := 4.0 if _tank_in_cave else 2.0
		rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), turn_speed * delta)
	elif kind != Kind.TANK:
		super._turn(direction, delta)

func _move(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if kind == Kind.TANK or state == &"incoming":
		super._move(delta)
		return
	_action_left = maxf(0.0, _action_left - delta)
	var previous := global_position
	match kind:
		Kind.RAM:
			_move_ram(delta)
		Kind.CATAPULT:
			_move_catapult(delta)
		Kind.SHOOTER:
			_move_shooter(delta)
	_step_on_surface(previous)

func _move_ram(delta: float) -> void:
	if not _valid_target(_target):
		_target = _game.nearest_building(hit_point())
		state = &"ram_approach"
		if _target == null:
			_stop(delta)
			return
	var contact := _ram_contact()
	var offset := AsterArt.horizontal(contact - global_position)
	var distance := offset.length()
	var reachable := absf(contact.y - hit_point().y) < 0.88
	match state:
		&"ram_retreat":
			if distance >= RAM_BACKUP or not reachable or _action_left <= 0.0:
				state = &"ram_windup"
				_action_left = RAM_WINDUP
			else:
				_walk(global_position - offset.normalized() * RAM_BACKUP, delta)
				_turn(offset, delta)
		&"ram_windup":
			_stop(delta)
			_turn(offset, delta)
			if _action_left <= 0.0:
				_charge_direction = offset.normalized()
				_charge_speed = _speed
				state = &"ram_charge"
				_action_left = 1.35
				_game.sound.bug_cue(AsterSound.BugCue.WINDUP, hit_point())
		&"ram_charge":
			if reachable and distance <= 1.53 and _clear_ram_contact(contact):
				_target.damage(_power)
				_game.dust.impact(contact)
				_game.sound.bug_cue(AsterSound.BugCue.STRUCTURE_HIT, contact)
				_strike_left = STRIKE_TIME
				_stop(delta)
				_ram_retreat()
			elif _action_left <= 0.0 or not reachable:
				_ram_retreat()
			else:
				_charge_speed = move_toward(_charge_speed, _balance.ram_charge_speed, delta * 11.0)
				var fall := 0.0 if is_on_floor() else velocity.y - 18.0 * delta
				velocity = Vector3(_charge_direction.x * _charge_speed, fall, _charge_direction.z * _charge_speed)
				move_and_slide()
		_:
			if reachable and distance <= RAM_BACKUP and _clear_ram_contact(contact):
				state = &"ram_windup"
				_action_left = RAM_WINDUP
				_stop(delta)
			else:
				_walk(_ram_waypoint(contact), delta)

func _ram_retreat() -> void:
	state = &"ram_retreat"
	_action_left = 1.45

func _ram_contact() -> Vector3:
	var section := _target as AsterStructure
	if section != null and not section.is_core:
		var local := section.to_local(hit_point())
		var outside := local.z >= (0.0 if section.is_gate else AsterStructure.WALL_CENTER)
		if section.is_gate and section.gate_open:
			return section.to_global(Vector3(1.74 if local.x >= 0.0 else -1.74, 0.74, 0.53 if outside else -0.53))
		var face := AsterStructure.GATE_PANEL_DEPTH * 0.5 if section.is_gate else AsterStructure.OUTER_FACE
		var depth := AsterStructure.GATE_PANEL_DEPTH if section.is_gate else AsterStructure.WALL_DEPTH
		return section.to_global(Vector3(clampf(local.x, -1.03, 1.03), 0.74, face if outside else face - depth))
	return _target.closest_point(hit_point())

func _clear_ram_contact(contact: Vector3) -> bool:
	var hit := AsterArt.ray(get_world_3d(), hit_point(), contact, AsterArt.SOLID)
	return hit.is_empty() or AsterArt.hit_target(hit.collider) == _target

func _ram_waypoint(contact: Vector3) -> Vector3:
	var at := global_position
	var outside := at.z > AsterTerrain.FRONT_Z + 0.18
	if _target is AsterStructure and not _target.is_core and absf(at.x - contact.x) > 0.44:
		var lane := contact.z + (1.96 if contact.z >= AsterTerrain.FRONT_Z else -1.96)
		return Vector3(at.x if absf(lane - at.z) > 0.25 and absf(at.z - contact.z) < 1.70 else contact.x, at.y, lane)
	var needs_ramp := _target is AsterTurret and contact.y > 2.4 and at.y < 2.75
	var other_side := outside and (contact.z < AsterTerrain.FRONT_Z - 0.45 or needs_ramp)
	if other_side and not (_target is AsterStructure and not _target.is_core):
		var entry: AsterStructure
		var best := INF
		for section: AsterStructure in _game.walls:
			if section.blocking:
				continue
			var cost := absf(section.global_position.x - at.x) + absf(section.global_position.x - contact.x)
			if cost < best:
				entry = section
				best = cost
		if entry != null:
			var mouth := entry.global_position + Vector3.BACK * 1.1
			if absf(at.x - mouth.x) > 0.36 and at.z > mouth.z - 0.55:
				return mouth
			return entry.global_position + Vector3.FORWARD * AsterStructure.INSIDE_CLEARANCE
	if needs_ramp:
		var ramp: AsterStructure
		var best := INF
		for mount: AsterTurret in _game.turrets:
			if not mount.direct_ramp or not mount.wall.blocking:
				continue
			var cost := absf(mount.global_position.x - contact.x)
			if cost < best:
				ramp = mount.wall
				best = cost
		if ramp != null:
			var foot := AsterTerrain.ramp_point(ramp, AsterTerrain.RAMP_START + 0.12)
			if absf(foot.x - at.x) > 0.32 or at.z < foot.z - 0.22:
				return foot
			return AsterTerrain.ramp_point(ramp, AsterTerrain.LANDING_EDGE - 0.4)
	return contact

func _move_catapult(delta: float) -> void:
	if not _valid_target(_target) or (_target is AsterPlayer and _cooldown <= 0.0 and _game.nearest_building(hit_point(), false) != null):
		_target = _game.nearest_building(hit_point(), false)
		if _target == null and _game.player.alive:
			_target = _game.player
		_cover = Vector3.INF
		_firing_position = Vector3.INF
		_rock.hide()
		state = &"catapult_search"
	if not _valid_target(_target):
		_stop(delta)
		return
	var aim: Vector3 = _target.global_position + Vector3.UP * 0.9
	match state:
		&"catapult_dig", &"catapult_throw":
			_catapult_attack(aim, delta)
		&"catapult_retreat":
			if _cover.is_finite() and AsterArt.horizontal(_cover - global_position).length_squared() > 0.24:
				_walk(_cover, delta)
			else:
				_stop(delta)
				if _cooldown <= 0.0:
					state = &"catapult_advance"
		&"catapult_advance":
			if AsterArt.horizontal(_firing_position - global_position).length_squared() > 0.36:
				_walk(_firing_position, delta)
			elif _arc_clear(_estimated_release(global_position, aim), aim):
				state = &"catapult_dig"
				_action_left = DIG_TIME
				_stop(delta)
				_game.sound.bug_cue(AsterSound.BugCue.WINDUP, hit_point())
			else:
				state = &"catapult_search"
		_:
			var distance := AsterArt.horizontal(global_position - aim).length()
			if distance < _balance.catapult_range + 10.0 and _find_firing_position(aim):
				state = &"catapult_retreat" if _cover.is_finite() and AsterArt.horizontal(_cover - global_position).length_squared() > 0.24 else &"catapult_advance"
			else:
				var lane := Vector3(clampf(aim.x, -12.0, 12.0), 0, maxf(AsterTerrain.FRONT_APPROACH_Z + 3.0, aim.z + 7.0))
				_walk(lane, delta)

func _catapult_attack(aim: Vector3, delta: float) -> void:
	_stop(delta)
	var direction := AsterArt.horizontal(aim - global_position)
	_turn(direction, delta)
	if state == &"catapult_dig":
		if _action_left <= DIG_TIME * 0.58 and not _rock.visible:
			_rock.show()
			_game.dust.impact(to_global(Vector3(0.39, 0.07, -1.02)))
		if _action_left <= 0.0:
			state = &"catapult_throw"
			_action_left = THROW_TIME
		return
	if _action_left <= 0.0:
		var from := _scoop_socket.global_position
		if _arc_clear(from, aim):
			_game.throw_rock(from, aim, self)
			_cooldown = _balance.catapult_period
			state = &"catapult_retreat"
		else:
			state = &"catapult_search"
		_rock.hide()

func _find_firing_position(aim: Vector3) -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = 0.65
	var at := global_position
	var toward := AsterArt.horizontal(aim - at).normalized()
	if toward.is_zero_approx():
		toward = -global_basis.z
	var side := toward.cross(Vector3.UP)
	var fallback := Vector3.INF
	for offset: Vector3 in [Vector3.ZERO, side * 2.1, -side * 2.1, side * 4.6, -side * 4.6, toward * 3.2, -toward * 2.5, side * 7.5, -side * 7.5]:
		var candidate := at + offset
		candidate.y = AsterTerrain.surface_height(candidate.x, candidate.z)
		if AsterArt.horizontal(aim - candidate).length() > _balance.catapult_range or not _arc_clear(_estimated_release(candidate, aim), aim):
			continue
		if not _walk_clear(at, candidate):
			continue
		if not fallback.is_finite():
			fallback = candidate
		if _screened_from(candidate, aim):
			continue
		for step: Vector3 in [-toward * 3.4, side * 3.2, -side * 3.2, -toward * 5.2 + side * 2.2, -toward * 5.2 - side * 2.2]:
			var hideout := candidate + step
			hideout.y = AsterTerrain.surface_height(hideout.x, hideout.z)
			if _walk_clear(at, hideout) and _walk_clear(hideout, candidate) and _screened_from(hideout, aim):
				_cover = hideout
				_firing_position = candidate
				return true
	if fallback.is_finite() and AsterArt.horizontal(aim - at).length() < _balance.catapult_range - 2.5:
		_cover = Vector3.INF
		_firing_position = fallback
		return true
	return false

func _walk_clear(from: Vector3, to: Vector3) -> bool:
	return from.distance_squared_to(to) < 0.04 or AsterArt.ray(get_world_3d(), from + Vector3.UP * 0.63, to + Vector3.UP * 0.63, AsterArt.SOLID).is_empty()

func _screened_from(point: Vector3, aim: Vector3) -> bool:
	var hit := AsterArt.ray(get_world_3d(), point + Vector3.UP * 0.76, aim, AsterArt.SOLID)
	return not hit.is_empty() and AsterArt.hit_target(hit.collider) != _target

func _estimated_release(point: Vector3, aim: Vector3) -> Vector3:
	return point + Vector3.UP * 1.72 - AsterArt.horizontal(aim - point).normalized() * 1.34

func _arc_clear(from: Vector3, aim: Vector3) -> bool:
	var duration := AsterBugProjectile.flight_time(from, aim)
	var launch := AsterBugProjectile.rock_velocity(from, aim, duration)
	var last := from
	for index in range(1, 9):
		var time := duration * index / 8.0
		var next := from + launch * time + Vector3.DOWN * (AsterBugProjectile.GRAVITY * time * time * 0.5)
		var hit := AsterArt.ray(get_world_3d(), last, next, AsterArt.SOLID | AsterArt.ACCESS)
		if not hit.is_empty():
			return AsterArt.hit_target(hit.collider) == _target
		last = next
	return true

func _move_shooter(delta: float) -> void:
	if _action_left > 0.0 or state == &"shooter_aim":
		if not _valid_target(_target) or not _quill_clear(_shot_point, _target):
			state = _march_state
			_action_left = 0.0
			return
		_stop(delta)
		_turn(AsterArt.horizontal(_shot_point - global_position), delta)
		if _action_left <= 0.0:
			_game.fire_quill(_quill_origin(), _shot_point, self)
			_strike_left = STRIKE_TIME
			_game.sound.bug_cue(AsterSound.BugCue.STRUCTURE_HIT, _quill_origin())
			_cooldown = _balance.shooter_period
			state = _march_state
		return
	if _cooldown <= 0.0 and state in [&"front", &"approach", &"inside"]:
		var player: AsterPlayer = _game.player
		var enemy: Node3D = player if player.alive else null
		if enemy == null or not _in_shooting_range(enemy):
			enemy = _game.nearest_building(hit_point())
		if _valid_target(enemy) and _in_shooting_range(enemy):
			_target = enemy
			_shot_point = _shot_target(enemy)
			_march_state = state
			state = &"shooter_aim"
			_action_left = SHOOT_WINDUP
			_game.sound.bug_cue(AsterSound.BugCue.WINDUP, hit_point())
			return
		_cooldown = 0.24
	super._move(delta)

func _quill_origin() -> Vector3:
	return _look.to_global(Vector3(0.0, 1.15, 0.04))

func _shot_target(enemy: Node3D) -> Vector3:
	if enemy is AsterPlayer:
		return enemy.global_position + Vector3.UP * 0.86
	if enemy is AsterTurret:
		return enemy.attack_position()
	return enemy.closest_point(global_position + Vector3.UP * 0.87)

func _in_shooting_range(enemy: Node3D) -> bool:
	if enemy == null:
		return false
	var point := _shot_target(enemy)
	var distance := _quill_origin().distance_to(point)
	return distance > 2.0 and distance <= _balance.shooter_range and _quill_clear(point, enemy)

func _quill_clear(point: Vector3, enemy: Node3D) -> bool:
	var hit := AsterArt.ray(get_world_3d(), _quill_origin(), point, AsterArt.SOLID | AsterArt.ACCESS)
	return hit.is_empty() or AsterArt.hit_target(hit.collider) == enemy

func _valid_target(target: Node3D) -> bool:
	return is_instance_valid(target) and target.hp > 0.0 and not (target is AsterTurret and target.rebuilding)

func _update_pose(delta: float) -> void:
	super._update_pose(delta)
	if not _limb_meshes.is_empty():
		var eye: Vector3 = _game.player.eye.global_position
		var distance := LIMB_SHADOW_DISTANCE + (0.75 if _limb_shadows else -0.75)
		var shadowed := eye.distance_squared_to(global_position) <= distance * distance
		if shadowed != _limb_shadows:
			_limb_shadows = shadowed
			for limb in _limb_meshes:
				limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadowed else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		Kind.TANK:
			_look.rotation.z *= 0.57
			_look.position.y *= 0.55
		Kind.RAM:
			var leaning := 0.20 if state == &"ram_charge" else (-0.13 if state == &"ram_windup" else 0.0)
			_look.rotation.x += leaning
		Kind.CATAPULT:
			if state == &"catapult_dig":
				var progress := 1.0 - _action_left / DIG_TIME
				_tail.rotation.x = lerpf(0.12, 0.96, sin(progress * PI))
				_tail.rotation.y = sin(progress * PI) * 0.33
				_sting.rotation.x = -0.63
				_legs[0].rotation.x += sin(_action_left * 23.0) * 0.37
				_legs[3].rotation.x -= sin(_action_left * 23.0) * 0.37
				var scoop := _look.to_local(_scoop_socket.global_position)
				var side := Vector3(0.69, 0.29, 0.41)
				_rock.position = Vector3(0.39, 0.02, -1.02).lerp(side, smoothstep(0.42, 0.74, progress))
				_rock.position = _rock.position.lerp(scoop, smoothstep(0.72, 1.0, progress))
			elif state == &"catapult_throw":
				var load_up := 1.0 - _action_left / THROW_TIME
				_tail.rotation.x = lerpf(0.39, -0.83, load_up * load_up)
				_sting.rotation.x = lerpf(-0.30, -0.53, load_up)
				_rock.position = _look.to_local(_scoop_socket.global_position)
		Kind.SHOOTER:
			_quills.rotation.x = -0.22 * (1.0 - _action_left / SHOOT_WINDUP) if state == &"shooter_aim" else _strike_left * 0.61
