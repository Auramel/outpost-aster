class_name AsterTerrain
extends RefCounted

const FRONT_Z := 12.0
const FRONT_HALF_WIDTH := 12.0
const FRONT_APPROACH_Z := FRONT_Z + 2.10
const ARENA_EDGE := 78.0
const SCREEN_Z := 53.8
const SCREEN_CENTERS := [-47.0, -28.0, -9.0, 10.0, 29.0, 48.0]
const RAMP_START := 8.02
const RAMP_END := 3.85
const LANDING_EDGE := AsterStructure.WALL_DEPTH - AsterStructure.OUTER_FACE - 0.03
const ROCK_MODELS := [&"stone_1", &"stone_2", &"stone_3"]

static func build(world: Node3D) -> void:
	var atmosphere := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = AsterModels.SKY
	panorama.energy_multiplier = 1.00
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b4c0cf")
	env.ambient_light_energy = 0.48
	env.fog_enabled = true
	env.fog_light_color = Color("#c8a67c")
	env.fog_density = 0.0084
	env.fog_sky_affect = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.75
	env.ssao_enabled = true
	env.ssao_radius = 0.93
	env.ssao_intensity = 1.48
	env.ssao_power = 1.17
	atmosphere.environment = env
	world.add_child(atmosphere)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -38, 0)
	sun.light_color = Color("#fff0d8")
	sun.light_energy = 1.22
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 65.0
	sun.shadow_bias = 0.065
	sun.shadow_normal_bias = 1.45
	world.add_child(sun)
	_sand(world)
	_build_mountain(world)
	_build_screening_ridges(world)
	_build_desert_dressing(world)

	for side: float in [-1, 1]:
		AsterArt.collider(world, Vector3(0.5, 70, ARENA_EDGE * 2.0 + 2.0), Vector3(side * ARENA_EDGE, 8, 0), AsterArt.SOLID)
		AsterArt.collider(world, Vector3(ARENA_EDGE * 2.0 + 2.0, 70, 0.5), Vector3(0, 8, side * ARENA_EDGE), AsterArt.SOLID)

static func _build_desert_dressing(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 16014
	var dressing := Node3D.new()
	dressing.name = "DesertDressing"
	world.add_child(dressing)
	var mesas: Array[Transform3D] = []
	var rubble: Array[Transform3D] = []
	var shale: Array[Transform3D] = []
	var scrub: Array[Transform3D] = []
	for i in range(22):
		var angle := (i / 21.0 - 0.5) * PI + rng.randf_range(-0.045, 0.045)
		var direction := Vector3(sin(angle), 0, cos(angle))
		var distance := rng.randf_range(88.0, 98.0) / maxf(absf(direction.x), absf(direction.z))
		var mass := 0.65 + pow(absf(sin(i * 0.89)), 2.0)
		var size := Vector3(rng.randf_range(12.0, 22.0), rng.randf_range(9.0, 21.0), rng.randf_range(8.0, 19.0)) * mass
		mesas.append(_scatter_transform(direction * distance, size, rng.randf() * TAU))
		var lower := direction * (distance - 3.2) + Vector3(rng.randf_range(-5, 5), -0.05, rng.randf_range(-2, 2))
		rubble.append(_scatter_transform(lower, size * Vector3(0.65, 0.46, 0.72), rng.randf() * TAU))
	for i in range(135):
		var angle := rng.randf_range(-1.46, 1.46)
		var distance := rng.randf_range(14.5, 74.0)
		var point := Vector3(sin(angle) * distance, -0.018, FRONT_Z + cos(angle) * distance * 0.80)
		if absf(point.x - 2.0) < 2.6 and point.z < 30.0:
			continue
		var size := rng.randf_range(0.11, 0.63) * (1.65 if i % 4 == 0 else 1.0)
		var form := Vector3(size * 1.35, size * rng.randf_range(0.18, 0.63), size)
		shale.append(_scatter_transform(point, form, rng.randf() * TAU))
		if i % 7 == 0 and absf(point.x) > 7.0:
			scrub.append(_scatter_transform(point + Vector3(0.60, 0.02, 0.22), Vector3.ONE * rng.randf_range(0.55, 1.20), rng.randf() * TAU))
	for side in [-1.0, 1.0]:
		for index in range(9):
			var point := Vector3(side * rng.randf_range(10.98, 11.84), -0.028, -10.3 + index * 2.42)
			rubble.append(_scatter_transform(point, Vector3(1.05, rng.randf_range(0.24, 0.64), 1.26), rng.randf() * TAU))
			if index % 2 == 0:
				scrub.append(_scatter_transform(point + Vector3(side * -0.19, 0.03, 0.46), Vector3.ONE * rng.randf_range(0.72, 1.15), rng.randf() * TAU))
	for point in [Vector3(-15.4, 0, 24.1), Vector3(13.8, 0, 20.4), Vector3(-24.1, 0, 38.0), Vector3(27.4, 0, 47.2)]:
		scrub.append(_scatter_transform(point, Vector3(1.75, 2.6, 1.81), rng.randf() * TAU))
	AsterModels.scatter(dressing, &"mesa", mesas)
	AsterModels.scatter(dressing, &"stone_2", rubble)
	AsterModels.scatter(dressing, &"stone_3", shale)
	AsterModels.scatter(dressing, &"scrub", scrub)

static func _scatter_transform(at: Vector3, size: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), at)

static func _build_screening_ridges(world: Node3D) -> void:
	var ridge := Node3D.new()
	ridge.name = "ScreeningRidges"
	world.add_child(ridge)
	var heights := PackedFloat32Array([0.96, 1.12, 1.21, 0.98, 1.17, 1.05])
	for index in range(SCREEN_CENTERS.size()):
		var center := Vector3(SCREEN_CENTERS[index], 0.0, SCREEN_Z)
		var proportions := Vector3(1.0, heights[index], 1.0)
		var rock := AsterModels.attach(ridge, &"screen_rock", center, proportions)
		rock.rotation.y = PI if index % 2 == 1 else 0.0
		var solid := AsterArt.collider(ridge, Vector3(12.55, 6.35, 3.7), center + Vector3.UP * 3.15, AsterArt.SOLID | AsterArt.SPAWN_SCREEN)
		solid.name = "ScreenOccluder"
		var debris := center + Vector3(index % 2 * 4.9 - 2.45, -0.04, -3.55)
		AsterModels.attach(ridge, ROCK_MODELS[index % 3], debris, Vector3(1.84, 1.32, 1.89))
		AsterModels.attach(ridge, ROCK_MODELS[(index + 1) % 3], debris + Vector3(-1.85, 0.03, -0.52), Vector3(1.30, 0.82, 0.94))

static func _build_mountain(world: Node3D) -> void:
	var rear := -FRONT_Z
	var toe := FRONT_Z + 0.43
	var far_edge := ARENA_EDGE + 6.0
	var rock_width := far_edge - FRONT_HALF_WIDTH
	AsterArt.collider(world, Vector3(far_edge * 2, 38, far_edge + rear), Vector3(0, 15, (rear - far_edge) * 0.5), AsterArt.SOLID)
	_cliff(world, Vector3(-far_edge, 0, rear), Vector3(far_edge, 0, rear), Vector3.FORWARD, 610, 16.0)
	for side: float in [-1.0, 1.0]:
		var inner_edge := side * FRONT_HALF_WIDTH
		var outer_edge := side * far_edge
		AsterArt.collider(world, Vector3(rock_width, 38, toe + far_edge), Vector3((inner_edge + outer_edge) * 0.5, 15, (toe - far_edge) * 0.5), AsterArt.SOLID)
		_cliff(world, Vector3(inner_edge, 0, rear), Vector3(inner_edge, 0, toe), Vector3.RIGHT * side, 1200 + int(side), 13.0)
		_cliff(world, Vector3(inner_edge, 0, toe), Vector3(outer_edge, 0, toe), Vector3.FORWARD, 129 + int(side), 12.0)

static func _cliff(world: Node3D, start: Vector3, finish: Vector3, outward: Vector3, seed: int, height: float) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(6, roundi(start.distance_to(finish) / 1.48))
	var beds := [
		Vector2(0.04, 0.00), Vector2(0.20, 0.09), Vector2(0.38, 0.19), Vector2(0.58, 0.23),
		Vector2(0.24, 0.29), Vector2(0.71, 0.32), Vector2(1.00, 0.44), Vector2(1.36, 0.48),
		Vector2(0.95, 0.54), Vector2(1.68, 0.57), Vector2(2.05, 0.67), Vector2(2.62, 0.71),
		Vector2(1.97, 0.76), Vector2(2.94, 0.80), Vector2(3.65, 0.91), Vector2(4.85, 1.00),
		Vector2(8.55, 0.97), Vector2(15.50, 0.84),
	]
	var rock := Color("#cfb393")
	var seam := Color("#97785d")
	var columns: Array[PackedVector3Array] = []
	for segment in range(segments + 1):
		var t := float(segment) / segments
		var center := start.lerp(finish, t)
		var edge := smoothstep(0.0, 0.08, minf(t, 1.0 - t))
		var roll := 1.65 * sin(segment * 0.28 + seed) + 1.1 * sin(segment * 0.76)
		var width_break := sin(segment * 0.64 + seed) * 0.61 + sin(segment * 0.19) * 0.45
		var column := PackedVector3Array()
		for bed: Vector2 in beds:
			var y := 0.01 + (height + edge * roll) * bed.y
			y += random.randf_range(-0.36, 0.36) * minf(1.0, bed.y * 6.0) * edge
			var depth := bed.x + edge * (width_break + random.randf_range(-0.26, 0.26)) * minf(1.0, bed.y * 6.0)
			column.append(center + outward * maxf(-0.30, depth) + Vector3.UP * y)
		columns.append(column)
	for segment in range(segments):
		var left := columns[segment]
		var right := columns[segment + 1]
		for row in range(beds.size() - 1):
			var compress := row in [4, 8, 12]
			var tint := (seam if compress else rock).lerp(Color("#e1cbb0"), 0.10 + 0.09 * sin(segment * 0.41 + row))
			var n_left := _bed_normal(columns, segment, row, -outward)
			var n_right := _bed_normal(columns, segment + 1, row, -outward)
			_cliff_triangle(mesh, [left[row], right[row], right[row + 1]], [n_left, n_right, n_right], -outward, tint)
			_cliff_triangle(mesh, [left[row], right[row + 1], left[row + 1]], [n_left, n_right, n_left], -outward, tint)
	mesh.generate_tangents()
	var cliff := MeshInstance3D.new()
	cliff.mesh = mesh.commit()
	cliff.material_override = AsterModels.cliff_finish()
	world.add_child(cliff)

static func _bed_normal(columns: Array[PackedVector3Array], column: int, row: int, facing: Vector3) -> Vector3:
	var previous := columns[maxi(0, column - 1)]
	var following := columns[mini(columns.size() - 1, column + 1)]
	var along := (following[row] + following[row + 1]) - (previous[row] + previous[row + 1])
	var bed := columns[column]
	var normal := along.cross(bed[row + 1] - bed[row]).normalized()
	return normal if normal.dot(facing) >= 0.0 else -normal

static func _cliff_triangle(surface: SurfaceTool, points: Array, normals: Array, facing: Vector3, color: Color) -> void:
	var geometric: Vector3 = (points[2] - points[0]).cross(points[1] - points[0])
	var order := [0, 2, 1] if geometric.dot(facing) < 0.0 else [0, 1, 2]
	for index: int in order:
		var vertex: Vector3 = points[index]
		surface.set_color(color)
		surface.set_normal(normals[index])
		var along := vertex.z if absf(facing.x) > 0.5 else vertex.x
		surface.set_uv(Vector2(along * 0.195, -vertex.y * 0.255 + along * 0.007))
		surface.add_vertex(vertex)

static func mark_gate(world: Node3D, gate: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		for slot in range(8):
			var offset := -3.5 + slot * 0.85
			AsterArt.box(world, Vector3(0.095, 0.012, 0.52), gate + Vector3(side * 1.35, 0.012, offset), AsterArt.AMBER, true)
		AsterArt.box(world, Vector3(0.19, 0.53, 0.22), gate + Vector3(side * 1.77, 0.265, 3.55), AsterArt.METAL)
		AsterArt.box(world, Vector3(0.16, 0.095, 0.19), gate + Vector3(side * 1.77, 0.54, 3.55), AsterArt.AMBER, true)

static func _sand(world: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-19, 19):
		for z in range(-19, 19):
			var a := Vector3(x * 5.5, 0, z * 5.5)
			var b := a + Vector3(5.5, 0, 0)
			var c := a + Vector3(5.5, 0, 5.5)
			var d := a + Vector3(0, 0, 5.5)
			for vertex: Vector3 in [a, b, c, a, c, d]:
				var drift := 0.90 + sin(vertex.x * 0.22 + vertex.z * 0.16) * 0.055 + cos(vertex.z * 0.13 - vertex.x * 0.14) * 0.055
				var track := Vector2(vertex.x - 2.0, maxf(0.0, vertex.z - 38.0)).length()
				drift -= (1.0 - smoothstep(1.3, 7.0, track)) * 0.12
				surface.set_color(Color(drift, drift * 0.977, drift * 0.951))
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(vertex.x, vertex.z) * 0.33)
				surface.add_vertex(vertex)
	surface.generate_tangents()
	var terrain := MeshInstance3D.new()
	terrain.mesh = surface.commit()
	terrain.material_override = AsterModels.floor_finish()
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(terrain)
	AsterArt.collider(world, Vector3(210, 1.0, 210), Vector3(0, -0.5, 0), AsterArt.SOLID)

static func service_platform(world: Node3D, wall: AsterStructure) -> void:
	var landing := Node3D.new()
	world.add_child(landing)
	landing.global_position = wall.global_position - wall.outward * 3.56
	var platform_size := Vector3(2.78, 0.25, 0.82)
	var platform_center := Vector3(0, AsterStructure.WALL_HEIGHT - 0.119, 0)
	AsterArt.box(landing, platform_size, platform_center, AsterArt.METAL).material_override = AsterModels.deck_finish()
	for side: float in [-1.12, 1.12]:
		AsterArt.box(landing, Vector3(0.18, 3.0, 0.19), Vector3(side, 1.48, 0.28), AsterArt.DARK)
		AsterArt.box(landing, Vector3(0.10, 0.05, 0.80), Vector3(side, 3.22, 0), AsterArt.AMBER)
	var incline := Node3D.new()
	world.add_child(incline)
	var rise := AsterStructure.WALL_HEIGHT
	var pitch := atan2(rise, RAMP_START - RAMP_END)
	incline.rotation.x = -pitch * wall.outward.z
	incline.global_position = wall.global_position - wall.outward * ((RAMP_START + RAMP_END) / 2.0) + Vector3.UP * (rise / 2.0)
	var ramp_size := Vector3(2.38, 0.23, Vector2(rise, RAMP_START - RAMP_END).length())
	AsterArt.box(incline, ramp_size, Vector3.DOWN * ramp_size.y * 0.5, AsterArt.CONCRETE).material_override = AsterModels.deck_finish()
	for i in range(12):
		var tone := AsterArt.AMBER if i == 0 or i == 11 else AsterArt.DARK
		var position_on_ramp := (float(i) / 11.0 - 0.5) * (ramp_size.z - 0.30)
		AsterArt.box(incline, Vector3(2.19, 0.022, 0.085), Vector3(0, 0.012, position_on_ramp), tone)
	_build_ramp_surface(world, wall)
	AsterArt.lettering(world, "↑  ПЛОЩАДКА", wall.global_position - wall.outward * 8.5 + Vector3.UP * 1.11, 23, AsterArt.AMBER, true)

static func ramp_point(wall: AsterStructure, depth: float) -> Vector3:
	var fraction := clampf((RAMP_START - depth) / (RAMP_START - RAMP_END), 0.0, 1.0)
	return wall.global_position - wall.outward * depth + Vector3.UP * AsterStructure.WALL_HEIGHT * fraction

static func _build_ramp_surface(world: Node3D, wall: AsterStructure) -> void:
	var points := [ramp_point(wall, RAMP_START), ramp_point(wall, RAMP_END), ramp_point(wall, LANDING_EDGE)]
	walkable_strip(world, points, [1.19, 1.19, 1.38])

static func walkable_strip(world: Node3D, points: Array, half_widths: Array) -> void:
	var vertices := PackedVector3Array()
	for index in range(points.size() - 1):
		var left: Vector3 = points[index] - Vector3.RIGHT * half_widths[index]
		var right: Vector3 = points[index] + Vector3.RIGHT * half_widths[index]
		var far_left: Vector3 = points[index + 1] - Vector3.RIGHT * half_widths[index + 1]
		var far_right: Vector3 = points[index + 1] + Vector3.RIGHT * half_widths[index + 1]
		vertices.append_array(PackedVector3Array([left, right, far_right, left, far_right, far_left]))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(vertices)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.collision_layer = AsterArt.ACCESS
	body.collision_mask = 0
	body.set_meta(&"footstep_deck", true)
	body.add_child(collision)
	world.add_child(body)
