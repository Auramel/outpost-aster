class_name AsterAmmoDrone
extends Node3D

enum Flight { PARKED, OUTBOUND, LOADING, INBOUND, UNLOADING }

var flight := Flight.PARKED
var payload := 0
var flights_completed := 0
var _turret: Node3D
var _supply: Node3D
var _tuning: AsterTurretTuning
var _altitude := 7.5
var _pickup_offset := 0.0
var _route := PackedVector3Array()
var _waypoint := 0
var _loading := 0.0
var _rotors: Array[Node3D] = []
var _crate: MeshInstance3D

func setup(turret: Node3D, supply: Node3D) -> void:
	_turret = turret
	_supply = supply
	_tuning = turret.tuning
	_altitude = maxf(_altitude, turret.global_position.y + 3.2)
	var side := 1.0 if turret.global_position.x > 0.0 else -1.0
	_altitude += (0.65 if side > 0.0 else 0.0) + (0.0 if turret.direct_ramp else 1.3)
	_pickup_offset = side * (0.34 if turret.direct_ramp else 0.99)
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
	_crate = AsterArt.box(self, Vector3(0.29, 0.16, 0.29), Vector3.DOWN * 0.165, AsterArt.AMBER)
	_crate.hide()
	global_position = _dock()

func _dock() -> Vector3:
	return _turret.global_position + AsterTurretKit.DRONE_PAD + Vector3.UP * 0.24

func _pickup() -> Vector3:
	return _supply.global_position + Vector3(_pickup_offset, 1.81, -0.20)

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
				_loading = lerpf(0.65, 0.22, float(_tuning.upgrade_level(AsterTurretTuning.Path.DRONE) - 1) / (AsterTurretTuning.MAX_LEVEL - 1))
		Flight.LOADING:
			_loading -= delta
			if _loading <= 0.0:
				payload = roundi(_tuning.stat(AsterTurretTuning.Path.DRONE))
				_crate.scale = Vector3.ONE * lerpf(1.0, 1.58, float(_tuning.upgrade_level(AsterTurretTuning.Path.DRONE) - 1) / (AsterTurretTuning.MAX_LEVEL - 1))
				_crate.show()
				_depart(_dock(), Flight.INBOUND)
		Flight.INBOUND:
			if _advance(delta):
				flight = Flight.UNLOADING
		Flight.UNLOADING:
			if _turret.service == &"":
				if _turret.receive_drone_ammo(payload) > 0:
					flights_completed += 1
				payload = 0
				_crate.hide()
				flight = Flight.PARKED
