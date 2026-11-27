class_name AsterModels
extends RefCounted

const VIEWMODEL_LAYER := 1 << 19
const DUST := preload("res://assets/art/materials/field_dust.jpg")
const DUST_NORMAL := preload("res://assets/art/materials/field_dust_normal.png")
const STRATA := preload("res://assets/art/materials/field_strata.jpg")
const STRATA_NORMAL := preload("res://assets/art/materials/field_strata_normal.png")
const ALLOY := preload("res://assets/art/materials/field_alloy.jpg")
const ALLOY_NORMAL := preload("res://assets/art/materials/field_alloy_normal.png")
const PARKERIZED := preload("res://assets/art/materials/parkerized.jpg")
const PARKERIZED_NORMAL := preload("res://assets/art/materials/parkerized_normal.png")
const PARKERIZED_ROUGHNESS := preload("res://assets/art/materials/parkerized_roughness.png")
const PAINTED := preload("res://assets/art/materials/painted.jpg")
const PAINTED_NORMAL := preload("res://assets/art/materials/painted_normal.png")
const PAINTED_ROUGHNESS := preload("res://assets/art/materials/painted_roughness.png")
const POLYMER := preload("res://assets/art/materials/polymer.jpg")
const POLYMER_NORMAL := preload("res://assets/art/materials/polymer_normal.png")
const POLYMER_ROUGHNESS := preload("res://assets/art/materials/polymer_roughness.png")
const ARMORY := preload("res://assets/art/materials/armory.jpg")
const ARMORY_NORMAL := preload("res://assets/art/materials/armory_normal.png")
const ARMORY_ROUGHNESS := preload("res://assets/art/materials/armory_roughness.png")
const SKY := preload("res://assets/art/materials/amber_panorama.jpg")
const PARTS := {
	&"carbine": preload("res://assets/art/models/aster_carbine.glb"),
	&"carbine_magazine": preload("res://assets/art/models/aster_carbine_magazine.glb"),
	&"carbine_support": preload("res://assets/art/models/aster_carbine_support.glb"),
	&"repair": preload("res://assets/art/models/field_repair_tool.glb"),
	&"turret_base": preload("res://assets/art/models/turret_base.glb"),
	&"turret_head": preload("res://assets/art/models/turret_head.glb"),
	&"turret_emitters": preload("res://assets/art/models/turret_emitters.glb"),
	&"turret_wreck": preload("res://assets/art/models/turret_wreck.glb"),
	&"bug": preload("res://assets/art/models/dune_beetle.glb"),
	&"leg_left": preload("res://assets/art/models/beetle_leg_left.glb"),
	&"leg_right": preload("res://assets/art/models/beetle_leg_right.glb"),
	&"claw_left": preload("res://assets/art/models/beetle_claw_left.glb"),
	&"claw_right": preload("res://assets/art/models/beetle_claw_right.glb"),
	&"wall": preload("res://assets/art/models/wall_segment.glb"),
	&"gate_frame": preload("res://assets/art/models/gate_frame.glb"),
	&"gate_panels": preload("res://assets/art/models/gate_panels.glb"),
	&"relay": preload("res://assets/art/models/relay_bunker.glb"),
	&"station": preload("res://assets/art/models/field_terminal.glb"),
	&"supply": preload("res://assets/art/models/supply_rack.glb"),
	&"drone": preload("res://assets/art/models/supply_drone.glb"),
	&"breach": preload("res://assets/art/models/breach_debris.glb"),
	&"screen_rock": preload("res://assets/art/models/sandstone_screen.glb"),
	&"stone_1": preload("res://assets/art/models/eroded_boulder_1.glb"),
	&"stone_2": preload("res://assets/art/models/eroded_boulder_2.glb"),
	&"stone_3": preload("res://assets/art/models/eroded_boulder_3.glb"),
	&"mesa": preload("res://assets/art/models/tabletop_mesa.glb"),
	&"scrub": preload("res://assets/art/models/ironleaf_scrub.glb"),
}

static var _meshes: Dictionary = {}
static var _finishes: Dictionary = {}
static var _ground_material: StandardMaterial3D
static var _cliff_material: StandardMaterial3D
static var _deck_material: StandardMaterial3D

static func attach(parent: Node3D, part: StringName, center := Vector3.ZERO, size := Vector3.ONE, casts_shadow := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = String(part)
	instance.mesh = _get_mesh(part)
	instance.position = center
	instance.scale = size
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

static func scatter(parent: Node3D, part: StringName, placements: Array[Transform3D]) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _get_mesh(part)
	batch.instance_count = placements.size()
	for index in range(placements.size()):
		batch.set_instance_transform(index, placements[index])
	var instances := MultiMeshInstance3D.new()
	instances.name = String(part)
	instances.multimesh = batch
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instances)

static func floor_finish() -> StandardMaterial3D:
	if _ground_material == null:
		_ground_material = StandardMaterial3D.new()
		_ground_material.vertex_color_use_as_albedo = true
		_ground_material.albedo_color = Color("#dbd6c9")
		_ground_material.roughness = 0.94
		_set_maps(_ground_material, DUST, DUST_NORMAL, 0.66)
	return _ground_material

static func cliff_finish() -> StandardMaterial3D:
	if _cliff_material == null:
		_cliff_material = StandardMaterial3D.new()
		_cliff_material.vertex_color_use_as_albedo = true
		_cliff_material.roughness = 0.91
		_set_maps(_cliff_material, STRATA, STRATA_NORMAL, 0.82)
	return _cliff_material

static func deck_finish() -> StandardMaterial3D:
	if _deck_material == null:
		_deck_material = StandardMaterial3D.new()
		_deck_material.albedo_color = Color("#a9ada6")
		_deck_material.metallic = 0.46
		_deck_material.metallic_specular = 0.38
		_deck_material.roughness = 0.72
		_set_maps(_deck_material, PAINTED, PAINTED_NORMAL, 0.88, PAINTED_ROUGHNESS)
		_deck_material.uv1_scale = Vector3(2.0, 2.0, 1.0)
	return _deck_material

static func _get_mesh(part: StringName) -> ArrayMesh:
	if not _meshes.has(part):
		var source: PackedScene = PARTS[part]
		var nodes := source.instantiate()
		var visual := nodes as MeshInstance3D
		if visual == null:
			visual = nodes.find_children("*", "MeshInstance3D", true, false).front() as MeshInstance3D
		var mesh := visual.mesh as ArrayMesh
		for surface in range(mesh.get_surface_count()):
			var original := mesh.surface_get_material(surface) as StandardMaterial3D
			mesh.surface_set_material(surface, _finish(original))
		_meshes[part] = mesh
		nodes.free()
	return _meshes[part]

static func _finish(original: StandardMaterial3D) -> StandardMaterial3D:
	var finish := original.resource_name
	if not _finishes.has(finish):
		var material := original.duplicate() as StandardMaterial3D
		match finish:
			"Graphite", "Black", "Steel":
				var tone := 0.79 if finish == "Graphite" else (0.60 if finish == "Black" else 1.0)
				material.albedo_color = Color(tone, tone, tone)
				material.metallic_specular = 0.44
				_set_maps(material, PARKERIZED, PARKERIZED_NORMAL, 0.83, PARKERIZED_ROUGHNESS)
			"Alloy", "Ceramic", "OliveMetal":
				var tone := 0.91 if finish == "Alloy" else (0.77 if finish == "OliveMetal" else 1.0)
				material.albedo_color = Color(tone, tone, tone)
				material.metallic = 0.27
				_set_maps(material, PAINTED, PAINTED_NORMAL, 0.91, PAINTED_ROUGHNESS)
			"BarrelSteel":
				_set_maps(material, PARKERIZED, PARKERIZED_NORMAL, 0.7, PARKERIZED_ROUGHNESS)
			"ColdReceiver":
				material.albedo_color = Color("#b0c2dd")
				material.metallic_specular = 0.49
				_set_maps(material, PARKERIZED, PARKERIZED_NORMAL, 0.79, PARKERIZED_ROUGHNESS)
			"Cowl":
				material.albedo_color = Color("#b9c5bc")
				_set_maps(material, PAINTED, PAINTED_NORMAL, 0.82, PAINTED_ROUGHNESS)
			"ScuffedEdge":
				_set_maps(material, ALLOY, ALLOY_NORMAL, 0.39)
			"Hazard":
				_set_maps(material, ALLOY, ALLOY_NORMAL, 0.56, PAINTED_ROUGHNESS)
			"Rubber", "Fabric":
				material.albedo_color = Color.WHITE
				material.metallic_specular = 0.32
				_set_maps(material, POLYMER, POLYMER_NORMAL, 0.74, POLYMER_ROUGHNESS)
			"Concrete":
				material.albedo_color = Color("#cfcbc1")
				_set_maps(material, ARMORY, ARMORY_NORMAL, 0.91, ARMORY_ROUGHNESS)
			"Rock", "StoneDark":
				_set_maps(material, STRATA, STRATA_NORMAL, 0.66)
			"Shell", "Ridge":
				material.albedo_color = material.albedo_color.lightened(0.12)
				_set_maps(material, DUST, ARMORY_NORMAL, 0.49)
			"Horn", "Membrane":
				material.normal_enabled = true
				material.normal_texture = ARMORY_NORMAL
				material.normal_scale = 0.32
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			"DryLeaf", "RedLeaf":
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if finish.ends_with("Lamp") or finish == "Eye":
			material.emission_enabled = true
			material.emission = material.albedo_color
			material.emission_energy_multiplier = 1.25
		_finishes[finish] = material
	return _finishes[finish]

static func _set_maps(material: StandardMaterial3D, diffuse: Texture2D, normal: Texture2D, strength: float, roughness: Texture2D = null) -> void:
	material.albedo_texture = diffuse
	material.roughness_texture = roughness
	if roughness != null:
		material.roughness = 1.0
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = strength
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
