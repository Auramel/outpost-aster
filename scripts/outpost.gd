class_name AsterOutpost
extends Node3D

@export var balance: AsterBalance

var walls: Array[AsterStructure] = []
var turrets: Array[AsterTurret] = []
var turret_tuning: AsterTurretTuning
var core: AsterStructure
var gate: AsterStructure
var supply := Node3D.new()
var rifle_terminal := Node3D.new()
var tuning_terminal := Node3D.new()

func _build_map() -> void:
	turret_tuning = AsterTurretTuning.new(balance)
	AsterTerrain.build(self)
	_build_base()

func _build_base() -> void:
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
		if slot in [1, 4]:
			_install_turret(wall.position + Vector3.UP * AsterStructure.WALL_HEIGHT, wall, true)
			AsterTerrain.service_platform(self, wall)
	for slot in [0, 5]:
		var flank := walls[slot]
		_install_turret(flank.position + Vector3.UP * AsterStructure.WALL_HEIGHT, flank)
	AsterTerrain.mark_gate(self, gate.global_position)
	_build_supply()
	_build_terminal(rifle_terminal, Vector3(3.35, 0, 4.55), "ТЮНИНГ АВТОМАТА", AsterArt.CYAN)
	_build_terminal(tuning_terminal, Vector3(-3.35, 0, 5.95), "ТЮНИНГ ТУРЕЛЕЙ", AsterArt.AMBER)
	for i in range(12):
		var marker := AsterArt.box(self, Vector3(0.16, 0.012, 0.48), Vector3(-3.6, 0.009, -4.6 + i * 0.93), AsterArt.PALE)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(5):
		AsterArt.box(self, Vector3(0.20, 0.012, 0.65), Vector3(2.93, 0.009, 2.3 + i), AsterArt.AMBER)

func _install_turret(position_in_yard: Vector3, wall: AsterStructure, direct_ramp := false) -> void:
	var turret := AsterTurret.new()
	turret.position = position_in_yard
	add_child(turret)
	turret.setup(self, "Т%d" % (turrets.size() + 1), wall, direct_ramp)
	turrets.append(turret)

func _build_supply() -> void:
	supply.name = "Supply"
	supply.position = Vector3(-8.65, 0, 2.70)
	add_child(supply)
	AsterArt.collider(supply, Vector3(2.45, 1.30, 1.48), Vector3(0, 0.65, 0), AsterArt.ACCESS | AsterArt.TARGET, supply)
	AsterModels.attach(supply, &"supply")
	AsterArt.lettering(supply, "СКЛАД  /  БОЕПРИПАСЫ", Vector3(0, 1.69, 0.287), 26, AsterArt.AMBER)

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
