class_name AsterBalance
extends Resource

@export_group("Игрок")
@export var player_hp: float = 100.0
@export var player_speed: float = 6.3
@export var sprint_speed_factor: float = 1.54
@export var crouch_speed_factor: float = 0.56
@export var jump_speed: float = 5.5
@export var rifle_magazine: int = 100
@export var rifle_reserve: int = 500
@export var rifle_damage: float = 24.0
@export var rifle_rate: float = 9.0
@export var rifle_range: float = 65.0
@export var rifle_reload: float = 1.25
@export_range(40.0, 105.0, 1.0) var hip_fov: float = 79.0
@export_range(30.0, 79.0, 1.0) var aim_fov: float = 55.0
@export_range(0.3, 1.0, 0.01) var aim_speed_factor: float = 0.78
@export_range(0.3, 1.0, 0.01) var aim_sensitivity_factor: float = 0.71
@export var repair_range: float = 4.1
@export var repair_rate: float = 29.0
@export var use_range: float = 3.25
@export var hospital_heal_rate: float = 15.0

@export_group("База")
@export var wall_hp: float = 220.0
@export var wall_collision_fraction: float = 0.36
@export var core_hp: float = 680.0
@export var turret_hp: float = 185.0
@export var turret_capacity: int = 1000
@export var turret_start_rounds: int = 900
@export var turret_rate: float = 7.2
@export var turret_damage: float = 14.0
@export var turret_range: float = 38.0
@export var turret_turn_speed: float = 5.2

@export_group("Тюнинг")
@export var rate_gain: float = 27.6
@export var damage_gain: float = 42.0
@export var range_gain: float = 82.0
@export var capacity_gain: int = 5400
@export var drone_first_payload: int = 100
@export var drone_payload_gain: int = 1200
@export var drone_first_speed: float = 8.5
@export var drone_speed_gain: float = 37.5
@export_range(0.0, 1.0) var stability_gain: float = 0.81
@export var upgrade_price_step: int = 36
@export var rifle_rate_gain: float = 5.0
@export var rifle_damage_gain: float = 22.0
@export var rifle_accuracy_gain: float = 0.70
@export var rifle_recoil_reduction: float = 0.65

@export_group("Жуки и осада")
@export var ground_hp: float = 156.0
@export var climber_hp: float = 57.0
@export var ground_speed: float = 3.75
@export var climber_speed: float = 5.4
@export var climb_speed: float = 3.3
@export var ground_damage: float = 14.0
@export var climber_damage: float = 17.0
@export var flyer_hp: float = 94.0
@export var flyer_speed: float = 7.6
@export var flyer_damage: float = 18.0
@export var bug_attack_period: float = 0.88
@export_range(1, 80) var active_limit: int = 80
@export_range(1, 80) var assault_opening_population: int = 9
@export var assault_ramp_time: float = 300.0
@export var assault_opening_interval: float = 1.30
@export var assault_peak_interval: float = 1.0
@export var assault_clear_delay: float = 2.0
@export var combat_points_per_kill: int = 15

@export_group("Спецжуки")
@export var special_start: float = 45.0
@export var special_ramp_time: float = 660.0
@export_range(0.0, 1.0) var special_peak_chance: float = 0.19
@export var tank_start: float = 285.0
@export var tank_hp: float = 650.0
@export var tank_armor: float = 0.46
@export var tank_speed: float = 2.1
@export var tank_damage: float = 9.0
@export var catapult_hp: float = 185.0
@export var catapult_armor: float = 0.14
@export var catapult_speed: float = 3.4
@export var catapult_damage: float = 29.0
@export var catapult_range: float = 46.0
@export var catapult_radius: float = 4.0
@export var catapult_period: float = 7.5
@export var kamikaze_hp: float = 48.0
@export var kamikaze_speed: float = 12.4
@export var kamikaze_damage: float = 60.0
@export var kamikaze_radius: float = 3.5
@export var transporter_hp: float = 250.0
@export var transporter_armor: float = 0.15
@export var transporter_speed: float = 8.0
@export var ram_hp: float = 315.0
@export var ram_armor: float = 0.30
@export var ram_speed: float = 3.2
@export var ram_charge_speed: float = 10.2
@export var ram_damage: float = 54.0
@export var shooter_hp: float = 162.0
@export var shooter_armor: float = 0.13
@export var shooter_range: float = 18.0
@export var shooter_damage: float = 15.0
@export var shooter_period: float = 2.1

@export_group("Партия")
@export var respawn_points: int = 5
@export var respawn_delay: float = 5.0

func tuning_price(base_price: int, rank: int) -> int:
	var previous_price := roundi((base_price + upgrade_price_step * rank) * 0.8)
	return roundi(previous_price * 1.3)
