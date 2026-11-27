class_name AsterInteraction
extends Node

var aimed: Node
var usable: Node
var _look_timer := 0.0
var game: Node
var player: AsterPlayer

func tick(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0 or Input.is_action_just_pressed(&"interact"):
		refresh()
		_look_timer = 0.045
	if Input.is_action_just_pressed(&"interact"):
		start()

func refresh() -> void:
	var from := player.eye.global_position
	var to: Vector3 = from - player.eye.global_basis.z * game.balance.repair_range
	var hit := AsterArt.ray(player.get_world_3d(), from, to, AsterArt.SOLID | AsterArt.TARGET | AsterArt.ACCESS, true)
	aimed = null
	if not hit.is_empty() and hit.collider.has_meta(&"target"):
		aimed = hit.collider.get_meta(&"target")
	usable = null
	var candidates: Array[Node3D] = [game.tuning_terminal, game.gate]
	if aimed in candidates and can_reach(aimed):
		usable = aimed
		return
	var nearest: float = game.balance.use_range
	for candidate in candidates:
		if not can_reach(candidate):
			continue
		var distance := from.distance_to(anchor(candidate))
		if distance < nearest:
			nearest = distance
			usable = candidate

func anchor(node: Node3D) -> Vector3:
	if node is AsterTurret:
		return node.service_position()
	return node.global_position + Vector3.UP * 1.08

func can_reach(node: Node3D) -> bool:
	if not is_instance_valid(node):
		return false
	var from := player.eye.global_position
	var point := anchor(node)
	if point.distance_to(from) > game.balance.use_range:
		return false
	if node is AsterTurret and absf(player.global_position.y - node.global_position.y) > 1.52:
		return false
	var obstruction := AsterArt.ray(player.get_world_3d(), from, point, AsterArt.SOLID)
	return obstruction.is_empty() or (node == game.gate and obstruction.collider.get_meta(&"target", false) == node)

func start() -> void:
	if not player.alive or not can_reach(usable):
		return
	if usable == game.tuning_terminal:
		game.set_tuning(true)
	elif usable == game.gate and game.gate.toggle_gate():
		game.sound.play(&"lock")

func action_hint() -> String:
	if aimed == game.supply:
		return "Склад · Резерв автомата пополняется рядом"
	if usable == game.tuning_terminal:
		return "E · Тюнинг и огневая поддержка"
	if usable == game.gate:
		return "E · Управление воротами"
	if aimed is AsterTurret:
		return "%s  ·  Боезапас %d/%d" % [aimed.title, aimed.rounds, aimed.capacity()]
	return ""
