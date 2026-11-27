class_name AsterInteraction
extends Node

var aimed: Node
var usable: Node
var stage: StringName = &""
var elapsed := 0.0
var duration := 1.0
var station: AsterTurret
var _look_timer := 0.0
var _needs_release := false
var game: Node
var player: AsterPlayer

func tick(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0:
		refresh()
		_look_timer = 0.045
	if not Input.is_action_pressed(&"interact"):
		_needs_release = false
		cancel()
		return
	if stage != &"":
		if not advance(delta):
			return
	elif not _needs_release and Input.is_action_just_pressed(&"interact"):
		refresh()
		start()

func refresh() -> void:
	var from := player.eye.global_position
	var to: Vector3 = from - player.eye.global_basis.z * game.balance.repair_range
	var hit := AsterArt.ray(player.get_world_3d(), from, to, AsterArt.SOLID | AsterArt.TARGET | AsterArt.ACCESS, true)
	aimed = null
	if not hit.is_empty() and hit.collider.has_meta(&"target"):
		aimed = hit.collider.get_meta(&"target")
	usable = null
	if (aimed in [game.supply, game.rifle_terminal, game.tuning_terminal, game.gate] or aimed is AsterTurret) and can_reach(aimed):
		usable = aimed
	else:
		var nearest: float = game.balance.use_range
		for candidate in [game.supply, game.rifle_terminal, game.tuning_terminal, game.gate] + game.turrets:
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
	_needs_release = true
	if stage != &"" or not player.alive or not can_reach(usable):
		return
	if usable == game.supply:
		if player.take_box():
			game.sound.play(&"crate")
		return
	if usable == game.rifle_terminal:
		game.set_tuning(true, true)
		return
	if usable == game.tuning_terminal:
		game.set_tuning(true)
		return
	if usable == game.gate:
		if game.gate.toggle_gate():
			game.sound.play(&"lock")
		elif game.gate.gate_open:
			game.notify("Ворота · Освободите проём")
		else:
			game.notify("Ворота · Требуется ремонт")
		return
	if usable is AsterTurret:
		station = usable
		stage = station.try_service(player.carrying)
		if stage != &"":
			elapsed = 0.0
			duration = game.balance.remove_duration if stage == &"remove" else game.balance.insert_duration

func advance(delta: float) -> bool:
	if stage == &"":
		return false
	if not player.alive or not can_reach(station) or station.service != stage or station.rebuilding:
		cancel()
		return false
	elapsed += delta
	if elapsed < duration:
		return true
	if station.finish_service(stage, player.carrying):
		if stage == &"insert":
			player.carrying = false
			game.notify(station.title + " заряжена")
		else:
			game.notify(station.title + " · Старый ящик снят")
	station = null
	stage = &""
	elapsed = 0.0
	return false

func cancel() -> void:
	if is_instance_valid(station):
		station.cancel_service()
	station = null
	stage = &""
	elapsed = 0.0

func action_hint() -> String:
	if usable == game.supply:
		return "Ящик уже на спине · резерв автомата пополнен" if player.carrying else "E · Взять ящик   /   Резерв автомата пополняется рядом"
	if usable == game.rifle_terminal:
		return "E · Тюнинг автомата"
	if usable == game.tuning_terminal:
		return "E · Тюнинг турелей"
	if usable == game.gate:
		return game.gate.gate_hint()
	if usable is AsterTurret:
		if usable.rebuilding:
			return usable.repair_hint()
		if usable.has_box:
			return "Отпустите E" if _needs_release and stage == &"" else "Удерж. E · Снять ящик · остаток будет потерян"
		if not player.carrying:
			return "Нужен полный ящик со склада"
		return "Отпустите E для следующего этапа" if _needs_release and stage == &"" else "Удерж. E · Установить ящик"
	return ""
