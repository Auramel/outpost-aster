class_name AsterArt
extends RefCounted

const SOLID := 1
const ENEMY := 2
const TARGET := 4
const ACCESS := 8
const PLAYER := 16
const SPAWN_SCREEN := 32
const SAND := Color("#a48776")
const CONCRETE := Color("#686f70")
const METAL := Color("#353f4a")
const DARK := Color("#19242e")
const PALE := Color("#92a6ac")
const AMBER := Color("#ffa34e")
const CYAN := Color("#8cdeff")
const RED := Color("#ff6658")

static var materials: Dictionary = {}
static var meshes: Dictionary = {}

static func material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var key := [color, luminous]
	if not materials.has(key):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.vertex_color_use_as_albedo = false
		result.roughness = 0.86
		if luminous:
			result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.no_depth_test = false
		materials[key] = result
	return materials[key]

static func primitive(parent: Node3D, shape: String, size: Vector3, center: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var key := [shape, size]
	if not meshes.has(key):
		match shape:
			"box":
				var box := BoxMesh.new()
				box.size = size
				meshes[key] = box
			"prism", "cylinder", "cone":
				var cylinder := CylinderMesh.new()
				cylinder.radial_segments = 6 if shape == "prism" else 8
				cylinder.rings = 1
				cylinder.top_radius = size.x * 0.5 if shape != "cone" else size.x * 0.13
				cylinder.bottom_radius = size.z * 0.5
				cylinder.height = size.y
				meshes[key] = cylinder
			"orb":
				var sphere := SphereMesh.new()
				sphere.radial_segments = 8
				sphere.rings = 4
				sphere.radius = 0.5
				sphere.height = 1.0
				meshes[key] = sphere
	var instance := MeshInstance3D.new()
	instance.mesh = meshes[key]
	instance.material_override = material(color, glow)
	instance.position = center
	if shape == "orb":
		instance.scale = size
	if glow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

static func box(parent: Node3D, size: Vector3, center: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	return primitive(parent, "box", size, center, color, glow)

static func collider(parent: Node3D, size: Vector3, center: Vector3, layer: int, owner_node: Node = null, area: bool = false) -> CollisionObject3D:
	var body: CollisionObject3D
	if area:
		var marker := Area3D.new()
		marker.monitoring = false
		marker.monitorable = false
		body = marker
	else:
		body = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	if owner_node != null:
		body.set_meta(&"target", owner_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

static func lettering(parent: Node3D, words: String, center: Vector3, size: int, color: Color, billboard: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.position = center
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 4
	label.outline_modulate = DARK
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

static func ray(world: World3D, from: Vector3, to: Vector3, mask: int, areas: bool = false) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_areas = areas
	return world.direct_space_state.intersect_ray(query)

static func horizontal(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
