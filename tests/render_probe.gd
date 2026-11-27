extends SceneTree

const GAME := preload("res://scenes/outpost.tscn")
var game: Node
var directory: String

func _initialize() -> void:
	call_deferred(&"_measure")

func _measure() -> void:
	var arguments := OS.get_cmdline_user_args()
	directory = arguments[arguments.find("--capture-dir") + 1] if "--capture-dir" in arguments else OS.get_temp_dir()
	var count_option := arguments.find("--stress-count")
	var requested := int(arguments[count_option + 1]) if count_option >= 0 and count_option + 1 < arguments.size() else -1
	game = GAME.instantiate()
	game.balance = game.balance.duplicate()
	if requested > 0:
		game.balance.active_limit = clampi(requested, 1, AsterAssault.GROUND_CAP)
	root.add_child(game)
	if "--max-turrets" in arguments:
		for path in range(AsterTurretTuning.Path.size()):
			for level in range(AsterTurretTuning.MAX_LEVEL):
				game.turret_tuning.apply_upgrade(path)
		for mount: AsterTurret in game.turrets:
			mount.rounds = mount.capacity()
	var assault: AsterAssault = game.assault
	var ground_count := assault.ground_cap()
	seed(723)
	assault._rng.seed = 723
	current_scene = game
	game.assault.set_physics_process(false)
	await create_timer(0.8).timeout
	if "--no-capture" not in arguments:
		await _capture("aster-preparation")
	game.assault.elapsed = game.balance.assault_ramp_time
	game.core.hp = 30000
	game.core.max_hp = 30000
	for section: AsterStructure in game.walls:
		section.hp = 30000
		section.max_hp = 30000
	var turret: AsterTurret = game.turrets[0]
	game.player.global_position = turret.global_position - turret.facing * 1.60 + Vector3(1.05, 0.05, 0)
	var player: AsterPlayer = game.player
	player.rotation.y = PI + 0.25
	player.eye.rotation.x = -0.19
	const LANES := 18
	for index in range(assault.active_cap()):
		var flying := index >= ground_count
		var slot := index - ground_count if flying else index
		var lane := slot % LANES
		var row := floori(float(slot) / LANES)
		var angle := lerpf(-0.99, 0.99, (lane + 0.5) / LANES)
		var radius := 15.8 + row * 4.1 + randf_range(-0.62, 0.62)
		var at := Vector3(
			sin(angle) * radius + randf_range(-0.40, 0.40),
			5.6 + row * 0.9 if flying else 0.06,
			AsterTerrain.FRONT_Z + cos(angle) * radius * 0.84 + 4.35)
		var kind := AsterBug.Kind.FLYER if flying else AsterBug.Kind.GROUND
		var bug := assault.spawn_enemy(at, kind)
		bug.hp = 10000.0
	game.player.hp = 30000
	game.assault.set_physics_process(true)
	await create_timer(1.7).timeout
	if "--no-capture" not in arguments:
		await _capture("aster-combat")
	await create_timer(1.0).timeout
	var since := Time.get_ticks_usec()
	var previous := since
	var times := PackedFloat64Array()
	while Time.get_ticks_usec() - since < 10_000_000:
		await process_frame
		var current := Time.get_ticks_usec()
		times.append((current - previous) / 1000.0)
		previous = current
	var total := (previous - since) / 1_000_000.0
	var frame_count := times.size()
	times.sort()
	print("ASTER RENDER ", root.get_texture().get_size(), " | active=", game.assault.enemies.size(), " | frames=", frame_count, " | seconds=", total, " | fps=", frame_count / total, " | p95_ms=", times[floori(frame_count * 0.95) - 1], " | p99_ms=", times[floori(frame_count * 0.99) - 1], " | worst_ms=", times[frame_count - 1])
	if "--capture-tuning" in arguments:
		game.combat_points = 500
		player.global_position = game.rifle_terminal.global_position + Vector3.BACK * 1.9
		game.set_tuning(true, true)
		await _capture("aster-rifle-tuning")
		game.set_tuning(false)
		player.global_position = game.tuning_terminal.global_position + Vector3.BACK * 1.9
		game.set_tuning(true)
		await _capture("aster-turret-tuning")
		game.set_tuning(false)
	quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var graphic := root.get_texture().get_image()
	var path := directory.path_join(label + ".png")
	var status := graphic.save_png(path)
	print("ASTER CAPTURE ", path, " ", graphic.get_size(), " ", status)
