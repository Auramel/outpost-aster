class_name AsterAssault
extends Node

signal bug_defeated(position: Vector3)

const ACTIVE_CAP := 120
const SPAWN_Z := AsterTerrain.SCREEN_Z + 4.5
const MIN_SPAWN_DISTANCE := 13.0
const SPACING := 1.68
const CELL_SIZE := 2.0

var elapsed := 0.0
var enemies: Array[AsterBug] = []
var _timer := 0.65
var _grid_timer := 0.0
var _cells: Dictionary = {}
var _game: Node
var _balance: AsterBalance
var _rng := RandomNumberGenerator.new()

func setup(game: Node) -> void:
	_game = game
	_balance = game.balance
	_rng.randomize()

func active_cap() -> int:
	return clampi(_balance.active_limit, 1, ACTIVE_CAP)

func pressure() -> float:
	return clampf(elapsed / maxf(1.0, _balance.assault_ramp_time), 0.0, 1.0)

func target_population() -> int:
	return mini(active_cap(), roundi(lerpf(_balance.assault_opening_population, active_cap(), pressure())))

func spawn_interval() -> float:
	return lerpf(_balance.assault_opening_interval, _balance.assault_peak_interval, pressure())

func _physics_process(delta: float) -> void:
	if _game.lost:
		return
	elapsed += delta
	_grid_timer -= delta
	if _grid_timer <= 0.0:
		_grid_timer = 0.085
		_rebuild_grid()
	_timer = maxf(0.0, _timer - delta)
	var slots := target_population() - enemies.size()
	if _timer > 0.0 or slots <= 0:
		return
	var packet := 1 + roundi(pressure() * 3.0)
	var routes := _scatter(mini(slots, _rng.randi_range(maxi(1, packet - 1), packet + 1)))
	for path in routes:
		var offset := Vector2(_rng.randf_range(-1.12, 1.12), _rng.randf_range(0.0, 0.77))
		var bug := spawn_enemy(path[0], AsterBug.Kind.GROUND, offset)
		if bug != null:
			bug.set_entry_path(path.slice(1))
			bug.speed_factor = _rng.randf_range(0.91, 1.12)
	_timer = 0.23 if routes.is_empty() else spawn_interval() * _rng.randf_range(0.77, 1.23)

func spawn_enemy(point: Vector3, kind: AsterBug.Kind = AsterBug.Kind.GROUND, formation_offset := Vector2.ZERO) -> AsterBug:
	if enemies.size() >= active_cap():
		return null
	var bug := AsterBug.new()
	_game.add_child(bug)
	point.y = maxf(point.y, AsterTerrain.surface_height(point.x, point.z) + 0.025)
	bug.global_position = point
	bug.setup(_game, kind, formation_offset)
	bug.died.connect(_remove_enemy)
	enemies.append(bug)
	return bug

func _remove_enemy(bug: AsterBug) -> void:
	if enemies.has(bug):
		enemies.erase(bug)
		bug_defeated.emit(bug.global_position)

func _scatter(count: int) -> Array[PackedVector3Array]:
	var routes: Array[PackedVector3Array] = []
	var sites := AsterTerrain.SCREEN_SITES
	var first_site := _rng.randi_range(0, sites.size() - 1)
	var eye: Vector3 = _game.player.eye.global_position
	var world: World3D = _game.get_world_3d()
	for index in range(count):
		for attempt in range(26):
			var site := (first_site + index * 2 + attempt) % sites.size()
			var center: Vector2 = sites[site]
			var face := eye.z > center.y + 3.75 and attempt >= 12
			var depth := center.y - _rng.randf_range(5.3, 7.7) if face else _rng.randf_range(maxf(SPAWN_Z, center.y + 5.6), 73.0)
			var x := center.x + _rng.randf_range(-4.0, 4.0)
			var point := Vector3(x, AsterTerrain.surface_height(x, depth) + 0.060, depth)
			if not _clear_of_swarm(point, routes) or not _is_screened(world, eye, point):
				continue
			var route := PackedVector3Array([point])
			if not face:
				var high_route := site in AsterTerrain.HIGH_SCREEN_SITES
				var side := -1 if _rng.randf() < 0.5 else 1
				if high_route:
					side = 1 if center.x < 0.0 else -1
				var channel := center.x + side * 9.6
				var neighbor := site + side
				if neighbor >= 0 and neighbor < sites.size():
					channel = (center.x + sites[neighbor].x) * 0.5
				channel += _rng.randf_range(-0.67, 0.67)
				route.append(Vector3(channel, 0.0, center.y + 5.08))
				route.append(Vector3(channel + _rng.randf_range(-0.58, 0.58), 0.0, center.y - 5.05))
				if high_route:
					var slope := signf(center.x)
					route.append(Vector3(slope * _rng.randf_range(16.4, 21.3), 0.0, _rng.randf_range(36.0, 41.8)))
					route.append(Vector3(slope * _rng.randf_range(10.9, 15.2), 0.0, _rng.randf_range(23.6, 28.2)))
			routes.append(route)
			break
	return routes

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))

func _rebuild_grid() -> void:
	_cells.clear()
	for bug in enemies:
		var cell := _cell(bug.global_position)
		if not _cells.has(cell):
			_cells[cell] = []
		_cells[cell].append(bug)

func spacing_velocity(bug: AsterBug, direction: Vector3) -> Vector3:
	var at := bug.global_position
	var cell := _cell(at)
	var lateral := Vector3(-direction.z, 0, direction.x)
	var steer := 0.0
	var brake := 0.0
	for x in range(-1, 2):
		for z in range(-1, 2):
			var neighbor := cell + Vector2i(x, z)
			if not _cells.has(neighbor):
				continue
			for entry in _cells[neighbor]:
				if not is_instance_valid(entry) or entry == bug:
					continue
				var other: AsterBug = entry
				if other.hp <= 0.0:
					continue
				var offset := other.global_position - at
				if absf(offset.y) > 0.8:
					continue
				offset.y = 0.0
				var distance_sq := offset.length_squared()
				if distance_sq >= SPACING * SPACING:
					continue
				var distance := sqrt(distance_sq)
				var closeness := 1.0 - distance / SPACING
				var across := offset.dot(lateral)
				var ahead := offset.dot(direction)
				# For directly aligned neighbors, opposite choices open up the column.
				var side := signf(across) if absf(across) > 0.16 else (1.0 if bug.get_instance_id() < other.get_instance_id() else -1.0)
				steer -= side * closeness
				if ahead > 0.0:
					brake = maxf(brake, closeness * (1.0 - absf(across) / SPACING))
	return direction * (1.0 - brake * 0.53) + lateral * clampf(steer, -0.63, 0.63)

func _is_screened(world: World3D, eye: Vector3, point: Vector3) -> bool:
	if not _game.player.alive:
		return true
	if eye.distance_squared_to(point) < MIN_SPAWN_DISTANCE * MIN_SPAWN_DISTANCE:
		return false
	var screen: CollisionObject3D
	for offset: Vector3 in [Vector3.ZERO, Vector3(-0.66, 1.16, 0), Vector3(0.66, 1.16, 0), Vector3(0.0, 1.16, -0.78)]:
		var hit := AsterArt.ray(world, eye, point + offset, AsterArt.SPAWN_SCREEN)
		if hit.is_empty() or (screen != null and screen != hit.collider):
			return false
		screen = hit.collider
	return true

func _clear_of_swarm(point: Vector3, routes: Array[PackedVector3Array]) -> bool:
	for route in routes:
		if route[0].distance_squared_to(point) < 5.0:
			return false
	for bug in enemies:
		if bug.global_position.distance_squared_to(point) < 4.4:
			return false
	return true
