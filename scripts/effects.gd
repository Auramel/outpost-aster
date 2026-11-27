class_name AsterEffects
extends Node3D

const COUNT := 32
const FLASH_SIZE := 64
const FUME_COUNT := 48
const BLAST_COUNT := 12
const BLAST_DURATION := 2.0
const SCORCH_LIMIT := 32
const ROCKET_BLAST := preload("res://assets/art/rocket_blast.gdshader")
const KAMIKAZE_RESIDUE := preload("res://assets/art/kamikaze_residue.gdshader")

class Fume:
	var sprite: Sprite3D
	var velocity := Vector3.ZERO
	var age := 0.0
	var duration := 0.0
	var size := 0.0

class Blast:
	var plate: MeshInstance3D
	var light: OmniLight3D
	var point := Vector3.ZERO
	var normal := Vector3.UP
	var age := 0.0
	var size := 0.0

var _blasts: Array[Blast] = []
var _scorches: Array[MeshInstance3D] = []
var _next_blast := 0
var _fumes: Array[Fume] = []
var _next_fume := 0
static var _fume_texture: ImageTexture
static var _flash_texture: ImageTexture
static var _rifle_flash_mesh: ArrayMesh
var _beams: Array[MeshInstance3D] = []
var _sparks: Array[MeshInstance3D] = []
var _muzzles: Array[Sprite3D] = []
var _time: Array[float] = []
var _next := 0

func _ready() -> void:
	for slot in range(COUNT):
		_beams.append(AsterArt.box(self, Vector3.ONE, Vector3.ZERO, AsterArt.CYAN, true))
		_sparks.append(AsterArt.primitive(self, "orb", Vector3.ONE, Vector3.ZERO, AsterArt.AMBER, true))
		_muzzles.append(muzzle_sprite(self, Vector3.ZERO))
		_time.append(0.0)
		_hide(slot)

	if _fume_texture == null:
		_fume_texture = AsterBattleDust._make_texture()
	for slot in range(FUME_COUNT):
		var sprite := Sprite3D.new()
		sprite.texture = _fume_texture
		sprite.pixel_size = 1.0 / sprite.texture.get_width()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.hide()
		add_child(sprite)
		var fume := Fume.new()
		fume.sprite = sprite
		_fumes.append(fume)

	var fireball := QuadMesh.new()
	var flame := ShaderMaterial.new()
	flame.shader = ROCKET_BLAST
	fireball.material = flame
	for index in range(BLAST_COUNT):
		var blast := Blast.new()
		blast.plate = MeshInstance3D.new()
		blast.plate.mesh = fireball
		blast.plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blast.plate)
		blast.plate.hide()
		blast.light = OmniLight3D.new()
		blast.light.light_color = Color("#ffad5c")
		blast.light.omni_attenuation = 1.6
		add_child(blast.light)
		blast.light.hide()
		_blasts.append(blast)

func _claim(life: float) -> int:
	var slot := _next
	_next = (_next + 1) % COUNT
	_hide(slot)
	_time[slot] = life
	return slot

func repair_beam(from: Vector3, hit: Vector3) -> void:
	var offset := hit - from
	if offset.length_squared() < 0.0001:
		return
	var slot := _claim(0.078)
	var beam := _beams[slot]
	beam.global_position = from + offset * 0.5
	beam.look_at(hit, _up_for(offset.normalized()))
	beam.scale = Vector3(0.023, 0.023, offset.length())
	beam.show()
	_spark(slot, hit, AsterArt.CYAN, 0.085)

func flash(origin: Vector3, direction: Vector3, size := 1.0) -> void:
	var slot := _claim(0.043)
	var muzzle := _muzzles[slot]
	muzzle.global_position = origin + direction * 0.16
	muzzle.scale = Vector3.ONE * randf_range(0.79, 1.14) * size
	muzzle.show()
	muzzle_gas(origin, direction, true)

func gauss_flash(origin: Vector3, direction: Vector3) -> void:
	var slot := _claim(0.092)
	var beam := _beams[slot]
	beam.global_position = origin + direction * 0.48
	beam.look_at(origin + direction * 1.1, _up_for(direction))
	beam.scale = Vector3(0.041, 0.041, 0.92)
	beam.show()
	_spark(slot, origin + direction * 0.13, Color("#c3f2ff"), 0.23)

func rocket_flash(origin: Vector3, direction: Vector3) -> void:
	flash(origin, direction, 1.85)
	_fume(origin, -direction * 1.6 + Vector3.UP * 0.70, 1.35, 1.2, Color("#a39889"))

func rocket_trail(origin: Vector3) -> void:
	_fume(origin, Vector3(0.26, 0.68, 0.15), 0.58, 1.25, Color("#bab4a9"))

func artillery_flash(origin: Vector3, direction: Vector3) -> void:
	var slot := _claim(0.13)
	var muzzle := _muzzles[slot]
	muzzle.global_position = origin + direction * 0.44
	muzzle.scale = Vector3.ONE * 4.3
	muzzle.show()
	for index in range(4):
		_fume(origin + direction * (0.6 + index * 0.45), direction * (7.3 - index * 0.8) + Vector3.UP * 0.86,
			1.9 + index * 0.31, 1.35 + index * 0.30, Color("#72665d"))

func muzzle_gas(origin: Vector3, direction: Vector3, heavy: bool) -> void:
	var size := 0.63 if heavy else 0.50
	var plume := direction * (3.45 if heavy else 2.80) + Vector3.UP * 0.39
	var front := origin + direction * (0.21 if heavy else 0.35)
	_fume(front, plume, size, 0.47 if heavy else 0.37, Color("#afa59a"))
	if not heavy:
		_fume(front + direction * 0.14 + Vector3.UP * 0.065, plume * 0.76, size * 0.83, 0.53, Color("#a49c91"))

func _fume(at: Vector3, velocity: Vector3, size: float, duration: float, color: Color) -> void:
	var fume := _fumes[_next_fume]
	_next_fume = (_next_fume + 1) % FUME_COUNT
	fume.sprite.global_position = at
	fume.sprite.modulate = Color(color, 0.0)
	fume.sprite.scale = Vector3.ONE * size * 0.48
	fume.velocity = velocity
	fume.size = size
	fume.duration = duration
	fume.age = 0.0
	fume.sprite.show()

static func _muzzle_texture() -> ImageTexture:
	if _flash_texture == null:
		var pixels := Image.create_empty(FLASH_SIZE, FLASH_SIZE, false, Image.FORMAT_RGBA8)
		for row in range(FLASH_SIZE):
			for column in range(FLASH_SIZE):
				var p := (Vector2(column + 0.5, row + 0.5) / FLASH_SIZE - Vector2(0.5, 0.5)) * 2.0
				var radius := p.length()
				var spokes := pow(absf(cos(p.angle() * 3.0 + 0.21)), 17.0)
				var core := 1.0 - smoothstep(0.05, 0.39, radius)
				var flame := 1.0 - smoothstep(0.06, 0.26 + spokes * 0.65, radius)
				var color := Color("#ffc371").lerp(Color("#fff9dd"), core)
				color.a = clampf(core + flame * (0.54 + spokes * 0.46), 0.0, 1.0)
				pixels.set_pixel(column, row, color)
		pixels.generate_mipmaps()
		_flash_texture = ImageTexture.create_from_image(pixels)
	return _flash_texture

static func muzzle_sprite(parent: Node3D, point: Vector3) -> Sprite3D:
	var flash_node := Sprite3D.new()
	flash_node.position = point
	flash_node.texture = _muzzle_texture()
	flash_node.pixel_size = 1.0 / FLASH_SIZE
	flash_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flash_node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flash_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash_node)
	return flash_node

static func rifle_flash(parent: Node3D, muzzle: Vector3) -> MeshInstance3D:
	if _rifle_flash_mesh == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var front := Vector3.FORWARD * 0.34
		for angle: float in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
			var edge := Vector3(cos(angle), sin(angle), 0.0) * 0.094
			var root := edge * 0.24
			_flash_quad(surface, [-root, root, front + edge, front - edge], 0.44)
		# The face-on flare keeps the flash readable through the sights.
		var face := Vector3.FORWARD * 0.075
		var right := Vector3.RIGHT * 0.157
		var up := Vector3.UP * 0.157
		_flash_quad(surface, [face - right + up, face + right + up, face + right - up, face - right - up])
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_texture = _muzzle_texture()
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		surface.set_material(material)
		_rifle_flash_mesh = surface.commit()
	var flash_node := MeshInstance3D.new()
	flash_node.mesh = _rifle_flash_mesh
	flash_node.position = muzzle
	flash_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash_node)
	return flash_node

static func _flash_quad(surface: SurfaceTool, corners: Array[Vector3], start_v := 0.0) -> void:
	var uv := [Vector2(0, start_v), Vector2(1, start_v), Vector2(1, 1), Vector2(0, 1)]
	for corner in [0, 1, 2, 0, 2, 3]:
		surface.set_uv(uv[corner])
		surface.add_vertex(corners[corner])

func artillery_impact(point: Vector3, normal: Vector3) -> void:
	var slot := _claim(0.12)
	_spark(slot, point + normal * 0.35, Color("#ffc07c"), 2.45)
	for index in range(5):
		var bearing := index * TAU / 5.0
		var drift := Vector3(cos(bearing), 0.85, sin(bearing))
		_fume(point + drift * 0.72, drift * 2.05, 2.22 + index * 0.42, 1.44 + index * 0.24, Color("#514a42"))

func rocket_impact(point: Vector3, normal: Vector3, radius: float) -> void:
	var blast := _blasts[_next_blast]
	_next_blast = (_next_blast + 1) % BLAST_COUNT
	blast.age = 0.0
	blast.point = point
	blast.normal = normal
	blast.size = radius
	blast.plate.set_instance_shader_parameter(&"variation", randf())
	blast.plate.show()
	blast.light.global_position = point + normal * 0.80 + Vector3.UP * 0.35
	blast.light.omni_range = radius * 3.0
	blast.light.light_energy = 4.5
	blast.light.show()
	_update_blast(blast, get_viewport().get_camera_3d())
	_ground_residue(point, radius * 0.83, true)

func _update_blast(blast: Blast, camera: Camera3D) -> void:
	var progress := blast.age / BLAST_DURATION
	var bloom := 1.0 - exp(-blast.age * 9.0)
	var extent := blast.size * (0.85 + bloom * 1.04 + progress * 0.62)
	var center := blast.point + blast.normal * 0.45 + Vector3.UP * (extent * 0.27 + progress * 0.65)
	var orientation := camera.global_basis if is_instance_valid(camera) else Basis.IDENTITY
	blast.plate.global_transform = Transform3D(orientation.scaled_local(Vector3.ONE * extent), center)
	blast.plate.set_instance_shader_parameter(&"progress", progress)
	if blast.age < 0.23:
		blast.light.light_energy = 4.5 * (1.0 - blast.age / 0.23)
	else:
		blast.light.hide()

func kamikaze_impact(point: Vector3, radius: float) -> void:
	_spark(_claim(0.085), point, Color("#ffd275"), 1.50)
	for index in range(6):
		var angle := index * TAU / 6.0
		var direction := Vector3(cos(angle), 0.24, sin(angle))
		_fume(point + direction * 0.3, direction * 4.6, 1.42 + index * 0.083, 0.55 + index * 0.074, Color("#ae702c"))
	_ground_residue(point, radius)

func _ground_residue(point: Vector3, radius: float, scorch := false) -> void:
	var above := point + Vector3.UP * 0.15 if scorch else point
	var below := point + Vector3.DOWN * (2.8 if scorch else 120.0)
	var ground := AsterArt.ray(get_world_3d(), above, below, AsterArt.SOLID | AsterArt.ACCESS)
	if ground.is_empty() or (scorch and ground.normal.y < 0.57):
		return
	var center: Vector3 = ground.position
	var height := point.y - center.y
	var reach := maxf(radius * 0.39, sqrt(maxf(0.0, radius * radius - height * height)))
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cells := PackedInt32Array()
	var supported := PackedByteArray()
	const STEPS := 8
	for z in range(STEPS + 1):
		for x in range(STEPS + 1):
			var uv := Vector2(x, z) / STEPS
			var sample := center + Vector3(uv.x * 2.0 - 1.0, 0, uv.y * 2.0 - 1.0) * reach
			var floor_hit := AsterArt.ray(get_world_3d(), sample + Vector3.UP * 0.6, sample + Vector3.DOWN * 0.77, AsterArt.SOLID | AsterArt.ACCESS)
			var has_floor: bool = not floor_hit.is_empty() and floor_hit.normal.y > 0.57
			if has_floor:
				sample = floor_hit.position
			sample.y += 0.023
			vertices.append(to_local(sample))
			uvs.append(uv)
			supported.append(int(has_floor))
	for z in range(STEPS):
		for x in range(STEPS):
			var corner := z * (STEPS + 1) + x
			var far_corner := corner + STEPS + 1
			if scorch and (supported[corner] + supported[corner + 1] + supported[far_corner] + supported[far_corner + 1] < 4):
				continue
			cells.append_array(PackedInt32Array([corner, corner + 1, far_corner, corner + 1, far_corner + 1, far_corner]))
	if cells.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = cells
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var stain := MeshInstance3D.new()
	stain.mesh = mesh
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = KAMIKAZE_RESIDUE
	stain.material_override = material
	add_child(stain)
	var fade := stain.create_tween()
	if scorch:
		if _scorches.size() >= SCORCH_LIMIT:
			_scorches.pop_front().queue_free()
		_scorches.append(stain)
		material.set_shader_parameter(&"scorched", true)
		material.set_shader_parameter(&"variation", randf())
		material.set_shader_parameter(&"heat", 1.0)
		material.set_shader_parameter(&"fade", 1.0)
		fade.tween_method(func(value: float) -> void: material.set_shader_parameter(&"heat", value), 1.0, 0.0, 2.3)
		fade.tween_interval(9.7)
		fade.tween_method(func(value: float) -> void: material.set_shader_parameter(&"fade", value), 1.0, 0.0, 5.0)
		fade.tween_callback(func() -> void:
			_scorches.erase(stain)
			stain.queue_free())
	else:
		fade.tween_method(func(value: float) -> void: material.set_shader_parameter(&"fade", value), 1.0, 0.0, 2.0).set_delay(4.3)
		fade.tween_callback(stain.queue_free)

func impact(point: Vector3, normal: Vector3) -> void:
	_spark(_claim(0.035), point + normal * 0.047, AsterArt.AMBER, 0.11)

func _spark(slot: int, point: Vector3, color: Color, size: float) -> void:
	var spark := _sparks[slot]
	spark.global_position = point
	spark.material_override = AsterArt.material(color, true)
	spark.scale = Vector3.ONE * size
	spark.show()

func _up_for(direction: Vector3) -> Vector3:
	return Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT

func _hide(slot: int) -> void:
	_beams[slot].hide()
	_sparks[slot].hide()
	_muzzles[slot].hide()

func _process(delta: float) -> void:
	for slot in range(COUNT):
		if _time[slot] <= 0.0:
			continue
		_time[slot] -= delta
		if _time[slot] <= 0.0:
			_hide(slot)

	var camera := get_viewport().get_camera_3d()
	for blast in _blasts:
		if not blast.plate.visible:
			continue
		blast.age += delta
		if blast.age >= BLAST_DURATION:
			blast.plate.hide()
			blast.light.hide()
		else:
			_update_blast(blast, camera)

	for fume in _fumes:
		if not fume.sprite.visible:
			continue
		fume.age += delta
		if fume.age >= fume.duration:
			fume.sprite.hide()
			continue
		var progress := fume.age / fume.duration
		fume.sprite.position += fume.velocity * (1.0 - progress * 0.76) * delta
		fume.sprite.scale = Vector3.ONE * fume.size * (0.48 + progress * 1.58)
		fume.sprite.modulate.a = smoothstep(0.0, 0.09, progress) * (1.0 - progress) * 0.62
