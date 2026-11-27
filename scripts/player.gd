class_name AsterPlayer
extends CharacterBody3D

const HIP_POSITION := Vector3(0.309, -0.326, -0.57)
const REPAIR_POSITION := Vector3(0.30, -0.30, -0.53)
const FIRING_GRIP := Vector3(0.035, -0.172, 0.134)
const SUPPORT_GRIP := Vector3(-0.074, -0.179, -0.574)
const MAGAZINE_SEAT := Vector3(0, -0.120, -0.268)
const RELOAD_GRIP := Vector3(-0.099, -0.254, -0.276)
const SIGHT_HEIGHT := 0.211
const AIM_POSITION := Vector3(0, -SIGHT_HEIGHT, -0.61)
const MUZZLE := Vector3(0, 0.027, -0.998)
const EJECTION_PORT := Vector3(0.155, 0.049, -0.049)
const REPAIR_TIP := Vector3(0, 0.028, -0.53)
const AIM_TRANSITION := 0.16
const STAND_HEIGHT := 1.69
const CROUCH_HEIGHT := 1.08
const BODY_RADIUS := 0.33
const STAND_EYE := 1.55
const CROUCH_EYE := 0.96

var eye := Camera3D.new()
var hp: float
var magazine: int
var reserve: int
var alive := true
var carrying := false
var tool := 1
var sensitivity := 0.00255
var aim_amount := 0.0
var crouching := false
var sprinting := false
var reload_left := 0.0
var damage_flash := 0.0
var hit_flash := 0.0
var input_enabled := true
var interaction: AsterInteraction
var rifle_tuning := AsterRifleTuning.new()
var _game: Node
var _balance: AsterBalance
var _body_collision := CollisionShape3D.new()
var _stand_shape := CapsuleShape3D.new()
var _crouch_shape := CapsuleShape3D.new()
var _head_clearance := CapsuleShape3D.new()
var _sprint_blend := 0.0
var _weapon_slot := Node3D.new()
var _rifle := Node3D.new()
var _repair_tool := Node3D.new()
var _rifle_magazine: MeshInstance3D
var _support_hand: MeshInstance3D
var _gun_flash: MeshInstance3D
var _flash_light: OmniLight3D
var _shot_timer := 0.0
var _repair_beep := 0.0
var _recoil := 0.0
var _view_kick := 0.0
var _walk_phase := 0.0
var _step_remaining := 0.70
var _firing_visual := 0.0

func setup(game: Node, spawn: Vector3) -> void:
	_game = game
	_balance = game.balance
	collision_layer = AsterArt.PLAYER
	collision_mask = AsterArt.SOLID | AsterArt.ACCESS
	floor_snap_length = 0.45
	_stand_shape.radius = BODY_RADIUS
	_stand_shape.height = STAND_HEIGHT
	_crouch_shape.radius = BODY_RADIUS
	_crouch_shape.height = CROUCH_HEIGHT
	_head_clearance.radius = BODY_RADIUS
	_head_clearance.height = STAND_HEIGHT - CROUCH_HEIGHT + 0.30
	_set_stance(false)
	add_child(_body_collision)
	eye.position.y = STAND_EYE
	eye.fov = _balance.hip_fov
	eye.near = 0.055
	eye.far = 186.0
	add_child(eye)
	eye.make_current()
	eye.add_child(_weapon_slot)
	_weapon_slot.position = HIP_POSITION
	_build_tools()
	interaction = AsterInteraction.new()
	interaction.game = game
	interaction.player = self
	add_child(interaction)
	respawn(spawn)

func _build_tools() -> void:
	_weapon_slot.add_child(_rifle)
	_weapon_slot.add_child(_repair_tool)
	AsterModels.attach(_rifle, &"carbine", Vector3.ZERO, Vector3.ONE, false).layers = AsterModels.VIEWMODEL_LAYER
	_rifle_magazine = AsterModels.attach(_rifle, &"carbine_magazine", MAGAZINE_SEAT, Vector3.ONE, false)
	_rifle_magazine.layers = AsterModels.VIEWMODEL_LAYER
	_support_hand = AsterModels.attach(_rifle, &"carbine_support", SUPPORT_GRIP, Vector3.ONE, false)
	_support_hand.layers = AsterModels.VIEWMODEL_LAYER
	AsterModels.attach(_rifle, &"carbine_grip", FIRING_GRIP, Vector3.ONE, false).layers = AsterModels.VIEWMODEL_LAYER
	rifle_tuning.setup(_balance, _rifle)
	AsterModels.attach(_repair_tool, &"repair", Vector3.ZERO, Vector3.ONE, false).layers = AsterModels.VIEWMODEL_LAYER
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.35, 0.24, -0.35)
	fill.light_color = Color("#c9d8eb")
	fill.light_energy = 0.66
	fill.omni_range = 2.4
	fill.light_cull_mask = AsterModels.VIEWMODEL_LAYER
	eye.add_child(fill)
	_gun_flash = AsterEffects.rifle_flash(_rifle, MUZZLE)
	_gun_flash.layers = AsterModels.VIEWMODEL_LAYER
	_gun_flash.hide()
	_flash_light = OmniLight3D.new()
	_flash_light.position = MUZZLE
	_flash_light.light_color = Color("#ffc18a")
	_flash_light.light_energy = 1.8
	_flash_light.omni_range = 1.65
	_flash_light.light_cull_mask = AsterModels.VIEWMODEL_LAYER
	_rifle.add_child(_flash_light)
	_flash_light.hide()
	_repair_tool.hide()

func look(relative: Vector2) -> void:
	var scale := sensitivity * lerpf(1.0, _balance.aim_sensitivity_factor, aim_amount)
	rotate_y(-relative.x * scale)
	eye.rotation.x = clampf(eye.rotation.x - relative.y * scale, -1.51, 1.51)

func take_box() -> bool:
	if not alive or carrying:
		return false
	carrying = true
	return true

func move_speed() -> float:
	var cargo_factor := _balance.cargo_speed_factor if carrying else 1.0
	var stance_factor := _balance.crouch_speed_factor if crouching else (_balance.sprint_speed_factor if sprinting else 1.0)
	return _balance.player_speed * cargo_factor * stance_factor * lerpf(1.0, _balance.aim_speed_factor, aim_amount)

func _physics_process(delta: float) -> void:
	if not alive or not input_enabled or _game.lost:
		return
	var axis := Input.get_vector(&"left", &"right", &"forward", &"back")
	_update_stance(delta, axis)
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	var speed := move_speed()
	velocity.x = move_toward(velocity.x, direction.x * speed, 34.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 34.0 * delta)
	if Input.is_action_just_pressed(&"jump") and is_on_floor() and not crouching:
		velocity.y = _balance.jump_speed
	elif not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()
	_update_footsteps()
	damage_flash = maxf(0.0, damage_flash - delta * 2.0)
	hit_flash = maxf(0.0, hit_flash - delta)
	_shot_timer = maxf(-delta, _shot_timer - delta)
	_repair_beep = maxf(0.0, _repair_beep - delta)
	_firing_visual = maxf(0.0, _firing_visual - delta)
	_gun_flash.visible = _firing_visual > 0.0
	_flash_light.visible = _gun_flash.visible
	_recoil = move_toward(_recoil, 0.0, delta * 0.64)
	_set_view_kick(move_toward(_view_kick, 0.0, delta * 0.24))
	_walk_phase += delta * AsterArt.horizontal(velocity).length() * 1.25
	if global_position.distance_to(_game.supply.global_position) < 3.15:
		reserve = _balance.rifle_reserve
	if Input.is_action_just_pressed(&"rifle"):
		set_tool(1)
	if Input.is_action_just_pressed(&"repair"):
		set_tool(2)
	interaction.tick(delta)
	if _game.tuning_open:
		return
	if reload_left > 0.0:
		_advance_reload(delta)
	var servicing := interaction.stage != &""
	if not servicing and Input.is_action_just_pressed(&"reload") and tool == 1:
		reload_rifle()
	_update_aim(delta, tool == 1 and not servicing and reload_left <= 0.0 and Input.is_action_pressed(&"aim"))
	if not servicing and Input.is_action_pressed(&"fire"):
		if tool == 1:
			fire_rifle()
		else:
			repair_target(delta)

func _update_footsteps() -> void:
	var distance := AsterArt.horizontal(get_position_delta()).length()
	if not is_on_floor() or distance < 0.011:
		_step_remaining = minf(_step_remaining, 0.70)
		return
	_step_remaining -= distance
	if _step_remaining > 0.0:
		return
	_step_remaining += 1.85 if crouching else (3.10 if sprinting else 2.45)
	var foot := global_position
	var hit := AsterArt.ray(get_world_3d(), foot + Vector3.UP * 0.24, foot - Vector3.UP * 0.44, AsterArt.SOLID | AsterArt.ACCESS)
	var surface: CollisionObject3D = hit.get("collider")
	var on_deck := surface != null and bool(surface.get_meta(&"footstep_deck", false))
	_game.sound.step(on_deck, -7.0 if crouching else (2.5 if sprinting else 0.0))

func _update_stance(delta: float, axis: Vector2) -> void:
	var wants_crouch := Input.is_action_pressed(&"crouch")
	if wants_crouch and not crouching:
		_set_stance(true)
	elif crouching and not wants_crouch and _can_stand():
		_set_stance(false)
	sprinting = Input.is_action_pressed(&"sprint") and axis.y < -0.15 and not crouching and aim_amount < 0.05 and not Input.is_action_pressed(&"aim") and not Input.is_action_pressed(&"fire") and interaction.stage == &""
	_sprint_blend = move_toward(_sprint_blend, 1.0 if sprinting else 0.0, delta * 7.0)
	eye.position.y = move_toward(eye.position.y, CROUCH_EYE if crouching else STAND_EYE, delta * 5.0)

func _set_stance(crouched: bool) -> void:
	crouching = crouched
	_body_collision.shape = _crouch_shape if crouched else _stand_shape
	_body_collision.position.y = _capsule_center(CROUCH_HEIGHT if crouched else STAND_HEIGHT)

func _capsule_center(height: float) -> float:
	return height * 0.5 + 0.016

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _head_clearance
	var height := STAND_HEIGHT + 0.016 - _head_clearance.height * 0.5
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * height)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _update_aim(delta: float, aiming: bool) -> void:
	aim_amount = move_toward(aim_amount, 1.0 if aiming else 0.0, delta / AIM_TRANSITION)
	var blend := smoothstep(0.0, 1.0, aim_amount)
	var sway := lerpf(1.0, 0.07, blend)
	var hip_position := HIP_POSITION if tool == 1 else REPAIR_POSITION
	var pose := hip_position.lerp(AIM_POSITION, blend)
	pose.y += (sin(_walk_phase) * 0.021 + _recoil * 0.22) * sway - _sprint_blend * 0.117
	pose.z += _recoil * lerpf(1.0, 0.52, blend)
	var progress := 1.0 - clampf(reload_left / _balance.rifle_reload, 0.0, 1.0)
	var inspection := _pose_reload(progress)
	_weapon_slot.position = pose + inspection * Vector3(-0.032, 0.057, -0.19)
	_weapon_slot.rotation = inspection * Vector3(0.12, 0.36, 0.52) + Vector3(_recoil * 0.41, 0, _recoil * 0.12)
	var fov := lerpf(_balance.hip_fov + _sprint_blend * 5.0, _balance.aim_fov, blend)
	if eye.fov != fov:
		eye.fov = fov

func _pose_reload(progress: float) -> float:
	var tilt := smoothstep(0.0, 0.21, progress) * (1.0 - smoothstep(0.73, 1.0, progress))
	var grip := smoothstep(0.08, 0.26, progress) * (1.0 - smoothstep(0.78, 0.99, progress))
	var draw := smoothstep(0.24, 0.49, progress) * (1.0 - smoothstep(0.56, 0.83, progress))
	var offset := draw * Vector3(-0.073, -0.243, 0.025)
	_rifle_magazine.position = MAGAZINE_SEAT + offset
	_rifle_magazine.rotation = Vector3(0.18, -0.12, -0.22) * draw
	_support_hand.position = SUPPORT_GRIP.lerp(RELOAD_GRIP, grip) + offset * grip
	_support_hand.rotation = Vector3(-0.20, -0.42, 0.49) * grip
	return tilt

func _set_view_kick(value: float) -> void:
	var resting_pitch := eye.rotation.x - _view_kick
	eye.rotation.x = clampf(resting_pitch + value, -1.51, 1.51)
	_view_kick = eye.rotation.x - resting_pitch

func clear_aim() -> void:
	_set_view_kick(0.0)
	_recoil = 0.0
	sprinting = false
	_sprint_blend = 0.0
	aim_amount = 0.0
	eye.fov = _balance.hip_fov
	_weapon_slot.position = HIP_POSITION if tool == 1 else REPAIR_POSITION
	_weapon_slot.rotation = Vector3.ZERO
	_pose_reload(1.0)

func set_tool(slot: int) -> void:
	if slot != tool:
		reload_left = 0.0
		tool = slot
		clear_aim()
	_rifle.visible = slot == 1
	_repair_tool.visible = slot == 2

func reload_rifle() -> void:
	if reload_left <= 0.0 and magazine < _balance.rifle_magazine and reserve > 0:
		reload_left = _balance.rifle_reload
		_game.sound.play(&"rifle_reload_grip")

func _advance_reload(delta: float) -> void:
	var previous := reload_left
	reload_left = maxf(0.0, reload_left - delta)
	var removal := _balance.rifle_reload * 0.68
	var seating := _balance.rifle_reload * 0.18
	if previous > removal and reload_left <= removal:
		_game.sound.play(&"rifle_reload_remove")
	if previous > seating and reload_left <= seating:
		_game.sound.play(&"rifle_reload_seat")
	if reload_left == 0.0:
		var amount := mini(_balance.rifle_magazine - magazine, reserve)
		magazine += amount
		reserve -= amount

func fire_rifle() -> void:
	if interaction.stage != &"" or _shot_timer > 0.0 or reload_left > 0.0:
		return
	if magazine == 0:
		reload_rifle()
		if reload_left == 0.0:
			_shot_timer = 0.3
			_game.sound.play(&"empty")
		return
	magazine -= 1
	_shot_timer += 1.0 / rifle_tuning.stat(AsterRifleTuning.Path.RATE)
	_firing_visual = 0.058
	_gun_flash.scale = Vector3.ONE * randf_range(0.84, 1.16)
	_gun_flash.show()
	_flash_light.show()
	_game.effects.muzzle_gas(_rifle.to_global(MUZZLE), -_rifle.global_basis.z, false)
	var from := eye.global_position
	var spread := lerpf(0.0085, 0.0031, aim_amount) * (1.0 - rifle_tuning.stat(AsterRifleTuning.Path.ACCURACY))
	var disk := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * spread
	var view_direction := (-eye.global_basis.z + eye.global_basis.x * disk.x + eye.global_basis.y * disk.y).normalized()
	var end := from + view_direction * _balance.rifle_range
	var cover := AsterArt.SOLID | AsterArt.ACCESS
	var hit := AsterArt.ray(get_world_3d(), from, end, cover | AsterArt.ENEMY)
	if not hit.is_empty():
		end = hit.position
	var origin := _rifle.to_global(MUZZLE)
	var direction := (end - origin).normalized()
	if from.distance_squared_to(end) <= from.distance_squared_to(origin) or not AsterArt.ray(get_world_3d(), from, origin, cover).is_empty():
		origin = from
		direction = view_direction
	var port := _rifle.to_global(EJECTION_PORT)
	_game.fire_round(origin, direction, _balance.rifle_range, rifle_tuning.stat(AsterRifleTuning.Path.DAMAGE), false, port, _rifle.global_basis.x)
	var kick_scale := 1.0 - rifle_tuning.stat(AsterRifleTuning.Path.RECOIL)
	_recoil = minf(_recoil + 0.068 * kick_scale, 0.14 * kick_scale)
	_set_view_kick(minf(_view_kick + lerpf(0.022, 0.015, aim_amount) * kick_scale, 0.046 * kick_scale))

func repair_target(delta: float) -> void:
	if interaction.stage != &"":
		return
	interaction.refresh()
	var target := interaction.aimed
	if target is AsterStructure or target is AsterTurret:
		if target.repair(_balance.repair_rate * delta) and _repair_beep <= 0.0:
			_repair_beep = 0.13
			var end: Vector3 = target.global_position + Vector3.UP * 0.65
			var ray := AsterArt.ray(get_world_3d(), eye.global_position, eye.global_position - eye.global_basis.z * _balance.repair_range, AsterArt.SOLID | AsterArt.TARGET | AsterArt.ACCESS, true)
			_game.repair_beam(_repair_tool.to_global(REPAIR_TIP), ray.get("position", end))

func damage(amount: float) -> void:
	if not alive or _game.lost:
		return
	hp = maxf(0.0, hp - amount)
	damage_flash = 0.77
	if hp == 0.0:
		alive = false
		carrying = false
		interaction.cancel()
		clear_aim()
		reload_left = 0.0
		remove_from_group(&"wall_occupants")
		set_deferred(&"collision_layer", 0)
		_weapon_slot.hide()
		_game.player_died()

func respawn(spawn: Vector3) -> void:
	_set_stance(false)
	eye.position.y = STAND_EYE
	global_position = spawn
	velocity = Vector3.ZERO
	rotation.y = 0.0
	eye.rotation.x = 0.0
	_view_kick = 0.0
	hp = _balance.player_hp
	magazine = _balance.rifle_magazine
	reserve = _balance.rifle_reserve
	alive = true
	carrying = false
	reload_left = 0.0
	_step_remaining = 0.70
	_shot_timer = 0.0
	_recoil = 0.0
	_firing_visual = 0.0
	clear_aim()
	damage_flash = 0.0
	hit_flash = 0.0
	_weapon_slot.show()
	set_tool(1)
	set_deferred(&"collision_layer", AsterArt.PLAYER)
	if not is_in_group(&"wall_occupants"):
		add_to_group(&"wall_occupants")
