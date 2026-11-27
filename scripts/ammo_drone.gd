class_name AsterAmmoDrone
extends Node3D

enum Flight { PARKED, OUTBOUND, LOADING, INBOUND, UNLOADING }

const CRATE_SCALE := Vector3(0.60, 0.64, 0.68)

var flight := Flight.PARKED
var payload := 0
var flights_completed := 0
var _turret: AsterTurret
var _supply: Node3D
var _tuning: AsterTurretTuning
var _altitude := 7.5
var _pickup_offset := Vector3.ZERO
var _route := PackedVector3Array()
var _waypoint := 0
var _loading := 0.0
var _rotors: Array[Node3D] = []
var _crate: MeshInstance3D

func setup(turret: AsterTurret, supply: Node3D, index: int) -> void:
	_turret = turret
	_supply = supply
	_tuning = turret.tuning
	_altitude = maxf(_altitude + float(index % 6) * 0.48, turret.global_position.y + 4.2)
	_pickup_offset = Vector3((float(index % 6) - 2.5) * 0.74, 1.85, -0.14 + float((index / 6) % 3) * 0.72)
	AsterModels.attach(self, &"drone", Vector3.ZERO, Vector3.ONE, false)
	for x: float in [-1, 1]:
		for z: float in [-1, 1]:
			var wing := Vector3(0.30 * x, 0.025, 0.27 * z)
			var rotor := Node3D.new()
			rotor.position = wing + Vector3.UP * 0.085
			add_child(rotor)
			_rotors.append(rotor)
			AsterArt.primitive(rotor, "cylinder", Vector3(0.14, 0.062, 0.14), Vector3.ZERO, AsterArt.METAL)
			AsterArt.box(rotor, Vector3(0.32, 0.023, 0.055), Vector3.UP * 0.034, AsterArt.PALE, true)
	_crate = AsterModels.attach(self, &"turret_cartridge", Vector3.DOWN * 0.16, CRATE_SCALE, false)
	_crate.hide()
	global_position = _dock()

func _dock() -> Vector3:
	var pad := AsterTurretKit.DRONE_PAD if _tuning.type == AsterTurretTuning.Type.THRESHER else Vector3(1.33, 0.15, -0.96)
	return _turret.global_position + pad + Vector3.UP * 0.24

func _pickup() -> Vector3:
	return _supply.global_position + _pickup_offset

func _depart(destination: Vector3, next: Flight) -> void:
	flight = next
	_route = PackedVector3Array([
		Vector3(global_position.x, _altitude, global_position.z),
		Vector3(destination.x, _altitude, destination.z),
		destination,
	])
	_waypoint = 0

func _advance(delta: float) -> bool:
	var point := _route[_waypoint]
	var travel := point - global_position
	var horizontal := AsterArt.horizontal(travel)
	if horizontal.length_squared() > 0.045:
		var yaw := atan2(-horizontal.x, -horizontal.z)
		rotation.y = rotate_toward(rotation.y, yaw, delta * 7.0)
	global_position = global_position.move_toward(point, _tuning.drone_speed() * delta)
	if global_position.distance_squared_to(point) < 0.0001:
		_waypoint += 1
	return _waypoint >= _route.size()

func tick(delta: float) -> void:
	if _turret.rebuilding:
		if visible:
			hide()
			payload = 0
			_crate.hide()
			flight = Flight.PARKED
			global_position = _dock()
		return
	show()
	if flight != Flight.PARKED:
		for index in range(_rotors.size()):
			_rotors[index].rotate_y(delta * (17.0 if index % 2 == 0 else -17.0))
	match flight:
		Flight.PARKED:
			if _turret.needs_drone_ammo():
				_depart(_pickup(), Flight.OUTBOUND)
		Flight.OUTBOUND:
			if _advance(delta):
				flight = Flight.LOADING
				_loading = lerpf(0.65, 0.22, float(_tuning.upgrade_level(AsterTurretTuning.Path.DRONE)) / AsterTurretTuning.MAX_LEVEL)
		Flight.LOADING:
			_loading -= delta
			if _loading <= 0.0:
				payload = roundi(_tuning.stat(AsterTurretTuning.Path.DRONE))
				_crate.scale = CRATE_SCALE * lerpf(1.0, 1.58, float(_tuning.upgrade_level(AsterTurretTuning.Path.DRONE)) / AsterTurretTuning.MAX_LEVEL)
				_crate.show()
				_depart(_dock(), Flight.INBOUND)
		Flight.INBOUND:
			if _advance(delta):
				flight = Flight.UNLOADING
		Flight.UNLOADING:
			if _turret.receive_drone_ammo(payload) > 0:
				flights_completed += 1
			payload = 0
			_crate.hide()
			flight = Flight.PARKED
