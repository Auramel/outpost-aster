class_name AsterOutpost
extends Node3D

@export var balance: AsterBalance

var walls: Array[AsterStructure] = []
var turrets: Array[AsterTurret] = []
var dreadnoughts: Array[AsterDreadnought] = []
var turret_tuning: AsterTurretTuning
var turret_tunings: Array[AsterTurretTuning] = []
var core: AsterStructure
var gate: AsterStructure
var supply := Node3D.new()
var tuning_terminal := Node3D.new()
var field_hospital := Node3D.new()
var daylight := AsterDaylight.new()
var nests := PackedVector3Array()

func _build_map() -> void:
	for type in range(AsterTurretTuning.TITLES.size()):
		turret_tunings.append(AsterTurretTuning.new(balance, type))
	turret_tuning = turret_tunings[AsterTurretTuning.Type.THRESHER]
	add_child(daylight)
	var mounts := AsterTerrain.TurretMounts.new()
	nests = AsterTerrain.build(self, mounts)
	_build_base(mounts)
	for anchor in AsterTerrain.bastion_anchors():
		var artillery := AsterDreadnought.new()
		artillery.position = anchor + Vector3(0, AsterTerrain.BASTION_DECK, -1.38)
		add_child(artillery)
		artillery.setup(self, turret_tunings[AsterTurretTuning.Type.DREADNOUGHT])
		dreadnoughts.append(artillery)
	daylight.bind_fixtures(self)

func _build_base(mounts: AsterTerrain.TurretMounts) -> void:
	core = AsterStructure.new()
	core.position = AsterTerrain.BUNKER_GATE
	add_child(core)
	core.setup(balance, "Ворота бункера")
	var section_count := roundi(AsterTerrain.FRONT_HALF_WIDTH * 2.0 / AsterStructure.WALL_LENGTH)
	for slot in range(section_count):
		var lateral := (slot + 0.5) * AsterStructure.WALL_LENGTH - AsterTerrain.FRONT_HALF_WIDTH
		var wall := AsterStructure.new()
		wall.position = Vector3(lateral, 0, AsterTerrain.FRONT_Z)
		add_child(wall)
		var is_gate := slot == 3
		var label := "Ворота периметра" if is_gate else "Секция Ю-%02d" % (slot + 1)
		wall.setup(balance, label, Vector3.BACK, is_gate)
		walls.append(wall)
		if is_gate:
			gate = wall
		if slot in [1, 5]:
			_install_turret(wall.position + Vector3.UP * AsterStructure.WALL_HEIGHT, wall, true)
			AsterTerrain.service_platform(self, wall)
	for slot in [0, 6]:
		var flank := walls[slot]
		_install_turret(flank.position + Vector3.UP * AsterStructure.WALL_HEIGHT, flank)
	_install_turret(gate.position + Vector3.UP * AsterStructure.WALL_HEIGHT, gate)
	AsterTerrain.mark_gate(self, gate.global_position)
	_build_supply()
	_build_specialized_defenses(mounts)
	for index in range(turrets.size()):
		turrets[index].setup_drone(supply, index)
	_build_terminal(tuning_terminal, Vector3(5.76, 0, -10.60), "ТЮНИНГ И ПОДДЕРЖКА", AsterArt.CYAN)
	_build_field_hospital()

func _build_specialized_defenses(mounts: AsterTerrain.TurretMounts) -> void:
	for at in mounts.stingers:
		_install_turret(at, null, false, AsterTurretTuning.Type.STINGER)
	for at in mounts.dragonflies:
		_install_turret(at, null, false, AsterTurretTuning.Type.DRAGONFLY)
	for at in mounts.bulbas:
		_install_turret(at, null, false, AsterTurretTuning.Type.BULBA)

func _install_turret(position_in_yard: Vector3, wall: AsterStructure, direct_ramp := false, type := AsterTurretTuning.Type.THRESHER) -> void:
	var turret := AsterTurret.new()
	turret.position = position_in_yard
	add_child(turret)
	var number := 1
	for placed in turrets:
		if placed.tuning.type == type:
			number += 1
	var title: PackedStringArray = AsterTurretTuning.TITLES[type].split(" ", false, 1)
	turret.setup(self, "%s «%s» · %d" % [title[0], title[1], number], wall, direct_ramp, turret_tunings[type])
	turrets.append(turret)

func _build_supply() -> void:
	supply.name = "Supply"
	supply.position = Vector3(11.0, 0, -10.55)
	add_child(supply)
	AsterArt.collider(supply, Vector3(2.45, 1.30, 1.48), Vector3(0, 0.65, 0), AsterArt.ACCESS | AsterArt.TARGET, supply)
	AsterModels.attach(supply, &"supply")
	AsterArt.lettering(supply, "СКЛАД  /  БОЕПРИПАСЫ", Vector3(0, 1.69, 0.287), 26, AsterArt.AMBER)

func _build_field_hospital() -> void:
	field_hospital.name = "FieldHospital"
	field_hospital.position = Vector3(-7.95, 0, -10.25)
	add_child(field_hospital)
	AsterModels.attach(field_hospital, &"hospital")
	AsterArt.collider(field_hospital, Vector3(3.05, 2.32, 1.65), Vector3(0, 1.16, -0.26), AsterArt.SOLID)
	AsterArt.lettering(field_hospital, "ПОЛЕВОЙ ГОСПИТАЛЬ", Vector3(0, 1.99, 0.68), 26, AsterArt.PALE)

func _build_terminal(station: Node3D, position_in_yard: Vector3, label: String, glow: Color) -> void:
	station.position = position_in_yard
	add_child(station)
	AsterArt.collider(station, Vector3(1.32, 1.22, 0.79), Vector3(0, 0.61, 0), AsterArt.ACCESS | AsterArt.TARGET, station)
	AsterModels.attach(station, &"station")
	var screen := Node3D.new()
	station.add_child(screen)
	screen.position = Vector3(0, 1.05, 0)
	screen.rotation.x = -0.61
	for i in range(3):
		AsterArt.box(screen, Vector3(0.55 - i * 0.12, 0.012, 0.025), Vector3(-0.10, 0.119, -0.096 + i * 0.087), glow, true)
	AsterArt.lettering(station, label, Vector3(0, 1.63, 0), 30, glow, true)
