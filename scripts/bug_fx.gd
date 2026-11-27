class_name AsterBugFX
extends Node3D

const BLOOD := Color("#6e2028")
const BLOOD_EDGE := Color("#2e1016")
const SHELL := Color("#8b624a")
const DROP_LIMIT := 160
const CHIP_LIMIT := 64

class Fragment:
	var point := Vector3.ZERO
	var velocity := Vector3.ZERO
	var loft := Basis.IDENTITY
	var life := 0.0
	var size := 0.0

var _blood_mesh: MultiMesh
var _chip_mesh: MultiMesh
var _drops: Array[Fragment] = []
var _chips: Array[Fragment] = []
var _next_drop := 0
var _next_chip := 0
static var _wound_mesh: ArrayMesh

func _ready() -> void:
	var droplet := SphereMesh.new()
	droplet.radial_segments = 5
	droplet.rings = 3
	droplet.material = AsterArt.material(BLOOD)
	_blood_mesh = _batch(droplet, DROP_LIMIT, _drops)
	var shard := PrismMesh.new()
	shard.set_size(Vector3(1.0, 0.60, 0.46))
	shard.material = AsterArt.material(SHELL)
	_chip_mesh = _batch(shard, CHIP_LIMIT, _chips)

func _batch(mesh: Mesh, count: int, fragments: Array[Fragment]) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	batch.visible_instance_count = 0
	for index in range(count):
		fragments.append(Fragment.new())
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = batch
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return batch

func spray(at: Vector3, normal: Vector3, fatal: bool) -> void:
	for index in range(10 if fatal else 6):
		var scatter := Vector3(randf_range(-1.0, 1.0), randf_range(-0.48, 1.0), randf_range(-1.0, 1.0))
		_drop(at, normal * randf_range(1.0, 3.9) + scatter * 1.9, randf_range(0.047, 0.105), randf_range(0.20, 0.46))
	for index in range(5 if fatal else 3):
		var chip := _chips[_next_chip]
		_next_chip = (_next_chip + 1) % CHIP_LIMIT
		chip.point = at
		chip.velocity = normal * randf_range(1.8, 4.2) + Vector3(randf_range(-1.3, 1.3), randf_range(0.55, 2.0), randf_range(-1.3, 1.3))
		chip.size = randf_range(0.07, 0.14)
		chip.life = randf_range(0.30, 0.50)
		chip.loft = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU)

func drip(at: Vector3, carry: Vector3) -> void:
	_drop(at, carry * 0.36 + Vector3(randf_range(-0.20, 0.20), -0.9, randf_range(-0.20, 0.20)), 0.06, 0.40)

func _drop(at: Vector3, direction: Vector3, size: float, life: float) -> void:
	var drop := _drops[_next_drop]
	_next_drop = (_next_drop + 1) % DROP_LIMIT
	drop.point = at
	drop.velocity = direction
	drop.size = size
	drop.life = life

func _process(delta: float) -> void:
	_render(_drops, _blood_mesh, delta, true)
	_render(_chips, _chip_mesh, delta, false)

func _render(fragments: Array[Fragment], mesh: MultiMesh, delta: float, liquid: bool) -> void:
	var showing := 0
	for fragment in fragments:
		if fragment.life <= 0.0:
			continue
		fragment.life -= delta
		if fragment.life <= 0.0:
			continue
		fragment.velocity.y -= 12.5 * delta
		fragment.point += fragment.velocity * delta
		var size := fragment.size * minf(fragment.life * 14.0, 1.0)
		var pose := fragment.loft
		var scale := Vector3.ONE * size
		if liquid:
			var direction := fragment.velocity.normalized()
			if direction.length_squared() > 0.0:
				pose = Basis.looking_at(direction, Vector3.RIGHT if absf(direction.y) > 0.94 else Vector3.UP)
			scale.z *= 1.0 + minf(fragment.velocity.length() * 0.34, 1.8)
		else:
			fragment.loft = pose.rotated(Vector3.RIGHT, delta * 12.0)
		mesh.set_instance_transform(showing, Transform3D(pose.scaled_local(scale), fragment.point))
		showing += 1
	mesh.visible_instance_count = showing

static func wound(parent: Node3D) -> MeshInstance3D:
	if _wound_mesh == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var perimeter := PackedVector2Array([
			Vector2(-0.48, -0.18), Vector2(-0.26, -0.43), Vector2(-0.01, -0.30),
			Vector2(0.24, -0.48), Vector2(0.52, -0.11), Vector2(0.25, 0.10),
			Vector2(0.34, 0.33), Vector2(0.02, 0.24), Vector2(-0.28, 0.44),
		])
		for index in range(perimeter.size()):
			var start := perimeter[index]
			var end := perimeter[(index + 1) % perimeter.size()]
			_vertex(surface, Vector2.ZERO, 0.07, BLOOD)
			_vertex(surface, end * 0.73, 0.04, BLOOD_EDGE)
			_vertex(surface, start * 0.73, 0.04, BLOOD_EDGE)
			_vertex(surface, start * 0.73, 0.04, BLOOD_EDGE)
			_vertex(surface, end * 0.73, 0.04, BLOOD_EDGE)
			_vertex(surface, end, -0.04, SHELL.darkened(0.3))
			_vertex(surface, start * 0.73, 0.04, BLOOD_EDGE)
			_vertex(surface, end, -0.04, SHELL.darkened(0.3))
			_vertex(surface, start, -0.04, SHELL.darkened(0.3))
		surface.generate_normals()
		var finish := StandardMaterial3D.new()
		finish.vertex_color_use_as_albedo = true
		finish.cull_mode = BaseMaterial3D.CULL_DISABLED
		finish.roughness = 0.53
		surface.set_material(finish)
		_wound_mesh = surface.commit()
	var patch := MeshInstance3D.new()
	patch.mesh = _wound_mesh
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(patch)
	return patch

static func _vertex(surface: SurfaceTool, at: Vector2, depth: float, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(Vector3(at.x, at.y, depth))
