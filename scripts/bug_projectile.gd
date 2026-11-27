class_name AsterBugProjectile
extends Node3D

const GRAVITY := 16.0
const QUILL_SPEED := 34.0
const COVER := AsterArt.SOLID | AsterArt.ACCESS | AsterArt.TARGET

var _game: Node
var _velocity := Vector3.ZERO
var _damage := 0.0
var _radius := 0.0
var _left := 0.0
var _source: RID

static func flight_time(origin: Vector3, target: Vector3) -> float:
	return 0.82 + AsterArt.horizontal(target - origin).length() / 20.0

static func rock_velocity(origin: Vector3, target: Vector3, duration: float) -> Vector3:
	return (target - origin) / duration + Vector3.UP * (GRAVITY * duration * 0.5)

func launch_rock(game: Node, source: AsterBug, origin: Vector3, target: Vector3) -> void:
	_game = game
	_source = source.get_rid()
	global_position = origin
	var settings: AsterBalance = game.balance
	_damage = settings.catapult_damage
	_radius = settings.catapult_radius
	var duration := flight_time(origin, target)
	_left = duration + 2.0
	_velocity = rock_velocity(origin, target, duration)
	AsterModels.attach(self, &"bug_rock", Vector3.DOWN * 0.21, Vector3.ONE * 0.56)

func launch_quill(game: Node, source: AsterBug, origin: Vector3, target: Vector3) -> void:
	_game = game
	_source = source.get_rid()
	global_position = origin
	var settings: AsterBalance = game.balance
	_damage = settings.shooter_damage
	_left = (settings.shooter_range + 2.0) / QUILL_SPEED
	_velocity = (target - origin).normalized() * QUILL_SPEED
	look_at(origin + _velocity, Vector3.RIGHT if absf(_velocity.normalized().y) > 0.95 else Vector3.UP)
	AsterModels.attach(self, &"bug_quill", Vector3.ZERO, Vector3.ONE, false)

func _physics_process(delta: float) -> void:
	if _game.lost:
		queue_free()
		return
	_left -= delta
	var gravity := Vector3.DOWN * (GRAVITY if _radius > 0.0 else 0.0)
	var ahead := global_position + _velocity * delta + gravity * delta * delta * 0.5
	_velocity += gravity * delta
	var layers := COVER | AsterArt.PLAYER
	if _radius > 0.0:
		layers |= AsterArt.ENEMY
	var query := PhysicsRayQueryParameters3D.create(global_position, ahead, layers, [_source])
	query.collide_with_areas = true
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and hit.collider is Area3D:
		var marker := AsterArt.hit_target(hit.collider)
		if not ((marker is AsterStructure and not marker.blocking) or (marker is AsterTurret and marker.hp <= 0.0)):
			break
		var excluded := query.exclude
		excluded.append(hit.rid)
		query.exclude = excluded
		hit = space.intersect_ray(query)
	if hit.is_empty():
		global_position = ahead
		if _radius > 0.0:
			rotate_object_local(Vector3(0.8, 0.2, 0.56).normalized(), delta * 7.4)
		if _left <= 0.0:
			queue_free()
		return
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if _radius > 0.0:
		_game.effects.artillery_impact(point, normal)
		_game.dust.artillery(point)
		_game.sound.artillery(point, 0.77)
		_game.bug_blast(point, _damage, _radius, true)
	else:
		var obstacle: CollisionObject3D = hit.collider
		var victim: Node = obstacle if obstacle is AsterPlayer else AsterArt.hit_target(obstacle)
		if victim is AsterPlayer or victim is AsterStructure or victim is AsterTurret:
			victim.damage(_damage)
		_game.projectile_impact(point, normal)
	queue_free()
