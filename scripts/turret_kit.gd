class_name AsterTurretKit
extends RefCounted

const DRONE_PAD := Vector3(0.74, 0.46, -1.04)
const PART_COLOR := Color("#69746d")
const INSERT_COLOR := Color("#303943")
const TRIM_COLOR := Color("#738088")
const MODULE_LIGHT := Color("#59bbc4")
const FINISH := [Color("#bcb99b"), Color("#df9f65"), Color("#86c4d2"), Color("#ffe1a1")]

var _parts: Dictionary = {}
var _trim: Dictionary = {}
var _steps: Dictionary = {}
var _mounted_box: MeshInstance3D
var _ammo_boxes: Array[Node3D] = []
var _capacity_rank := 0

func setup(head: Node3D, carriage: Node3D, mount: Node3D) -> void:
	var rate := _part(AsterTurretTuning.Path.RATE, carriage, Vector3(0, 0.179, -0.44))
	for side in [-1.0, 1.0]:
		AsterArt.box(rate, Vector3(0.15, 0.068, 0.34), Vector3(side * 0.423, 0, 0), PART_COLOR)
		AsterArt.box(rate, Vector3(0.11, 0.025, 0.298), Vector3(side * 0.423, 0.043, 0), INSERT_COLOR)
	_badge(rate, AsterTurretTuning.Path.RATE, Vector3(-0.423, 0.031, -0.134))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.RATE, rate, Vector3(0.105, 0.018, 0.025), Vector3(0.423, 0.065, -0.116 + rank * 0.055), TRIM_COLOR)

	var damage := _part(AsterTurretTuning.Path.DAMAGE, carriage, Vector3(0, AsterTurret.MUZZLE.y, -1.28))
	for side in [-1.0, 1.0]:
		var collar := AsterArt.primitive(damage, "prism", Vector3(0.236, 0.187, 0.236), Vector3(side * AsterTurret.MUZZLE.x, 0, 0), PART_COLOR)
		collar.rotation.x = PI * 0.5
	_badge(damage, AsterTurretTuning.Path.DAMAGE, Vector3(-AsterTurret.MUZZLE.x, 0.088, -0.076))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		var rib := Node3D.new()
		damage.add_child(rib)
		_steps[AsterTurretTuning.Path.DAMAGE].append(rib)
		for side in [-1.0, 1.0]:
			var band := AsterArt.primitive(rib, "prism", Vector3(0.250, 0.019, 0.250), Vector3(side * AsterTurret.MUZZLE.x, 0.0, -0.078 + rank * 0.038), TRIM_COLOR)
			band.rotation.x = PI * 0.5

	var optics := _part(AsterTurretTuning.Path.RANGE, head, Vector3(-0.337, 0.462, 0.325))
	AsterArt.box(optics, Vector3(0.114, 0.106, 0.124), Vector3.ZERO, INSERT_COLOR)
	AsterArt.box(optics, Vector3(0.221, 0.092, 0.237), Vector3(0, 0.073, -0.049), PART_COLOR)
	_badge(optics, AsterTurretTuning.Path.RANGE, Vector3(0, 0.092, -0.174))

	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.RANGE, optics, Vector3(0.018, 0.013, 0.034), Vector3(-0.076 + rank * 0.038, 0.129, -0.075), MODULE_LIGHT, true)

	_mounted_box = AsterModels.attach(head, &"turret_cartridge", Vector3(0, -0.058, 0.545))
	var feed := _part(AsterTurretTuning.Path.CAPACITY, head, Vector3(0, -0.11, 0.60))
	AsterArt.box(feed, Vector3(1.18, 0.052, 0.23), Vector3(0, -0.168, 0.047), INSERT_COLOR)
	for side in [-1.0, 1.0]:
		var storage := Node3D.new()
		storage.position = Vector3(side * 0.394, 0, 0.015)
		feed.add_child(storage)
		_ammo_boxes.append(storage)
		AsterModels.attach(storage, &"turret_cartridge", Vector3.ZERO, Vector3(0.82, 0.91, 0.93))
	_badge(feed, AsterTurretTuning.Path.CAPACITY, Vector3(0, -0.160, 0.171))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.CAPACITY, feed, Vector3(0.043, 0.018, 0.017), Vector3(-0.116 + rank * 0.058, -0.154, 0.163), TRIM_COLOR)

	var dock := _part(AsterTurretTuning.Path.DRONE, mount, DRONE_PAD)
	AsterArt.box(dock, Vector3(0.52, 0.085, 0.42), Vector3.ZERO, PART_COLOR)
	AsterArt.box(dock, Vector3(0.15, 0.38, 0.15), Vector3(0, -0.18, 0), INSERT_COLOR)
	_badge(dock, AsterTurretTuning.Path.DRONE, Vector3(0, 0.061, 0.14))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.DRONE, dock, Vector3(0.019, 0.016, 0.239), Vector3(-0.19 + rank * 0.093, 0.049, 0), MODULE_LIGHT, true)

	var brace := _part(AsterTurretTuning.Path.STABILITY, mount, Vector3(0, 0.22, 0.28))
	for side in [-1.0, 1.0]:
		var damper := AsterArt.box(brace, Vector3(0.13, 0.34, 0.27), Vector3(side * 0.58, -0.014, 0), PART_COLOR)
		damper.rotation.z = side * 0.30
	_badge(brace, AsterTurretTuning.Path.STABILITY, Vector3(0, 0.12, 0.23))
	for rank in range(AsterTurretTuning.MAX_LEVEL):
		_rank_piece(AsterTurretTuning.Path.STABILITY, brace, Vector3(0.112, 0.029, 0.037), Vector3(0.59, 0.126 - rank * 0.059, 0.144), TRIM_COLOR)
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
	_mounted_box.visible = loaded
	_ammo_boxes[0].visible = loaded and _capacity_rank > 0
	_ammo_boxes[1].visible = loaded and _capacity_rank >= 3

func update_rank(path: int, rank: int, limit: int) -> void:
	var module: Node3D = _parts[path]
	var trim: MeshInstance3D = _trim[path]
	module.show()
	if path == AsterTurretTuning.Path.RATE or path == AsterTurretTuning.Path.RANGE:
		module.scale = Vector3.ONE * lerpf(0.94, 1.06, float(rank) / limit)
	for index in range(_steps[path].size()):
		_steps[path][index].visible = index < rank
	if path == AsterTurretTuning.Path.CAPACITY:
		_capacity_rank = rank
	var finish := mini(FINISH.size() - 1, floori(float(rank) / (limit / float(FINISH.size()))))
	trim.material_override = AsterArt.material(FINISH[finish], true)
