class_name AsterTerrain
extends RefCounted

const FRONT_Z := 12.0
const FRONT_HALF_WIDTH := 14.0
const FRONT_APPROACH_Z := FRONT_Z + 2.10
const BUNKER_GATE := Vector3(0, 0, -13.65)
const ARENA_EDGE := 91.0
const FAR_EDGE := 180.0
const BASTION_X := 16.65
const BASTION_SPACING := 11.10
const BASTIONS_PER_SIDE := 3
const BASTION_Z := 16.25
const BASTION_DECK := 8.88
const FACADE_ROOF_CENTER_Z := -2.96
const CAVE_SITES := [Vector2(-70, 148), Vector2(-51, 143), Vector2(-31, 154), Vector2(-11, 147),
	Vector2(11, 141), Vector2(31, 150), Vector2(51, 145), Vector2(70, 153)]
const CAVE_LANES := [-64.0, -37.7, -18.4, 0.55, 1.65, 20.75, 40.7, 62.9]
const NEST_SITES := [Vector2(-78, 172), Vector2(-62, 175), Vector2(-45, 171), Vector2(-28, 177),
	Vector2(-13, 173), Vector2(5, 169), Vector2(23, 175), Vector2(40, 170), Vector2(58, 175), Vector2(77, 176)]
const CAVE_PASSAGE := [Vector2(0, 0), Vector2(-0.25, 2.15), Vector2(0.68, 4.55), Vector2(3.24, 6.74), Vector2(6.23, 8.30), Vector2(7.45, 10.23)]
const SCREEN_Z := 53.8
const SCREEN_SITES := [
	Vector2(-47.3, 55.1), Vector2(-28.2, 52.4), Vector2(-8.6, 54.8),
	Vector2(10.8, 57.1), Vector2(30.7, 51.6), Vector2(50.3, 55.7),
]
const RIDGE_MODELS := [&"canyon_ridge", &"canyon_spur", &"canyon_cut"]
const GROUND_STEP := 2.0
const GROUND_RADIUS := 117
const GROUND_TILE_STEPS := 39
const RAMP_START := 8.02
const RAMP_END := 3.85
const LANDING_EDGE := AsterStructure.WALL_DEPTH - AsterStructure.OUTER_FACE - 0.03

static var _ground_tiles: Array[ArrayMesh] = []
static var _ground_collision: ConcavePolygonShape3D

class TurretMounts:
	var stingers := PackedVector3Array()
	var dragonflies := PackedVector3Array()
	var bulbas := PackedVector3Array()

static func build(world: Node3D, mounts: TurretMounts) -> PackedVector3Array:
	_sand(world)
	_build_fortifications(world, mounts)
	_build_screening_ridges(world)
	_build_desert_dressing(world)
	_build_eroded_outcrops(world)
	_build_bastions(world)
	for index in range(CAVE_SITES.size()):
		_build_cave(world, index)
	_build_facade_balconies(world)

	for side: float in [-1, 1]:
		AsterArt.collider(world, Vector3(0.5, 70, ARENA_EDGE + FAR_EDGE + 2.0), Vector3(side * ARENA_EDGE, 8, (FAR_EDGE - ARENA_EDGE) * 0.5), AsterArt.SOLID)
	for edge: float in [-ARENA_EDGE, FAR_EDGE]:
		AsterArt.collider(world, Vector3(ARENA_EDGE * 2.0 + 2.0, 70, 0.5), Vector3(0, 8, edge), AsterArt.SOLID)
	return _build_nests(world)

static func _height_profile(x: float, z: float) -> float:
	var apron := smoothstep(18.5, 34.0, z)
	var shoulder := smoothstep(12.7, 32.0, absf(x))
	var ground := 0.24 * sin(x * 0.32 + z * 0.23) + 0.128 * cos(z * 0.45 - x * 0.14)
	ground += 0.16 * sin(x * 0.71 - z * 0.313) * smoothstep(17.0, 24.0, absf(x))
	var terraces := 1.05 + 0.65 * sin(z * 0.176 + x * 0.077) + 0.29 * cos(x * 0.19 - z * 0.13)
	var ridge_center := -27.3 + 2.5 * sin(z * 0.139) if x < 0.0 else 29.0 + 3.1 * cos(z * 0.121)
	var ridge_width := 18.6 + 1.7 * sin(z * 0.123 - x * 0.048)
	var ridge_profile := 1.0 - smoothstep(2.75, ridge_width, absf(x - ridge_center))
	var ascent := smoothstep(24.0, 50.0, z) * (1.0 - smoothstep(60.0, 77.0, z))
	var ridge_height := (3.36 if x < 0.0 else 4.27) + sin(z * 0.27 + x * 0.13) * 0.67
	var channel := 2.5 + sin(z * 0.154) * 3.2 + cos(z * 0.29) * 1.34
	var wash := 0.76 * (1.0 - smoothstep(1.35, 5.5, absf(x - channel)))
	var foothills := smoothstep(69.0, 92.0, z) * (1.0 - smoothstep(116.0, 132.0, z))
	var swell := 1.7 + 1.06 * sin(x * 0.12 + z * 0.09) + 0.58 * cos(x * 0.25 - z * 0.121)
	var gullies := 0.45 * sin(x * 0.38 + z * 0.105) * sin(z * 0.33)
	return apron * (ground + shoulder * terraces - wash * smoothstep(23.0, 38.0, z)) + ridge_height * ascent * ridge_profile + foothills * (swell + gullies)

static func _build_desert_dressing(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 16014
	var dressing := Node3D.new()
	dressing.name = "CanyonDressing"
	world.add_child(dressing)
	var ridge_batches: Array[Array] = [[], [], []]
	for i in range(17):
		var angle := (i / 16.0 - 0.5) * 2.99 + rng.randf_range(-0.029, 0.029)
		var direction := Vector3(sin(angle), 0, cos(angle))
		var distance := rng.randf_range(164.0, 220.0) / maxf(absf(direction.x), absf(direction.z))
		var mass := 0.84 + 0.42 * pow(absf(sin(i * 0.89)), 2.0)
		var size := Vector3(rng.randf_range(2.45, 3.48), rng.randf_range(1.23, 2.13), rng.randf_range(1.65, 3.2)) * mass
		var center := direction * distance + Vector3.DOWN * 1.02
		ridge_batches[i % 3].append(_scatter_transform(center, size, rng.randf_range(-0.65, 0.65)))
		ridge_batches[(i + 1) % 3].append(_scatter_transform(center * 0.92 + direction.cross(Vector3.UP) * 10.4,
			size * Vector3(0.79, 0.49, 1.02), rng.randf_range(-0.82, 0.82)))
	for index in range(RIDGE_MODELS.size()):
		var placements: Array[Transform3D] = []
		placements.assign(ridge_batches[index])
		AsterModels.scatter(dressing, RIDGE_MODELS[index], placements)

	var shale: Array[Transform3D] = []
	var rubble: Array[Transform3D] = []
	var scrub: Array[Transform3D] = []
	for field in range(99):
		var angle := rng.randf_range(-1.50, 1.50)
		var distance := rng.randf_range(8.4, 140.0)
		var center := Vector2(sin(angle) * distance, FRONT_Z + cos(angle) * distance * 0.89)
		for index in range(rng.randi_range(2, 6)):
			var point := center + Vector2(rng.randf_range(-2.7, 2.7), rng.randf_range(-2.3, 2.3))
			if point.y < 15.1 or (absf(point.x - 2.0) < 2.8 and point.y < 35.0):
				continue
			var size := rng.randf_range(0.13, 0.71) * (1.72 if index == 0 else 1.0)
			var at := Vector3(point.x, surface_height(point.x, point.y) - size * 0.04, point.y)
			shale.append(_scatter_transform(at, Vector3(size * 1.31, size * rng.randf_range(0.29, 0.59), size), rng.randf() * TAU))
		if field % 6 == 0 and absf(center.x) > 6.6:
			var at := Vector3(center.x, surface_height(center.x, center.y), center.y)
			scrub.append(_scatter_transform(at, Vector3.ONE * rng.randf_range(0.65, 1.19), rng.randf() * TAU))
	for side in [-1.0, 1.0]:
		for index in range(14):
			var x: float = side * (23.5 + 4.18 * sin(index * 0.73) + rng.randf_range(-1.3, 1.3))
			var z := 26.7 + index * 1.64 + rng.randf_range(-0.85, 0.85)
			var ground := surface_height(x, z)
			rubble.append(_scatter_transform(Vector3(x, ground - 0.22, z),
				Vector3(rng.randf_range(0.9, 2.25), rng.randf_range(0.27, 0.53), rng.randf_range(0.67, 1.5)),
				rng.randf() * TAU))
		for index in range(13):
			var point := Vector3(side * rng.randf_range(FRONT_HALF_WIDTH - 0.8, FRONT_HALF_WIDTH - 0.08), -0.035, -11.1 + index * 1.81)
			rubble.append(_scatter_transform(point, Vector3(0.91, rng.randf_range(0.21, 0.59), 1.12), rng.randf() * TAU))
			if index % 3 == 0:
				scrub.append(_scatter_transform(point + Vector3(side * -0.15, 0.029, 0.42), Vector3.ONE * rng.randf_range(0.54, 0.96), rng.randf() * TAU))
	AsterModels.scatter(dressing, &"stone_2", rubble)
	AsterModels.scatter(dressing, &"stone_3", shale)
	AsterModels.scatter(dressing, &"scrub", scrub)

static func _build_eroded_outcrops(world: Node3D) -> void:
	var ledges: Array[Transform3D] = []
	var scrub: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 26371
	for position in [Vector2(-21, 26), Vector2(-26, 35), Vector2(28, 32), Vector2(47, 69), Vector2(-49, 83),
			Vector2(13, 85), Vector2(34, 98), Vector2(-27, 105), Vector2(52, 118), Vector2(-80, 121), Vector2(2, 124)]:
		var at := Vector3(position.x, surface_height(position.x, position.y) - 0.24, position.y)
		var size := Vector3(rng.randf_range(1.55, 3.3), rng.randf_range(0.83, 1.53), rng.randf_range(1.34, 2.23))
		var yaw := rng.randf_range(-PI, PI)
		var placement := _scatter_transform(at, size, yaw)
		ledges.append(placement)
		var collision := AsterArt.collider(world, Vector3(1.26, 1.27, 0.88) * size,
			placement * Vector3(-0.86, 0.53, -0.12), AsterArt.SOLID | AsterArt.SPAWN_SCREEN)
		collision.rotation.y = yaw
		for step in range(3):
			var x := at.x + rng.randf_range(-3.4, 3.4)
			var z := at.z - rng.randf_range(2.8, 5.5)
			scrub.append(_scatter_transform(Vector3(x, surface_height(x, z), z), Vector3.ONE * rng.randf_range(0.8, 1.66), rng.randf() * TAU))
	AsterModels.scatter(world, &"scan_rock", ledges)
	AsterModels.scatter(world, &"scrub", scrub)

static func _scatter_transform(at: Vector3, size: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), at)

static func _build_screening_ridges(world: Node3D) -> void:
	var ridge := Node3D.new()
	ridge.name = "ScreeningRidges"
	world.add_child(ridge)
	var shapes := [0, 1, 2, 1, 0, 2]
	var relief := [0.71, 0.42, 0.62, 0.64, 0.52, 0.72]
	var talus: Array[Transform3D] = []
	for index in range(SCREEN_SITES.size()):
		var site: Vector2 = SCREEN_SITES[index]
		var rock_floor := surface_height(site.x, site.y)
		for edge: Vector2 in [Vector2(-5.8, 0), Vector2(5.8, 0), Vector2(-3.5, -3.1), Vector2(3.5, 3.1)]:
			rock_floor = minf(rock_floor, surface_height(site.x + edge.x, site.y + edge.y))
		var center := Vector3(site.x, rock_floor - 0.47, site.y)
		var size := Vector3(1.0, relief[index], 1.0)
		var rock := AsterModels.attach(ridge, RIDGE_MODELS[shapes[index]], center, size)
		rock.rotation.y = PI if index in [0, 2, 3] else 0.0
		_rock_collision(rock, AsterArt.SOLID | AsterArt.SPAWN_SCREEN)
		for step in range(4):
			var x := center.x + (-1.0 if index % 2 else 1.0) * (2.42 + step * 1.07)
			var z := center.z - 2.71 - step * 0.76
			talus.append(_scatter_transform(Vector3(x, surface_height(x, z) - 0.11, z),
				Vector3(2.32 - step * 0.33, 1.12 - step * 0.19, 1.21), index + step * 0.79))
	AsterModels.scatter(ridge, &"stone_1", talus)

static func _rock_collision(rock: MeshInstance3D, layers: int) -> void:
	var solid := StaticBody3D.new()
	solid.collision_layer = layers
	solid.collision_mask = 0
	solid.position = rock.position
	solid.rotation = rock.rotation
	var faces := rock.mesh.get_faces()
	for vertex in range(faces.size()):
		faces[vertex] *= rock.scale
	var hull := ConcavePolygonShape3D.new()
	hull.set_faces(faces)
	hull.backface_collision = true
	var shape := CollisionShape3D.new()
	shape.shape = hull
	solid.add_child(shape)
	rock.get_parent().add_child(solid)

static func bastion_anchors() -> PackedVector3Array:
	var anchors := PackedVector3Array()
	for index in range(BASTIONS_PER_SIDE):
		for side: float in [-1, 1]:
			anchors.append(Vector3(side * (BASTION_X + index * BASTION_SPACING), 0.0, BASTION_Z))
	return anchors

static func _build_bastions(world: Node3D) -> void:
	var approach := Node3D.new()
	approach.name = "FortressBastions"
	world.add_child(approach)
	for anchor in bastion_anchors():
		var side := signf(anchor.x)
		var shoulder := AsterModels.attach(approach, &"canyon_bastion", anchor, Vector3(1.10, 1, 1.14))
		shoulder.rotation.y = side * -0.075
		_rock_collision(shoulder, AsterArt.SOLID)
		var foot := anchor + Vector3(-side * 1.75, 6.75, 0.16)
		floodlight(approach, foot, Vector3(anchor.x - side * 8.65, 0, 35.0), 7.8, 45.0, 37.0)
	for side: float in [-1, 1]:
		var joint := Vector3(side * (FRONT_HALF_WIDTH + 0.60), 1.52, FRONT_Z + 0.25)
		var seam := Vector3(1.31, 3.03, 1.18)
		AsterArt.box(approach, seam, joint, AsterArt.METAL).material_override = AsterModels.deck_finish()
		AsterArt.collider(approach, seam, joint, AsterArt.SOLID)

static func _build_facade_balconies(world: Node3D) -> void:
	_balcony(world, Vector3(-FRONT_HALF_WIDTH + 0.48, 6.6, 1.80), PI * 0.5, 4.10)
	_balcony(world, Vector3(-0.80, 9.25, -12.12), 0.0, 5.35)
	_balcony(world, Vector3(FRONT_HALF_WIDTH - 0.48, 7.08, -1.50), -PI * 0.5, 3.70)

static func _balcony(world: Node3D, at: Vector3, yaw: float, width: float) -> void:
	var balcony := Node3D.new()
	balcony.name = "ServiceBalcony"
	balcony.position = at
	balcony.rotation.y = yaw
	world.add_child(balcony)
	AsterArt.box(balcony, Vector3(width, 0.26, 2.05), Vector3(0, 0, 0.52), AsterArt.METAL).material_override = AsterModels.deck_finish()
	AsterArt.box(balcony, Vector3(width - 0.16, 1.88, 0.64), Vector3(0, 0.88, -0.31), AsterArt.METAL).material_override = AsterModels.deck_finish()
	AsterArt.box(balcony, Vector3(0.90, 1.47, 0.13), Vector3(-width * 0.22, 0.74, 0.03), AsterArt.DARK)
	AsterArt.box(balcony, Vector3(0.10, 0.10, 0.04), Vector3(-width * 0.22 + 0.30, 0.74, 0.11), AsterArt.AMBER, true)
	AsterArt.box(balcony, Vector3(width, 0.075, 0.075), Vector3(0, 0.99, 1.51), AsterArt.PALE)
	AsterArt.box(balcony, Vector3(width, 0.044, 0.044), Vector3(0, 0.54, 1.51), AsterArt.METAL)
	for x: float in [-width * 0.48, 0.0, width * 0.48]:
		AsterArt.box(balcony, Vector3(0.074, 0.88, 0.074), Vector3(x, 0.56, 1.51), AsterArt.METAL)
	for x: float in [-width * 0.34, width * 0.34]:
		var brace := AsterArt.box(balcony, Vector3(0.19, 1.94, 0.22), Vector3(x, -0.83, 0.52), AsterArt.DARK)
		brace.rotation.x = -0.73
	for x: float in [-width * 0.48, width * 0.48]:
		AsterArt.box(balcony, Vector3(0.075, 0.075, 1.52), Vector3(x, 0.99, 0.76), AsterArt.PALE)
	floodlight(balcony, Vector3(width * 0.25, -0.39, 1.63), Vector3(width * 0.50, -9.4, 8.0), 2.8)

static func floodlight(parent: Node3D, at: Vector3, target: Vector3, energy: float, reach := 26.0, angle := 32.0, size := 1.0) -> void:
	var lamp := Node3D.new()
	lamp.name = "Floodlight"
	lamp.position = at
	parent.add_child(lamp)
	lamp.look_at(parent.to_global(target))
	AsterArt.box(lamp, Vector3(0.77, 0.46, 0.32), Vector3.ZERO, AsterArt.DARK).material_override = AsterModels.deck_finish()
	var glass := AsterArt.box(lamp, Vector3(0.67, 0.34, 0.04), Vector3(0, 0, -0.166), Color("#e2f5ff"), true)
	for x: float in [-0.22, 0.0, 0.22]:
		AsterArt.box(lamp, Vector3(0.022, 0.35, 0.032), Vector3(x, 0, -0.196), AsterArt.DARK)
	var beam := SpotLight3D.new()
	beam.position.z = -0.22
	beam.light_color = Color("#cce8ff")
	beam.light_energy = energy
	beam.spot_range = reach
	beam.spot_angle = angle
	beam.shadow_enabled = reach >= 20.0
	beam.shadow_bias = 0.07
	lamp.add_child(beam)
	lamp.scale = Vector3.ONE * size
	AsterDaylight.fixture(beam, glass)

static func cave_transform(index: int) -> Transform3D:
	var site: Vector2 = CAVE_SITES[index]
	var scale_factor := 0.81 + 0.048 * (index % 4)
	var yaw := 0.145 * sin(index * 2.66)
	return Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3.ONE * scale_factor), Vector3(site.x, surface_height(site.x, site.y), site.y))

static func _build_cave(world: Node3D, site_index: int) -> void:
	var passage := [Vector2(-2.63, -0.83), Vector2(-2.46, 1.37), Vector2(-1.89, 2.74), Vector2(-0.68, 3.46),
		Vector2(0.86, 3.34), Vector2(1.96, 2.60), Vector2(2.43, 1.22), Vector2(2.51, -0.79)]
	var ridge := [Vector2(-11.40, -0.86), Vector2(-9.75, 2.20), Vector2(-6.90, 5.14), Vector2(-2.76, 7.40),
		Vector2(2.41, 7.66), Vector2(7.88, 5.84), Vector2(11.64, 3.51), Vector2(14.15, -0.86)]
	var inside: Array[PackedVector3Array] = []
	var outside: Array[PackedVector3Array] = []
	for index in range(CAVE_PASSAGE.size()):
		var station: Vector2 = CAVE_PASSAGE[index]
		var inner := PackedVector3Array()
		var outer := PackedVector3Array()
		for edge in range(passage.size()):
			var opening: Vector2 = passage[edge]
			var rock: Vector2 = ridge[edge]
			var height := sin(index * 1.06 + edge * 0.64 + site_index * 1.84)
			var above_floor := smoothstep(-0.7, 2.0, opening.y)
			inner.append(Vector3(station.x + opening.x, opening.y + height * above_floor * 0.16, station.y))
			var spread := 0.96 + sin(index * 0.77 + 0.21) * 0.15
			var setback := sin(edge * 1.14 + index * 0.52 + site_index * 0.70) * 1.25
			outer.append(Vector3(station.x * 0.62 + rock.x * spread, rock.y + height * above_floor * 0.88, station.y + setback))
		inside.append(inner)
		outside.append(outer)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var entrance := PackedVector3Array()
	var ledges := [-1.65, -2.15, -1.36, -0.60, -1.82, -1.02, -2.32, -1.90]
	for edge in range(passage.size()):
		var ledge := inside[0][edge].lerp(outside[0][edge], 0.38 + 0.14 * sin(edge * 2.5))
		ledge.z = ledges[edge] + 0.35 * sin(edge * 2.8 + site_index * 1.1)
		entrance.append(ledge)
	for edge in range(passage.size() - 1):
		var opening: Vector2 = passage[edge].lerp(passage[edge + 1], 0.5)
		var facing := Vector3(opening.x, opening.y - 0.32, 0).normalized()
		var color := Color("#d2c4af").lerp(Color("#9c8574"), 0.18 + 0.16 * cos(edge * 2.7))
		for index in range(CAVE_PASSAGE.size() - 1):
			var shade := color.darkened(0.19 + 0.06 * index)
			_cave_face(surface, [inside[index][edge], inside[index + 1][edge], inside[index + 1][edge + 1], inside[index][edge + 1]], -facing, shade)
			_cave_face(surface, [outside[index][edge], outside[index + 1][edge], outside[index + 1][edge + 1], outside[index][edge + 1]], facing, color)
		_cave_face(surface, [inside[0][edge], inside[0][edge + 1], entrance[edge + 1], entrance[edge]], Vector3.FORWARD, color.darkened(0.09))
		_cave_face(surface, [entrance[edge], entrance[edge + 1], outside[0][edge + 1], outside[0][edge]], Vector3.FORWARD, color)
		_cave_face(surface, [inside[-1][edge], inside[-1][edge + 1], outside[-1][edge + 1], outside[-1][edge]], Vector3.BACK, color)
		var center := Vector3(CAVE_PASSAGE[-1].x, -0.84, CAVE_PASSAGE[-1].y)
		_cave_face(surface, [inside[-1][edge], inside[-1][edge + 1], center], Vector3.FORWARD, color.darkened(0.37))
	surface.generate_tangents()
	var cave := MeshInstance3D.new()
	cave.name = "DuneCave%d" % (site_index + 1)
	cave.transform = cave_transform(site_index)
	cave.mesh = surface.commit()
	cave.material_override = AsterModels.cliff_finish()
	world.add_child(cave)
	_rock_collision(cave, AsterArt.SOLID | AsterArt.SPAWN_SCREEN)
	var rim := AsterModels.attach(world, &"scan_rock", cave.transform * Vector3(1.65, 3.24, -0.94), Vector3(2.34, 1.18, 1.58))
	rim.rotation.y = cave.rotation.y - 0.11 * sin(site_index * 2.0)
	for side: float in [-1, 1]:
		var buttress := AsterModels.attach(world, &"scan_rock", cave.transform * Vector3(side * 5.1, 0.03, -0.93), Vector3(2.10, 2.33, 2.14))
		buttress.rotation.y = cave.rotation.y + (0.16 if side < 0 else -PI + 0.17 * sin(site_index))
		for step in range(4):
			var position_in_cave := Vector3(side * (3.9 + step * 1.93), 0, -1.25 - 0.68 * step + 0.53 * sin(step * 1.5 + site_index))
			var at := cave.transform * position_in_cave
			at.y = surface_height(at.x, at.z) - 0.14
			var size := Vector3(3.25, 2.46, 2.61) * (1.0 - step * 0.17)
			var rubble := AsterModels.attach(world, &"stone_1" if step % 2 == 0 else &"stone_2", at, size)
			rubble.rotation.y = side * step * 1.08 + site_index

static func _build_nests(world: Node3D) -> PackedVector3Array:
	var group := Node3D.new()
	group.name = "MountainNests"
	world.add_child(group)
	var locations := PackedVector3Array()
	for index in range(NEST_SITES.size()):
		var site: Vector2 = NEST_SITES[index]
		var size := Vector3(1.72, 1.38 + 0.14 * (index % 5), 1.71)
		var rock := AsterModels.attach(group, RIDGE_MODELS[index % RIDGE_MODELS.size()], Vector3(site.x, -0.47, site.y), size)
		rock.rotation.y = 0.14 * sin(index * 2.2)
		_rock_collision(rock, AsterArt.SOLID | AsterArt.SPAWN_SCREEN)
		var faces := rock.mesh.get_faces()
		var center := Vector3(0.25, 0.0, -0.17)
		var top := 0.0
		for vertex in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(center + Vector3.UP * 25.0, center, faces[vertex], faces[vertex + 1], faces[vertex + 2])
			if hit != null:
				top = maxf(top, hit.y)
		center.y = top
		var nest := AsterModels.attach(group, &"nest", rock.transform * center - Vector3.UP * 0.15, Vector3(0.80, 0.84, 0.82))
		nest.rotation.y = index * 0.38
		locations.append(nest.position + Vector3.UP * 0.30)
	return locations

static func _cave_face(surface: SurfaceTool, points: Array, facing: Vector3, tint: Color) -> void:
	for index in range(2, points.size()):
		var a: Vector3 = points[0]
		var b: Vector3 = points[index - 1]
		var c: Vector3 = points[index]
		var normal := (c - a).cross(b - a).normalized()
		var vertices := [a, b, c]
		if normal.dot(facing) < 0.0:
			normal = -normal
			vertices = [a, c, b]
		for vertex: Vector3 in vertices:
			var uv := Vector2(vertex.x, vertex.z)
			if absf(normal.y) < 0.60:
				uv = Vector2(vertex.z if absf(normal.x) > absf(normal.z) else vertex.x, -vertex.y)
			surface.set_uv(uv * 0.29)
			surface.set_color(tint)
			surface.set_normal(normal)
			surface.add_vertex(vertex)

static func _build_fortifications(world: Node3D, mounts: TurretMounts) -> void:
	var rear := -FRONT_Z
	var toe := FRONT_Z + 0.43
	var far_edge := ARENA_EDGE + 6.0
	var built_edge := 46.35
	var opening := 2.76
	var recess_back := BUNKER_GATE.z - 2.7
	var walls := Node3D.new()
	walls.name = "FortressBuildings"
	world.add_child(walls)
	for side: float in [-1, 1]:
		AsterArt.collider(world, Vector3(far_edge - opening, 14, far_edge + rear), Vector3(side * (far_edge + opening) * 0.5, 3, (rear - far_edge) * 0.5), AsterArt.SOLID)
		for bay in range(2):
			var building := _facade(walls, Vector3(side * (6.05 + bay * 6.36), 0, rear), 0.0, 0.93 + 0.19 * bay)
			if bay == 1:
				_mount_roof_pair(building, mounts.bulbas)
		var inner_edge := side * FRONT_HALF_WIDTH
		var outer_edge := side * far_edge
		AsterArt.collider(world, Vector3(built_edge - FRONT_HALF_WIDTH, 12, toe + far_edge), Vector3(side * (FRONT_HALF_WIDTH + built_edge) * 0.5, 2, (toe - far_edge) * 0.5), AsterArt.SOLID)
		AsterArt.collider(world, Vector3(far_edge - built_edge, 38, toe + far_edge), Vector3(side * (built_edge + far_edge) * 0.5, 15, (toe - far_edge) * 0.5), AsterArt.SOLID)
		for bay in range(4):
			var building := _facade(walls, Vector3(inner_edge, 0, rear + 2.97 + bay * 6.10), -side * PI * 0.5, 0.83 + 0.08 * ((bay + 1) % 3))
			if bay == 3:
				mounts.dragonflies.append(_facade_roof_point(building, 0.0))
		for bay in range(5):
			var building := _facade(walls, Vector3(side * (FRONT_HALF_WIDTH + 3.10 + bay * 6.45), 0, toe), 0.0, 0.87 + 0.08 * (bay % 2))
			if bay == 1:
				mounts.dragonflies.append(_facade_roof_point(building, 0.0))
		_cliff(world, Vector3(side * built_edge, 0, toe), Vector3(outer_edge, 0, toe), Vector3.FORWARD, 129 + int(side), 15.2)
		var platform := Vector3(side * 12.15, 7.50, 9.85)
		_turret_platform(walls, platform, -side * PI * 0.5)
		mounts.stingers.append(platform)
	AsterArt.collider(world, Vector3(opening * 2.0, 14, far_edge + recess_back), Vector3(0, 3, (recess_back - far_edge) * 0.5), AsterArt.SOLID)
	AsterArt.collider(world, Vector3(opening * 2.0, 7.4, rear - recess_back), Vector3(0, 8.3, (rear + recess_back) * 0.5), AsterArt.SOLID)
	var bunker := _facade(walls, Vector3(0, 4.62, rear - 0.1), 0.0, 0.77)
	_mount_roof_pair(bunker, mounts.bulbas)
	var rear_platform := Vector3(0, 6.50, -9.83)
	_turret_platform(walls, rear_platform, 0.0)
	mounts.stingers.append(rear_platform)
	_build_gate_recess(world, rear)
	AsterArt.lettering(walls, "ФОРПОСТ АСТЕР", Vector3(0, 12.06, rear - 0.40), 81, Color("#c4c5b8"))
	for side: float in [-1, 1]:
		var at := Vector3(side * 6.13, 5.25, rear + 0.53)
		floodlight(walls, at, Vector3(side * 6.0, 0.25, -6.0), 5.4, 22.0, 43.0, 0.59)

static func _facade(parent: Node3D, at: Vector3, yaw: float, height: float) -> MeshInstance3D:
	var facade := AsterModels.attach(parent, &"facade", at, Vector3(1.0, height, 1.0))
	facade.rotation.y = yaw
	_rock_collision(facade, AsterArt.SOLID)
	return facade

static func _mount_roof_pair(building: MeshInstance3D, points: PackedVector3Array) -> void:
	for x: float in [-1.51, 1.51]:
		points.append(_facade_roof_point(building, x))

static func _facade_roof_point(building: MeshInstance3D, x: float) -> Vector3:
	var origin := Vector3(x, 0, FACADE_ROOF_CENTER_Z)
	var start := origin + Vector3.UP * 20.0
	var faces := building.mesh.get_faces()
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, origin, faces[index], faces[index + 1], faces[index + 2])
		if hit != null:
			origin.y = maxf(origin.y, hit.y)
	return building.transform * origin

static func _turret_platform(parent: Node3D, at: Vector3, yaw: float) -> void:
	var platform := AsterModels.attach(parent, &"turret_platform", at)
	platform.rotation.y = yaw
	_rock_collision(platform, AsterArt.SOLID)

static func _build_gate_recess(world: Node3D, rear: float) -> void:
	var recess := Node3D.new()
	recess.name = "BunkerRecess"
	recess.position = Vector3(0, 0, BUNKER_GATE.z)
	world.add_child(recess)
	var depth := rear - BUNKER_GATE.z + 0.78
	AsterArt.box(recess, Vector3(6.42, 0.47, depth), Vector3(0, 4.87, 0.56), AsterArt.DARK).material_override = AsterModels.deck_finish()
	AsterArt.box(recess, Vector3(5.64, 4.64, 0.26), Vector3(0, 2.32, -1.24), AsterArt.DARK)
	for side: float in [-1.0, 1.0]:
		AsterArt.box(recess, Vector3(0.76, 4.70, depth), Vector3(side * 3.02, 2.35, 0.56), AsterArt.METAL).material_override = AsterModels.deck_finish()
		AsterArt.box(recess, Vector3(0.18, 3.8, 0.14), Vector3(side * 3.14, 2.0, 1.81), AsterArt.DARK)
		AsterArt.box(recess, Vector3(0.09, 0.65, 0.08), Vector3(side * 3.14, 3.50, 1.90), AsterArt.AMBER, true)

static func _cliff(world: Node3D, start: Vector3, finish: Vector3, outward: Vector3, seed: int, height: float) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(6, roundi(start.distance_to(finish) / 1.17))
	var beds := [
		Vector2(0.04, 0.00), Vector2(0.20, 0.09), Vector2(0.38, 0.19), Vector2(0.58, 0.23),
		Vector2(0.24, 0.29), Vector2(0.71, 0.32), Vector2(1.00, 0.44), Vector2(1.36, 0.48),
		Vector2(0.95, 0.54), Vector2(1.68, 0.57), Vector2(2.05, 0.67), Vector2(2.62, 0.71),
		Vector2(1.97, 0.76), Vector2(2.94, 0.80), Vector2(3.65, 0.91), Vector2(4.55, 1.00),
		Vector2(5.45, 0.995), Vector2(6.65, 0.96),
	]
	var rock := Color("#e1d7c9")
	var seam := Color("#ac9688")
	var columns: Array[PackedVector3Array] = []
	for segment in range(segments + 1):
		var t := float(segment) / segments
		var center := start.lerp(finish, t)
		var edge := smoothstep(0.0, 0.08, minf(t, 1.0 - t))
		var roll := 3.10 * sin(segment * 0.132 + seed) + 1.96 * sin(segment * 0.31 + 1.4) + 0.70 * sin(segment * 0.61)
		var width_break := sin(segment * 0.57 + seed) * 0.95 + sin(segment * 0.23) * 0.98
		var column := PackedVector3Array()
		for row in range(beds.size()):
			var bed: Vector2 = beds[row]
			var y := -0.065 + (height + edge * roll) * bed.y
			y += random.randf_range(-0.27, 0.27) * minf(1.0, bed.y * 6.0) * edge
			if row > 0 and row < beds.size() - 2:
				y = maxf(y, column[row - 1].y + 0.079)
			var depth := bed.x + edge * (width_break + random.randf_range(-0.30, 0.30)) * minf(1.0, bed.y * 2.2)
			column.append(center + outward * maxf(-0.30, depth) + Vector3.UP * y)
		columns.append(column)
	var end_direction := (finish - start).normalized()
	var orientation := signf(end_direction.cross(Vector3.UP).dot(-outward))
	for segment in range(segments):
		var left := columns[segment]
		var right := columns[segment + 1]
		for row in range(beds.size() - 1):
			var compress := row in [4, 8, 12]
			var tint := (seam if compress else rock).lerp(Color("#e6dace"), 0.10 + 0.09 * sin(segment * 0.41 + row))
			var n_left := _bed_normal(columns, segment, row) * orientation
			var n_right := _bed_normal(columns, segment + 1, row) * orientation
			_cliff_triangle(mesh, [left[row], right[row], right[row + 1]], [n_left, n_right, n_right], outward, orientation > 0.0, tint)
			_cliff_triangle(mesh, [left[row], right[row + 1], left[row + 1]], [n_left, n_right, n_left], outward, orientation > 0.0, tint)
	_cliff_endcap(mesh, columns[0], outward, -end_direction)
	_cliff_endcap(mesh, columns[segments], outward, end_direction)
	mesh.generate_tangents()
	var cliff := MeshInstance3D.new()
	cliff.mesh = mesh.commit()
	cliff.material_override = AsterModels.cliff_finish()
	world.add_child(cliff)

static func _cliff_endcap(surface: SurfaceTool, section: PackedVector3Array, outward: Vector3, facing: Vector3) -> void:
	var outline := section.duplicate()
	var bottom := outline[-1]
	bottom.y = outline[0].y
	outline.append(bottom)
	var local := PackedVector2Array()
	var origin := outline[0]
	for vertex in outline:
		local.append(Vector2((vertex - origin).dot(outward), vertex.y - origin.y))
	var indices := Geometry2D.triangulate_polygon(local)
	for triangle in range(0, indices.size(), 3):
		var a := outline[indices[triangle]]
		var b := outline[indices[triangle + 1]]
		var c := outline[indices[triangle + 2]]
		var flip := (c - a).cross(b - a).dot(facing) < 0.0
		_cliff_triangle(surface, [a, b, c], [facing, facing, facing], facing, flip, Color("#d7c9b8"))

static func _bed_normal(columns: Array[PackedVector3Array], column: int, row: int) -> Vector3:
	var previous := columns[maxi(0, column - 1)]
	var following := columns[mini(columns.size() - 1, column + 1)]
	var along := (following[row] + following[row + 1]) - (previous[row] + previous[row + 1])
	var bed := columns[column]
	return along.cross(bed[row + 1] - bed[row]).normalized()

static func _cliff_triangle(surface: SurfaceTool, points: Array, normals: Array, facing: Vector3, reverse_winding: bool, color: Color) -> void:
	var order := [0, 2, 1] if reverse_winding else [0, 1, 2]
	for index: int in order:
		var vertex: Vector3 = points[index]
		surface.set_color(color)
		surface.set_normal(normals[index])
		var along := vertex.z if absf(facing.x) > 0.5 else vertex.x
		surface.set_uv(Vector2(along * 0.195, -vertex.y * 0.255 + along * 0.007))
		surface.add_vertex(vertex)

static func mark_gate(world: Node3D, gate: Vector3) -> void:
	_approach_tracks(world, gate)

static func _approach_tracks(world: Node3D, gate: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var widths := [-0.52, -0.22, 0.24, 0.51]
	var opacity := [0.0, 0.37, 0.31, 0.0]
	for side: float in [-1.0, 1.0]:
		for row in range(52):
			for lane in range(widths.size() - 1):
				var corners := [
					Vector2i(lane, row), Vector2i(lane + 1, row), Vector2i(lane + 1, row + 1),
					Vector2i(lane, row), Vector2i(lane + 1, row + 1), Vector2i(lane, row + 1),
				]
				for corner: Vector2i in corners:
					var distance := corner.y * 0.54
					var z := gate.z + 0.47 + distance
					var x: float = gate.x + side * 0.96 + widths[corner.x] + 1.48 * sin((z - 13.0) * 0.14)
					var wear := smoothstep(0.0, 1.55, distance) * (1.0 - smoothstep(15.0, 28.0, distance))
					var grain := 0.82 + sin(z * 2.3 + side) * 0.18
					surface.set_color(Color(0.44, 0.38, 0.33, opacity[corner.x] * wear * grain))
					surface.set_normal(Vector3.UP)
					surface.set_uv(Vector2(x, z) * 0.48)
					surface.add_vertex(Vector3(x, surface_height(x, z) + 0.018, z))
	surface.generate_tangents()
	var tracks := MeshInstance3D.new()
	tracks.name = "GateApproachTracks"
	tracks.mesh = surface.commit()
	var finish := AsterModels.floor_finish().duplicate() as StandardMaterial3D
	finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finish.albedo_color = Color.WHITE
	tracks.material_override = finish
	tracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(tracks)

static func surface_height(x: float, z: float) -> float:
	var left := floorf(x / GROUND_STEP) * GROUND_STEP
	var near := floorf(z / GROUND_STEP) * GROUND_STEP
	var horizontal := (x - left) / GROUND_STEP
	var depth := (z - near) / GROUND_STEP
	var a := _height_profile(left, near)
	var c := _height_profile(left + GROUND_STEP, near + GROUND_STEP)
	if horizontal >= depth:
		var b := _height_profile(left + GROUND_STEP, near)
		return lerpf(a, b, horizontal) + depth * (c - b)
	var d := _height_profile(left, near + GROUND_STEP)
	return lerpf(a, d, depth) + horizontal * (c - d)

static func _sand(world: Node3D) -> void:
	if _ground_tiles.is_empty():
		_bake_basin()
	var terrain := Node3D.new()
	terrain.name = "CanyonBasin"
	world.add_child(terrain)
	for mesh in _ground_tiles:
		var tile := MeshInstance3D.new()
		tile.mesh = mesh
		tile.material_override = AsterModels.floor_finish()
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		terrain.add_child(tile)
	var floor_body := StaticBody3D.new()
	floor_body.name = "CanyonWalkableSurface"
	floor_body.collision_layer = AsterArt.SOLID
	floor_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = _ground_collision
	floor_body.add_child(collision)
	world.add_child(floor_body)

static func _bake_basin() -> void:
	var stride := GROUND_RADIUS * 2 + 1
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var shades := PackedColorArray()
	for ix in range(-GROUND_RADIUS, GROUND_RADIUS + 1):
		for iz in range(-GROUND_RADIUS, GROUND_RADIUS + 1):
			var x := ix * GROUND_STEP
			var z := iz * GROUND_STEP
			points.append(Vector3(x, _height_profile(x, z), z))
			var nx := _height_profile(x - 0.4, z) - _height_profile(x + 0.4, z)
			var nz := _height_profile(x, z - 0.4) - _height_profile(x, z + 0.4)
			normals.append(Vector3(nx, 0.8, nz).normalized())
			var mineral := 0.91 + 0.048 * sin(x * 0.17 + z * 0.28) + 0.045 * cos(z * 0.32 - x * 0.19) + 0.031 * sin(x * 0.73 - z * 0.34)
			var road_axis := 2.0 + 1.48 * sin((z - 13.0) * 0.14)
			var packed_distance := absf(x - road_axis)
			var trail := (1.0 - smoothstep(1.25, 3.73, packed_distance)) * smoothstep(8.4, 14.2, z) * (1.0 - smoothstep(24.0, 41.0, z))
			var floor_color := Color(mineral, mineral * 0.989, mineral * 0.98)
			shades.append(floor_color.lerp(Color("#aaa69e"), trail * 0.43))
	var faces := PackedVector3Array()
	for tile_x in range(0, stride - 1, GROUND_TILE_STEPS):
		for tile_z in range(0, stride - 1, GROUND_TILE_STEPS):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for ix in range(tile_x, mini(tile_x + GROUND_TILE_STEPS, stride - 1)):
				for iz in range(tile_z, mini(tile_z + GROUND_TILE_STEPS, stride - 1)):
					var a := ix * stride + iz
					var b := a + stride
					for corner: int in [a, b, b + 1, a, b + 1, a + 1]:
						var at := points[corner]
						surface.set_color(shades[corner])
						surface.set_normal(normals[corner])
						surface.set_uv(Vector2(at.x, at.z) * 0.40)
						surface.add_vertex(at)
						faces.append(at)
			surface.index()
			surface.generate_tangents()
			_ground_tiles.append(surface.commit())
	_ground_collision = ConcavePolygonShape3D.new()
	_ground_collision.set_faces(faces)
	_ground_collision.backface_collision = true

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
