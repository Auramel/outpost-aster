class_name AsterStatusTag
extends Node3D

const TRACK_WIDTH := 144
const METER_HEIGHT := 8
const PIXEL_SIZE := 0.009
const VIEW_RANGE := 34.0
const HEALTH := Color("#ff5c64")
const AMMO := Color("#57baff")
const TRACK := Color("#101721df")
const INK := Color("#e8f3fb")
const ALERT := Color("#ffbd77")

static var _flat_texture: ImageTexture
var _caption: String
var _label: Label3D
var _health_fill: Sprite3D
var _ammo_fill: Sprite3D

func setup(caption: String, has_ammo: bool = false) -> void:
	_caption = caption
	_label = AsterArt.lettering(self, caption, Vector3.UP * 0.20, 27, INK, true)
	_label.pixel_size = PIXEL_SIZE
	_label.outline_size = 8
	_label.visibility_range_end = VIEW_RANGE
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_fill = _add_meter(0.0, HEALTH)
	if has_ammo:
		_ammo_fill = _add_meter(-0.115, AMMO)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var depth := camera.global_position.distance_to(global_position)
	scale = Vector3.ONE * lerpf(0.42, 1.0, smoothstep(1.5, 7.8, depth))

func set_values(health_fraction: float, ammo_fraction: float = 0.0, warning: String = "") -> void:
	_set_fill(_health_fill, health_fraction)
	if _ammo_fill != null:
		_set_fill(_ammo_fill, ammo_fraction)
	var text := _caption if warning.is_empty() else _caption + "  ·  " + warning
	if text != _label.text:
		_label.text = text
		_label.modulate = INK if warning.is_empty() else ALERT

func _add_meter(y: float, color: Color) -> Sprite3D:
	var row := Node3D.new()
	row.position.y = y
	add_child(row)
	row.add_child(_strip(Color("#7795aa"), 0))
	row.add_child(_strip(TRACK, 1))
	var fill := _strip(color, 2)
	row.add_child(fill)
	return fill

func _strip(color: Color, inset: int) -> Sprite3D:
	var width := TRACK_WIDTH - inset * 2
	var height := METER_HEIGHT + 4 - inset * 2
	if _flat_texture == null:
		var image := Image.create_empty(TRACK_WIDTH, METER_HEIGHT + 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_flat_texture = ImageTexture.create_from_image(image)
	var strip := Sprite3D.new()
	strip.texture = _flat_texture
	strip.region_enabled = true
	strip.region_rect = Rect2(0, 0, width, height)
	strip.pixel_size = PIXEL_SIZE
	strip.centered = false
	strip.offset = Vector2(-width * 0.5, -height * 0.5)
	strip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	strip.modulate = color
	strip.render_priority = inset - 3
	strip.visibility_range_end = VIEW_RANGE
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return strip

func _set_fill(fill: Sprite3D, fraction: float) -> void:
	var width := roundi(clampf(fraction, 0.0, 1.0) * (TRACK_WIDTH - 4))
	fill.visible = width > 0
	if width > 0 and fill.region_rect.size.x != width:
		fill.region_rect = Rect2(0, 0, width, METER_HEIGHT)
