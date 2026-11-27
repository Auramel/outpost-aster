class_name AsterAssault
extends Node

signal bug_defeated(position: Vector3)

const GROUND_CAP := 120
const SPAWN_Z := AsterTerrain.SCREEN_Z + 4.5
const MIN_SPAWN_DISTANCE := 13.0
const SPACING := 1.68
const CELL_SIZE := 2.0
const ENTRY_STEP := 1.0
const ENTRY_FLOOR_NORMAL := 0.74
const GROUND_SCREEN_OFFSETS: Array[Vector3] = [
	Vector3.ZERO, Vector3(-0.66, 1.16, 0), Vector3(0.66, 1.16, 0), Vector3(0, 1.16, -0.78),
]
const FLYER_SCREEN_OFFSETS: Array[Vector3] = [
	Vector3.ZERO, Vector3(0, -0.52, 1.0), Vector3(0, 0.84, -0.90),
	Vector3(-2.62, 2.04, 0.82), Vector3(2.62, 2.04, 0.82),
	Vector3(-1.95, 2.93, 0.40), Vector3(1.95, 2.93, 0.40),
]

var elapsed := 0.0
var enemies: Array[AsterBug] = []
var flyer_count := 0
var _timer := 0.65
var _flyer_timer := 0.65
var _grid_timer := 0.0
var _cells: Dictionary = {}
var _game: Node
var _balance: AsterBalance
var _rng := RandomNumberGenerator.new()
var _flyer_rng := RandomNumberGenerator.new()

func setup(game: Node) -> void:
	_game = game
	_balance = game.balance
	_rng.randomize()
	_flyer_rng.randomize()

func ground_cap() -> int:
	return clampi(_balance.active_limit, 1, GROUND_CAP)

func flyer_cap() -> int:
	return floori(ground_cap() * 0.5)

func active_cap() -> int:
	return ground_cap() + flyer_cap()

func pressure() -> float:
	return clampf(elapsed / maxf(1.0, _balance.assault_ramp_time), 0.0, 1.0)

func target_population(cap: int) -> int:
	return mini(cap, roundi(lerpf(_balance.assault_opening_population, cap, pressure())))

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
	_timer = _advance_wave(_timer, delta, false)
	_flyer_timer = _advance_wave(_flyer_timer, delta, true)

func _advance_wave(timer: float, delta: float, flying: bool) -> float:
	timer = maxf(0.0, timer - delta)
	if timer > 0.0:
		return timer
	var cap := flyer_cap() if flying else ground_cap()
	var count := flyer_count if flying else enemies.size() - flyer_count
	var slots := target_population(cap) - count
	if slots <= 0:
		return 0.0
	var rng := _flyer_rng if flying else _rng
	var packet := 1 + roundi(pressure() * 3.0)
	var wave := mini(slots, rng.randi_range(maxi(1, packet - 1), packet + 1))
	var spawned := _spawn_flyers(wave) if flying else _spawn_ground(wave)
	return spawn_interval() * rng.randf_range(0.77, 1.23) if spawned else 0.23

func _spawn_ground(count: int) -> bool:
	var routes := _scatter(count)
	for path in routes:
		var offset := Vector2(_rng.randf_range(-1.12, 1.12), _rng.randf_range(0.0, 0.77))
		var bug := spawn_enemy(path[0], AsterBug.Kind.GROUND, offset)
		if bug != null:
			bug.set_entry_path(path.slice(1))
			bug.speed_factor = _rng.randf_range(0.91, 1.12)
	return not routes.is_empty()

func spawn_enemy(point: Vector3, kind: AsterBug.Kind = AsterBug.Kind.GROUND, formation_offset := Vector2.ZERO) -> AsterBug:
	var flying := kind == AsterBug.Kind.FLYER
	var count := flyer_count if flying else enemies.size() - flyer_count
	var cap := flyer_cap() if flying else ground_cap()
	if count >= cap:
		return null
	var bug: AsterBug = AsterFlyingBug.new() if flying else AsterBug.new()
	_game.add_child(bug)
	point.y = maxf(point.y, AsterTerrain.surface_height(point.x, point.z) + (0.67 if flying else 0.025))
	bug.global_position = point
	bug.setup(_game, kind, formation_offset)
	bug.died.connect(_remove_enemy)
	enemies.append(bug)
	if flying:
		flyer_count += 1
	return bug

func _spawn_flyers(count: int) -> bool:
	var player: AsterPlayer = _game.player
	if not player.alive:
		return false
	var eye := player.eye.global_position
	var world := player.get_world_3d()
	var sites := AsterTerrain.SCREEN_SITES
	var first := _flyer_rng.randi_range(0, sites.size() - 1)
	var spawned := 0
	for attempt in range(sites.size() * 4 + count * 3):
		var site: Vector2 = sites[(first + attempt) % sites.size()]
		var away := (site - Vector2(eye.x, eye.z)).normalized()
		if away.is_zero_approx():
			away = Vector2.DOWN
		var lateral := Vector2(-away.y, away.x)
		var at := site + away * _flyer_rng.randf_range(6.0, 12.8) + lateral * _flyer_rng.randf_range(-4.0, 4.0)
		var point := Vector3(at.x, AsterTerrain.surface_height(at.x, at.y) + 0.82, at.y)
		if _clear_of_swarm(point, []) and _is_screened(world, eye, point, FLYER_SCREEN_OFFSETS):
			var flyer := spawn_enemy(point, AsterBug.Kind.FLYER)
			if flyer != null:
				flyer.speed_factor = _flyer_rng.randf_range(0.91, 1.12)
				spawned += 1
				if spawned == count:
					break
	return spawned > 0

func _remove_enemy(bug: AsterBug) -> void:
	if enemies.has(bug):
		enemies.erase(bug)
		if bug is AsterFlyingBug:
			flyer_count -= 1
		bug_defeated.emit(bug.global_position)

func _scatter(count: int) -> Array[PackedVector3Array]:
	var routes: Array[PackedVector3Array] = []
	var sites := AsterTerrain.SCREEN_SITES
	var first_site := _rng.randi_range(0, sites.size() - 1)
	var eye: Vector3 = _game.player.eye.global_position
	var world: World3D = _game.get_world_3d()
	if count > 0 and _rng.randf() < 0.30:
		var cave := _cave_route()
		if _clear_of_swarm(cave[0], routes) and _is_screened(world, eye, cave[0]) and _entry_is_clear(world, cave):
			routes.append(cave)
	for index in range(count - routes.size()):
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
			if _entry_is_clear(world, route):
				routes.append(route)
				break
	return routes

func _cave_route() -> PackedVector3Array:
	var passage := AsterTerrain.CAVE_PASSAGE
	var start: Vector2 = passage[-2] + Vector2(_rng.randf_range(-0.83, 0.83), _rng.randf_range(-0.53, 0.60))
	var point := AsterTerrain.CAVE_MOUTH + Vector3(start.x, 0, start.y)
	point.y = AsterTerrain.surface_height(point.x, point.z) + 0.060
	var route := PackedVector3Array([point])
	for index in range(passage.size() - 3, -1, -1):
		var turn: Vector2 = passage[index]
		route.append(AsterTerrain.CAVE_MOUTH + Vector3(turn.x, 0, turn.y))
	var approach := (AsterTerrain.SCREEN_SITES[2].x + AsterTerrain.SCREEN_SITES[3].x) * 0.5
	route.append(Vector3(approach, 0.0, 75.0))
	route.append(Vector3(approach, 0.0, AsterTerrain.SCREEN_Z - 8.0))
	return route

func _entry_is_clear(world: World3D, route: PackedVector3Array) -> bool:
	var previous := route[0]
	var step := _entry_floor(world, previous, Vector3.ZERO)
	if step == Vector3.INF:
		return false
	for index in range(1, maxi(2, route.size())):
		var goal := route[index] if index < route.size() else previous + Vector3.FORWARD * 5.0
		var travel := AsterArt.horizontal(goal - previous)
		var direction := travel.normalized()
		var width := direction.cross(Vector3.UP) * 0.55
		var intervals := maxi(1, ceili(travel.length() / ENTRY_STEP))
		for sample in range(1, intervals + 1):
			var next := _entry_floor(world, previous.lerp(goal, float(sample) / intervals), direction)
			if next == Vector3.INF:
				return false
			var lift := Vector3.UP * 0.57
			for side: float in [-1.0, 0.0, 1.0]:
				var offset := lift + width * side
				if not AsterArt.ray(world, step + offset, next + offset, AsterArt.SPAWN_SCREEN).is_empty():
					return false
			step = next
		previous = goal
	return true

func _entry_floor(world: World3D, point: Vector3, direction: Vector3) -> Vector3:
	point.y = AsterTerrain.surface_height(point.x, point.z)
	var floor_hit := AsterArt.ray(world, point + Vector3.UP * 0.6, point + Vector3.DOWN * 0.24, AsterArt.SOLID)
	if floor_hit.is_empty() or floor_hit.position.y > point.y + 0.14:
		return Vector3.INF
	var normal: Vector3 = floor_hit.normal
	if normal.y < ENTRY_FLOOR_NORMAL and normal.dot(direction) < -0.08:
		return Vector3.INF
	return floor_hit.position

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

func _is_screened(world: World3D, eye: Vector3, point: Vector3, offsets: Array[Vector3] = GROUND_SCREEN_OFFSETS) -> bool:
	if not _game.player.alive:
		return true
	if eye.distance_squared_to(point) < MIN_SPAWN_DISTANCE * MIN_SPAWN_DISTANCE:
		return false
	var screen: CollisionObject3D
	for offset in offsets:
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
