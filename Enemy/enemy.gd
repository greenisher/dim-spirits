extends CharacterBody3D

const RUN_VELOCITY_THRESHOLD := 2.0

var attack_animation: Array = ['light_attack', 'heavy_attack']
var gravity: float = ProjectSettings.get_setting('physics/3d/default_gravity')
var velocity_target := Vector3.ZERO

@export var max_health: float = 10.0
@export var enemy_speed := 3.0
@export var xp_value: int = 10
@export var crit_rate := 0.05

@onready var enemy_rig: Node3D = $EnemyRig
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var player_detector: ShapeCast3D = $EnemyRig/Skeleton_Minion/PlayerDetector
@onready var attack_area: ShapeCast3D = $EnemyRig/Skeleton_Minion/AreaAttack
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

@onready var player: Player = get_tree().get_first_node_in_group('Player')

func _ready() -> void:
	health_component.update_max_health(max_health)

func _physics_process(delta: float) -> void:
	navigation_agent_3d.target_position = player.global_position
	
	if is_on_floor():
		velocity_target = Vector3.ZERO
		if enemy_rig.is_idle():
			check_for_player()
			if not navigation_agent_3d.is_target_reached():
				velocity_target = get_local_navigation_direction() * enemy_speed
				orient_rig(navigation_agent_3d.get_next_path_position())
	else:
		velocity_target.y -= gravity * delta
	navigation_agent_3d.velocity = velocity_target

func check_for_player() -> void:
	for collision_id in player_detector.get_collision_count():
		var collider = player_detector.get_collider(collision_id)
		if collider is Player:
			enemy_rig.travel(attack_animation.pick_random())
			navigation_agent_3d.avoidance_mask = 0
	
func _on_health_component_defeat() -> void:
	print("I'm die thank you forever")
	player.stats.xp += xp_value
	enemy_rig.travel("Death_A") 
	collision_shape_3d.disabled = true
	set_physics_process(false)
	navigation_agent_3d.target_position = global_position
	navigation_agent_3d.velocity = Vector3.ZERO

func _on_rig_heavy_attack() -> void:
	attack_area.deal_damage(10.0, crit_rate)
	navigation_agent_3d.avoidance_mask = 1

func _on_rig_light_attack() -> void:
	attack_area.deal_damage(5.0, crit_rate)
	navigation_agent_3d.avoidance_mask = 1 
	
func orient_rig(target_position: Vector3) -> void:
	target_position.y = player.global_position.y
	if enemy_rig.global_position.is_equal_approx(target_position):
		return
	enemy_rig.look_at(target_position, Vector3.UP, true)

func get_local_navigation_direction() -> Vector3:
	var destination = navigation_agent_3d.get_next_path_position()
	var local_destination = destination - global_position
	return local_destination.normalized()


func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if safe_velocity.length() > RUN_VELOCITY_THRESHOLD:
		enemy_rig.run_weight_target = 1.0
	else:
		enemy_rig.run_weight_target = 0.0
	velocity = safe_velocity
	move_and_slide()
