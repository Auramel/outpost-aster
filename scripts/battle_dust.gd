class_name AsterBattleDust
extends Node3D

const TRAIL_LIMIT := 32
const PUFF_LIMIT := 56
const DUST_SIZE := 64

static var _texture: ImageTexture
var _sprites: Array[Sprite3D] = []
var _age := PackedFloat32Array()
var _duration := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _opacity := PackedFloat32Array()
var _cursor := 0
var _impact_cursor := TRAIL_LIMIT
var _impact_delay := 0.0
var _march_cursor := 0
var _march_delay := 0.0
var _rng := RandomNumberGenerator.new()
var _wind := Vector3(0.50, 0.0, -0.29)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	if _texture == null:
		_texture = _make_texture()
	for index in range(PUFF_LIMIT):
		var puff := Sprite3D.new()
		puff.name = "DustPuff"
		puff.texture = _texture
		puff.pixel_size = 1.0 / DUST_SIZE
		puff.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.render_priority = -4
		puff.hide()
		add_child(puff)
		_sprites.append(puff)
		_age.append(0.0)
		_duration.append(0.0)
		_radius.append(0.0)
		_opacity.append(0.0)

func march(delta: float, enemies: Array, eye: Vector3) -> void:
	if _sprites.is_empty():
		return
	_impact_delay = maxf(0.0, _impact_delay - delta)
	if enemies.is_empty():
		return
	_march_delay -= delta
	if _march_delay > 0.0:
		return
	_march_delay = 0.13
	var count := mini(4, enemies.size())
	for index in range(count):
		_march_cursor %= enemies.size()
		var bug: AsterBug = enemies[_march_cursor]
		_march_cursor += 1
		var place := bug.global_position
		if place.z > AsterTerrain.FRONT_Z - 0.5 and place.y < 0.58 and place.distance_squared_to(eye) < 6400.0:
			if AsterArt.horizontal(bug.velocity).length_squared() > 1.0:
				var wake := -AsterArt.horizontal(bug.velocity).normalized() * 0.68
				var drift := wake + Vector3(_rng.randf_range(-0.40, 0.40), 0.28, 0.0)
				_emit(place + drift, _rng.randf_range(0.68, 1.05), 0.29, _rng.randf_range(0.89, 1.58))

func impact(point: Vector3) -> void:
	if _impact_delay == 0.0 and point.z > AsterTerrain.FRONT_Z - 0.5 and point.y < 2.15 and point.y > -0.24:
		_impact_delay = 0.043
		_emit(point + Vector3.UP * 0.22, _rng.randf_range(0.62, 0.97), 0.64, 0.90, true)

func defeated(point: Vector3) -> void:
	_emit(point + Vector3.UP * 0.41, 1.22, 0.61, 1.51, true)
	_emit(point + Vector3(-0.36, 0.21, 0.42), 0.89, 0.47, 1.08, true)

func _emit(point: Vector3, size: float, opacity: float, duration: float, impact_puff := false) -> void:
	if _sprites.is_empty():
		return
	var index := _impact_cursor if impact_puff else _cursor
	if impact_puff:
		_impact_cursor = TRAIL_LIMIT + (_impact_cursor + 1 - TRAIL_LIMIT) % (PUFF_LIMIT - TRAIL_LIMIT)
	else:
		_cursor = (_cursor + 1) % TRAIL_LIMIT
	var puff := _sprites[index]
	puff.global_position = point
	puff.scale = Vector3.ONE * size
	puff.modulate = Color(0.91, 0.79, 0.61, 0.0) if impact_puff else Color(0.80, 0.69, 0.51, 0.0)
	_age[index] = 0.0
	_duration[index] = duration
	_radius[index] = size
	_opacity[index] = opacity
	puff.show()

func _process(delta: float) -> void:
	for index in range(_sprites.size()):
		var puff := _sprites[index]
		if not puff.visible:
			continue
		_age[index] += delta
		var life := _age[index] / _duration[index]
		if life >= 1.0:
			puff.hide()
			continue
		puff.position += (_wind + Vector3.UP * (0.44 - 0.22 * life)) * delta
		var spread := 0.57 + 1.62 * life
		var lift := 0.55 + life if index >= TRAIL_LIMIT else 0.58 + 0.48 * life
		puff.scale = Vector3(spread, lift, spread) * _radius[index]
		puff.modulate.a = smoothstep(0.0, 0.14, life) * (1.0 - life) * _opacity[index]

static func _make_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 743
	noise.frequency = 0.095
	var image := Image.create_empty(DUST_SIZE, DUST_SIZE, false, Image.FORMAT_RGBA8)
	for row in range(DUST_SIZE):
		for column in range(DUST_SIZE):
			var offset := (Vector2(column + 0.5, row + 0.5) / DUST_SIZE - Vector2(0.5, 0.5)) * 2.0
			var at := Vector2(column, row)
			var body := noise.get_noise_2dv(at * 0.62)
			var grain := noise.get_noise_2dv(at * 1.78)
			var radius := offset.length() + body * 0.25 + grain * 0.09
			var mask := 1.0 - smoothstep(0.08, 0.96, radius)
			var shade := 0.87 + 0.14 * body + 0.06 * grain
			image.set_pixel(column, row, Color(shade, shade, shade, mask * mask * (0.82 + 0.18 * grain)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
