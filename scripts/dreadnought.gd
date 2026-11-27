class_name AsterDreadnought
extends Node3D

const TITLE := "Т-5 «Дредноут»"
const PRICE := 40
const SALVOS := 3
const MUZZLE := Vector3(0.73, 0.0, -4.70)

var tuning: AsterTurretTuning
var _game: Node
var _head := Node3D.new()
var _elevation := Node3D.new()
var _barrels := Node3D.new()
var _target: AsterBug
var _aim_point := Vector3.ZERO
var _salvos_left := 0
var _timer := 0.0
var _kick := 0.0
var shots_fired := 0

func setup(game: Node, upgrades: AsterTurretTuning) -> void:
	_game = game
	tuning = upgrades
	AsterModels.attach(self, &"dreadnought_ring")
	add_child(_head)
	_head.position.y = 0.72
	_head.rotation.y = PI
	AsterModels.attach(_head, &"dreadnought_housing")
	_head.add_child(_elevation)
	_elevation.position = Vector3(0, 0.56, -0.47)
	_elevation.add_child(_barrels)
	AsterModels.attach(_barrels, &"dreadnought_barrels")
	AsterTerrain.floodlight(_elevation, Vector3(0, 0.19, -1.34), Vector3(0, -0.2, -10), 2.7, 12.5, 24.0, 0.44)
	for side: float in [-1, 1]:
		var label := AsterArt.lettering(_head, "Т-5", Vector3(side * 1.85, 0.90, -0.37), 60, AsterArt.PALE)
		label.rotation.y = side * PI * 0.5

func busy() -> bool:
	return _salvos_left > 0 or _timer > 0.0

func call_salvos(enemies: Array) -> bool:
	if busy():
		return false
	_target = _select_target(enemies)
	if not is_instance_valid(_target):
		return false
	_aim_point = _target.hit_point()
	_salvos_left = SALVOS
	_timer = 0.65
	return true

func tick(delta: float, enemies: Array) -> void:
	_timer = maxf(0.0, _timer - delta)
	_kick = move_toward(_kick, 0.0, delta * 1.3)
	_barrels.position.z = _kick
	if _salvos_left == 0:
		_head.rotation.y = rotate_toward(_head.rotation.y, PI, delta * 0.39)
		_elevation.rotation.x = move_toward(_elevation.rotation.x, 0.04, delta * 0.39)
		return
	if not is_instance_valid(_target) or _target.hp <= 0.0 or not _can_hit(_target.hit_point()):
		_target = _select_target(enemies)
	if is_instance_valid(_target):
		_aim_point = _target.hit_point() + _target.velocity * (global_position.distance_to(_target.hit_point()) / AsterBallistics.TURRET_SPEED)
	var offset := _aim_point - _elevation.global_position
	var direction := offset.normalized()
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := asin(direction.y)
	_head.rotation.y = rotate_toward(_head.rotation.y, yaw, delta * 0.63)
	_elevation.rotation.x = move_toward(_elevation.rotation.x, pitch, delta * 0.47)
	if _timer > 0.0 or absf(angle_difference(_head.rotation.y, yaw)) > 0.025 or absf(_elevation.rotation.x - pitch) > 0.023:
		return
	for side: float in [-1, 1]:
		var tip := _barrels.to_global(Vector3(side * MUZZLE.x, MUZZLE.y, MUZZLE.z))
		_game.fire_artillery(tip, tip.direction_to(_aim_point), tuning.stat(AsterTurretTuning.SupportPath.DAMAGE), tuning.stat(AsterTurretTuning.SupportPath.BLAST_RADIUS), tip.distance_to(_aim_point) + 1.1)
	_kick = 0.77
	_game.sound.artillery(_elevation.global_position)
	_game.player.artillery_jolt(_elevation.global_position)
	shots_fired += 1
	_salvos_left -= 1
	_timer = 1.0 / tuning.stat(AsterTurretTuning.SupportPath.SALVO_RATE)

func _can_hit(point: Vector3) -> bool:
	var reach := tuning.stat(AsterTurretTuning.SupportPath.RANGE)
	return point.z > AsterTerrain.FRONT_APPROACH_Z + 7.0 and global_position.distance_squared_to(point) < reach * reach and AsterArt.ray(get_world_3d(), _elevation.global_position, point, AsterArt.SOLID).is_empty()

func _select_target(enemies: Array) -> AsterBug:
	var selected: AsterBug
	var score := -INF
	var radius := tuning.stat(AsterTurretTuning.SupportPath.BLAST_RADIUS)
	for bug: AsterBug in enemies:
		if bug.hp <= 0.0 or bug is AsterFlyingBug or not _can_hit(bug.hit_point()):
			continue
		var weight := -bug.global_position.distance_to(global_position) * 0.006
		for neighbor: AsterBug in enemies:
			if neighbor.hp > 0.0 and not neighbor is AsterFlyingBug and bug.global_position.distance_squared_to(neighbor.global_position) < radius * radius:
				weight += 1.0
		if weight > score:
			selected = bug
			score = weight
	return selected
