class_name AsterWallDamage
extends RefCounted

const SHADE := Color("#30251f")
const CUT := Color("#59473b")
const EDGE := Color("#8a7760")
const CORE := Color("#75624d")
const IRON := Color("#44474a")

static var _faces: Array[ArrayMesh] = []

static func build(parent: Node3D, gate: bool) -> Array[Node3D]:
	if _faces.is_empty():
		_bake()
	var layers: Array[Node3D] = []
	for stage in range(_faces.size()):
		var layer := Node3D.new()
		layer.name = "DamageStage%d" % (stage + 1)
		layer.hide()
		parent.add_child(layer)
		layers.append(layer)
		for side in [1.0, -1.0]:
			var mark := MeshInstance3D.new()
			mark.mesh = _faces[stage]
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var front := 0.54
			var rear := AsterStructure.OUTER_FACE - AsterStructure.WALL_DEPTH - 0.154
			if gate:
				front = 0.51
				rear = -0.51
				mark.scale = Vector3(0.9, 0.85, 1.0)
			mark.position.z = front if side > 0.0 else rear
			mark.rotation.y = 0.0 if side > 0.0 else PI
			layer.add_child(mark)
			if not gate and stage > 0:
				var edge := AsterStructure.OUTER_FACE if side > 0.0 else rear
				var rock := AsterModels.attach(layer, &"stone_2", Vector3(0.45 - stage * 0.30, 0.0, edge + side * 0.29),
					Vector3(0.39, 0.11 + stage * 0.035, 0.28), false)
				rock.rotation.y = stage * 1.13 * side
	return layers

static func _bake() -> void:
	for stage in range(3):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		match stage:
			0:
				_crack(surface, [Vector2(-1.65, 2.06), Vector2(-1.32, 1.93), Vector2(-1.02, 2.02), Vector2(-0.74, 1.83), Vector2(-0.51, 1.86), Vector2(-0.30, 1.68)], 0.032, 0.008)
				_crack(surface, [Vector2(-1.03, 2.02), Vector2(-1.11, 2.28), Vector2(-0.92, 2.45)], 0.025, 0.009)
				_crack(surface, [Vector2(0.88, 1.00), Vector2(0.65, 1.22), Vector2(0.43, 1.21), Vector2(0.22, 1.51)], 0.025, 0.010)
			1:
				_spall(surface, Vector2(-0.82, 1.49), Vector2(0.99, 0.99), 0.018)
				_spall(surface, Vector2(0.81, 2.26), Vector2(0.77, 0.50), 0.020)
				_crack(surface, [Vector2(-0.90, 1.48), Vector2(-0.54, 1.43), Vector2(-0.38, 1.09), Vector2(-0.11, 0.98), Vector2(0.14, 0.76)], 0.059, 0.022)
				_crack(surface, [Vector2(0.69, 2.3), Vector2(0.44, 2.44), Vector2(0.23, 2.36), Vector2(0.06, 2.65)], 0.037, 0.023)
			2:
				_spall(surface, Vector2(0.42, 1.05), Vector2(1.55, 1.53), 0.036)
				_spall(surface, Vector2(-0.78, 0.54), Vector2(0.74, 0.55), 0.035)
				_crack(surface, [Vector2(0.60, 1.25), Vector2(1.01, 1.42), Vector2(1.33, 1.64), Vector2(1.59, 1.51), Vector2(1.79, 1.65)], 0.075, 0.040)
				for x in [-0.04, 0.29, 0.58, 0.82]:
					_strip(surface, Vector2(x, 0.68), Vector2(x + 0.075, 1.45), 0.037, 0.065, IRON)
					_strip(surface, Vector2(x + 0.02, 0.69), Vector2(x + 0.09, 1.43), 0.010, 0.070, EDGE.darkened(0.26))
				_strip(surface, Vector2(-0.14, 0.93), Vector2(0.94, 0.99), 0.044, 0.063, IRON)
		surface.generate_normals()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.albedo_texture = AsterModels.ARMORY
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.89
		material.metallic_specular = 0.22
		surface.set_material(material)
		_faces.append(surface.commit())

static func _crack(surface: SurfaceTool, path: Array, width: float, depth: float) -> void:
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var thick := width * lerpf(1.12, 0.43, float(i) / (path.size() - 1))
		_strip(surface, a + Vector2.ONE * 0.015, b + Vector2.ONE * 0.015, thick * 1.27, depth, EDGE)
		_strip(surface, a, b, thick, depth + 0.008, SHADE)

static func _spall(surface: SurfaceTool, center: Vector2, size: Vector2, depth: float) -> void:
	var rim := [
		Vector2(-0.51, -0.14), Vector2(-0.31, -0.43), Vector2(-0.10, -0.39),
		Vector2(0.23, -0.54), Vector2(0.47, -0.32), Vector2(0.41, -0.10),
		Vector2(0.52, 0.18), Vector2(0.18, 0.37), Vector2(-0.08, 0.29),
		Vector2(-0.26, 0.48), Vector2(-0.48, 0.22),
	]
	for i in range(rim.size()):
		var a: Vector2 = rim[i] * size
		var b: Vector2 = rim[(i + 1) % rim.size()] * size
		_triangle(surface, [center, center + a * 0.76, center + b * 0.76], depth + 0.013, CUT if i % 3 else SHADE)
		_triangle(surface, [center + a * 0.76, center + a, center + b], depth + 0.010, CORE if i % 2 else EDGE)
		_triangle(surface, [center + a * 0.76, center + b, center + b * 0.76], depth + 0.010, CORE if i % 2 else EDGE)

static func _strip(surface: SurfaceTool, a: Vector2, b: Vector2, width: float, depth: float, color: Color) -> void:
	var edge := (b - a).normalized().orthogonal() * width * 0.5
	_triangle(surface, [a - edge, b - edge, b + edge], depth, color)
	_triangle(surface, [a - edge, b + edge, a + edge], depth, color)

static func _triangle(surface: SurfaceTool, points: Array, depth: float, color: Color) -> void:
	for point: Vector2 in points:
		surface.set_color(color)
		surface.set_uv(point * 0.88)
		surface.add_vertex(Vector3(point.x, point.y, depth))
