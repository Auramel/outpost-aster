class_name AsterTurretTuning
extends RefCounted

signal upgraded(path: int, level: int)

enum Path { RATE, DAMAGE, RANGE, CAPACITY, DRONE, STABILITY }

const MAX_LEVEL := 5
const BASE_PRICES := [45, 55, 44, 52, 80, 54]

var _levels: Array[int] = [0, 0, 0, 0, 0, 0]
var _balance: AsterBalance

func _init(balance: AsterBalance) -> void:
	_balance = balance

func upgrade_level(path: int) -> int:
	return _levels[path] if path >= 0 and path < _levels.size() else -1

func upgrade_price(path: int) -> int:
	var level := upgrade_level(path)
	return _balance.tuning_price(BASE_PRICES[path], level) if level >= 0 and level < MAX_LEVEL else 0

func apply_upgrade(path: int) -> bool:
	if upgrade_price(path) == 0:
		return false
	_levels[path] += 1
	upgraded.emit(path, _levels[path])
	return true

static func _gain(level: int, first: int = 0) -> float:
	var ratio := clampf(float(level - first) / (MAX_LEVEL - first), 0.0, 1.0)
	return ratio * (1.35 - 0.35 * ratio)

func stat(path: int, preview_level: int = -1) -> float:
	var level := upgrade_level(path) if preview_level < 0 else preview_level
	var gain := _gain(level)
	match path:
		Path.RATE:
			return _balance.turret_rate + gain * _balance.rate_gain
		Path.DAMAGE:
			return _balance.turret_damage + gain * _balance.damage_gain
		Path.RANGE:
			return _balance.turret_range + gain * _balance.range_gain
		Path.CAPACITY:
			return _balance.turret_capacity + gain * _balance.capacity_gain
		Path.DRONE:
			return _balance.drone_first_payload + _gain(level, 1) * _balance.drone_payload_gain if level > 0 else 0.0
		Path.STABILITY:
			return _balance.stability_gain * gain
	return 0.0

func drone_speed(preview_level: int = -1) -> float:
	var level := upgrade_level(Path.DRONE) if preview_level < 0 else preview_level
	return _balance.drone_first_speed + _gain(level, 1) * _balance.drone_speed_gain if level > 0 else 0.0
