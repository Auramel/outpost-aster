class_name AsterStructure
extends Node3D

signal destroyed(structure: AsterStructure)

const WALL_HEIGHT := 3.18
const WALL_LENGTH := 4.0
const WALL_DEPTH := 3.70
const OUTER_FACE := 0.39
const WALL_CENTER := OUTER_FACE - WALL_DEPTH * 0.5
const INSIDE_CLEARANCE := WALL_DEPTH - OUTER_FACE + 0.74
const GATE_PANEL_DEPTH := 0.78
const CORE_HALF := Vector3(2.62, 0.0, 2.25)

var title: String
var hp: float
var max_hp: float
var is_core: bool
var is_gate := false
var gate_open := false
var blocking := true
var outward := Vector3.ZERO
var ceiling := WALL_HEIGHT
var attacked := 0.0
var support
var status_tag: AsterStatusTag
var _balance: AsterBalance
var _solid: CollisionObject3D
var _body_visual := Node3D.new()
var _damage_visual := Node3D.new()
var _damage_stages: Array[Node3D] = []
var damage_stage := 0
var _rubble := Node3D.new()
var _parapet_bodies: Array[CollisionObject3D] = []
var _gate_lights: Array[MeshInstance3D] = []

func setup(settings: AsterBalance, label: String, direction: Vector3 = Vector3.ZERO, gate: bool = false) -> void:
	_balance = settings
	title = label
	outward = direction
	is_core = direction == Vector3.ZERO
	is_gate = gate
	max_hp = settings.core_hp if is_core else settings.wall_hp
	hp = max_hp
	add_child(_body_visual)
	add_child(_damage_visual)
	add_child(_rubble)
	if is_core:
		_build_core()
	elif is_gate:
		_build_gate()
	else:
		_build_wall()
	if not is_core:
		_damage_stages = AsterWallDamage.build(_damage_visual, is_gate)
	status_tag = AsterStatusTag.new()
	add_child(status_tag)
	var caption := "УЗЕЛ СВЯЗИ" if is_core else title.trim_prefix("Секция ").to_upper()
	status_tag.setup(caption)
	_refresh()

func _build_wall() -> void:
	var size := Vector3(WALL_LENGTH + 0.025, WALL_HEIGHT, WALL_DEPTH)
	_solid = AsterArt.collider(self, size, Vector3(0, WALL_HEIGHT * 0.5, WALL_CENTER), AsterArt.SOLID, self)
	_solid.set_meta(&"footstep_deck", true)
	AsterArt.collider(self, Vector3(3.91, 0.40, WALL_DEPTH + 0.24), Vector3(0, 0.27, WALL_CENTER), AsterArt.TARGET, self, true)
	AsterModels.attach(_body_visual, &"wall")
	_build_parapet(_body_visual)
	AsterModels.attach(_rubble, &"breach", Vector3(0, 0, WALL_CENTER), Vector3(1.0, 1.0, 3.6))
	AsterArt.box(self, Vector3(3.96, 0.095, WALL_DEPTH + 0.15), Vector3(0, 0.044, WALL_CENTER), AsterArt.DARK)

func _build_gate() -> void:
	var half_width := WALL_LENGTH * 0.5
	var lintel_size := Vector3(WALL_LENGTH - 0.018, 0.29, WALL_DEPTH)
	var lintel_center := Vector3(0, WALL_HEIGHT - lintel_size.y * 0.5, WALL_CENTER)
	var lintel := AsterArt.box(self, lintel_size, lintel_center, AsterArt.METAL)
	lintel.material_override = AsterModels.deck_finish()
	AsterArt.collider(self, lintel_size, lintel_center, AsterArt.SOLID, self).set_meta(&"footstep_deck", true)
	_build_parapet(self)
	_solid = AsterArt.collider(self, Vector3(WALL_LENGTH, WALL_HEIGHT, GATE_PANEL_DEPTH), Vector3(0, WALL_HEIGHT * 0.5, 0), AsterArt.SOLID, self)
	AsterArt.collider(self, Vector3(3.91, 0.40, 0.92), Vector3(0, 0.21, 0), AsterArt.TARGET, self, true)
	AsterModels.attach(self, &"gate_frame", Vector3.ZERO, Vector3(1, 0.82, 1))
	AsterModels.attach(_body_visual, &"gate_panels", Vector3.ZERO, Vector3(1, 0.92, 1))
	AsterModels.attach(_rubble, &"breach")
	for side: float in [-1.0, 1.0]:
		var pillar_x := side * (half_width - 0.13)
		var post := Vector3(pillar_x, 1.70, 0)
		AsterArt.collider(self, Vector3(0.26, 3.18, 1.06), post - Vector3.UP * 0.11, AsterArt.SOLID, self)
		_gate_lights.append(AsterArt.box(self, Vector3(0.092, 0.28, 1.126), Vector3(pillar_x, 1.77, 0), AsterArt.AMBER, true))
		var sign_z := OUTER_FACE + 0.22 if side > 0.0 else OUTER_FACE - WALL_DEPTH - 0.16
		var sign := AsterArt.lettering(self, "ВОРОТА  /  E", Vector3(0, 2.79, sign_z), 29, AsterArt.AMBER)
		sign.rotation.y = 0.0 if side > 0.0 else PI

func _build_parapet(visual: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var center := Vector3(side * 1.52, WALL_HEIGHT + 0.245, OUTER_FACE - 0.20)
		var size := Vector3(0.78, 0.49, 0.39)
		var merlon := AsterArt.box(visual, size, center, AsterArt.METAL)
		_parapet_bodies.append(AsterArt.collider(self, size, center, AsterArt.ACCESS))
		merlon.material_override = AsterModels.deck_finish()
		AsterArt.box(visual, Vector3(0.82, 0.083, 0.45), center + Vector3.UP * 0.24, AsterArt.DARK)

func _build_core() -> void:
	ceiling = 4.1
	_solid = AsterArt.collider(self, Vector3(CORE_HALF.x * 2.0, 4.0, CORE_HALF.z * 2.0), Vector3(0, 2, 0), AsterArt.SOLID, self)
	AsterModels.attach(_body_visual, &"relay")
	AsterArt.lettering(self, "01  /  УЗЕЛ СВЯЗИ", Vector3(0, 2.83, 2.33), 27, AsterArt.CYAN)
	AsterArt.box(_damage_visual, Vector3(1.70, 0.12, 0.03), Vector3(0, 3.24, 2.295), AsterArt.RED, true)

func damage(amount: float) -> void:
	if hp <= 0.0:
		return
	attacked = 1.25
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		if not is_core:
			gate_open = false
			_set_blocking(false)
			if is_instance_valid(support):
				support.destroy()
		destroyed.emit(self)
	_refresh()

func repair(amount: float) -> bool:
	if hp >= max_hp or (is_core and hp <= 0.0):
		return false
	hp = minf(max_hp, hp + amount)
	_refresh()
	return true

func tick(delta: float) -> void:
	attacked = maxf(0.0, attacked - delta)
	if not is_core and not gate_open and not blocking and hp >= max_hp * _balance.wall_collision_fraction and _volume_clear():
		_set_blocking(true)
		_refresh()

func _volume_clear() -> bool:
	for actor: Node3D in get_tree().get_nodes_in_group(&"wall_occupants"):
		var point := to_local(actor.global_position)
		var center := 0.0 if is_gate else WALL_CENTER
		var depth := GATE_PANEL_DEPTH if is_gate else WALL_DEPTH
		if absf(point.x) < 2.53 and absf(point.z - center) < depth * 0.5 + 0.58 and point.y < WALL_HEIGHT + 0.04 and point.y > -1.2:
			return false
	return true

func _set_blocking(value: bool) -> void:
	blocking = value
	_solid.set_deferred(&"collision_layer", AsterArt.SOLID if value else 0)
	if not is_gate:
		for merlon in _parapet_bodies:
			merlon.set_deferred(&"collision_layer", AsterArt.ACCESS if value else 0)

func _refresh() -> void:
	var tag_y := WALL_HEIGHT + 0.41
	var warning := ""
	if hp <= 0.0:
		warning = "РАЗРУШЕНО" if is_core else "ПРОЛОМ"
	if is_core:
		tag_y = 4.55
	elif is_gate:
		tag_y = 4.10
		if gate_open:
			warning = "ОТКРЫТЫ"
	elif not blocking:
		tag_y = 0.95
	status_tag.position.y = tag_y
	status_tag.set_values(hp / max_hp, 0.0, warning)
	if not is_core:
		_body_visual.visible = blocking
		_rubble.visible = not blocking and not gate_open
	var fraction := hp / max_hp
	damage_stage = 4 if hp <= 0.0 else 0
	if hp > 0.0:
		if fraction <= 0.27:
			damage_stage = 3
		elif fraction <= 0.55:
			damage_stage = 2
		elif fraction <= 0.83:
			damage_stage = 1
	_damage_visual.visible = blocking and (fraction < 0.65 if is_core else damage_stage > 0)
	for index in range(_damage_stages.size()):
		_damage_stages[index].visible = index < damage_stage
	if is_gate:
		var color := AsterArt.CYAN if gate_open else (AsterArt.AMBER if blocking else AsterArt.RED)
		for lamp in _gate_lights:
			lamp.material_override = AsterArt.material(color, true)

func toggle_gate() -> bool:
	if not is_gate or (not gate_open and not blocking):
		return false
	if gate_open and not _volume_clear():
		return false
	gate_open = not gate_open
	_set_blocking(not gate_open)
	_refresh()
	return true

func gate_hint() -> String:
	if gate_open:
		return "E · Закрыть ворота"
	if blocking:
		return "E · Открыть ворота"
	return repair_hint()

func repair_hint() -> String:
	if hp >= max_hp:
		return "Прочность полная"
	if not is_core and not blocking:
		if hp >= max_hp * _balance.wall_collision_fraction:
			return "Освободите секцию для возврата коллизии"
		return "2 · Ремкомплект   ЛКМ · Восстановить ворота" if is_gate else "2 · Ремкомплект   ЛКМ · Восстановить секцию"
	return "2 · Ремкомплект   ЛКМ · Ремонт"
