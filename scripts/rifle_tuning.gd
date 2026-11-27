class_name AsterRifleTuning
extends RefCounted

enum Path { RATE, DAMAGE, ACCURACY, RECOIL }

const MAX_LEVEL := 5
const BASE_PRICES := [57, 67, 51, 54]
const ARMOUR := Color("#64716a")
const STEEL := Color("#a6aaa2")
const GRAPHITE := Color("#323c46")

var _levels: Array[int] = [0, 0, 0, 0]
var _modules: Array[Node3D] = []
var _rank_parts: Array = []
var _balance: AsterBalance

func setup(balance: AsterBalance, rifle: Node3D) -> void:
	_balance = balance
	var rate := _module(rifle, Vector3(0, 0.111, -0.42))
	for side in [-1.0, 1.0]:
		_box(rate, Vector3(0.043, 0.082, 0.34), Vector3(side * 0.178, 0.022, 0), ARMOUR)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.RATE].append(_box(rate, Vector3(0.020, 0.059, 0.034), Vector3(0.203, 0.024, -0.13 + rank * 0.063), STEEL))

	var damage := _module(rifle, Vector3(0, 0.037, -0.722))
	var crown := AsterArt.primitive(damage, "prism", Vector3(0.14, 0.13, 0.14), Vector3.ZERO, GRAPHITE)
	crown.rotation.x = PI * 0.5
	_viewmodel(crown)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.DAMAGE].append(_box(damage, Vector3(0.020, 0.018, 0.105), Vector3(-0.056 + rank * 0.028, 0.064, 0.01), STEEL))

	var accuracy := _module(rifle, Vector3(-0.116, 0.206, -0.357))
	_box(accuracy, Vector3(0.060, 0.077, 0.171), Vector3.ZERO, ARMOUR)
	_box(accuracy, Vector3(0.040, 0.035, 0.014), Vector3(0, 0.009, -0.093), AsterArt.CYAN, true)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.ACCURACY].append(_box(accuracy, Vector3(0.012, 0.014, 0.014), Vector3(-0.034, 0.008, -0.058 + rank * 0.029), AsterArt.CYAN, true))

	var recoil := _module(rifle, Vector3(0, 0.024, 0.288))
	for side in [-1.0, 1.0]:
		_box(recoil, Vector3(0.059, 0.104, 0.207), Vector3(side * 0.118, 0, 0), GRAPHITE)
	for rank in range(MAX_LEVEL):
		_rank_parts[Path.RECOIL].append(_box(recoil, Vector3(0.017, 0.068, 0.021), Vector3(0.154, 0, -0.082 + rank * 0.041), STEEL))

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
