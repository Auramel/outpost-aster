class_name AsterEffects
extends Node3D

const COUNT := 32
const FLASH_SIZE := 64
const FUME_COUNT := 48

class Fume:
	var sprite: Sprite3D
	var velocity := Vector3.ZERO
	var age := 0.0
	var duration := 0.0
	var size := 0.0

var _fumes: Array[Fume] = []
var _next_fume := 0
static var _fume_texture: ImageTexture
static var _flash_texture: ImageTexture
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

func flash(origin: Vector3, direction: Vector3) -> void:
	var slot := _claim(0.043)
	var muzzle := _muzzles[slot]
	muzzle.global_position = origin + direction * 0.16
	muzzle.scale = Vector3.ONE * randf_range(0.79, 1.14)
	muzzle.show()
	muzzle_gas(origin, direction, true)

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

static func muzzle_sprite(parent: Node3D, point: Vector3) -> Sprite3D:
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
	var flash_node := Sprite3D.new()
	flash_node.position = point
	flash_node.texture = _flash_texture
	flash_node.pixel_size = 1.0 / FLASH_SIZE
	flash_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flash_node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flash_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash_node)
	return flash_node

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
