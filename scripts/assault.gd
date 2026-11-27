class_name AsterAssault
extends Node

signal bug_defeated(position: Vector3)

const GROUND_CAP := 80
const MIN_SPAWN_DISTANCE := 13.0
const SPACING := 1.68
const CELL_SIZE := 2.0
const ENTRY_STEP := 1.0
const ENTRY_FLOOR_NORMAL := 0.74
const GROUND_SCREEN_OFFSETS: Array[Vector3] = [
	Vector3.ZERO, Vector3(-0.66, 1.16, 0), Vector3(0.66, 1.16, 0), Vector3(0, 1.16, -0.78),
]

var elapsed := 0.0
var enemies: Array[AsterBug] = []
var flyer_count := 0
var _timer := 0.65
var _grid_timer := 0.0
var _cells: Dictionary = {}
var _game: Node
var _balance: AsterBalance
var _rng := RandomNumberGenerator.new()
var _flyer_rng := RandomNumberGenerator.new()
var _special_rng := RandomNumberGenerator.new()
var _cave_routes: Array[PackedVector3Array] = []

func setup(game: Node) -> void:
	_game = game
	_balance = game.balance
	_rng.randomize()
	_flyer_rng.randomize()
	_special_rng.randomize()

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
	_timer = maxf(0.0, _timer - delta)
	if _timer > 0.0:
		return
	var ground_spawned := _spawn_wave(false)
	var flyers_spawned := _spawn_wave(true)
	_timer = spawn_interval() if ground_spawned or flyers_spawned else 0.23

func _spawn_wave(flying: bool) -> bool:
	var cap := flyer_cap() if flying else ground_cap()
	var count := flyer_count if flying else enemies.size() - flyer_count
	var slots := target_population(cap) - count
	if slots <= 0:
		return false
	var rng := _flyer_rng if flying else _rng
	var packet := 1 + roundi(pressure() * 6.0)
	var wave := mini(slots, rng.randi_range(maxi(1, packet - 1), packet + 1))
	return _spawn_flyers(wave) if flying else _spawn_ground(wave)

func _spawn_ground(count: int) -> bool:
	var routes := _scatter(count)
	for path in routes:
		var offset := Vector2(_rng.randf_range(-1.12, 1.12), _rng.randf_range(0.0, 0.77))
		var bug := spawn_enemy(path[0], _wave_kind(false), offset)
		if bug != null:
			bug.set_entry_path(path.slice(1))
			bug.speed_factor = _rng.randf_range(0.91, 1.12)
	return not routes.is_empty()

func _wave_kind(flying: bool) -> AsterBug.Kind:
	var progress := smoothstep(_balance.special_start, maxf(_balance.special_start + 1.0, _balance.special_ramp_time), elapsed)
	if progress <= 0.0 or _special_rng.randf() >= _balance.special_peak_chance * progress:
		return AsterBug.Kind.FLYER if flying else AsterBug.Kind.GROUND
	if flying:
		return AsterBug.Kind.KAMIKAZE if _special_rng.randf() < 0.57 else AsterBug.Kind.TRANSPORTER
	var tank_weight := smoothstep(_balance.tank_start, _balance.tank_start + 105.0, elapsed) * 0.62
	var roll := _special_rng.randf() * (3.0 + tank_weight)
	if roll < 1.0:
		return AsterBug.Kind.SHOOTER
	if roll < 2.0:
		return AsterBug.Kind.RAM
	return AsterBug.Kind.CATAPULT if roll < 3.0 else AsterBug.Kind.TANK

func spawn_enemy(point: Vector3, kind: AsterBug.Kind = AsterBug.Kind.GROUND, formation_offset := Vector2.ZERO) -> AsterBug:
	var flying := kind in [AsterBug.Kind.FLYER, AsterBug.Kind.KAMIKAZE, AsterBug.Kind.TRANSPORTER]
	var count := flyer_count if flying else enemies.size() - flyer_count
	var cap := flyer_cap() if flying else ground_cap()
	if count >= cap:
		return null
	var bug: AsterBug
	match kind:
		AsterBug.Kind.GROUND, AsterBug.Kind.CLIMBER:
			bug = AsterBug.new()
		AsterBug.Kind.FLYER:
			bug = AsterFlyingBug.new()
		AsterBug.Kind.KAMIKAZE, AsterBug.Kind.TRANSPORTER:
			bug = AsterSpecialFlyer.new()
		_:
			bug = AsterSpecialBug.new()
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
	var nests: PackedVector3Array = _game.nests
	var first := _flyer_rng.randi_range(0, nests.size() - 1)
	var spawned := 0
	for attempt in range(nests.size()):
		var point := nests[(first + attempt) % nests.size()]
		if not _clear_of_swarm(point, []):
			continue
		var flyer := spawn_enemy(point, _wave_kind(true)) as AsterFlyingBug
		if flyer == null:
			break
		flyer.launch_from_nest()
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
		if enemies.is_empty():
			_timer = maxf(_timer, _balance.assault_clear_delay)
		if bug.awards_kill:
			bug_defeated.emit(bug.global_position)

func _scatter(count: int) -> Array[PackedVector3Array]:
	var routes: Array[PackedVector3Array] = []
	var eye: Vector3 = _game.player.eye.global_position
	var world: World3D = _game.get_world_3d()
	if _cave_routes.is_empty():
		for index in range(AsterTerrain.CAVE_SITES.size()):
			var route := _cave_route(index)
			if _entry_is_clear(world, route):
				_cave_routes.append(route)
	if _cave_routes.is_empty() or count <= 0:
		return routes
	var first := _rng.randi_range(0, _cave_routes.size() - 1)
	for attempt in range(_cave_routes.size()):
		var route := _cave_routes[(first + attempt) % _cave_routes.size()]
		var point := route[0]
		if _clear_of_swarm(point, routes) and _is_screened(world, eye, point):
			routes.append(route)
			if routes.size() == count:
				break
	return routes

func _cave_route(index: int) -> PackedVector3Array:
	var passage := AsterTerrain.CAVE_PASSAGE
	var pose := AsterTerrain.cave_transform(index)
	var route := PackedVector3Array()
	for turn_index in range(passage.size() - 2, -1, -1):
		var turn: Vector2 = passage[turn_index]
		var point := pose * Vector3(turn.x, 0, turn.y)
		point.y = AsterTerrain.surface_height(point.x, point.z) + 0.060
		route.append(point)
	var far_exit := pose * Vector3(0, 0, -8.7)
	var lane: float = AsterTerrain.CAVE_LANES[index]
	route.append(far_exit)
	route.append(Vector3(lane, 0, 73.0))
	route.append(Vector3(lane, 0, AsterTerrain.SCREEN_Z - 13.5))
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
				var clearance := 3.0 if bug.kind == AsterBug.Kind.TANK or other.kind == AsterBug.Kind.TANK else SPACING
				var distance_sq := offset.length_squared()
				if distance_sq >= clearance * clearance:
					continue
				var distance := sqrt(distance_sq)
				var closeness := 1.0 - distance / clearance
				var across := offset.dot(lateral)
				var ahead := offset.dot(direction)
				# For directly aligned neighbors, opposite choices open up the column.
				var side := signf(across) if absf(across) > 0.16 else (1.0 if bug.get_instance_id() < other.get_instance_id() else -1.0)
				steer -= side * closeness
				if ahead > 0.0:
					brake = maxf(brake, closeness * (1.0 - absf(across) / clearance))
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
