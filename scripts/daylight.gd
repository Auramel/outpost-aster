class_name AsterDaylight
extends Node3D

const PHASE_LENGTH := 12.0 * 60.0
const EAST := Vector3(0.918, 0.0, 0.397)
const SKY_SHADER := preload("res://assets/art/canyon_sky.gdshader")

var elapsed := 0.0
var _update_left := 0.0
var _environment := Environment.new()
var _sky := ShaderMaterial.new()
var _sun := DirectionalLight3D.new()
var _moon := DirectionalLight3D.new()
var _fixtures: Array[Light3D] = []

func _ready() -> void:
	var atmosphere := WorldEnvironment.new()
	var sky := Sky.new()
	_sky.shader = SKY_SHADER
	_sky.set_shader_parameter("panorama", AsterModels.SKY)
	sky.sky_material = _sky
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.fog_enabled = true
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_white = 2.75
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.57
	_environment.ssao_enabled = true
	_environment.ssao_radius = 0.95
	_environment.ssao_intensity = 1.31
	_environment.ssao_power = 1.17
	atmosphere.environment = _environment
	add_child(atmosphere)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 115.0
	_sun.shadow_bias = 0.055
	_sun.shadow_normal_bias = 1.24
	add_child(_sun)
	_moon.light_color = Color("#8eabed")
	add_child(_moon)
	set_clock(0.0)

func bind_fixtures(world: Node3D) -> void:
	for fixture: Light3D in world.find_children("*", "Light3D", true, false):
		if fixture.has_meta(&"night_energy"):
			_fixtures.append(fixture)
	set_clock(elapsed)

static func fixture(light: Light3D, lens: MeshInstance3D = null) -> void:
	light.set_meta(&"night_energy", light.light_energy)
	if lens != null:
		var glass := lens.material_override.duplicate() as StandardMaterial3D
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		glass.albedo_color = Color("#7d94a2")
		glass.emission_enabled = true
		glass.emission = Color("#cfeaff")
		lens.material_override = glass
		light.set_meta(&"night_glass", glass)
	light.hide()

func advance(delta: float) -> void:
	elapsed += delta
	_update_left -= delta
	if _update_left <= 0.0:
		_update_left = 0.42
		set_clock(elapsed)

func set_view_distance(distance: float) -> void:
	_environment.fog_mode = Environment.FOG_MODE_DEPTH
	_environment.fog_depth_begin = distance * 0.38
	_environment.fog_depth_end = distance
	_environment.fog_depth_curve = 2.3
	_environment.fog_density = 1.0
	_sun.directional_shadow_max_distance = minf(115.0, distance * 0.72)
	set_clock(elapsed)

func set_clock(seconds: float) -> void:
	elapsed = seconds
	var angle := fposmod(seconds, PHASE_LENGTH * 2.0) * PI / PHASE_LENGTH
	var arc := sin(angle)
	var sunward := (EAST * cos(angle) + (Vector3.UP * 0.83 + EAST.cross(Vector3.UP) * 0.55) * arc).normalized()
	var day := smoothstep(-0.13, 0.32, sunward.y)
	var sunset := (1.0 - smoothstep(0.08, 0.43, absf(sunward.y))) * smoothstep(-0.22, 0.01, sunward.y)
	_sun.basis = Basis.looking_at(-sunward, Vector3.UP)
	_sun.light_color = Color("#fff0db").lerp(Color("#ffad70"), sunset * 0.75)
	_sun.light_energy = 1.70 * smoothstep(-0.014, 0.30, sunward.y) + sunset * 0.40 * smoothstep(-0.08, 0.025, sunward.y)
	_sun.visible = _sun.light_energy > 0.01
	_moon.basis = Basis.looking_at(sunward, Vector3.UP)
	_moon.light_energy = (1.0 - day) * (1.0 - sunset * 0.8) * 0.24
	_environment.ambient_light_color = Color("#6e8ac3").lerp(Color("#bed0e0"), day)
	_environment.ambient_light_energy = lerpf(0.18, 0.28, day) + sunset * 0.11
	var depth_fog := _environment.fog_mode == Environment.FOG_MODE_DEPTH
	var night_fog := Color("#404c66") if depth_fog else Color("#1d2b4b")
	_environment.fog_light_color = night_fog.lerp(Color("#a9a69f"), day).lerp(Color("#bb7956"), sunset * 0.43)
	if depth_fog:
		_environment.fog_aerial_perspective = smoothstep(0.28, 0.80, day)
	else:
		_environment.fog_density = lerpf(0.0044, 0.0030, day)
	_environment.fog_sky_affect = 0.07
	_sky.set_shader_parameter("sunward", sunward)
	_sky.set_shader_parameter("daylight", day)
	_sky.set_shader_parameter("sunset", sunset)
	var lamp := 1.0 - smoothstep(-0.115, -0.035, sunward.y)
	for light in _fixtures:
		light.visible = lamp > 0.015
		light.light_energy = lamp * float(light.get_meta(&"night_energy"))
		var glass := light.get_meta(&"night_glass", null) as StandardMaterial3D
		if glass != null:
			glass.emission_energy_multiplier = lamp * 2.3
