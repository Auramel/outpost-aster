class_name AsterModels
extends RefCounted

const VIEWMODEL_LAYER := 1 << 19
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
const CHITIN := preload("res://assets/art/materials/dune_chitin.png")
const CHITIN_NORMAL := preload("res://assets/art/materials/dune_chitin_normal.png")
const SIEGE_ROUGHNESS := preload("res://assets/art/materials/dune_siege_roughness.png")
const SIEGE_OCCLUSION := preload("res://assets/art/materials/dune_siege_occlusion.png")
const WING := preload("res://assets/art/materials/dune_wing.png")
const CANYON_GRAVEL := preload("res://assets/art/materials/canyon_gravel.jpg")
const CANYON_GRAVEL_NORMAL := preload("res://assets/art/materials/canyon_gravel_normal.png")
const CANYON_GRAVEL_ROUGHNESS := preload("res://assets/art/materials/canyon_gravel_roughness.png")
const CANYON_ROCK := preload("res://assets/art/materials/canyon_sandstone.jpg")
const CANYON_ROCK_NORMAL := preload("res://assets/art/materials/canyon_sandstone_normal.png")
const CANYON_ROCK_ROUGHNESS := preload("res://assets/art/materials/canyon_sandstone_roughness.png")
const CANYON_CONCRETE := preload("res://assets/art/materials/canyon_bunker.jpg")
const CANYON_CONCRETE_NORMAL := preload("res://assets/art/materials/canyon_bunker_normal.png")
const CANYON_CONCRETE_ROUGHNESS := preload("res://assets/art/materials/canyon_bunker_roughness.png")
const CANYON_ARMOR := preload("res://assets/art/materials/canyon_armor.jpg")
const CANYON_ARMOR_NORMAL := preload("res://assets/art/materials/canyon_armor_normal.png")
const CANYON_ARMOR_ROUGHNESS := preload("res://assets/art/materials/canyon_armor_roughness.png")
const SKY := preload("res://assets/art/materials/day_panorama.jpg")
const PARTS := {
	&"carbine": preload("res://assets/art/models/aster_carbine.glb"),
	&"carbine_magazine": preload("res://assets/art/models/aster_carbine_magazine.glb"),
	&"carbine_support": preload("res://assets/art/models/aster_carbine_support.glb"),
	&"carbine_grip": preload("res://assets/art/models/aster_carbine_grip.glb"),
	&"repair": preload("res://assets/art/models/field_repair_tool.glb"),
	&"turret_base": preload("res://assets/art/models/turret_base.glb"),
	&"stinger_base": preload("res://assets/art/models/stinger_base.glb"),
	&"stinger_head": preload("res://assets/art/models/stinger_head.glb"),
	&"stinger_barrel": preload("res://assets/art/models/stinger_barrel.glb"),
	&"dragonfly_base": preload("res://assets/art/models/dragonfly_base.glb"),
	&"dragonfly_head": preload("res://assets/art/models/dragonfly_head.glb"),
	&"dragonfly_guns": preload("res://assets/art/models/dragonfly_guns.glb"),
	&"bulba_base": preload("res://assets/art/models/bulba_base.glb"),
	&"bulba_head": preload("res://assets/art/models/bulba_head.glb"),
	&"bulba_pods": preload("res://assets/art/models/bulba_pods.glb"),
	&"turret_head": preload("res://assets/art/models/turret_head.glb"),
	&"turret_emitters": preload("res://assets/art/models/turret_emitters.glb"),
	&"turret_cartridge": preload("res://assets/art/models/turret_cartridge.glb"),
	&"turret_ammo_layer": preload("res://assets/art/models/turret_ammo_layer.glb"),
	&"turret_damage_light": preload("res://assets/art/models/turret_damage_light.glb"),
	&"turret_damage_heavy": preload("res://assets/art/models/turret_damage_heavy.glb"),
	&"dreadnought_ring": preload("res://assets/art/models/dreadnought_ring.glb"),
	&"dreadnought_housing": preload("res://assets/art/models/dreadnought_housing.glb"),
	&"dreadnought_barrels": preload("res://assets/art/models/dreadnought_barrels.glb"),
	&"facade": preload("res://assets/art/models/fortification_facade.glb"),
	&"turret_platform": preload("res://assets/art/models/facade_turret_platform.glb"),
	&"hospital": preload("res://assets/art/models/field_hospital.glb"),
	&"nest": preload("res://assets/art/models/cliff_nest.glb"),
	&"scan_rock": preload("res://assets/art/models/rock_face_02.glb"),
	&"turret_wreck": preload("res://assets/art/models/turret_wreck.glb"),
	&"bug": preload("res://assets/art/models/dune_beetle.glb"),
	&"leg_left": preload("res://assets/art/models/beetle_leg_left.glb"),
	&"leg_right": preload("res://assets/art/models/beetle_leg_right.glb"),
	&"claw_left": preload("res://assets/art/models/beetle_claw_left.glb"),
	&"claw_right": preload("res://assets/art/models/beetle_claw_right.glb"),
	&"bug_tail": preload("res://assets/art/models/beetle_tail.glb"),
	&"bug_sting": preload("res://assets/art/models/beetle_sting.glb"),
	&"flyer": preload("res://assets/art/models/flying_beetle.glb"),
	&"flyer_tail": preload("res://assets/art/models/flying_beetle_tail.glb"),
	&"flyer_wing": preload("res://assets/art/models/flying_beetle_wing.glb"),
	&"tank_shell": preload("res://assets/art/models/tank_shell.glb"),
	&"ram_shell": preload("res://assets/art/models/ram_shell.glb"),
	&"catapult_shell": preload("res://assets/art/models/catapult_shell.glb"),
	&"siege_leg": preload("res://assets/art/models/siege_leg.glb"),
	&"siege_claw": preload("res://assets/art/models/siege_claw.glb"),
	&"catapult_tail": preload("res://assets/art/models/catapult_tail.glb"),
	&"catapult_scoop": preload("res://assets/art/models/catapult_scoop.glb"),
	&"shooter_quills": preload("res://assets/art/models/shooter_quills.glb"),
	&"bug_quill": preload("res://assets/art/models/bug_quill.glb"),
	&"bug_rock": preload("res://assets/art/models/eroded_boulder_1.glb"),
	&"kamikaze_shell": preload("res://assets/art/models/kamikaze_shell.glb"),
	&"kamikaze_sac": preload("res://assets/art/models/kamikaze_sac.glb"),
	&"transporter_shell": preload("res://assets/art/models/transporter_shell.glb"),
	&"transporter_tail": preload("res://assets/art/models/transporter_tail.glb"),
	&"transporter_grip": preload("res://assets/art/models/transporter_grip.glb"),
	&"wall": preload("res://assets/art/models/wall_segment.glb"),
	&"gate_frame": preload("res://assets/art/models/gate_frame.glb"),
	&"gate_panels": preload("res://assets/art/models/gate_panels.glb"),
	&"relay": preload("res://assets/art/models/relay_bunker.glb"),
	&"station": preload("res://assets/art/models/field_terminal.glb"),
	&"supply": preload("res://assets/art/models/supply_rack.glb"),
	&"drone": preload("res://assets/art/models/supply_drone.glb"),
	&"breach": preload("res://assets/art/models/breach_debris.glb"),
	&"canyon_ridge": preload("res://assets/art/models/canyon_ridge.glb"),
	&"canyon_spur": preload("res://assets/art/models/canyon_spur.glb"),
	&"canyon_cut": preload("res://assets/art/models/canyon_cut.glb"),
	&"canyon_bastion": preload("res://assets/art/models/canyon_bastion.glb"),
	&"stone_1": preload("res://assets/art/models/eroded_boulder_1.glb"),
	&"stone_2": preload("res://assets/art/models/eroded_boulder_2.glb"),
	&"stone_3": preload("res://assets/art/models/eroded_boulder_3.glb"),
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
		_ground_material.albedo_color = Color("#fff5e5")
		_ground_material.roughness = 0.94
		_ground_material.metallic_specular = 0.22
		_set_maps(_ground_material, CANYON_GRAVEL, CANYON_GRAVEL_NORMAL, 0.67, CANYON_GRAVEL_ROUGHNESS)
	return _ground_material

static func cliff_finish() -> StandardMaterial3D:
	if _cliff_material == null:
		_cliff_material = StandardMaterial3D.new()
		_cliff_material.vertex_color_use_as_albedo = true
		_cliff_material.roughness = 0.91
		_cliff_material.metallic_specular = 0.23
		_set_maps(_cliff_material, CANYON_ROCK, CANYON_ROCK_NORMAL, 0.72, CANYON_ROCK_ROUGHNESS)
	return _cliff_material

static func deck_finish() -> StandardMaterial3D:
	if _deck_material == null:
		_deck_material = StandardMaterial3D.new()
		_deck_material.albedo_color = Color("#a9ada6")
		_deck_material.metallic = 0.46
		_deck_material.metallic_specular = 0.38
		_deck_material.roughness = 0.72
		_set_maps(_deck_material, CANYON_ARMOR, CANYON_ARMOR_NORMAL, 0.78, CANYON_ARMOR_ROUGHNESS)
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
			"TurretEnamel", "HospitalEnamel", "HospitalRed":
				_set_maps(material, PAINTED, PAINTED_NORMAL, 0.78, PAINTED_ROUGHNESS)
			"TurretCast", "CharredTurret":
				material.metallic_specular = 0.41
				_set_maps(material, PARKERIZED, PARKERIZED_NORMAL, 0.61, PARKERIZED_ROUGHNESS)
			"TurretScanLamp":
				material.metallic_specular = 0.48
			"CarbineSatin":
				material.metallic_specular = 0.49
				_set_maps(material, PARKERIZED, PARKERIZED_NORMAL, 0.70, PARKERIZED_ROUGHNESS)
			"CarbineAccent":
				_set_maps(material, PAINTED, PAINTED_NORMAL, 0.73, PAINTED_ROUGHNESS)
			"GripPolymer", "GloveFabric":
				material.metallic_specular = 0.28
				_set_maps(material, POLYMER, POLYMER_NORMAL, 0.5, POLYMER_ROUGHNESS)
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
			"BunkerConcrete":
				_set_maps(material, CANYON_CONCRETE, CANYON_CONCRETE_NORMAL, 0.82, CANYON_CONCRETE_ROUGHNESS)
			"BunkerArmor", "BunkerRim":
				_set_maps(material, CANYON_ARMOR, CANYON_ARMOR_NORMAL, 0.76, CANYON_ARMOR_ROUGHNESS)
			"rock_face_02":
				material.albedo_color = Color(1.25, 1.03, 0.80)
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			"Rock", "StoneDark", "CanyonLedge", "CanyonShade":
				material.metallic_specular = 0.26
				_set_maps(material, CANYON_ROCK, CANYON_ROCK_NORMAL, 0.72, CANYON_ROCK_ROUGHNESS)
			"DuneChitin":
				material.metallic_specular = 0.44
				_set_maps(material, CHITIN, CHITIN_NORMAL, 0.73)
			"DuneSiegeChitin", "DunePlateEdge", "DuneTendon":
				material.metallic_specular = 0.43
				_set_maps(material, CHITIN, CHITIN_NORMAL, 0.73 if finish != "DuneTendon" else 0.39, SIEGE_ROUGHNESS)
				material.ao_enabled = true
				material.ao_texture = SIEGE_OCCLUSION
			"DuneSac", "DuneSacVein":
				_set_maps(material, CHITIN, CHITIN_NORMAL, 0.35 if finish == "DuneSac" else 0.58)
				material.clearcoat_enabled = true
				material.clearcoat = 0.36
				material.emission_enabled = finish == "DuneSac"
				material.emission = Color("#6b340b")
				material.emission_energy_multiplier = 0.37
			"DuneSinew":
				material.normal_enabled = true
				material.normal_texture = ARMORY_NORMAL
				material.normal_scale = 0.32
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			"DuneWing":
				material.albedo_texture = WING
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			"DryLeaf", "RedLeaf":
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if finish.ends_with("Lamp"):
			material.emission_enabled = true
			material.emission = material.albedo_color
			if finish == "TurretScanLamp":
				material.emission_energy_multiplier = 0.55
			elif finish == "DuneEyeLamp":
				material.emission_energy_multiplier = 0.84
			else:
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
