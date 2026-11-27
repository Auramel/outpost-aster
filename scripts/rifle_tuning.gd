class_name AsterRifleTuning
extends RefCounted

enum Path { RATE, DAMAGE, ACCURACY, RECOIL }

const MAX_LEVEL := 5
const BASE_PRICES := [57, 67, 51, 54]
const ARMOUR := Color("#536477")
const STEEL := Color("#a3aeb8")
const GRAPHITE := Color("#323c46")

var _levels: Array[int] = [0, 0, 0, 0]
var _modules: Array[Node3D] = []
var _rank_parts: Array = []
var _balance: AsterBalance

func setup(balance: AsterBalance, rifle: Node3D) -> void:
	_balance = balance
	var rate := _module(rifle, Vector3(0, 0.065, -0.565))
	for side in [-1.0, 1.0]:
		_box(rate, Vector3(0.032, 0.045, 0.30), Vector3(side * 0.130, 0.006, 0), ARMOUR)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.RATE].append(_box(rate, Vector3(0.014, 0.032, 0.027), Vector3(-0.149, 0.010, -0.11 + rank * 0.052), STEEL))

	var damage := _module(rifle, Vector3(0, 0.027, -0.945))
	var crown := AsterArt.primitive(damage, "prism", Vector3(0.126, 0.099, 0.126), Vector3.ZERO, GRAPHITE)
	crown.rotation.x = PI * 0.5
	_viewmodel(crown)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.DAMAGE].append(_box(damage, Vector3(0.017, 0.013, 0.055), Vector3(-0.045 + rank * 0.023, 0.048, -0.021), STEEL))

	var accuracy := _module(rifle, Vector3(-0.119, 0.151, -0.405))
	_box(accuracy, Vector3(0.060, 0.077, 0.171), Vector3.ZERO, ARMOUR)
	_box(accuracy, Vector3(0.040, 0.035, 0.014), Vector3(0, 0.009, -0.093), AsterArt.CYAN, true)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.ACCURACY].append(_box(accuracy, Vector3(0.012, 0.014, 0.014), Vector3(-0.034, 0.008, -0.058 + rank * 0.029), AsterArt.CYAN, true))

	var recoil := _module(rifle, Vector3(0, 0.021, 0.379))
	for side in [-1.0, 1.0]:
		_box(recoil, Vector3(0.041, 0.080, 0.179), Vector3(side * 0.110, 0, 0), GRAPHITE)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.RECOIL].append(_box(recoil, Vector3(0.014, 0.049, 0.018), Vector3(-0.133, 0, -0.068 + rank * 0.034), STEEL))

func upgrade_level(path: int) -> int:
	return _levels[path] if path >= 0 and path < _levels.size() else -1

func upgrade_price(path: int) -> int:
	var level := upgrade_level(path)
	return _balance.tuning_price(BASE_PRICES[path], level) if level >= 0 and level < MAX_LEVEL else 0

func apply_upgrade(path: int) -> bool:
	if upgrade_price(path) == 0:
		return false
	_levels[path] += 1
	_modules[path].show()
	for rank in range(MAX_LEVEL):
		_rank_parts[path][rank].visible = rank < _levels[path]
	return true

func stat(path: int, preview_level: int = -1) -> float:
	var level := upgrade_level(path) if preview_level < 0 else preview_level
	var factor := clampf(float(level) / MAX_LEVEL, 0.0, 1.0)
	match path:
		Path.RATE: return _balance.rifle_rate + factor * _balance.rifle_rate_gain
		Path.DAMAGE: return _balance.rifle_damage + factor * _balance.rifle_damage_gain
		Path.ACCURACY: return factor * _balance.rifle_accuracy_gain
		Path.RECOIL: return factor * _balance.rifle_recoil_reduction
	return 0.0

func _module(parent: Node3D, at: Vector3) -> Node3D:
	var model := Node3D.new()
	model.position = at
	model.hide()
	parent.add_child(model)
	_modules.append(model)
	_rank_parts.append([])
	return model

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var box := AsterArt.box(parent, size, at, color, glow)
	_viewmodel(box)
	return box

func _viewmodel(mesh: MeshInstance3D) -> void:
	mesh.layers = AsterModels.VIEWMODEL_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
