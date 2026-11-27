class_name AsterBug
extends CharacterBody3D

signal died(bug: AsterBug)

enum Kind { GROUND, CLIMBER }

const ATTACK_REACH := 1.25
const WINDUP_TIME := 0.21
const STRIKE_TIME := 0.25
const FALL_TIME := 0.42

var hp: float
var speed_factor := 1.0
var climber: bool
var state: StringName = &"front"
var wall: AsterStructure
var _power: float
var _speed: float
var _formation_offset := Vector2.ZERO
var _entry := PackedVector3Array()
var _entry_index := 0
var _game: Node
var _balance: AsterBalance
var _look := Node3D.new()
var _legs: Array[Node3D] = []
var _shell: MeshInstance3D
var _phase := 0.0
var _step_travel := 0.0
var _step_side := 1.0
var _flash := 0.0
var _voice_left := 0.0
var _death_left := 0.0
var _wounds: Array[MeshInstance3D] = []
var _next_wound := 0
var _bleed_time := 0.0
var _drip_timer := 0.0
var _climb_pitch := 0.0
var _windup_left := 0.0
var _strike_left := 0.0
var _attack_target: Node
var _attack_contact := false
var _chassis_lift := 0.0
var _attack := 0.25
var _updated := 0.0
var _lure_left := 0.0
var _lure_cooldown := 0.0
var _ramp_turret: AsterTurret

func setup(game: Node, kind: Kind, formation_offset: Vector2) -> void:
	_game = game
	_balance = game.balance
	climber = kind == Kind.CLIMBER
	_formation_offset = formation_offset
	hp = _balance.climber_hp if climber else _balance.ground_hp
	_power = _balance.climber_damage if climber else _balance.ground_damage
	_speed = _balance.climber_speed if climber else _balance.ground_speed
	collision_layer = AsterArt.ENEMY
	collision_mask = AsterArt.SOLID
	floor_snap_length = 0.20
	var hitbox := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.52
	capsule.height = 1.13
	hitbox.shape = capsule
	hitbox.position.y = 0.58
	add_child(hitbox)
	add_child(_look)
	add_to_group(&"wall_occupants")
	_build_shell()
	_phase = float(get_instance_id() % 37)
	_step_travel = randf_range(0.0, 0.58)
	_voice_left = randf_range(1.9, 12.8)

func _build_shell() -> void:
	_shell = AsterModels.attach(_look, &"bug")
	_shell.lod_bias = 0.76
	for side: float in [-1.0, 1.0]:
		var foot_mesh: StringName = &"leg_left" if side < 0.0 else &"leg_right"
		var claw_mesh: StringName = &"claw_left" if side < 0.0 else &"claw_right"
		var sockets: Array[Vector3] = [
			Vector3(side * 0.238, 0.568, -0.554),
			Vector3(side * 0.305, 0.505, -0.35),
			Vector3(side * 0.283, 0.502, 0.39),
		]
		for index in range(sockets.size()):
			var joint := Node3D.new()
			joint.position = sockets[index]
			_look.add_child(joint)
			_legs.append(joint)
			var part := claw_mesh if index == 0 else foot_mesh
			AsterModels.attach(joint, part, Vector3.ZERO, Vector3.ONE, false).lod_bias = 0.72

func set_entry_path(points: PackedVector3Array) -> void:
	if not points.is_empty():
		_entry = points
		_entry_index = 0
		state = &"incoming"

func hit_point() -> Vector3:
	return global_position + Vector3.UP * 0.64

func damage(amount: float, hit := Vector3.INF, normal := Vector3.UP) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_flash = 0.16
	if hit.is_finite():
		_add_wound(hit)
		_game.bug_fx.spray(hit + normal * 0.036, normal, hp == 0.0)
	if hp > 0.0:
		_game.sound.bug_cue(AsterSound.BugCue.HURT, hit_point())
		return
	remove_from_group(&"wall_occupants")
	set_deferred(&"collision_layer", 0)
	_death_left = FALL_TIME
	set_physics_process(true)
	_game.sound.bug_cue(AsterSound.BugCue.DEATH, hit_point())
	died.emit(self)

func _add_wound(hit: Vector3) -> void:
	var patch: MeshInstance3D
	if _wounds.size() < 2:
		patch = AsterBugFX.wound(_look)
		_wounds.append(patch)
	var slot := _next_wound % _wounds.size()
	patch = _wounds[slot]
	_next_wound = slot + 1
	var local := _look.to_local(hit)
	var center := Vector3(0, 0.665, -0.11)
	var span := Vector3(0.425, 0.25, 0.56)
	if local.z > 0.31:
		center = Vector3(0, 0.557, 0.428)
		span = Vector3(0.33, 0.22, 0.33)
	elif local.z < -0.57:
		center = Vector3(0, 0.614, -0.758)
		span = Vector3(0.278, 0.16, 0.31)
	var radial := ((local - center) / span).normalized()
	if radial.is_zero_approx():
		radial = Vector3.UP
	var outward := (radial / span).normalized()
	var up := Vector3.RIGHT if absf(outward.y) > 0.92 else Vector3.UP
	var size := randf_range(0.24, 0.38)
	patch.transform = Transform3D(
		Basis.looking_at(-outward, up).rotated(outward, randf_range(-PI, PI)).scaled_local(Vector3.ONE * size),
		center + radial * span + outward * 0.021)
	_bleed_time = 1.30
	_drip_timer = 0.065

func _bleed(delta: float) -> void:
	if _bleed_time <= 0.0:
		return
	_bleed_time -= delta
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = 0.14
		_game.bug_fx.drip(_wounds[_next_wound - 1].global_position, velocity)

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		_death_left -= delta
		if _death_left <= 0.0:
			queue_free()
		else:
			var fall := 1.0 - _death_left / FALL_TIME
			_look.rotation.z = fall * fall * 1.39
			_look.position.y = -fall * 0.36
			_bleed(delta)
		return
	if _game.lost:
		return
	_attack = maxf(0.0, _attack - delta)
	_windup_left = maxf(0.0, _windup_left - delta)
	_strike_left = maxf(0.0, _strike_left - delta)
	_attack_contact = false
	_flash = maxf(0.0, _flash - delta)
	_lure_cooldown = maxf(0.0, _lure_cooldown - delta)
	_lure_left = maxf(0.0, _lure_left - delta)
	_voice_left -= delta
	if _voice_left <= 0.0:
		_voice_left = randf_range(6.3, 15.6)
		_game.sound.bug_cue(AsterSound.BugCue.CALL, hit_point())
	_bleed(delta)
	var step_origin := global_position
	match state:
		&"incoming":
			_follow_entry(delta)
		&"front":
			_seek_front(delta)
		&"approach":
			_approach_wall(delta)
		&"cross":
			_cross_wall(delta)
		&"climb":
			_climb(delta)
		&"ledge":
			_ledge(delta)
		&"drop":
			_drop(delta)
		&"inside":
			_attack_core(delta)
		&"ramp":
			_attack_platform(delta)
	if not _attack_contact:
		_attack_target = null
		_windup_left = 0.0
	_step_on_surface(step_origin)
	_update_legs(delta)

func _step_on_surface(previous: Vector3) -> void:
	var climbing := state == &"climb"
	var on_rampart := climbing or state == &"ledge" or state == &"ramp"
	if state == &"drop" or (not is_on_floor() and not on_rampart):
		return
	var distance := previous.distance_to(global_position)
	if distance < 0.003:
		return
	_step_travel += distance
	var stride := 0.92 if climber else 0.79
	if _step_travel < stride:
		return
	_step_travel -= stride
	_step_side = -_step_side
	var contact := global_position + global_basis.x * (_step_side * 0.33)
	if climbing:
		contact -= global_basis.z * 0.44
	_game.sound.bug_step(contact, climbing or global_position.y > 0.16, climber)

func _follow_entry(delta: float) -> void:
	var goal := _entry[_entry_index]
	if AsterArt.horizontal(global_position - goal).length_squared() < 0.13:
		_entry_index += 1
		if _entry_index >= _entry.size():
			state = &"front"
		return
	_walk(goal, delta)

func _choose_wall() -> AsterStructure:
	var best := INF
	var chosen: AsterStructure
	for section: AsterStructure in _game.walls:
		var cost := absf(section.global_position.x - global_position.x)
		if section.blocking:
			if climber:
				var mount: AsterTurret = section.support
				cost += -3.5 if is_instance_valid(mount) and mount.hp > 0.0 else 3.0
			else:
				cost += 7.0 + 3.5 * section.hp / section.max_hp
		if cost < best:
			best = cost
			chosen = section
	return chosen

func _seek_front(delta: float) -> void:
	_updated -= delta
	if not is_instance_valid(wall) or _updated <= 0.0:
		_updated = 0.44
		wall = _choose_wall()
	var point := AsterArt.horizontal(global_position)
	var ready_line := Vector3(wall.global_position.x + _formation_offset.x, 0, AsterTerrain.FRONT_APPROACH_Z + _formation_offset.y)
	if point.distance_to(ready_line) < 0.38:
		state = &"approach"
		return
	if point.z < AsterTerrain.FRONT_APPROACH_Z - 0.04:
		# Keep lateral travel in the open desert, ahead of the cliff corners.
		_walk(Vector3(point.x, 0.0, AsterTerrain.FRONT_APPROACH_Z), delta)
	else:
		_walk(ready_line, delta)

func _wall_point(depth: float) -> Vector3:
	return wall.global_position + wall.outward * depth + Vector3.RIGHT * _formation_offset.x

func _approach_wall(delta: float) -> void:
	if _engage_player(delta):
		return
	if not climber and wall.blocking:
		_updated -= delta
		if _updated <= 0.0:
			_updated = 0.44
			var entry := _choose_wall()
			if not entry.blocking:
				wall = entry
				state = &"front"
				return
	var outside := _wall_point(1.02 + _formation_offset.y)
	var distance := AsterArt.horizontal(global_position - outside).length()
	if distance > 0.20:
		_walk(outside, delta)
		return
	if not wall.blocking:
		if wall.hp > 0.0 and not climber and not wall.gate_open:
			_hit(wall)
		state = &"cross"
	elif climber:
		state = &"climb"
	else:
		_turn(-wall.outward, delta)
		_stop(delta)
		_hit(wall)

func _cross_wall(delta: float) -> void:
	var inside := _wall_point(-AsterStructure.INSIDE_CLEARANCE)
	if wall.blocking and (global_position - wall.global_position).dot(wall.outward) > -0.45:
		state = &"approach"
		return
	if AsterArt.horizontal(global_position - inside).length() <= 0.22:
		state = &"inside"
		return
	if not climber and wall.hp > 0.0 and not wall.gate_open and not wall.blocking and global_position.distance_to(wall.global_position) < 1.2:
		_hit(wall)
	_walk(inside, delta)

func _climb(delta: float) -> void:
	if not wall.blocking:
		state = &"drop" if global_position.y > 0.2 else &"cross"
		return
	var face := _wall_point(0.89)
	var top := face + Vector3.UP * (AsterStructure.WALL_HEIGHT + 0.035)
	global_position = global_position.move_toward(top, _balance.climb_speed * delta)
	_turn(-wall.outward, delta)
	_climb_pitch = lerpf(_climb_pitch, PI * 0.46, delta * 9.0)
	if global_position.distance_to(top) < 0.07:
		state = &"ledge"

func _ledge(delta: float) -> void:
	_climb_pitch = move_toward(_climb_pitch, 0.0, delta * 7.0)
	var turret: AsterTurret = wall.support
	if is_instance_valid(turret) and turret.hp > 0.0 and wall.blocking:
		_turn(-wall.outward, delta)
		_hit(turret)
		return
	var inside := _wall_point(-AsterStructure.INSIDE_CLEARANCE) + Vector3.UP * global_position.y
	global_position = global_position.move_toward(inside, _speed * delta)
	if global_position.distance_to(inside) < 0.10:
		state = &"drop"

func _drop(delta: float) -> void:
	global_position.y = move_toward(global_position.y, 0.035, delta * 6.2)
	_climb_pitch = move_toward(_climb_pitch, 0.0, delta * 6.0)
	if global_position.y <= 0.04:
		state = &"inside" if (global_position - wall.global_position).dot(wall.outward) < 0.0 else &"approach"

func _attack_core(delta: float) -> void:
	if _engage_player(delta):
		return
	if not climber and _find_nearby_platform():
		return
	var core: AsterStructure = _game.core
	var offset := global_position - core.global_position
	var face := Vector3(clampf(offset.x, -AsterStructure.CORE_HALF.x, AsterStructure.CORE_HALF.x), 0, clampf(offset.z, -AsterStructure.CORE_HALF.z, AsterStructure.CORE_HALF.z))
	var direction := AsterArt.horizontal(offset - face)
	var distance := direction.length()
	if distance <= ATTACK_REACH:
		_turn(-direction, delta)
		_stop(delta)
		_hit(core)
	else:
		_walk(core.global_position + face + direction.normalized() * 0.73, delta)

func _find_nearby_platform() -> bool:
	for turret: AsterTurret in _game.turrets:
		if not turret.direct_ramp or not is_instance_valid(turret.wall) or turret.hp <= 0.0 or turret.rebuilding:
			continue
		var foot := AsterTerrain.ramp_point(turret.wall, AsterTerrain.RAMP_START)
		if global_position.distance_squared_to(foot) > 10.24:
			continue
		if AsterArt.ray(get_world_3d(), hit_point(), foot + Vector3.UP * 0.55, AsterArt.SOLID).is_empty():
			_ramp_turret = turret
			state = &"ramp"
			return true
	return false

func _attack_platform(delta: float) -> void:
	var mount := _ramp_turret.wall
	var offset := global_position - mount.global_position
	var depth := -offset.dot(mount.outward)
	var foot := AsterTerrain.ramp_point(mount, AsterTerrain.RAMP_START)
	if _ramp_turret.hp <= 0.0 or _ramp_turret.rebuilding:
		if global_position.y < 0.08:
			state = &"inside"
			return
		_move_on_platform(mount, depth, AsterTerrain.RAMP_START, delta)
		return
	if global_position.y < 0.08 and AsterArt.horizontal(global_position - foot).length() > 0.20:
		_walk(foot, delta)
		return
	var station_depth := 1.36
	if depth > station_depth + 0.08:
		_move_on_platform(mount, depth, station_depth, delta)
	else:
		var target := _ramp_turret.attack_position()
		_turn(target - global_position, delta)
		if AsterArt.ray(get_world_3d(), hit_point(), target, AsterArt.SOLID).is_empty():
			_hit(_ramp_turret)

func _move_on_platform(mount: AsterStructure, depth: float, destination: float, delta: float) -> void:
	var point := AsterTerrain.ramp_point(mount, move_toward(depth, destination, _speed * delta * 0.72))
	_turn(point - global_position, delta)
	global_position = point + Vector3.UP * 0.035
	velocity = Vector3.ZERO

func _engage_player(delta: float) -> bool:
	var player: AsterPlayer = _game.player
	if not player.alive or absf(player.global_position.y - global_position.y) > 1.20:
		return false
	var point := player.global_position
	var distance := AsterArt.horizontal(point - global_position).length()
	if distance > 4.2 or maxf(absf(point.x), absf(point.z)) > 16.0 or _lure_cooldown > 0.0:
		return false
	if not AsterArt.ray(get_world_3d(), hit_point(), point + Vector3.UP * 0.9, AsterArt.SOLID).is_empty():
		return false
	if _lure_left == 0.0:
		_lure_left = 1.65
	if _lure_left <= delta:
		_lure_cooldown = 2.2
	if distance <= ATTACK_REACH:
		_turn(point - global_position, delta)
		_stop(delta)
		_hit(player)
	else:
		_walk(point, delta)
	return true

func _hit(target_node: Node) -> void:
	_attack_contact = true
	if _attack_target == target_node:
		if _windup_left > 0.0:
			return
		_attack_target = null
		_strike_left = STRIKE_TIME
		target_node.damage(_power)
		var contact := hit_point() - global_basis.z * 0.67
		var section := target_node as AsterStructure
		if section != null and not section.is_core:
			var local_contact := section.to_local(contact)
			var outside := section.to_local(global_position).z >= AsterStructure.WALL_CENTER
			local_contact.x = clampf(local_contact.x, -AsterStructure.WALL_LENGTH * 0.5, AsterStructure.WALL_LENGTH * 0.5)
			local_contact.z = AsterStructure.OUTER_FACE if outside else AsterStructure.OUTER_FACE - AsterStructure.WALL_DEPTH
			if section.is_gate:
				local_contact.z = AsterStructure.GATE_PANEL_DEPTH * (0.5 if outside else -0.5)
			contact = section.to_global(local_contact)
		var on_player := target_node is AsterPlayer
		var cue := AsterSound.BugCue.PLAYER_HIT if on_player else AsterSound.BugCue.STRUCTURE_HIT
		_game.sound.bug_cue(cue, contact)
		if not on_player:
			_game.dust.impact(contact)
		return
	if _attack_target != null:
		_attack_target = null
		_windup_left = 0.0
	if _attack > 0.0:
		return
	_attack_target = target_node
	_windup_left = WINDUP_TIME
	_attack = maxf(_balance.bug_attack_period, WINDUP_TIME + STRIKE_TIME)
	_game.sound.bug_cue(AsterSound.BugCue.WINDUP, hit_point())

func _stop(delta: float) -> void:
	_walk(global_position, delta)

func _walk(point: Vector3, delta: float) -> void:
	var offset := AsterArt.horizontal(point - global_position)
	var direction := offset.normalized()
	var speed_now := minf(_speed * speed_factor, offset.length() / delta)
	var stagger := smoothstep(0.48, 1.85, offset.length())
	var gait := direction
	if stagger > 0.0 and state in [&"incoming", &"front", &"approach", &"inside"]:
		gait = direction.lerp(_game.assault.spacing_velocity(self, direction), stagger)
	velocity.x = gait.x * speed_now
	velocity.z = gait.z * speed_now
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	_turn(gait, delta)
	move_and_slide()

func _turn(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.0001:
		rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), 10.0 * delta)

func _update_legs(delta: float) -> void:
	var moving := velocity.length_squared() > 0.3 or state == &"climb" or state == &"ledge" or state == &"ramp"
	_phase += delta * (15.2 if moving else 4.2)
	var bob := 0.038 if moving else 0.009
	_chassis_lift = lerpf(_chassis_lift, bob, minf(1.0, delta * 9.0))
	var windup := smoothstep(0.0, 1.0, 1.0 - _windup_left / WINDUP_TIME) if _attack_target != null else 0.0
	var strike := smoothstep(0.0, 1.0, _strike_left / STRIKE_TIME)
	var flinch := _flash / 0.16
	_look.position.y = cos(_phase * 2.0) * _chassis_lift + windup * 0.086
	_look.position.z = windup * 0.11 - strike * 0.23 + flinch * 0.06
	_look.rotation.x = _climb_pitch + windup * 0.19 - strike * 0.28
	_look.rotation.z = sin(_phase) * (_chassis_lift * 0.87 + flinch * 0.065)
	for index in range(_legs.size()):
		var side := -1.0 if index < 3 else 1.0
		var leg := _legs[index]
		var socket := index % 3
		var phase := _phase + (0.0 if side < 0.0 else PI)
		if socket == 0:
			leg.rotation = Vector3(-0.12 + windup * 0.63 - strike * 0.65 + sin(phase) * 0.07, side * (0.10 + windup * 0.44 - strike * 0.30), -side * (0.06 + windup * 0.23))
		else:
			phase += 2.66 if socket == 2 else 0.0
			var stride := 0.45 if moving else 0.029
			var sweep := side * (-0.25 if socket == 1 else 0.16)
			leg.rotation = Vector3(stride * sin(phase), sweep, side * maxf(0.0, cos(phase)) * stride * 0.31)
