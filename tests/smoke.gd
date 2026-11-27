extends SceneTree

const GAME := preload("res://scenes/outpost.tscn")
var game: Node
var player: AsterPlayer
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred(&"_run")

func _expect(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("PASS ", name)
	else:
		failures += 1
		printerr("FAIL ", name)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _fresh(run_assault := false) -> void:
	if is_instance_valid(game):
		current_scene = null
		game.free()
	game = GAME.instantiate()
	game.balance = game.balance.duplicate()
	root.add_child(game)
	current_scene = game
	player = game.player
	game.assault._rng.seed = 723
	game.assault._flyer_rng.seed = 724
	game.assault.set_physics_process(run_assault)
	await _frames(5)

func _go(point: Vector3, limit: int = 360) -> bool:
	Input.action_press(&"forward")
	var arrived := false
	for index in range(limit):
		var direction := AsterArt.horizontal(point - player.global_position)
		if direction.length() < 0.23:
			arrived = true
			break
		player.rotation.y = atan2(-direction.x, -direction.z)
		await physics_frame
	Input.action_release(&"forward")
	await _frames(15)
	if not arrived:
		printerr("PATH ", point, " blocked at ", player.global_position)
	return arrived

func _warp(point: Vector3) -> void:
	player.global_position = point
	player.velocity = Vector3.ZERO
	await _frames(3)

func _aim(point: Vector3) -> void:
	var direction := (point - player.eye.global_position).normalized()
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.eye.rotation.x = asin(direction.y)
	await _frames(5)

func _press(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(3)

func _run() -> void:
	await _fresh()
	await _assets_are_live()
	await _fresh()
	await _logistics()
	await _fresh()
	await _rampart_access()
	await _fresh()
	await _aim_and_tags()
	await _fresh()
	await _movement()
	await _fresh()
	await _tuning_and_points()
	await _fresh()
	await _turret_specialists()
	await _fresh()
	await _oversized_drone_delivery()
	await _fresh()
	await _rifle_tuning_tab()
	await _fresh()
	await _daylight_support_and_hospital()
	await _fresh()
	await _turret_sustained_fire()
	await _fresh()
	await _ballistics()
	await _fresh()
	await _creature_combat()
	await _fresh()
	await _player_aggro()
	await _fresh()
	await _flying_bugs()
	await _fresh()
	await _wall_stages()
	await _fresh()
	await _gate_and_mountain()
	await _fresh(true)
	await _continuous_siege()
	await _fresh()
	await _mountain_routes()
	await _fresh(true)
	await _cap_and_replacements()
	await _fresh(true)
	await _spacing()
	await _fresh(true)
	await _screen_when_scouting()
	await _fresh()
	await _turret_visibility()
	await _fresh()
	await _navigation()
	await _fresh()
	await _respawn()
	await _main_menu_flow()
	print("ASTER CHECKS ", checks - failures, "/", checks)
	quit(0 if failures == 0 else 1)

func _assets_are_live() -> void:
	var carbine: MeshInstance3D = player.get("_rifle").get_node("carbine")
	_expect(carbine.mesh.get_surface_count() >= 6 and carbine.layers == AsterModels.VIEWMODEL_LAYER, "first-person view uses the detailed imported carbine mesh")
	var mapped := false
	for index in range(carbine.mesh.get_surface_count()):
		var finish := carbine.mesh.surface_get_material(index) as StandardMaterial3D
		var tangent: PackedFloat32Array = carbine.mesh.surface_get_arrays(index)[Mesh.ARRAY_TANGENT]
		mapped = mapped or (finish.albedo_texture == AsterModels.PARKERIZED and finish.roughness_texture == AsterModels.PARKERIZED_ROUGHNESS and finish.normal_enabled and not tangent.is_empty())
	_expect(mapped, "imported carbine has weathered metal, roughness and tangent-space normals")
	_expect(player._rifle_magazine.get_parent() == carbine.get_parent() and player._support_hand.get_parent() == carbine.get_parent(), "magazine and support hand are independent parts of the carbine rig")
	var grip := player._rifle.get_node("carbine_grip") as MeshInstance3D
	_expect(grip.layers == AsterModels.VIEWMODEL_LAYER and grip.position == AsterPlayer.FIRING_GRIP, "the firing hand mounts separately to the new carbine")
	var triangles := carbine.mesh.get_faces()
	var clear_sight := true
	var open_stock := true
	var sight_from := Vector3(0, AsterPlayer.SIGHT_HEIGHT, 0.2)
	var sight_to := Vector3(0, AsterPlayer.SIGHT_HEIGHT, -1.05)
	var stock_from := Vector3(-0.25, -0.08, 0.31)
	var stock_to := Vector3(0.25, -0.08, 0.31)
	for index in range(0, triangles.size(), 3):
		var a := triangles[index]
		var b := triangles[index + 1]
		var c := triangles[index + 2]
		clear_sight = clear_sight and Geometry3D.segment_intersects_triangle(sight_from, sight_to, a, b, c) == null
		open_stock = open_stock and Geometry3D.segment_intersects_triangle(stock_from, stock_to, a, b, c) == null
	_expect(clear_sight and open_stock, "the optic and stock have real unobstructed openings in the baked mesh")
	var flash := player._gun_flash
	var flash_material := flash.mesh.surface_get_material(0) as StandardMaterial3D
	_expect(flash.position == AsterPlayer.MUZZLE and flash.get_aabb().end.z <= 0.0 and not flash_material.no_depth_test,
		"rifle flash geometry stays in front of the muzzle and is occluded by the weapon")
	var mount: AsterTurret = game.turrets[0]
	var head: Node3D = mount.get("_head")
	var elevation: Node3D = mount.get("_elevation")
	_expect(head.has_node("turret_head") and mount._carriage.has_node("turret_emitters") and mount._carriage.get_parent() == elevation and elevation.get_parent() == head, "new turret meshes follow independent aim pivots")
	var turret_mesh: MeshInstance3D = head.get_node("turret_head")
	var sensor_found := false
	var scanner_found := false
	for index in range(turret_mesh.mesh.get_surface_count()):
		var finish := turret_mesh.mesh.surface_get_material(index) as StandardMaterial3D
		sensor_found = sensor_found or (finish.resource_name == "SignalLamp" and finish.emission_enabled)
		scanner_found = scanner_found or (finish.resource_name == "TurretScanLamp" and finish.emission_enabled)
	_expect(sensor_found and scanner_found, "turret optics and status lamps light up on the moving head")
	var emitters := mount._carriage.get_node("turret_emitters") as MeshInstance3D
	var barrel_front := emitters.get_aabb().position.z
	_expect(absf(barrel_front - AsterTurret.MUZZLE.z) < 0.015, "turret muzzle effects align with the front of the new barrel mesh")
	_expect(mount._kit._mounted_box.visible and not mount._kit._ammo_boxes[0].is_visible_in_tree(), "a stock turret shows its mounted ammunition cartridge")
	var wall: AsterStructure = game.walls[0]
	var body: Node3D = wall.get("_body_visual")
	_expect(body.has_node("wall") and game.supply.has_node("supply") and game.tuning_terminal.has_node("station"), "base wall, supply rack and terminal use baked meshes in the real scene")
	var actor: AsterBug = game.assault.spawn_enemy(Vector3(-6, 0.05, 29))
	var shell: MeshInstance3D = actor.get("_shell")
	var legs: Array = actor.get("_legs")
	_expect(shell.mesh.get_surface_count() >= 3 and legs.size() == 6 and legs[0].has_node("claw_left") and legs[3].has_node("claw_right") and legs[1].has_node("leg_left") and legs[5].has_node("leg_right"), "insect attaches four stride legs and two separate foreclaws")
	var chitin := false
	var amber_eyes := false
	for index in range(shell.mesh.get_surface_count()):
		var finish := shell.mesh.surface_get_material(index) as StandardMaterial3D
		chitin = chitin or (finish.albedo_texture == AsterModels.CHITIN and finish.normal_texture == AsterModels.CHITIN_NORMAL)
		amber_eyes = amber_eyes or (finish.resource_name == "DuneEyeLamp" and finish.emission_enabled)
	var stinger := actor._sting.get_node("bug_sting") as MeshInstance3D
	var stinger_finish := stinger.mesh.surface_get_material(0) as StandardMaterial3D
	_expect(chitin and amber_eyes and stinger_finish.albedo_texture == AsterModels.CHITIN and actor._tail.has_node("bug_tail"),
		"the beetle has a chitin shell, amber eyes and an armored two-part tail")
	var environment := actor.get_world_3d().environment
	_expect(environment.sky.sky_material is ShaderMaterial and AsterModels.floor_finish().normal_texture == AsterModels.CANYON_GRAVEL_NORMAL, "scene uses the daylight sky and textured canyon ground")
	await _frames(2)
	_expect(actor._tail.rotation.length_squared() > 0.0 and absf(actor._sting.rotation.x) > 0.0, "the lower and upper tail articulate during the bug's movement")

func _last_local_sound() -> AudioStream:
	var sound: AsterSound = game.sound
	return sound._players[posmod(sound._next - 1, sound._players.size())].stream

func _last_service_sound() -> AudioStreamPlayer3D:
	var sound: AsterSound = game.sound
	return sound._service_voices[posmod(sound._next_service - 1, sound._service_voices.size())]

func _logistics() -> void:
	_expect(game.turrets.size() == 18 and game.dreadnoughts.size() == 6 and game.walls.size() == 7 and game.assault.enemies.is_empty(), "startup: seven wall sections, eighteen automatic turrets and six artillery installations")
	var has_ramp_sign := false
	for label: Label3D in game.find_children("*", "Label3D", true, false):
		has_ramp_sign = has_ramp_sign or "ПЛОЩАДКА" in label.text.to_upper()
	_expect(not has_ramp_sign, "the two ramps remain without platform signs")
	_expect(root.get_camera_3d() == player.eye, "first-person camera is active")
	var quiet_cursor: int = game.sound._next
	await _frames(16)
	_expect(game.sound._next == quiet_cursor, "standing still emits no footsteps")
	var through_yard := await _go(Vector3(0, 0, -5.10))
	var rack: Vector3 = game.supply.global_position
	_expect(rack.distance_to(Vector3(10.986, 0.0, -10.557)) < 0.10 and through_yard and await _go(rack + Vector3.BACK * 1.85),
		"the player can walk from spawn to the marked rear supply position")
	_expect(_last_local_sound() in game.sound._sand_steps, "walking the yard plays a sand footstep")
	var normal_speed := player.move_speed()
	player.reserve = 0
	var magazine_before := player.magazine
	await _frames(4)
	_expect(player.reserve == game.balance.rifle_reserve and player.magazine == magazine_before, "supply fills rifle reserve only")
	await _press(&"interact", 4)
	_expect(is_equal_approx(player.move_speed(), normal_speed), "the ammunition supply no longer gives the operator cargo")
	await _press(&"fire", 5)
	_expect(player.magazine == magazine_before - 1, "rifle works at the supply rack")
	await _press(&"reload", 85)
	_expect(player.magazine == game.balance.rifle_magazine, "rifle reload works")
	_expect(_last_local_sound() == game.sound._clips[&"rifle_reload_seat"], "seating the rifle magazine plays its mechanical cue")
	var left_path := true
	for point: Vector3 in [Vector3(-8, 0, 3.94), Vector3(-8, 0, 10.72)]:
		if not await _go(point):
			left_path = false
			break
	var left: AsterTurret = game.turrets[0]
	_expect(left_path and player.global_position.y > 2.9 and player.interaction.can_reach(left), "walk from supply up to left turret")
	_expect(_last_local_sound() in game.sound._deck_steps, "crossing the ramp and top deck switches footstep banks")
	var right_path := true
	for point: Vector3 in [Vector3(-8, 0, 3.99), Vector3(8.0, 0, 3.99), Vector3(8.0, 0, 10.72)]:
		if not await _go(point):
			right_path = false
			break
	var right: AsterTurret = game.turrets[1]
	_expect(right_path and player.global_position.y > 2.9 and player.interaction.can_reach(right), "walk across yard up to right turret")
	await _aim(right.attack_position())
	right.damage(32)
	var damaged := right.hp
	player.set_tool(2)
	await _press(&"fire", 9)
	_expect(right.hp > damaged, "aimed repair works on a turret with automated ammunition supply")
	right.rounds = right.capacity()
	await _press(&"interact", 246)
	_expect(right.rounds == right.capacity() and right.has_box and right._kit._mounted_box.visible, "holding E cannot unload the mounted cartridge")

func _hold_fire(allowed: AsterTurret = null) -> void:
	for turret: AsterTurret in game.turrets:
		if turret != allowed:
			turret.rounds = 0
			turret.drone.flight = AsterAmmoDrone.Flight.LOADING
			turret.drone._loading = INF

func _rampart_access() -> void:
	var left: AsterTurret = game.turrets[2]
	var right: AsterTurret = game.turrets[3]
	var mounts: Array[float] = []
	for turret: AsterTurret in game.turrets.slice(0, 5):
		_expect(turret.wall.support == turret and is_equal_approx(turret.global_position.y, AsterStructure.WALL_HEIGHT) and is_equal_approx(turret.global_position.z, AsterTerrain.FRONT_Z), turret.title + " mounts on the lower front line")
		mounts.append(turret.global_position.x)
	mounts.sort()
	_expect(mounts == [-12.0, -8.0, 0.0, 8.0, 12.0] and AsterStructure.WALL_DEPTH >= 3.65, "five symmetric mounts share the front wall")
	var foot := Vector3(-8, 0, 3.55)
	await _go(foot)
	var ascended := await _go(Vector3(-8, 0, 10.33))
	var reached_left := await _go(Vector3(left.position.x, 0, 10.33))
	_expect(ascended and reached_left and absf(player.global_position.y - AsterStructure.WALL_HEIGHT) < 0.09 and player.interaction.can_reach(left), "left ramp reaches the outer turret by walking on the wall")
	left.destroy()
	_expect(left.repair(left.max_hp) and not left.rebuilding and left.rounds == 0, "outer turret can be rebuilt on an intact wall")
	_expect(is_instance_valid(left.drone), "rebuilding retains the turret's original supply drone")
	game.gate.toggle_gate()
	var crossed := await _go(Vector3(right.position.x, 0, 10.33))
	_expect(crossed and absf(player.global_position.y - AsterStructure.WALL_HEIGHT) < 0.09 and player.interaction.can_reach(right), "player crosses over the open gate to the other outer turret")
	var reached_ramp := await _go(Vector3(8, 0, 10.33))
	var descended := await _go(Vector3(8, 0, 3.55))
	_expect(reached_ramp and descended and player.global_position.y < 0.20, "right ramp leads down into the yard")
	right.rounds = 0
	_expect(is_instance_valid(right.drone) and game.turret_tuning.upgrade_level(AsterTurretTuning.Path.DRONE) == 0, "an outer turret has a drone without buying a rank")
	await _frames(780)
	_expect(right.drone.flights_completed > 0 and right.rounds > 0, "a drone can deliver a crate to the far end of the rampart")
	_expect(_last_service_sound().stream == game.sound._clips[&"turret_seat"], "a successful drone reload also plays the turret completion cue")

func _aim_and_tags() -> void:
	_expect(ProjectSettings.get_setting("display/window/size/mode") == DisplayServer.WINDOW_MODE_FULLSCREEN, "the exported project requests fullscreen at startup")
	_expect(root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and root.content_scale_size == Vector2i(1920, 1080), "fullscreen uses the project's 1080p base render resolution")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(5)
	_expect(player.aim_amount > 0.0 and player.aim_amount < 1.0 and player.eye.fov < game.balance.hip_fov, "right mouse starts a gradual sight transition")
	await _frames(13)
	var viewmodel: Node3D = player.get("_weapon_slot")
	_expect(is_equal_approx(player.eye.fov, game.balance.aim_fov) and absf(viewmodel.position.x) < 0.001, "held aim centers the optic and narrows camera FOV")
	var previous_yaw := player.rotation.y
	player.look(Vector2(30, 0))
	_expect(is_equal_approx(previous_yaw - player.rotation.y, player.sensitivity * 30.0 * game.balance.aim_sensitivity_factor), "mouse look applies aim sensitivity")
	_expect(is_equal_approx(player.move_speed(), game.balance.player_speed * game.balance.aim_speed_factor), "aiming slows movement")
	var previous_ammo := player.magazine
	await _press(&"fire", 5)
	_expect(player.magazine == previous_ammo - 1 and player.aim_amount == 1.0, "left mouse fires while right mouse stays held")
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(14)
	_expect(is_equal_approx(player.eye.fov, game.balance.hip_fov) and is_equal_approx(viewmodel.position.x, AsterPlayer.HIP_POSITION.x), "release returns to normal FOV and weapon pose")
	Input.action_press(&"aim")
	await _frames(14)
	await _press(&"repair", 2)
	_expect(player.tool == 2 and player.aim_amount == 0.0 and is_equal_approx(player.eye.fov, game.balance.hip_fov), "repair tool never zooms while aim is held")
	await _press(&"rifle", 2)
	await _frames(14)
	await _press(&"reload", 2)
	await _frames(14)
	_expect(player.reload_left > 0.0 and player.aim_amount == 0.0, "reload lowers a raised optic")
	Input.action_release(&"aim")
	await _frames(19)
	_expect(player._rifle_magazine.position.y < AsterPlayer.MAGAZINE_SEAT.y - 0.10 and player._support_hand.position.distance_to(AsterPlayer.SUPPORT_GRIP) > 0.18 and viewmodel.rotation.z > 0.20, "reload tilts the carbine while the off hand removes the magazine")
	await _frames(41)
	_expect(player.reload_left == 0.0 and player.magazine == game.balance.rifle_magazine and player._rifle_magazine.position.is_equal_approx(AsterPlayer.MAGAZINE_SEAT) and player._support_hand.position.is_equal_approx(AsterPlayer.SUPPORT_GRIP), "reload reseats the magazine and returns the off hand to the grip")

	var wall: AsterStructure = game.walls[0]
	var tower: AsterTurret = game.turrets[0]
	_expect(wall.find_children("*", "Sprite3D", true, false).is_empty() and tower.find_children("*", "Sprite3D", true, false).is_empty(),
		"wall and turret condition has no floating meters")
	wall.damage(wall.max_hp * 0.5)
	tower.damage(tower.max_hp * 0.6)
	tower.rounds = int(game.balance.turret_capacity * 0.25)
	await _frames(3)
	var layers: Node3D = tower._kit._round_layers[0]
	_expect(wall.damage_stage == 2 and tower._damage_heavy.visible and layers.get_child(1).visible and not layers.get_child(2).visible,
		"damage marks the wall and turret, and cartridges thin out as their ammunition drops")
	wall.damage(wall.hp)
	tower.destroy()
	await _frames(3)
	_expect(not wall.blocking and tower._wreck.visible and not tower._complete.visible, "destroyed defenses leave damaged models")

func _movement() -> void:
	_expect(player.magazine == 100 and player.reserve == 500, "rifle begins with a 100-round magazine and 500 reserve")
	var controls := InputMap.action_get_events(&"crouch")
	var shift := InputMap.action_get_events(&"sprint")
	_expect(controls[0].physical_keycode == KEY_CTRL and shift[0].physical_keycode == KEY_SHIFT, "Ctrl and Shift are bound to the new movement controls")
	Input.action_press(&"sprint")
	Input.action_press(&"forward")
	await _frames(28)
	var stride := AsterArt.horizontal(player.velocity).length()
	_expect(player.sprinting and stride > game.balance.player_speed * 1.4, "forward sprint accelerates the physical player")
	Input.action_press(&"aim")
	await _frames(12)
	_expect(not player.sprinting and player.aim_amount > 0.9, "aiming cancels sprint")
	Input.action_release(&"aim")
	Input.action_release(&"sprint")
	Input.action_release(&"forward")
	await _warp(Vector3(-5.0, 0.06, -6.0))
	Input.action_press(&"crouch")
	await _frames(17)
	var body: CollisionShape3D = player.get("_body_collision")
	var shape: CapsuleShape3D = body.shape
	_expect(player.crouching and is_equal_approx(player.eye.position.y, AsterPlayer.CROUCH_EYE) and is_equal_approx(shape.height, AsterPlayer.CROUCH_HEIGHT), "holding Ctrl lowers both camera and collision capsule")
	_expect(is_equal_approx(player.move_speed(), game.balance.player_speed * game.balance.crouch_speed_factor), "crouch reduces walking speed")
	var ceiling := AsterArt.collider(game, Vector3(2.3, 0.21, 2.3), player.global_position + Vector3.UP * 1.42, AsterArt.SOLID)
	await _frames(4)
	Input.action_release(&"crouch")
	await _frames(18)
	_expect(player.crouching, "player cannot stand up inside a low ceiling")
	ceiling.queue_free()
	await _frames(18)
	_expect(not player.crouching and is_equal_approx(player.eye.position.y, AsterPlayer.STAND_EYE), "clearing the ceiling restores standing")

func _reach_tuning() -> void:
	var point: Vector3 = game.tuning_terminal.global_position
	await _warp(point + Vector3.BACK * 1.85 + Vector3.UP * 0.08)
	await _aim(point + Vector3.UP)
	await _press(&"interact", 5)

func _tuning_and_points() -> void:
	var left: AsterTurret = game.turrets[0]
	var right: AsterTurret = game.turrets[1]
	var tuning: AsterTurretTuning = game.turret_tuning
	var all_stock := true
	for turret: AsterTurret in game.turrets:
		all_stock = all_stock and turret.tuning == game.turret_tunings[turret.tuning.type] and is_instance_valid(turret.drone)
	for path in range(AsterTuningPanel.TITLES.size()):
		all_stock = all_stock and tuning.upgrade_level(path) == 0
	all_stock = all_stock and is_equal_approx(tuning.stat(AsterTurretTuning.Path.RATE), 7.2)
	_expect(all_stock, "automatic turrets start with their shared type profile and an individual drone")
	_expect(not game.purchase_tuning(tuning, AsterTurretTuning.Path.RATE), "purchases are unavailable away from tuning terminal")
	_hold_fire()
	var rifle_target: AsterBug = game.assault.spawn_enemy(Vector3(0, 0.03, 4.8))
	rifle_target.set_physics_process(false)
	await _aim(rifle_target.hit_point())
	await _press(&"fire", 65)
	_expect(game.combat_points == 15 and game.kills == 1, "first rifle kill awards 15 base points")
	right.rounds = 15
	var turret_target: AsterBug = game.assault.spawn_enemy(right.wall.global_position + Vector3.BACK * 8.0 + Vector3.UP * 0.05)
	turret_target.set_physics_process(false)
	await _frames(160)
	_expect(game.combat_points == game.balance.combat_points_per_kill * 2 and game.kills == 2 and game.points == game.balance.respawn_points, "turret kill awards the same points without affecting respawns")
	_expect(game.hud._score.text == str(game.combat_points), "combat points are shown on the HUD")
	await _reach_tuning()
	_expect(game.tuning_open and paused and game.hud._tuning.visible, "E at the combined terminal opens and pauses the tuning interface")
	var before: int = game.combat_points
	_expect(not game.purchase_tuning(tuning, AsterTurretTuning.Path.RATE) and game.combat_points == before, "unaffordable upgrades neither debit nor change level")

	game.combat_points = 20000
	var panel: AsterTuningPanel = game.hud._tuning
	var rate_module: Node3D = left._kit._parts[AsterTurretTuning.Path.RATE]
	_expect(not rate_module.visible and panel._buy.size() == 6 and panel._status.text == "Универсальная оборона", "terminal presents six shared upgrade paths")
	var price := tuning.upgrade_price(AsterTurretTuning.Path.RATE)
	_expect(price == 47 and panel._buy[AsterTurretTuning.Path.RATE].text.begins_with("47"), "turret upgrades display prices 30 percent above the previous prices")
	_expect(not game.purchase_tuning(right, AsterTurretTuning.Path.RATE), "the terminal accepts only the shared turret tuning target")
	panel._buy[AsterTurretTuning.Path.RATE].pressed.emit()
	var all_installed := true
	for turret: AsterTurret in game.turrets.slice(0, 5):
		all_installed = all_installed and turret._kit._parts[AsterTurretTuning.Path.RATE].visible
	_expect(tuning.upgrade_level(AsterTurretTuning.Path.RATE) == 1 and all_installed and game.combat_points == 20000 - price, "one purchase adds the upgrade to every Thresher and debits once")
	_expect(tuning.upgrade_price(AsterTurretTuning.Path.RATE) == 85, "higher levels also increase by 30 percent")
	for path: int in [AsterTurretTuning.Path.DAMAGE, AsterTurretTuning.Path.RANGE, AsterTurretTuning.Path.CAPACITY, AsterTurretTuning.Path.STABILITY]:
		var base := tuning.stat(path)
		_expect(game.purchase_tuning(tuning, path) and tuning.stat(path) > base, "purchased tuning increases " + AsterTuningPanel.TITLES[path])
	var first_module_scale := rate_module.scale.x
	_expect(left.capacity() == right.capacity() and left.capacity() > 1000 and left.rounds == 0, "shared capacity upgrades do not create rounds")
	_expect(left._kit._ammo_boxes[0].visible and not left._kit._ammo_boxes[1].visible, "level one adds one external ammo box")
	for index in range(2):
		game.purchase_tuning(tuning, AsterTurretTuning.Path.CAPACITY)
	_expect(left._kit._ammo_boxes[0].visible and left._kit._ammo_boxes[1].visible, "third capacity upgrade adds the second box")

	left.has_box = false
	left.rounds = 0
	left.drone.flight = AsterAmmoDrone.Flight.PARKED
	_expect(game.purchase_tuning(tuning, AsterTurretTuning.Path.DRONE), "the shared drone upgrade can be purchased once")
	var drone := left.drone
	var drone_stops := {}
	for turret: AsterTurret in game.turrets:
		if is_instance_valid(turret.drone):
			drone_stops[turret.drone._pickup()] = true
	_expect(drone_stops.size() == game.turrets.size(), "every turret gets a drone with a distinct pickup position")
	var payload_one := tuning.stat(AsterTurretTuning.Path.DRONE)
	var speed_one := tuning.drone_speed()
	_expect(game.purchase_tuning(tuning, AsterTurretTuning.Path.DRONE) and left.drone == drone and tuning.stat(AsterTurretTuning.Path.DRONE) > payload_one and tuning.drone_speed() > speed_one, "higher drone level improves payload and speed without spawning extras")
	for index in range(AsterTurretTuning.MAX_LEVEL):
		game.purchase_tuning(tuning, AsterTurretTuning.Path.RATE)
	_expect(tuning.upgrade_level(AsterTurretTuning.Path.RATE) == AsterTurretTuning.MAX_LEVEL and tuning.upgrade_price(AsterTurretTuning.Path.RATE) == 0, "tuning levels stop at the cap")
	_expect(AsterTurretTuning.MAX_LEVEL == 5 and rate_module.scale.x > first_module_scale and is_equal_approx(tuning.stat(AsterTurretTuning.Path.RATE), 34.8), "rank five enlarges the visible upgrade and doubles the previous maximum cadence")
	var maximum := [34.8, 56.0, 120.0, 6400.0, 1300.0, 0.81]
	for path in range(maximum.size()):
		_expect(is_equal_approx(tuning.stat(path, AsterTurretTuning.MAX_LEVEL), maximum[path]), "maximum stat for " + AsterTuningPanel.TITLES[path])
	_expect(is_equal_approx(tuning.drone_speed(AsterTurretTuning.MAX_LEVEL), 46.0), "maximum drone speed doubles")
	panel._close.pressed.emit()
	_expect(not game.tuning_open and not paused, "closing the terminal returns to live play")
	left.has_box = false
	var entered_supply := false
	for index in range(470):
		await physics_frame
		if drone.flight == AsterAmmoDrone.Flight.LOADING:
			entered_supply = drone.global_position.distance_to(game.supply.global_position) < 3.0
			break
	_expect(entered_supply and left.rounds == 0, "drone flies from the turret to the real supply rack before filling")
	for frame in range(365):
		await physics_frame
		if drone.flights_completed > 0:
			break
	_expect(left.has_box and left.rounds == roundi(tuning.stat(AsterTurretTuning.Path.DRONE)) and drone.flights_completed == 1, "return flight installs ammunition on an empty turret")
	var full := left.capacity()
	left.rounds = full - 4
	_expect(left.receive_drone_ammo(80) == 4 and left.rounds == full, "air deliveries cannot overfill a turret")

func _turret_specialists() -> void:
	const Type = AsterTurretTuning.Type
	const Path = AsterTurretTuning.Path
	var counts := [0, 0, 0, 0]
	for turret: AsterTurret in game.turrets:
		counts[turret.tuning.type] += 1
	_expect(counts == [5, 3, 4, 6], "the fort installs the full automatic turret family")
	_hold_fire()
	var stinger: AsterTurret = game.turrets[5]
	var dragonfly: AsterTurret = game.turrets[8]
	var bulba: AsterTurret = game.turrets[12]
	var world := player.get_world_3d()
	var elevated := true
	for turret: AsterTurret in game.turrets.slice(5):
		var position := turret.global_position
		var deck := AsterArt.ray(world, position + Vector3.UP, position - Vector3.UP, AsterArt.SOLID)
		elevated = elevated and position.y >= 6.50 and not deck.is_empty() and position.distance_to(deck.position) < 0.02
	_expect(elevated, "all thirteen specialists sit on their physical roofs or platforms")
	var at := Vector3(stinger.position.x, 0.06, 31)
	var near: AsterBug = game.assault.spawn_enemy(at + Vector3(3, 0, -2))
	var farther: AsterBug = game.assault.spawn_enemy(at + Vector3(3, 0, 2))
	near.max_hp = 200
	farther.max_hp = 320
	farther.hp = 12
	for bug in [near, farther]:
		bug.set_physics_process(false)
	var pivot := stinger._head.global_position
	_expect(stinger._find_enemy([near, farther], pivot) == farther, "Stinger prioritizes maximum health over distance and remaining health")
	near.max_hp = farther.max_hp
	_expect(stinger._find_enemy([farther, near], pivot) == near, "Stinger breaks maximum-health ties by distance")
	var flyer: AsterBug = game.assault.spawn_enemy(at + Vector3(0, 9, 0), AsterBug.Kind.FLYER)
	flyer.set_physics_process(false)
	_expect(dragonfly._find_enemy([near, farther], dragonfly._head.global_position) == null and dragonfly._find_enemy([near, flyer], dragonfly._head.global_position) == flyer, "Dragonfly tracks flying targets only")
	farther.max_hp = 400
	stinger.rounds = 1
	dragonfly.rounds = 4
	var near_health := near.hp
	var flyer_health := flyer.hp
	await _frames(180)
	_expect(stinger.shots_fired == 1 and not is_instance_valid(farther) and near.hp == near_health, "Stinger fires on the sturdier target")
	var gauss := false
	for voice: AudioStreamPlayer3D in game.sound._turret_voices:
		gauss = gauss or (voice.stream != null and voice.stream == AsterSound._gauss_wave)
	_expect(gauss and AsterSound._gauss_wave.data.size() > 4000, "Stinger plays a dedicated positional Gauss discharge")
	_expect(dragonfly.shots_fired > 0 and flyer.hp < flyer_health, "Dragonfly fires on the airborne target")
	near.hp = 275
	var aim: Vector3 = near.hit_point()
	var solid_cover := AsterArt.collider(game, Vector3(30, 3.8, 0.65), Vector3(0, 1.9, aim.z - 3.2), AsterArt.SOLID)
	await _frames(3)
	_expect(not AsterArt.ray(bulba.get_world_3d(), bulba._head.global_position, aim, AsterArt.SOLID).is_empty(), "line to the rocket target is blocked")
	bulba.rounds = 1
	await _frames(255)
	_expect(bulba.shots_fired == 1 and is_instance_valid(near) and near.hp < 275, "Bulba arcs a rocket over cover and damages the target")
	var first_scorch: MeshInstance3D = game.effects._scorches.front() if not game.effects._scorches.is_empty() else null
	_expect(game.effects._next_blast > 0 and is_instance_valid(first_scorch) and first_scorch.mesh.get_surface_count() == 1, "a Bulba impact creates a dedicated blast and a ground-conforming scorch")
	near.hp = 2500
	var next_bulba: AsterTurret = game.turrets[13]
	var last_bulba: AsterTurret = game.turrets[14]
	next_bulba.rounds = 3
	last_bulba.rounds = 2
	var launch_at: Array[int] = []
	var shots := 0
	for frame in range(240):
		await physics_frame
		var launched := next_bulba.shots_fired + last_bulba.shots_fired
		while shots < launched:
			launch_at.append(frame)
			shots += 1
		if shots == 5:
			break
	var sequential := launch_at.size() == 5
	for index in range(1, launch_at.size()):
		sequential = sequential and launch_at[index] - launch_at[index - 1] >= 16
	_expect(sequential and next_bulba.rounds == 0 and last_bulba.rounds == 0, "Bulba launches full and partial salvos one rocket at a time across the battery")
	_expect(is_instance_valid(first_scorch), "the scorch stays after the initial smoke clears")

	solid_cover.queue_free()
	bulba.rounds = 0
	bulba.drone.flight = AsterAmmoDrone.Flight.PARKED
	await _frames(840)
	_expect(bulba.drone.flights_completed > 0, "a roof battery still receives ammunition from the supply rack")
	await _frames(230)
	_expect(not is_instance_valid(first_scorch), "the scorch mark fades and frees its mesh")

	await _reach_tuning()
	game.combat_points = 5000
	var panel: AsterTuningPanel = game.hud._tuning
	panel._select_turret(Type.STINGER)
	var damage := stinger.tuning.stat(Path.DAMAGE)
	_expect(game.purchase_tuning(stinger.tuning, Path.DAMAGE) and stinger.tuning.stat(Path.DAMAGE) > damage and dragonfly.tuning.upgrade_level(Path.DAMAGE) == 0 and game.turret_tuning.upgrade_level(Path.DAMAGE) == 0, "upgrades are isolated by turret type")
	panel._select_turret(Type.DREADNOUGHT)
	var artillery: AsterDreadnought = game.dreadnoughts[0]
	var range_before := artillery.tuning.stat(Path.RANGE)
	_expect(panel._support_panel.visible and game.purchase_tuning(artillery.tuning, Path.RANGE) and artillery.tuning.stat(Path.RANGE) > range_before and game.dreadnoughts[5].tuning == artillery.tuning, "the Dreadnought tab upgrades every bastion independently of automatic turrets")
	game.set_tuning(false)

func _oversized_drone_delivery() -> void:
	var turret: AsterTurret = game.turrets[0]
	var tuning: AsterTurretTuning = game.turret_tuning
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		tuning.apply_upgrade(AsterTurretTuning.Path.DRONE)
	var drone := turret.drone
	for rounds_before: int in [150, 0]:
		var deliveries := drone.flights_completed
		var carried_full_load := false
		turret.rounds = rounds_before
		for frame in range(360):
			await physics_frame
			carried_full_load = carried_full_load or drone.payload == 1300
			if drone.flights_completed > deliveries:
				break
		_expect(carried_full_load and drone.flights_completed == deliveries + 1 and turret.rounds == 1000 and drone.payload == 0,
			"drone fills a 1000-round turret from %d with an oversized 1300-round shipment" % rounds_before)
	await _frames(15)
	_expect(drone.flight == AsterAmmoDrone.Flight.PARKED, "the drone parks once the ammunition crate is full")

func _rifle_tuning_tab() -> void:
	_hold_fire()
	var tuning := player.rifle_tuning
	var point: Vector3 = game.tuning_terminal.global_position
	await _warp(point + Vector3.BACK * 1.85 + Vector3.UP * 0.08)
	await _aim(point + Vector3.UP)
	await _press(&"interact", 5)
	var panel: AsterTuningPanel = game.hud._tuning
	panel._rifle_tab.pressed.emit()
	_expect(game.tuning_open and game.rifle_tuning_open and paused and panel._cards[3].visible and not panel._cards[4].visible, "combined terminal switches to the four rifle upgrade cards")
	_expect(not game.purchase_tuning(tuning, AsterRifleTuning.Path.RATE), "rifle tuning respects available funds")
	_expect(tuning.upgrade_price(AsterRifleTuning.Path.RATE) == 60 and panel._buy[AsterRifleTuning.Path.RATE].text.begins_with("60"), "rifle upgrades display prices 30 percent above the previous prices")
	game.combat_points = 10000
	_expect(not game.purchase_tuning(game.turret_tuning, AsterTurretTuning.Path.RATE), "the rifle tab cannot purchase turret ranks")
	for path in range(4):
		var base := tuning.stat(path)
		var before: int = game.combat_points
		var price := tuning.upgrade_price(path)
		panel._buy[path].pressed.emit()
		_expect(tuning.upgrade_level(path) == 1 and tuning.stat(path) > base and game.combat_points == before - price and tuning._modules[path].visible and tuning._rank_parts[path][0].visible and not tuning._rank_parts[path][1].visible, "rifle buy applies stat and shows rank-one model for path %d" % path)
		for index in range(4):
			game.purchase_tuning(tuning, path)
		_expect(tuning.upgrade_level(path) == 5 and tuning._rank_parts[path][4].visible and not game.purchase_tuning(tuning, path), "rifle path %d shows the fifth upgrade and caps spending" % path)
	game.set_tuning(false)
	var start_reserve := player.reserve
	var start_magazine := player.magazine
	var at := Vector3(0, 0.07, 3.4)
	await _warp(Vector3(0, 0.07, 7.5))
	var target: AsterBug = game.assault.spawn_enemy(at)
	target.set_physics_process(false)
	var hp := target.hp
	await _aim(target.hit_point())
	await _press(&"fire", 1)
	_expect(target.hp == hp - tuning.stat(AsterRifleTuning.Path.DAMAGE) and player.magazine == start_magazine - 1 and player.reserve == start_reserve, "upgraded damage is used by the real rifle projectile")
	_expect(player._recoil < 0.04 and player._shot_timer < 0.085, "upgraded recoil and cadence affect the live shot")

func _daylight_support_and_hospital() -> void:
	_hold_fire()
	_hold_fire()
	var world := player.get_world_3d()
	var spacing := true
	var supports := true
	for index in range(game.dreadnoughts.size()):
		var at: Vector3 = game.dreadnoughts[index].global_position
		var deck := AsterArt.ray(world, at + Vector3.UP, at + Vector3.DOWN, AsterArt.SOLID)
		supports = supports and not deck.is_empty() and absf(deck.position.y - at.y) < 0.16
		if index >= 2:
			var inner: Vector3 = game.dreadnoughts[index - 2].global_position
			spacing = spacing and is_equal_approx(at.distance_to(inner), 11.10)
	_expect(spacing and supports, "both wings have three equally spaced artillery installations mounted on physical bastion decks")
	var cycle: AsterDaylight = game.daylight
	_expect(cycle.elapsed < 1.0 and AsterDaylight.PHASE_LENGTH == 720.0 and cycle._sun.basis.z.dot(AsterDaylight.EAST) > 0.95,
		"the match starts at the marked east horizon with 12-minute phases")
	cycle.set_clock(AsterDaylight.PHASE_LENGTH * 0.5)
	var day_fixtures := 0
	for light in cycle._fixtures:
		day_fixtures += int(light.visible)
	cycle.set_clock(AsterDaylight.PHASE_LENGTH * 1.5)
	var night_fixtures := 0
	for light in cycle._fixtures:
		night_fixtures += int(light.visible)
	_expect(day_fixtures == 0 and night_fixtures == cycle._fixtures.size() and night_fixtures >= 24,
		"night switches on the fixed projectors, both sides of the wall, and turret headlights")
	player.damage(45.0)
	var hurt := player.hp
	await _warp(game.field_hospital.global_position + Vector3(0, 0.07, 1.85))
	await _frames(65)
	_expect(player.hp > hurt + 12.0 and player.hp < game.balance.player_hp, "the field hospital heals a nearby living player gradually")

	var artillery: AsterDreadnought = game.dreadnoughts[0]
	var director: AsterAssault = game.assault
	var target := director.spawn_enemy(Vector3(-7, 0.05, 42.0))
	target.set_physics_process(false)
	target.hp = 1800.0
	var neighbor := director.spawn_enemy(Vector3(-6.0, 0.05, 42.0))
	neighbor.set_physics_process(false)
	neighbor.hp = 500.0
	await _frames(30)
	_expect(artillery.shots_fired == 0, "the heavy guns remain idle next to an eligible target")
	game.combat_points = 80
	await _reach_tuning()
	_expect(game.purchase_support(0) and game.combat_points == 40 and not game.tuning_open, "the shared terminal debits 40 points and starts a call")
	_expect(not artillery.call_salvos(director.enemies), "the same heavy gun rejects overlapping calls")
	await _frames(560)
	_expect(artillery.shots_fired == 3 and (not is_instance_valid(neighbor) or neighbor.hp < 500.0) and not artillery.busy(), "three direct-fire salvos damage nearby bugs and return to ready")
	target = director.spawn_enemy(Vector3(-7, 0.05, 43.0))
	target.set_physics_process(false)
	await _reach_tuning()
	var funds: int = game.combat_points
	_expect(game.purchase_support(0) and game.combat_points == funds - 40, "support can be purchased again after the series")
	var east: AsterDreadnought = game.dreadnoughts[5]
	var east_target := director.spawn_enemy(Vector3(east.global_position.x, 0.07, 45.0))
	east_target.set_physics_process(false)
	east_target.hp = 4500.0
	game.combat_points = AsterDreadnought.PRICE
	await _reach_tuning()
	var panel: AsterTuningPanel = game.hud._tuning
	panel._select_turret(AsterTurretTuning.Type.DREADNOUGHT)
	_expect(panel._support_panel.visible and panel._support.size() == 6 and not panel._support[5].disabled, "the terminal offers a separate control for each bastion")
	panel._support[5].pressed.emit()
	_expect(east.busy() and not game.tuning_open and game.combat_points == 0, "the outer east bastion starts from its own terminal control")
	await _frames(560)
	_expect(east.shots_fired == 3 and east_target.hp < 4500.0, "the added bastion completes a live artillery series")

func _turret_sustained_fire() -> void:
	var turret: AsterTurret = game.turrets[0]
	var tuning: AsterTurretTuning = game.turret_tuning
	_hold_fire(turret)
	var target: AsterBug = game.assault.spawn_enemy(turret.wall.global_position + Vector3.BACK * 10.0 + Vector3.UP * 0.08)
	target.hp = 90000.0
	target.set_physics_process(false)
	turret.drone.flight = AsterAmmoDrone.Flight.LOADING
	turret.drone._loading = INF
	var stock_rounds := 100
	var first_second := Engine.physics_ticks_per_second
	var frame_margin := 18
	turret.rounds = stock_rounds
	await _frames(first_second)
	_expect(turret.shots_fired >= 6 and turret.shots_fired <= 8, "stock turret fires sustained automatic bursts")
	var stock_duration := ceili((stock_rounds - 1) * first_second / tuning.stat(AsterTurretTuning.Path.RATE))
	await _frames(stock_duration + frame_margin - first_second)
	_expect(turret.shots_fired == stock_rounds and turret.rounds == 0 and not turret.ready_to_fire(), "stock turret maintains its cadence until the crate is empty")
	_expect(not turret._kit._round_layers[0].get_child(0).visible, "empty mounted crate shows no cartridge layers")
	await _reach_tuning()
	game.combat_points = 5000
	for index in range(AsterTurretTuning.MAX_LEVEL):
		game.purchase_tuning(tuning, AsterTurretTuning.Path.RATE)
	var tuned_rounds := 180
	turret.receive_drone_ammo(tuned_rounds)
	var last := turret.shots_fired
	game.set_tuning(false)
	await _frames(first_second)
	_expect(turret.shots_fired - last >= 33 and turret.shots_fired - last <= 36, "a turret with max fire rate resumes at the doubled cadence after a crate change")
	var tuned_duration := ceili((tuned_rounds - 1) * first_second / tuning.stat(AsterTurretTuning.Path.RATE))
	await _frames(tuned_duration + frame_margin - first_second)
	_expect(turret.shots_fired - last == tuned_rounds and turret.rounds == 0 and not turret.ready_to_fire(), "fully tuned turret maintains its cadence until the crate is empty")

func _ballistics() -> void:
	_hold_fire()
	await _warp(Vector3(-6, AsterStructure.WALL_HEIGHT + 0.055, 10.37))
	var target: AsterBug = game.assault.spawn_enemy(Vector3(-6, 0.05, 32.0))
	target.set_physics_process(false)
	await _aim(target.hit_point())
	var hp := target.hp
	var pitch := player.eye.rotation.x
	player.fire_rifle()
	var ballistics: AsterBallistics = game.ballistics
	_expect(target.hp == hp and ballistics._rounds.size() == 1 and ballistics._cases.size() == 1, "rifle launches a traveling round and ejects a case")
	_expect(player.eye.rotation.x > pitch and player._recoil > 0.0, "rifle firing kicks the camera and the view model")
	var muzzle := ballistics._rounds[0].position
	await _frames(3)
	_expect(target.hp == hp and ballistics._rounds[0].position.distance_to(muzzle) > 2.0, "projectile advances before striking a distant target")
	await _frames(12)
	_expect(target.hp == hp - game.balance.rifle_damage and player.hit_flash > 0.0, "projectile collision applies damage and confirms a hit")
	_expect(ballistics._cases.size() == 1, "casings remain briefly after their rounds impact")
	await _frames(180)
	_expect(ballistics._cases.is_empty() and ballistics._rounds.is_empty(), "expired casings and bullets are recycled")
	var heavy: AudioStreamWAV = game.sound._turret_clips[0]
	var light: AudioStreamWAV = game.sound._rifle_clips[0]
	_expect(heavy.data.size() > light.data.size() and light.data.decode_s16(160) != 0, "original heavy and rifle shots produce distinct PCM clips")
	var turret: AsterTurret = game.turrets[0]
	var shield := AsterArt.collider(game, Vector3(2.0, 2.0, 0.42), Vector3(-6.0, 2.27, 21.5), AsterArt.SOLID)
	turret.rounds = 0
	var shield_hp := target.hp
	await _aim(target.hit_point())
	player.fire_rifle()
	await _frames(16)
	_expect(target.hp == shield_hp and ballistics._rounds.is_empty(), "solid cover stops a flying projectile")
	shield.queue_free()
	await _frames(3)
	turret.rounds = 50
	var exhausted := AsterBallistics.MAX_CASES
	for index in range(exhausted + 20):
		ballistics.fire(player.eye.global_position, Vector3.UP, 2.0, 0.0, false, player.eye.global_position, Vector3.RIGHT)
	_expect(ballistics._cases.size() == exhausted and ballistics._rounds.size() <= AsterBallistics.MAX_ROUNDS, "the firing effects enforce finite budgets")
	for index in range(20):
		await physics_frame
		if turret.shots_fired > 0:
			break
	_expect(turret.shots_fired > 0 and turret._kick > 0.0 and turret._carriage.position.z > 0.0, "turret barrel assembly recoils during automatic fire")

func _last_bug_sound() -> AudioStreamPlayer3D:
	var sound: AsterSound = game.sound
	return sound._bug_voices[posmod(sound._next_bug - 1, sound._bug_voices.size())]

func _creature_combat() -> void:
	_hold_fire()
	var wall: AsterStructure = game.walls[2]
	var bug: AsterBug = game.assault.spawn_enemy(wall.global_position + Vector3(0.0, 0.045, 1.08))
	bug.wall = wall
	bug.state = &"approach"
	bug._voice_left = 0.0
	await _frames(2)
	_expect(_last_bug_sound().stream in game.sound._bug_clips[AsterSound.BugCue.CALL], "nearby living creature plays a positional call")
	var hp := wall.hp
	await _frames(18)
	_expect(bug._windup_left > 0.0 and wall.hp == hp and _last_bug_sound().stream in game.sound._bug_clips[AsterSound.BugCue.WINDUP], "claws wind up with a cue before the strike deals damage")
	await _frames(16)
	var strike_sound := _last_bug_sound()
	_expect(wall.hp < hp and bug._strike_left > 0.0 and strike_sound.stream in game.sound._bug_clips[AsterSound.BugCue.STRUCTURE_HIT], "impact applies damage alongside the attack follow-through and sound")
	_expect(is_equal_approx(wall.to_local(strike_sound.global_position).z, AsterStructure.OUTER_FACE), "the wall impact sound comes from the surface being hit")
	var patient: AsterBug = game.assault.spawn_enemy(Vector3(-5.4, 0.05, 26.2))
	patient.set_physics_process(false)
	await _warp(Vector3(-5.4, AsterStructure.WALL_HEIGHT + 0.06, 10.35))
	await _aim(patient.hit_point())
	var fumes: int = game.effects._next_fume
	player.fire_rifle()
	_expect(player._gun_flash.visible and game.effects._next_fume != fumes, "firing the rifle shows a muzzle flash and emits gas from the muzzle")
	await _frames(14)
	_expect(patient.hp < game.balance.ground_hp and patient._wounds.size() == 1 and patient._bleed_time > 0.0 and game.bug_fx._next_chip > 0, "projectiles leave a point-local wound and throw chitin fragments")
	var drops: int = game.bug_fx._next_drop
	patient._bleed(0.08)
	_expect(game.bug_fx._next_drop != drops, "a fresh wound continues to drip")
	patient.damage(patient.hp)
	_expect(patient._death_left > 0.0 and patient not in game.assault.enemies and _last_bug_sound().stream in game.sound._bug_clips[AsterSound.BugCue.DEATH], "death removes the enemy from play, begins its fall and plays a different cue")
	await _frames(33)
	_expect(not is_instance_valid(patient), "fallen enemies are released after their animation")
	var walker: AsterBug = game.assault.spawn_enemy(Vector3(-5.4, 0.03, 20.8))
	walker._step_travel = 0.75
	var sound: AsterSound = game.sound
	var step_cursor := sound._next_bug_step
	await _frames(8)
	var step_voice := sound._bug_step_voices[posmod(sound._next_bug_step - 1, sound._bug_step_voices.size())]
	_expect(sound._next_bug_step != step_cursor and step_voice.stream in sound._bug_sand_steps and step_voice.global_position.distance_to(walker.global_position) < 1.0, "a moving bug plays a localized claw step on sand")

func _player_aggro() -> void:
	_hold_fire()
	await _warp(Vector3(0, 0.05, 25.0))
	var incoming: AsterBug = game.assault.spawn_enemy(player.global_position + Vector3.BACK * 2.7)
	incoming.set_entry_path(PackedVector3Array([incoming.global_position + Vector3.RIGHT * 6.0]))
	var hp := player.hp
	await _frames(65)
	_expect(player.hp < hp and incoming.state == &"incoming", "an incoming bug leaves its route to chase and hit a nearby player outside the walls")
	await _frames(50)
	hp = player.hp
	await _frames(60)
	_expect(player.hp < hp and player.alive, "an incoming bug keeps attacking a player who stays within reach")
	await _warp(Vector3(0, 0.05, 7.9))
	var x := incoming.global_position.x
	await _frames(25)
	_expect(incoming.global_position.x > x + 0.8, "the bug resumes its entry route when the player leaves")
	incoming.damage(incoming.hp)

	await _warp(Vector3(0, 0.05, 25.0))
	var marching: AsterBug = game.assault.spawn_enemy(player.global_position + Vector3.FORWARD * 0.95)
	hp = player.hp
	await _frames(40)
	_expect(player.hp < hp and marching.global_position.distance_to(player.global_position) < 1.3,
		"a bug marching to the front turns and strikes a player at point-blank range")
	marching.damage(marching.hp)

	var door: Vector3 = game.gate.global_position
	await _warp(door + Vector3(0, 0.05, -0.76))
	var screened: AsterBug = game.assault.spawn_enemy(door + Vector3(0, 0.05, 0.98))
	var start := screened.global_position
	screened.set_entry_path(PackedVector3Array([start + Vector3.BACK * 6.0]))
	hp = player.hp
	await _frames(45)
	_expect(player.hp == hp and screened.global_position.z > start.z + 1.4, "a closed gate screens the player from a nearby bug")

	var mount: AsterTurret = game.turrets[1]
	var ramp := AsterTerrain.ramp_point(mount.wall, 6.0)
	await _warp(ramp + Vector3(0.48, 0.035, 0))
	var raider: AsterBug = game.assault.spawn_enemy(ramp + Vector3(-0.48, 0.035, 0))
	raider._ramp_turret = mount
	raider.state = &"ramp"
	start = raider.global_position
	hp = player.hp
	await _frames(40)
	_expect(player.hp < hp and raider.global_position.is_equal_approx(start), "a bug can strike a nearby player without stepping off the ramp")

func _flying_bugs() -> void:
	_hold_fire()
	var director: AsterAssault = game.assault
	game.balance.active_limit = 12
	for index in range(director.ground_cap()):
		var ground := director.spawn_enemy(Vector3(index * 2.0 - 11.0, 0.05, 30.0))
		ground.set_physics_process(false)
	director.set_physics_process(true)
	var flyer: AsterFlyingBug
	for index in range(150):
		await physics_frame
		for bug in director.enemies:
			if bug is AsterFlyingBug:
				flyer = bug
				break
		if flyer != null:
			break
	_expect(flyer != null and director.enemies.size() - director.flyer_count == director.ground_cap(),
		"the opening siege launches flyers even when all ground slots are taken")
	if flyer == null:
		return
	_expect(game.nests.size() == 10 and flyer.state == &"launch" and flyer.global_position in game.nests,
		"the flying bug starts on one of ten mountain nests before taking off")
	await _frames(180)
	_expect(director.flyer_count >= 3 and director.elapsed < 6.0, "airborne waves keep arriving at the opening siege cadence")
	director.set_physics_process(false)
	for bug in director.enemies:
		if bug != flyer:
			bug.set_physics_process(false)
	var wing := flyer._wings[0].rotation.z
	await _frames(8)
	_expect(not is_equal_approx(flyer._wings[0].rotation.z, wing) and flyer._tail.has_node("flyer_tail"),
		"the airborne model animates separate wings and a hanging tail")
	var hp := player.hp
	for index in range(2100):
		if player.hp < hp:
			break
		await physics_frame
	_expect(player.hp < hp and game.gate.blocking and game.gate.hp == game.gate.max_hp and flyer.global_position.z < game.gate.global_position.z,
		"a flyer crosses the closed perimeter and dives at the player")
	if player.hp >= hp:
		return
	flyer.set_physics_process(false)
	var start := flyer.global_position.y
	var origin := player.eye.global_position
	game.fire_round(origin, origin.direction_to(flyer.hit_point()), 20.0, flyer.hp + 1.0, false, origin, Vector3.RIGHT)
	await _frames(22)
	_expect(flyer.hp == 0.0 and flyer not in director.enemies and flyer.global_position.y < start,
		"a rifle round kills a flyer and drops it from the air")

	var turret: AsterTurret = game.turrets[0]
	var raider := director.spawn_enemy(turret.global_position + Vector3(0, 3.1, 5.0), AsterBug.Kind.FLYER) as AsterFlyingBug
	_expect(raider._choose_victim() == player, "flyers choose the living player ahead of defenses")
	player.alive = false
	_expect(raider._choose_victim() == turret, "flyers switch to the nearest live turret while the player is down")
	await _frames(160)
	_expect(turret.hp < turret.max_hp, "a flying bug damages the turret it chose")
	for mount: AsterTurret in game.turrets:
		mount.destroy()
	raider.global_position = game.core.global_position + Vector3(0, 1.65, 4.2)
	_expect(raider._choose_victim() == game.core, "a flying bug falls back to buildings after the turrets are gone")
	await _frames(135)
	_expect(game.core.hp < game.core.max_hp, "a flying bug can damage the bunker gate")

func _wall_stages() -> void:
	var wall: AsterStructure = game.walls[4]
	_expect(wall.damage_stage == 0 and not wall._damage_visual.visible, "intact wall has a clean exterior")
	wall.damage(wall.max_hp * 0.22)
	_expect(wall.damage_stage == 1 and wall._damage_stages[0].visible and not wall._damage_stages[1].visible, "lightly damaged wall shows individual cracks")
	wall.damage(wall.max_hp * 0.28)
	_expect(wall.damage_stage == 2 and wall._damage_stages[1].visible and not wall._damage_stages[2].visible, "moderate damage exposes chipped concrete")
	wall.damage(wall.max_hp * 0.28)
	_expect(wall.damage_stage == 3 and wall._damage_stages[2].visible and wall.blocking, "critical damage exposes the reinforcement while the section still blocks")
	wall.repair(wall.max_hp * 0.6)
	_expect(wall.damage_stage == 1 and not wall._damage_stages[2].visible, "partial repair clears critical damage visuals as health recovers")
	wall.repair(wall.max_hp)
	_expect(wall.damage_stage == 0 and not wall._damage_visual.visible, "complete repair restores the clean exterior")

func _gate_and_mountain() -> void:
	var gate: AsterStructure = game.gate
	var door := gate.global_position
	var from := door + Vector3.UP
	var outside := door + Vector3.BACK * 2.25
	var inside := door + Vector3.FORWARD * 2.25
	var world := player.get_world_3d()
	var left_rock := AsterArt.ray(world, Vector3(0, 1.05, 6), Vector3(-18, 1.05, 6), AsterArt.SOLID)
	var right_rock := AsterArt.ray(world, Vector3(0, 1.05, 6), Vector3(18, 1.05, 6), AsterArt.SOLID)
	var rear_rock := AsterArt.ray(world, Vector3(-4, 1.05, 4), Vector3(-4, 1.05, -18), AsterArt.SOLID)
	_expect(not left_rock.is_empty() and not right_rock.is_empty() and not rear_rock.is_empty(), "solid mountain covers left flank, right flank and rear")
	var core: AsterStructure = game.core
	var bunker := AsterArt.ray(world, Vector3(0, 1.05, 4), Vector3(0, 1.05, -18), AsterArt.SOLID)
	_expect(not bunker.is_empty() and bunker.collider.get_meta(&"target", null) == core and bunker.position.z < -AsterTerrain.FRONT_Z,
		"the rear cliff opens into a recessed, damageable bunker gate")
	var frontline := true
	for section: AsterStructure in game.walls:
		frontline = frontline and section.outward == Vector3.BACK and is_equal_approx(section.global_position.z, AsterTerrain.FRONT_Z)
	_expect(frontline and game.turrets[0].wall.outward == game.turrets[1].wall.outward, "all defenses face the one desert front")
	_expect(gate.blocking and not gate.gate_open, "main gate starts closed")
	await _warp(inside + Vector3.UP * 0.08)
	await _aim(from)
	await _press(&"interact", 6)
	_expect(gate.gate_open and not gate.blocking and AsterArt.ray(world, inside + Vector3.UP, outside + Vector3.UP, AsterArt.SOLID).is_empty(), "E opens gate from inside and removes its collision")
	_expect(await _go(outside), "player walks out through the open gate")
	await _aim(from)
	await _press(&"interact", 6)
	_expect(not gate.gate_open and gate.blocking, "E closes the gate from outside")
	await _press(&"forward", 42)
	_expect(player.global_position.z > door.z + 0.62, "closed gate physically stops a player")
	await _press(&"interact", 6)
	_expect(gate.gate_open, "E opens gate from outside while standing by closed panels")
	await _warp(door + Vector3.UP * 0.08)
	await _press(&"interact", 6)
	_expect(gate.gate_open and not gate.blocking, "gate refuses to close on a player in the opening")
	_expect(await _go(inside), "player walks in through the open gate")
	await _aim(from)
	await _press(&"interact", 6)
	_expect(gate.blocking, "player can close the gate after stepping clear")
	var tower: AsterTurret = game.turrets[1]
	await _warp(tower.global_position - Vector3.BACK * 1.30 + Vector3.UP * 0.08)
	var reached_desert := await _go(Vector3(tower.global_position.x, 0, door.z + 3.35))
	await _frames(45)
	_expect(reached_desert and player.global_position.y < 0.25, "player drops from the turret wall to the desert")
	await _go(outside)
	await _aim(from)
	await _press(&"interact", 6)
	_expect(gate.gate_open and await _go(inside), "player can reenter after falling outside")
	_hold_fire()
	await _warp(Vector3(-9, 0.08, -8))
	var bug: AsterBug = game.assault.spawn_enemy(door + Vector3.BACK * 10.0 + Vector3.UP * 0.06)
	var health := gate.hp
	await _frames(710)
	_expect(is_instance_valid(bug) and bug.state == &"inside" and bug.global_position.z < door.z - 0.4 and gate.hp == health and core.hp < core.max_hp,
		"ground bugs use the open perimeter gate and attack the bunker gate")
	if is_instance_valid(bug):
		bug.damage(bug.hp)
	gate.damage(gate.hp)
	_expect(not gate.gate_open and not gate.blocking, "destroyed gate leaves the opening passable")
	gate.repair(gate.max_hp)
	await _frames(6)
	_expect(gate.blocking and not gate.gate_open, "repair restores the gate in the closed position")

func _continuous_siege() -> void:
	var director: AsterAssault = game.assault
	var population := director.target_population(director.ground_cap())
	var interval := director.spawn_interval()
	var observed := {}
	var hidden := true
	var min_x := INF
	var max_x := -INF
	for index in range(690):
		await physics_frame
		for bug: AsterBug in director.enemies:
			var id := bug.get_instance_id()
			if observed.has(id):
				continue
			observed[id] = true
			if not bug is AsterFlyingBug:
				min_x = minf(min_x, bug.global_position.x)
				max_x = maxf(max_x, bug.global_position.x)
				hidden = hidden and bug.global_position.z >= 138.0 and not AsterArt.ray(player.get_world_3d(), player.eye.global_position, bug.global_position, AsterArt.SPAWN_SCREEN).is_empty()
	_expect(observed.size() >= 7 and director.elapsed > 11.0, "an untouched match continuously deploys attackers automatically")
	_expect(hidden and max_x - min_x > 32.0, "initial ground attackers emerge from several distant caves")
	_expect(director.target_population(director.ground_cap()) > population and director.spawn_interval() < interval, "spawn population rises and delay falls with survived time")
	_expect(game.hud._phase.text.begins_with("ОСАДА") and "На поле" in game.hud._objective.text, "HUD reports elapsed siege and active enemy counts")
	for index in range(2500):
		if game.kills > 0:
			break
		await physics_frame
	_expect(game.kills > 0 and not game.lost, "stock turrets earn points in a real automatic siege")

func _mountain_routes() -> void:
	_hold_fire()
	var director: AsterAssault = game.assault
	director._scatter(6)
	_expect(director._cave_routes.size() == 8, "all eight caves have a screened, walkable exit")
	var actors: Array[AsterBug] = []
	for route in director._cave_routes:
		var bug := director.spawn_enemy(route[0])
		bug.set_entry_path(route.slice(1))
		actors.append(bug)
	await _frames(2550)
	var reached_apron := true
	for bug in actors:
		reached_apron = reached_apron and bug.state != &"incoming" and bug.global_position.z < 39.0
	_expect(not actors.is_empty() and reached_apron, "ground bugs leave every cave and reach the main approach under real movement physics")

func _cap_and_replacements() -> void:
	_hold_fire()
	game.balance.special_peak_chance = 0.0
	var director: AsterAssault = game.assault
	var ground_cap := 80
	var flyer_cap := 40
	var cap := ground_cap + flyer_cap
	_expect(director.ground_cap() == ground_cap and director.flyer_cap() == flyer_cap and director.active_cap() == cap,
		"the siege caps at 120 bugs with 80 ground bugs and 40 flyers")
	game.balance.active_limit = ground_cap + 26
	player.hp = 100000.0
	game.core.max_hp = 100000.0
	game.core.hp = game.core.max_hp
	for section: AsterStructure in game.walls:
		section.max_hp = 100000.0
		section.hp = section.max_hp
	director.elapsed = game.balance.assault_ramp_time + 1.0
	var highest := 0
	for index in range(2400):
		await physics_frame
		highest = maxi(highest, director.enemies.size())
		if highest >= cap:
			break
	_expect(highest == cap and director.enemies.size() == cap and director.flyer_count == flyer_cap,
		"maximum-pressure siege fills both independent caps")
	var point := Vector3(0, 0, 65)
	_expect(director.spawn_enemy(point) == null and director.spawn_enemy(point, AsterBug.Kind.FLYER) == null,
		"direct spawning enforces both caps")
	for index in range(7):
		var bug: AsterBug = director.enemies[0]
		bug.damage(bug.hp)
	for index in range(650):
		if director.enemies.size() == cap:
			break
		await physics_frame
	_expect(director.enemies.size() == cap and director.flyer_count == flyer_cap and game.kills == 7,
		"continuous replacements refill freed ground and air slots")
	_expect(game.combat_points == 105, "seven kills award only the base reward")
	for index in range(2):
		var bug: AsterBug = director.enemies[0]
		bug.damage(bug.hp)
	_expect(game.kills == 9 and game.combat_points == 135, "ninth kill has no milestone bonus")
	director.enemies[0].damage(director.enemies[0].hp)
	_expect(game.kills == 10 and game.combat_points == 160, "tenth kill adds ten points to its base reward")
	for index in range(10):
		var bug: AsterBug = director.enemies[0]
		bug.damage(bug.hp)
	_expect(game.kills == 20 and game.combat_points == 320, "another ten kills award the same ten-point bonus")

	for index in range(650):
		if director.enemies.size() == cap:
			break
		await physics_frame
	_expect(director.enemies.size() == cap, "all 120 slots refill before the full clear")
	for bug: AsterBug in director.enemies.duplicate():
		bug.damage(bug.hp)
	var empty_frames := 0
	while director.enemies.is_empty() and empty_frames < 150:
		await physics_frame
		empty_frames += 1
	var next_count := director.enemies.size()
	_expect(empty_frames >= 119 and next_count > 0 and next_count < cap, "a full clear gives two seconds before the next group")
	await _frames(45)
	_expect(director.enemies.size() == next_count, "one short pause separates successive ground and air groups")


func _spacing() -> void:
	_hold_fire()
	var director: AsterAssault = game.assault
	game.balance.active_limit = 12
	var actors: Array[AsterBug] = []
	for index in range(12):
		actors.append(director.spawn_enemy(Vector3(0.0, 0.055, 32.0 + index * 0.73)))
	director._rebuild_grid()
	var shove := director.spacing_velocity(actors[1], Vector3.FORWARD)
	_expect(absf(shove.x) > 0.10 and shove.length() > 0.35, "neighbors ahead steer staggered columns sideways and preserve forward motion")
	var close_before := _close_pairs(actors)
	await _frames(190)
	var low := INF
	var high := -INF
	for actor in actors:
		low = minf(low, actor.global_position.x)
		high = maxf(high, actor.global_position.x)
	_expect(_close_pairs(actors) < close_before and high - low > 1.45, "live attackers spread apart while approaching the wall")

func _close_pairs(actors: Array[AsterBug]) -> int:
	var close := 0
	for i in range(actors.size()):
		for j in range(i):
			if actors[i].global_position.distance_squared_to(actors[j].global_position) < 1.65:
				close += 1
	return close

func _screen_when_scouting() -> void:
	_hold_fire()
	player.hp = 100000.0
	await _warp(Vector3(10.0, 0.10, 70.0))
	var observed := {}
	var seen_flyers := false
	var truly_hidden := true
	for index in range(920):
		await physics_frame
		for bug: AsterBug in game.assault.enemies:
			var id := bug.get_instance_id()
			if observed.has(id):
				continue
			observed[id] = true
			seen_flyers = seen_flyers or bug is AsterFlyingBug
			var ray := AsterArt.ray(player.get_world_3d(), player.eye.global_position, bug.global_position, AsterArt.SPAWN_SCREEN)
			if not bug is AsterFlyingBug:
				truly_hidden = truly_hidden and not ray.is_empty() and bug.global_position.distance_to(player.global_position) >= AsterAssault.MIN_SPAWN_DISTANCE - 0.1
	_expect(observed.size() >= 7, "the siege finds alternative hidden positions while the player scouts beyond the ridges")
	_expect(seen_flyers, "flyers can spawn while the player scouts beyond their usual side of the ridges")
	_expect(truly_hidden, "scouting never reveals the ground spawns in direct sight")

func _turret_visibility() -> void:
	var left: AsterTurret = game.turrets[0]
	_hold_fire(left)
	game.balance.turret_range = 175.0
	var director: AsterAssault = game.assault
	var cave := PackedVector3Array()
	for attempt in range(25):
		for route in director._scatter(6):
			if route[0].z > 140.0:
				cave = route
				break
		if not cave.is_empty():
			break
	_expect(not cave.is_empty(), "automatic siege uses the screened cave passage")
	if cave.is_empty():
		return
	var enemy := director.spawn_enemy(cave[0])
	enemy.set_physics_process(false)
	enemy.hp = 1000
	var screened := true
	for turret: AsterTurret in game.turrets:
		screened = screened and not AsterArt.ray(player.get_world_3d(), turret.attack_position(), enemy.hit_point(), AsterArt.SOLID).is_empty()
	await _frames(100)
	_expect(screened and left.shots_fired == 0 and enemy.hp == 1000, "rock blocks fire from the turrets into the cave spawn")
	enemy.global_position = left.wall.global_position + left.wall.outward * 9.0 + Vector3.UP * 0.04
	await _frames(95)
	_expect(left.shots_fired > 0 and enemy.hp < 1000, "same target becomes eligible after entering clear range")
	_hold_fire()
	enemy.global_position = cave[0]
	enemy.set_entry_path(cave.slice(1))
	enemy.set_physics_process(true)
	await _frames(2550)
	_expect(enemy.state != &"incoming" and enemy.global_position.z < 39.0, "a cave attacker rounds the bend and crosses the screening ridges")

func _navigation() -> void:
	var left: AsterTurret = game.turrets[0]
	var right: AsterTurret = game.turrets[1]
	_hold_fire()
	var side: AsterStructure = game.walls[2]
	var ground: AsterBug = game.assault.spawn_enemy(side.global_position + side.outward * 11.0 + Vector3.UP * 0.04)
	await _frames(250)
	_expect(ground.state == &"approach" and side.hp < side.max_hp and ground.global_position.z > 12.4, "ground bug stops at and damages solid wall")
	await _warp(Vector3(-9.1, 0.08, -6.0))
	side.damage(side.hp)
	await _frames(480)
	_expect(ground.state == &"inside" and ground.global_position.z < 11.8 and game.core.hp < game.core.max_hp, "ground bug crosses the breach and attacks the bunker gate")
	ground.damage(ground.hp)
	var climber: AsterBug = game.assault.spawn_enemy(left.wall.global_position + left.wall.outward * 7.0 + Vector3.UP * 0.04, AsterBug.Kind.CLIMBER)
	var ascended := false
	var fastest_rise := 0.0
	var previous_height := climber.global_position.y
	for index in range(240):
		await physics_frame
		fastest_rise = maxf(fastest_rise, climber.global_position.y - previous_height)
		previous_height = climber.global_position.y
		if previous_height > 0.6 and previous_height < 2.75:
			ascended = true
	_expect(ascended and fastest_rise < 0.12 and left.hp < left.max_hp and left.wall.blocking, "climber travels up a solid wall and attacks turret")
	climber.damage(climber.hp)
	var ramp_foot := AsterTerrain.ramp_point(right.wall, AsterTerrain.RAMP_START)
	var raider: AsterBug = game.assault.spawn_enemy(ramp_foot + Vector3.DOWN * 0.7 + Vector3.LEFT * 0.6)
	raider.global_position.y = 0.035
	raider.state = &"inside"
	await _frames(240)
	_expect(raider.global_position.y > 2.9 and right.hp < right.max_hp, "ground bug can reach an accessible turret using the inner ramp")
	raider.damage(raider.hp)
	left.wall.damage(left.wall.hp)
	_expect(left.rebuilding and left.hp == 0 and left.rounds == 0 and not left.has_box, "support wall destruction wipes turret and ammunition")
	_expect(not left.repair(40.0), "turret repair blocked until supporting wall is full")
	await _warp(left.wall.global_position + Vector3.UP * 0.04)
	left.wall.repair(left.wall.max_hp)
	await _frames(8)
	_expect(not left.wall.blocking, "repair waits to restore wall collision if occupied")
	await _warp(Vector3(0, 0.09, 7.9))
	await _frames(8)
	_expect(left.wall.blocking, "wall regains collision after footprint clears")
	left.repair(90)
	left.damage(40)
	_expect(is_equal_approx(left.hp, 50) and left.rebuilding, "incoming damage still applies while structure is rebuilt")
	left.repair(left.max_hp)
	_expect(not left.rebuilding and not left.has_box and left.rounds == 0, "rebuilt turret remains empty")
	var visible: AsterBug = game.assault.spawn_enemy(right.wall.global_position + right.wall.outward * 6 + Vector3.UP * 0.04)
	var initial: float = visible.hp
	await _frames(24)
	_expect(not right.ready_to_fire() and right.shots_fired == 0 and visible.hp == initial, "empty installed box disables turret fire")

func _respawn() -> void:
	game.points = 1
	player.damage(player.hp)
	_expect(game.points == 1 and not player.alive and game.respawn_left > 0.0, "death starts countdown without debiting")
	await _frames(306)
	_expect(game.points == 0 and player.alive and player.hp == game.balance.player_hp and player.magazine == game.balance.rifle_magazine, "respawn restores player and debits once")
	await _frames(20)
	_expect(not game.lost and game.points == 0, "a living player can continue with zero points")
	player.damage(player.hp)
	_expect(game.lost and "возрождения" in game.loss_reason, "next death at zero points ends run")
	await _fresh()
	player.damage(player.hp)
	game.core.damage(game.core.hp)
	await _frames(320)
	_expect(game.lost and not player.alive and game.points == game.balance.respawn_points and "Ворота бункера" in game.loss_reason,
		"destruction of the bunker gate ends the match during respawn")
	game.combat_points = 345
	game.turret_tuning.apply_upgrade(AsterTurretTuning.Path.DAMAGE)
	game.restart()
	await process_frame
	await process_frame
	game = current_scene
	_expect(is_instance_valid(game) and game.assault.elapsed < 1.0 and game.kills == 0 and game.player.alive and game.points == game.balance.respawn_points and game.core.hp == game.core.max_hp and game.combat_points == 0 and game.turret_tuning.upgrade_level(AsterTurretTuning.Path.DAMAGE) == 0, "restart resets the actual startup scene, points and tuning")


func _main_menu_flow() -> void:
	var home_scene := "res://scenes/main_menu.tscn"
	var loading_scene := "res://scenes/loading.tscn"
	_expect(ProjectSettings.get_setting("application/run/main_scene") == loading_scene and ProjectSettings.get_setting("application/boot_splash/image") == "res://assets/aster.png", "application starts with the Aster splash and loading screen")
	change_scene_to_file(loading_scene)
	await scene_changed
	_expect(current_scene.target_scene == home_scene and current_scene._progress.indeterminate, "startup loading screen prepares the main menu")
	await scene_changed
	var menu := current_scene
	_expect(menu._home.visible and not menu._settings.visible and [menu._start.text, menu._map_review.text, menu._options.text, menu._exit.text] == ["Начать игру", "Разметка карты", "Настройки", "Выход"], "startup offers the game, map review, settings, and exit")
	var original_sensitivity := AsterSettings.sensitivity
	var original_volume := AsterSettings.volume
	var original_view_distance := AsterSettings.view_distance
	var menu_view_distance := AsterSettings.MIN_VIEW_DISTANCE if original_view_distance > AsterSettings.MIN_VIEW_DISTANCE else AsterSettings.MIN_VIEW_DISTANCE + AsterSettings.VIEW_DISTANCE_STEP
	menu._options.pressed.emit()
	menu._mouse.value = 0.0042
	menu._volume.value = 0.63
	menu._view_distance.value = menu_view_distance
	_expect(menu._settings.visible and is_equal_approx(AsterSettings.sensitivity, 0.0042) and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.63)), "settings open and sliders reach the real input and audio state")
	menu._mouse.value = original_sensitivity
	menu._volume.value = original_volume
	menu._back.pressed.emit()
	_expect(menu._home.visible and not menu._settings.visible, "settings return to the main menu")
	AsterSettings.view_distance = AsterSettings.MAX_VIEW_DISTANCE
	AsterSettings.load_from_disk()
	_expect(AsterSettings.view_distance == menu_view_distance, "view distance is saved and loaded from the display settings")
	menu._start.pressed.emit()
	await scene_changed
	_expect(current_scene.scene_file_path == loading_scene and current_scene.target_scene == "res://scenes/outpost.tscn", "start shows the outpost loading screen")
	await scene_changed
	game = current_scene
	_expect(is_equal_approx(game.player.eye.far, float(menu_view_distance)), "a new game uses the configured view distance")
	await _frames(58)
	_expect(game.assault.elapsed > 0.8 and not game.assault.enemies.is_empty(), "start opens the actual outpost and activates continuous siege")
	game.set_paused(true)
	game.hud._view_distance.value = AsterSettings.MAX_VIEW_DISTANCE
	_expect(is_equal_approx(game.player.eye.far, float(AsterSettings.MAX_VIEW_DISTANCE))
		and is_equal_approx(game.daylight._environment.fog_depth_end, game.player.eye.far), "the pause slider updates the camera and distance fog immediately")
	game.hud._view_distance.value = original_view_distance
	game.hud._main_menu.pressed.emit()
	await scene_changed
	_expect(current_scene.scene_file_path == home_scene and not paused, "pause returns to the main menu and clears the session pause")
