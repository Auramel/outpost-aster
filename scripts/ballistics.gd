class_name AsterBallistics
extends Node3D

const RIFLE_SPEED := 145.0
const TURRET_SPEED := 162.0
const GAUSS_SPEED := 365.0
const MAX_ROUNDS := 256
const ROCKET_GRAVITY := 42.0
const MAX_CASES := 96
const CASE_LIFE := 2.9

class Round:
	var position: Vector3
	var direction: Vector3
	var remaining: float
	var damage: float
	var heavy: bool
	var blast_radius: float
	var velocity := Vector3.ZERO
	var trail_left := 0.0
	var gauss := false

class Casing:
	var position: Vector3
	var velocity: Vector3
	var floor_height: float
	var angle := 0.0
	var spin: float
	var size: float
	var life := CASE_LIFE

var _rounds: Array[Round] = []
var _cases: Array[Casing] = []
var _free_rounds: Array[Round] = []
var _free_cases: Array[Casing] = []
var _round_mesh: MultiMesh
var _case_mesh: MultiMesh
var _gauss_mesh: MultiMesh
var _game: Node

func setup(game: Node) -> void:
	_game = game
	var streak := BoxMesh.new()
	streak.size = Vector3(0.022, 0.022, 0.86)
	streak.material = AsterArt.material(Color("#ffe49b"), true)
	_round_mesh = _batch(streak, MAX_ROUNDS)
	var needle := BoxMesh.new()
	needle.size = Vector3(0.030, 0.030, 2.8)
	needle.material = AsterArt.material(Color("#c2f4ff"), true)
	_gauss_mesh = _batch(needle, MAX_ROUNDS)
	var brass := CylinderMesh.new()
	brass.height = 0.11
	brass.top_radius = 0.022
	brass.bottom_radius = 0.025
	brass.radial_segments = 6
	brass.rings = 1
	var alloy := StandardMaterial3D.new()
	alloy.albedo_color = Color("#c38c4b")
	alloy.metallic = 0.53
	alloy.roughness = 0.43
	brass.material = alloy
	_case_mesh = _batch(brass, MAX_CASES)

func _batch(mesh: Mesh, limit: int) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = limit
	batch.visible_instance_count = 0
	var renderer := MultiMeshInstance3D.new()
	renderer.multimesh = batch
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(renderer)
	return batch

func fire(origin: Vector3, direction: Vector3, distance: float, damage: float, heavy: bool, port: Vector3, ejection: Vector3, blast_radius := 0.0, gauss := false) -> void:
	var bullet := _new_round(origin, direction, distance, damage, heavy, blast_radius)
	bullet.velocity = Vector3.ZERO
	bullet.gauss = gauss
	if blast_radius <= 0.0 and not gauss:
		_eject(port, ejection, heavy)

static func rocket_duration(origin: Vector3, target: Vector3) -> float:
	var distance := AsterArt.horizontal(target - origin).length()
	return clampf(1.08 + distance * 0.019, 1.36, 3.65)

static func rocket_velocity(origin: Vector3, target: Vector3) -> Vector3:
	var duration := rocket_duration(origin, target)
	return (target - origin) / duration + Vector3.UP * (ROCKET_GRAVITY * duration * 0.5)

func fire_rocket(origin: Vector3, target: Vector3, damage: float, radius: float) -> Vector3:
	var velocity := rocket_velocity(origin, target)
	var rocket := _new_round(origin, velocity, rocket_duration(origin, target), damage, true, radius)
	rocket.velocity = velocity
	rocket.gauss = false
	rocket.trail_left = 0.0
	return velocity

func _new_round(origin: Vector3, direction: Vector3, remaining: float, damage: float, heavy: bool, blast_radius: float) -> Round:
	var bullet: Round
	if _rounds.size() == MAX_ROUNDS:
		bullet = _rounds.pop_front()
	elif _free_rounds.is_empty():
		bullet = Round.new()
	else:
		bullet = _free_rounds.pop_back()
	bullet.position = origin
	bullet.direction = direction.normalized()
	bullet.remaining = remaining
	bullet.damage = damage
	bullet.heavy = heavy
	bullet.blast_radius = blast_radius
	_rounds.append(bullet)
	return bullet

func _eject(port: Vector3, ejection: Vector3, heavy: bool) -> void:
	var casing: Casing
	if _cases.size() == MAX_CASES:
		casing = _cases.pop_front()
	elif _free_cases.is_empty():
		casing = Casing.new()
	else:
		casing = _free_cases.pop_back()
	casing.position = port
	casing.velocity = ejection.normalized() * randf_range(1.55, 2.6) + Vector3.UP * randf_range(1.25, 2.35)
	var settle_point := port + ejection.normalized() * 0.73
	var floor_hit := AsterArt.ray(get_world_3d(), settle_point, settle_point - Vector3.UP * 12.0, AsterArt.SOLID | AsterArt.ACCESS)
	casing.floor_height = float(floor_hit.position.y) + 0.045 if not floor_hit.is_empty() else -3.0
	casing.angle = randf_range(-PI, PI)
	casing.spin = randf_range(11.0, 23.0)
	casing.size = 1.0 if heavy else 0.68
	casing.life = CASE_LIFE
	_cases.append(casing)

func tick(delta: float) -> void:
	var world := get_world_3d()
	for index in range(_rounds.size() - 1, -1, -1):
		var bullet := _rounds[index]
		var speed := GAUSS_SPEED if bullet.gauss else TURRET_SPEED if bullet.heavy else RIFLE_SPEED
		var rocket := bullet.velocity != Vector3.ZERO
		var step := minf(bullet.remaining, delta if rocket else speed * delta)
		var endpoint := bullet.position + bullet.direction * step
		if rocket:
			endpoint = bullet.position + bullet.velocity * step - Vector3.UP * (0.5 * ROCKET_GRAVITY * step * step)
			bullet.velocity.y -= ROCKET_GRAVITY * step
			bullet.direction = bullet.velocity.normalized()
			bullet.trail_left -= delta
			if bullet.trail_left <= 0.0:
				_game.effects.rocket_trail(bullet.position)
				bullet.trail_left = 0.075
		var mask := AsterArt.SOLID | AsterArt.ENEMY
		if not bullet.heavy:
			mask |= AsterArt.ACCESS
		var hit := AsterArt.ray(world, bullet.position, endpoint, mask)
		if not hit.is_empty():
			if bullet.blast_radius > 0.0:
				_game.artillery_impact(hit.position, hit.normal, bullet.damage, bullet.blast_radius, rocket)
			elif hit.collider is AsterBug and hit.collider.hp > 0.0:
				hit.collider.damage(bullet.damage, hit.position, hit.normal)
				if not bullet.heavy and _game.player.alive:
					_game.player.hit_flash = 0.16
					_game.sound.play(&"hit")
			elif not hit.collider is AsterBug:
				_game.projectile_impact(hit.position, hit.normal)
			_free_rounds.append(bullet)
			_rounds.remove_at(index)
		else:
			bullet.position = endpoint
			bullet.remaining -= step
			if bullet.remaining <= 0.0:
				if bullet.blast_radius > 0.0:
					_game.artillery_impact(endpoint, -bullet.direction, bullet.damage, bullet.blast_radius, rocket)
				_free_rounds.append(bullet)
				_rounds.remove_at(index)

	for index in range(_cases.size() - 1, -1, -1):
		var casing := _cases[index]
		casing.life -= delta
		if casing.life <= 0.0:
			_free_cases.append(casing)
			_cases.remove_at(index)
			continue
		if casing.spin > 0.0:
			casing.velocity.y -= 13.0 * delta
			casing.position += casing.velocity * delta
			casing.angle += casing.spin * delta
			if casing.position.y < casing.floor_height and casing.velocity.y < 0.0:
				casing.position.y = casing.floor_height
				casing.velocity *= Vector3(0.64, -0.24, 0.64)
				casing.spin *= 0.42
				if casing.velocity.y < 0.41:
					casing.angle = PI * 0.5
					casing.spin = 0.0

func _process(_delta: float) -> void:
	var regular := 0
	var gauss := 0
	for bullet in _rounds:
		var up := Vector3.UP if absf(bullet.direction.y) < 0.98 else Vector3.RIGHT
		var basis := Basis.looking_at(bullet.direction, up)
		if bullet.gauss:
			_gauss_mesh.set_instance_transform(gauss, Transform3D(basis, bullet.position - bullet.direction * 1.15))
			gauss += 1
			continue
		var size := Vector3(4.2, 4.2, 2.5) if bullet.blast_radius > 0.0 else Vector3.ONE if bullet.heavy else Vector3(0.70, 0.70, 0.78)
		if bullet.velocity != Vector3.ZERO:
			size = Vector3(2.9, 2.9, 1.6)
		_round_mesh.set_instance_transform(regular, Transform3D(basis.scaled_local(size), bullet.position - bullet.direction * 0.35))
		regular += 1
	_round_mesh.visible_instance_count = regular
	_gauss_mesh.visible_instance_count = gauss
	for index in range(_cases.size()):
		var casing := _cases[index]
		var size := casing.size * minf(1.0, casing.life / 0.36)
		_case_mesh.set_instance_transform(index, Transform3D(Basis(Vector3.FORWARD, casing.angle).scaled(Vector3.ONE * size), casing.position))
	_case_mesh.visible_instance_count = _cases.size()
