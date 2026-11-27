extends SceneTree

const GAME := preload("res://scenes/outpost.tscn")
const Kinds := AsterBug.Kind

var game: Node
var failures := 0

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	await _fresh()
	_check_waves()
	await _fresh()
	await _tank()
	await _fresh()
	await _tank_caves()
	await _fresh()
	await _kamikaze()
	await _fresh()
	await _transporter()
	await _fresh()
	await _ram()
	await _fresh()
	await _shooter()
	await _fresh()
	await _catapult()
	await _fresh()
	await _catapult_cover()
	await _fresh()
	await _catapult_player()
	game.free()
	await process_frame
	print("ASTER SPECIAL BEETLES failures=", failures)
	quit(1 if failures > 0 else 0)

func _fresh() -> void:
	if is_instance_valid(game):
		game.free()
	game = GAME.instantiate()
	game.balance = game.balance.duplicate()
	root.add_child(game)
	game.assault.set_physics_process(false)
	for turret: AsterTurret in game.turrets:
		turret.rounds = 0
		turret.drone.flight = AsterAmmoDrone.Flight.LOADING
		turret.drone._loading = INF
	await _frames(3)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _expect(result: bool, description: String) -> void:
	if result:
		print("PASS ", description)
	else:
		failures += 1
		printerr("FAIL ", description)

func _spawn(kind: AsterBug.Kind, at: Vector3) -> AsterBug:
	return game.assault.spawn_enemy(at, kind)

func _check_waves() -> void:
	var assault: AsterAssault = game.assault
	assault._special_rng.seed = 567
	var early := 0
	var late := 0
	var kinds := {}
	for time: float in [120.0, 280.0, 310.0, 730.0]:
		assault.elapsed = time
		for round in range(2000):
			for flying in [false, true]:
				var kind := assault._wave_kind(flying)
				if kind not in [Kinds.FLYER, Kinds.GROUND]:
					if time == 120.0:
						early += 1
					if time == 730.0:
						late += 1
					if not kinds.has(kind):
						kinds[kind] = time
	_expect(early > 0 and late > early * 3 and kinds.size() == 6 and kinds[Kinds.TANK] == 310.0,
		"specials become more frequent and the Tank starts appearing near minute five")
	game.balance.active_limit = 2
	_spawn(Kinds.KAMIKAZE, Vector3(1, 8, 30))
	_spawn(Kinds.TANK, Vector3(1, 0.04, 27))
	_spawn(Kinds.RAM, Vector3(6, 0.04, 29))
	_expect(assault.flyer_count == 1 and assault.enemies.size() == 3 and _spawn(Kinds.TRANSPORTER, Vector3(5, 8, 30)) == null
		and _spawn(Kinds.SHOOTER, Vector3(7, 0.04, 28)) == null, "normal and special units use the same air and ground caps")

func _tank() -> void:
	var tank := _spawn(Kinds.TANK, Vector3(0, 0.055, 29))
	tank.set_physics_process(false)
	var soldier := _spawn(Kinds.GROUND, Vector3(0, 0.055, 25))
	soldier.set_physics_process(false)
	await _frames(4)
	var impact := AsterArt.ray(tank.get_world_3d(), Vector3(0, 0.8, 33), soldier.hit_point(), AsterArt.ENEMY)
	_expect(not impact.is_empty() and impact.collider == tank, "the physical Tank hitbox intercepts fire aimed at a smaller beetle")
	var step := KinematicCollision3D.new()
	_expect(soldier.test_move(soldier.global_transform, Vector3.BACK * 8.0, step) and step.get_collider() == tank,
		"ground beetles cannot walk under the Tank")
	tank.damage(100.0)
	_expect(is_equal_approx(tank.max_hp - tank.hp, 54.0), "Tank armor reduces incoming damage")
	tank.damage(10000.0)
	await _frames(3)
	impact = AsterArt.ray(soldier.get_world_3d(), Vector3(0, 0.8, 33), soldier.hit_point(), AsterArt.ENEMY)
	_expect(not impact.is_empty() and impact.collider == soldier, "a dead Tank clears the line of fire")

func _tank_caves() -> void:
	var assault: AsterAssault = game.assault
	assault._scatter(1)
	var tanks: Array[AsterSpecialBug] = []
	for route in assault._cave_routes:
		var tank := _spawn(Kinds.TANK, route[0]) as AsterSpecialBug
		tank.set_entry_path(route.slice(1))
		tanks.append(tank)
	await _frames(3600)
	var exited := 0
	for tank in tanks:
		if is_instance_valid(tank) and tank.global_position.z < 84.0 and not tank._tank_in_cave:
			exited += 1
	_expect(exited == 8, "Tanks use all eight cave exits and recover their full hitboxes outside")

func _kamikaze() -> void:
	var section: AsterStructure = game.gate
	game.player.global_position = Vector3(0, 0.08, 13.8)
	var neighbor := _spawn(Kinds.GROUND, Vector3(0.7, 0.04, 14.5))
	neighbor.set_physics_process(false)
	var attacker := _spawn(Kinds.KAMIKAZE, Vector3(0, 1.65, 14.25))
	var starting_wall := section.hp
	var starting_player: float = game.player.hp
	attacker.damage(1000.0)
	_expect(game.player.hp < starting_player and section.hp < starting_wall and neighbor.hp == neighbor.max_hp,
		"shooting down a Kamikaze immediately damages only the player and buildings")
	var remaining: float = game.player.hp
	await _frames(95)
	_expect(game.player.hp == remaining, "the visible Kamikaze residue has no damage ticks")
	attacker = _spawn(Kinds.KAMIKAZE, Vector3(0, 1.4, 21))
	for frame in range(300):
		if attacker not in game.assault.enemies:
			break
		await physics_frame
	_expect(attacker not in game.assault.enemies and game.player.hp < remaining and game.kills == 1, "contact also detonates without awarding the player a kill")

func _transporter() -> void:
	var passenger := _spawn(Kinds.GROUND, Vector3(0, 0.04, 23.0))
	passenger.set_physics_process(false)
	var carrier := _spawn(Kinds.TRANSPORTER, Vector3(0, 4.0, 25.0))
	for frame in range(300):
		if passenger.state == &"carried":
			break
		await physics_frame
	_expect(passenger.state == &"carried" and game.assault.enemies.size() == 2, "a Transporter picks up an existing beetle")
	if passenger.state != &"carried":
		return
	passenger.set_physics_process(true)
	await _frames(18)
	var hit := AsterArt.ray(carrier.get_world_3d(), passenger.hit_point() + Vector3.RIGHT * 4.0, passenger.hit_point(), AsterArt.ENEMY)
	_expect(not hit.is_empty() and hit.collider == passenger, "the carried beetle remains a valid bullet target")
	carrier.damage(10000.0)
	_expect(passenger.state == &"transport_fall" and passenger.hp == passenger.max_hp, "a downed Transporter drops its living passenger")
	for frame in range(180):
		if passenger.state == &"transport_stun":
			break
		await physics_frame
	_expect(passenger.state == &"transport_stun" and passenger._landing_stun >= 1.0 and passenger._landing_stun <= 2.0,
		"a crash landing stuns the passenger for one to two seconds")
	await _frames(130)
	_expect(passenger.state not in [&"transport_stun", &"transport_fall", &"carried"], "the passenger resumes the assault after the stun")
	await _fresh()
	passenger = _spawn(Kinds.GROUND, Vector3(-1.0, 0.04, 20))
	passenger.set_physics_process(false)
	carrier = _spawn(Kinds.TRANSPORTER, Vector3(-1.0, 4.0, 22))
	for frame in range(600):
		if passenger.state == &"transport_fall":
			break
		await physics_frame
	_expect(passenger.state == &"transport_fall" and passenger.global_position.z < AsterTerrain.FRONT_Z - 4.0,
		"a successful delivery releases the same passenger over the courtyard")

func _ram() -> void:
	var door: AsterStructure = game.gate
	door.toggle_gate()
	door.hp = 70.0
	var next: AsterStructure = game.walls[4]
	var before := next.hp
	var warrior := _spawn(Kinds.RAM, Vector3(0.85, 0.045, 16.5))
	for frame in range(720):
		if door.hp <= 0.0 and next.hp < before:
			break
		await physics_frame
	_expect(door.hp == 0.0, "the Ram charges and destroys an open gate")
	_expect(next.hp < before and warrior.hp > 0.0, "the Ram changes to the next nearest intact building")

func _shooter() -> void:
	game.player.global_position = Vector3(0, 0.08, 29)
	var shooter := _spawn(Kinds.SHOOTER, Vector3(0, 0.04, 40))
	for frame in range(240):
		if game.player.hp < game.balance.player_hp:
			break
		await physics_frame
	_expect(game.player.hp < game.balance.player_hp and game.player.global_position.distance_to(shooter.global_position) > 5.0,
		"the Shooter launches an actual dorsal quill from range")
	shooter.global_position = game.player.global_position + Vector3.BACK * 0.95
	shooter._cooldown = 100.0
	var before: float = game.player.hp
	await _frames(85)
	_expect(game.player.hp < before, "the Shooter still attacks at close range using the normal ground beetle behavior")

func _catapult() -> void:
	game.gate.support.hp = 0.0
	var catapult := _spawn(Kinds.CATAPULT, Vector3(0.2, 0.05, 34))
	var target: AsterStructure = game.gate
	var starting := target.hp
	var wound := _spawn(Kinds.GROUND, Vector3(0.6, 0.05, 13.35))
	wound.set_physics_process(false)
	game.player.global_position = Vector3(0.7, 0.08, 9.1)
	for frame in range(930):
		if target.hp < starting and wound.hp < wound.max_hp:
			break
		await physics_frame
	_expect(target.hp < starting and wound.hp < wound.max_hp and game.player.hp < game.balance.player_hp and catapult.hp > 0.0,
		"a Catapult rock targets the base and damages the structure, player and allied beetles")

func _catapult_cover() -> void:
	game.gate.support.hp = 0.0
	var catapult := _spawn(Kinds.CATAPULT, Vector3(0.0, 0.05, 35.0)) as AsterSpecialBug
	var ground := AsterTerrain.surface_height(0.0, 31.3)
	AsterArt.collider(game, Vector3(2.4, 2.65, 1.0), Vector3(0.0, ground + 1.27, 31.3), AsterArt.SOLID)
	var peeking := false
	var retreated := false
	for frame in range(700):
		if not is_instance_valid(catapult):
			break
		if catapult.state == &"catapult_throw" and catapult._cover.is_finite():
			peeking = catapult._firing_position.distance_to(catapult._cover) > 1.0
		if peeking and catapult.state == &"catapult_retreat" and catapult._cover.distance_to(catapult.global_position) < 0.65:
			retreated = true
			break
		await physics_frame
	_expect(peeking and retreated, "the Catapult leaves available cover to fire and returns to it afterward")

func _catapult_player() -> void:
	for structure: AsterStructure in game.walls:
		structure.damage(structure.hp)
	for turret: AsterTurret in game.turrets:
		turret.destroy()
	game.player.global_position = Vector3(0.2, 0.04, 28.0)
	var catapult := _spawn(Kinds.CATAPULT, Vector3(0, 0.04, 38.0)) as AsterSpecialBug
	for frame in range(600):
		if game.player.hp < game.balance.player_hp:
			break
		await physics_frame
	_expect(catapult._target == game.player and game.player.hp < game.balance.player_hp,
		"the Catapult switches to the player once the defenses are destroyed")
