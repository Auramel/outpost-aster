class_name AsterMapPicker
extends RefCounted

class Surface:
	var transform: Transform3D
	var inverse: Transform3D
	var bounds: AABB
	var faces: PackedVector3Array

var _surfaces: Array[Surface] = []

func setup(map: Node3D) -> void:
	var meshes: Dictionary = {}
	for visual: VisualInstance3D in map.find_children("*", "VisualInstance3D", true, false):
		if not visual.is_visible_in_tree():
			continue
		if visual is MeshInstance3D and visual.mesh != null:
			_add(visual.mesh, visual.global_transform, meshes)
		elif visual is MultiMeshInstance3D and visual.multimesh != null:
			var batch: MultiMesh = visual.multimesh
			var count := batch.instance_count if batch.visible_instance_count < 0 else batch.visible_instance_count
			for index in range(count):
				_add(batch.mesh, visual.global_transform * batch.get_instance_transform(index), meshes)

func _add(mesh: Mesh, transform: Transform3D, meshes: Dictionary) -> void:
	if mesh == null or is_zero_approx(transform.basis.determinant()):
		return
	if not meshes.has(mesh):
		meshes[mesh] = mesh.get_faces()
	var faces: PackedVector3Array = meshes[mesh]
	if faces.is_empty():
		return
	var surface := Surface.new()
	surface.transform = transform
	surface.inverse = transform.affine_inverse()
	surface.bounds = mesh.get_aabb().grow(0.001)
	surface.faces = faces
	_surfaces.append(surface)

func pick(origin: Vector3, end: Vector3) -> Dictionary:
	var result := {}
	var nearest := origin.distance_squared_to(end)
	for surface in _surfaces:
		var from := surface.inverse * origin
		var to := surface.inverse * end
		if surface.bounds.intersects_segment(from, to) == null:
			continue
		var faces := surface.faces
		for vertex in range(0, faces.size(), 3):
			var a := faces[vertex]
			var b := faces[vertex + 1]
			var c := faces[vertex + 2]
			var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, a, b, c)
			if hit == null:
				continue
			var position: Vector3 = surface.transform * hit
			var distance := origin.distance_squared_to(position)
			if distance >= nearest:
				continue
			var normal := (surface.inverse.basis.transposed() * (c - a).cross(b - a)).normalized()
			if normal.dot(origin - position) < 0.0:
				normal = -normal
			nearest = distance
			result = {"position": position, "normal": normal}
			to = hit
		if not result.is_empty():
			end = result.position
	return result
