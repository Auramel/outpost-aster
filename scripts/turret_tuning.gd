class_name AsterTurretTuning
extends RefCounted

signal upgraded(path: int, level: int)

enum Type { THRESHER, STINGER, DRAGONFLY, BULBA, DREADNOUGHT }
enum Path { RATE, DAMAGE, RANGE, CAPACITY, DRONE, STABILITY }
enum SupportPath { SALVO_RATE, DAMAGE, RANGE, BLAST_RADIUS }

const TITLES := ["Т-1 Молотилка", "Т-2 Жало", "Т-3 Стрекоза", "Т-4 Бульба", "Т-5 Дредноут"]
const MAX_LEVEL := 5
const BASE_PRICES := [45, 55, 44, 52, 80, 54]
const STINGER := [Vector2(0.64, 0.52), Vector2(83, 115), Vector2(72, 43), Vector2(64, 96), Vector2(18, 68)]
const DRAGONFLY := [Vector2(12, 16), Vector2(7, 15), Vector2(64, 50), Vector2(1350, 2150), Vector2(220, 1390)]
const BULBA := [Vector2(0.21, 0.22), Vector2(67, 68), Vector2(83, 64), Vector2(12, 24), Vector2(5, 24)]
const SUPPORT := [Vector2(1.0 / 2.1, 0.29), Vector2(440, 550), Vector2(138, 60), Vector2(5.6, 3.4)]

var type: Type
var _levels: Array[int] = [0, 0, 0, 0, 0, 0]
var _balance: AsterBalance

func _init(balance: AsterBalance, model := Type.THRESHER) -> void:
	_balance = balance
	type = model

func path_count() -> int:
	return SUPPORT.size() if type == Type.DREADNOUGHT else BASE_PRICES.size()

func upgrade_level(path: int) -> int:
	return _levels[path] if path >= 0 and path < path_count() else -1

func upgrade_price(path: int) -> int:
	var level := upgrade_level(path)
	return _balance.tuning_price(BASE_PRICES[path], level) if level >= 0 and level < MAX_LEVEL else 0

func apply_upgrade(path: int) -> bool:
	if upgrade_price(path) == 0:
		return false
	_levels[path] += 1
	upgraded.emit(path, _levels[path])
	return true

static func _gain(level: int) -> float:
	var ratio := clampf(float(level) / MAX_LEVEL, 0.0, 1.0)
	return ratio * (1.35 - 0.35 * ratio)

func stat(path: int, preview_level: int = -1) -> float:
	if path < 0 or path >= path_count():
		return 0.0
	var level := upgrade_level(path) if preview_level < 0 else preview_level
	var gain := _gain(level)
	if path == Path.STABILITY:
		return _balance.stability_gain * gain
	if type == Type.DREADNOUGHT:
		return SUPPORT[path].x + gain * SUPPORT[path].y
	if type == Type.STINGER:
		return STINGER[path].x + gain * STINGER[path].y
	if type == Type.DRAGONFLY:
		return DRAGONFLY[path].x + gain * DRAGONFLY[path].y
	if type == Type.BULBA:
		return BULBA[path].x + gain * BULBA[path].y
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
			return _balance.drone_first_payload + gain * _balance.drone_payload_gain
	return 0.0

func drone_speed(preview_level: int = -1) -> float:
	var level := upgrade_level(Path.DRONE) if preview_level < 0 else preview_level
	return _balance.drone_first_speed + _gain(level) * _balance.drone_speed_gain
