class_name AsterTurretKit
extends RefCounted

const PART_COLOR := Color("#596254")
const INSERT_COLOR := Color("#262e34")
const FINISH := [Color("#bcb99b"), Color("#df9f65"), Color("#86c4d2"), Color("#ffe1a1")]

var _parts: Dictionary = {}
var _trim: Dictionary = {}
var _steps: Dictionary = {}
var _ammo_boxes: Array[Node3D] = []
var _capacity_rank := 0

func setup(head: Node3D, carriage: Node3D, mount: Node3D) -> void:
	var rate := _part(AsterTurretTuning.Path.RATE, carriage, Vector3(0, 0.17, -0.64))
	for side in [-1.0, 1.0]:
		AsterArt.box(rate, Vector3(0.19, 0.16, 0.61), Vector3(side * 0.39, 0, 0), PART_COLOR)
		AsterArt.box(rate, Vector3(0.13, 0.044, 0.46), Vector3(side * 0.39, 0.091, 0), INSERT_COLOR)
	_badge(rate, AsterTurretTuning.Path.RATE, Vector3(0, 0.075, 0.06))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.RATE, rate, Vector3(0.12, 0.030, 0.045), Vector3(0.39, 0.135, -0.22 + rank * 0.105), AsterArt.PALE)

	var damage := _part(AsterTurretTuning.Path.DAMAGE, carriage, Vector3(0, 0, -1.04))
	for side in [-1.0, 1.0]:
		var collar := AsterArt.primitive(damage, "prism", Vector3(0.23, 0.25, 0.23), Vector3(side * 0.22, 0, 0), PART_COLOR)
		collar.rotation.x = PI * 0.5
	_badge(damage, AsterTurretTuning.Path.DAMAGE, Vector3(0, 0.05, 0.06))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		var rib := Node3D.new()
		damage.add_child(rib)
		_steps[AsterTurretTuning.Path.DAMAGE].append(rib)
		for side in [-1.0, 1.0]:
			var band := AsterArt.primitive(rib, "prism", Vector3(0.248, 0.023, 0.248), Vector3(side * 0.22, 0.0, -0.11 + rank * 0.049), AsterArt.PALE)
			band.rotation.x = PI * 0.5

	var optics := _part(AsterTurretTuning.Path.RANGE, head, Vector3(0.55, 0.30, 0.11))
	AsterArt.box(optics, Vector3(0.18, 0.38, 0.14), Vector3.ZERO, INSERT_COLOR)
	AsterArt.box(optics, Vector3(0.26, 0.15, 0.40), Vector3(0, 0.19, -0.11), PART_COLOR)
	_badge(optics, AsterTurretTuning.Path.RANGE, Vector3(0, 0.19, -0.32))

	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.RANGE, optics, Vector3(0.039, 0.030, 0.042), Vector3(-0.098 + rank * 0.049, 0.197, -0.316), AsterArt.CYAN, true)

	var feed := _part(AsterTurretTuning.Path.CAPACITY, head, Vector3(0, -0.122, 0.46))
	AsterArt.box(feed, Vector3(0.84, 0.076, 0.25), Vector3(0, -0.167, 0.21), INSERT_COLOR)
	for side in [-1.0, 1.0]:
		var storage := Node3D.new()
		storage.position = Vector3(side * 0.28, 0.0, 0.24)
		feed.add_child(storage)
		_ammo_boxes.append(storage)
		AsterArt.box(storage, Vector3(0.48, 0.37, 0.37), Vector3.ZERO, PART_COLOR)
		AsterArt.box(storage, Vector3(0.49, 0.062, 0.38), Vector3(0, 0.19, 0), INSERT_COLOR)
		for x in [-0.151, 0.151]:
			AsterArt.box(storage, Vector3(0.056, 0.18, 0.032), Vector3(x, 0.02, 0.198), AsterArt.PALE)
		AsterArt.box(storage, Vector3(0.20, 0.043, 0.022), Vector3(0.0, 0.025, 0.201), AsterArt.AMBER)
	_badge(feed, AsterTurretTuning.Path.CAPACITY, Vector3(0, 0.08, 0.046))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.CAPACITY, feed, Vector3(0.046, 0.035, 0.026), Vector3(-0.115 + rank * 0.057, -0.13, 0.35), AsterArt.PALE)

	var dock := _part(AsterTurretTuning.Path.DRONE, mount, Vector3(0.66, 0.49, -0.58))
	AsterArt.box(dock, Vector3(0.52, 0.085, 0.42), Vector3.ZERO, PART_COLOR)
	AsterArt.box(dock, Vector3(0.15, 0.38, 0.15), Vector3(0, -0.18, 0), INSERT_COLOR)
	_badge(dock, AsterTurretTuning.Path.DRONE, Vector3(0, 0.061, 0.14))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.DRONE, dock, Vector3(0.025, 0.026, 0.31), Vector3(-0.20 + rank * 0.096, 0.052, 0), AsterArt.CYAN, true)

	var brace := _part(AsterTurretTuning.Path.STABILITY, mount, Vector3(0, 0.23, 0.31))
	for side in [-1.0, 1.0]:
		var damper := AsterArt.box(brace, Vector3(0.16, 0.46, 0.37), Vector3(side * 0.57, -0.02, 0), PART_COLOR)
		damper.rotation.z = side * 0.28
	_badge(brace, AsterTurretTuning.Path.STABILITY, Vector3(0, 0.12, 0.23))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.STABILITY, brace, Vector3(0.146, 0.044, 0.054), Vector3(0.58, 0.22 - rank * 0.075, 0.149), AsterArt.PALE)
	set_loaded(true)

func _part(path: int, parent: Node3D, position: Vector3) -> Node3D:
	var module := Node3D.new()
	module.position = position
	module.hide()
	parent.add_child(module)
	_parts[path] = module
	_steps[path] = []
	return module

func _badge(parent: Node3D, path: int, position: Vector3) -> void:
	_trim[path] = AsterArt.box(parent, Vector3(0.12, 0.027, 0.033), position, FINISH[0], true)

func _rank_piece(path: int, parent: Node3D, size: Vector3, at: Vector3, color: Color, glow := false) -> void:
	_steps[path].append(AsterArt.box(parent, size, at, color, glow))

func set_loaded(loaded: bool) -> void:
	_ammo_boxes[0].visible = loaded and _capacity_rank > 0
	_ammo_boxes[1].visible = loaded and _capacity_rank >= 3

func update_rank(path: int, rank: int, limit: int) -> void:
	var module: Node3D = _parts[path]
	var trim: MeshInstance3D = _trim[path]
	module.show()
	module.scale = Vector3.ONE * lerpf(0.86, 1.12, float(rank) / limit)
	for index in range(_steps[path].size()):
		_steps[path][index].visible = index < rank
	if path == AsterTurretTuning.Path.CAPACITY:
		_capacity_rank = rank
	var finish := mini(FINISH.size() - 1, floori(float(rank) / (limit / float(FINISH.size()))))
	trim.material_override = AsterArt.material(FINISH[finish], true)
