extends Node3D

signal enemy_heavy_attack
signal enemy_light_attack

@export var animation_speed: float = 20.0

@onready var animation_tree: AnimationTree = $Militia_Enemy/Node/AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree['parameters/playback']
@onready var skeleton_3d: Skeleton3D = $Militia_Enemy/Node/Skeleton3D

var run_path: String = 'parameters/MoveSpace/blend_position' 
var run_weight_target := -1.0

func _ready() -> void:
	if animation_tree:
		animation_tree.animation_finished.connect(_on_animation_tree_animation_finished)

func _physics_process(delta: float) -> void:
	animation_tree[run_path] = move_toward(
		animation_tree[run_path],
		run_weight_target,
		delta * animation_speed
	)
	
func update_animation_tree(direction: Vector3) -> void:
	if direction.is_zero_approx():
		run_weight_target = -1.0
	else:
		run_weight_target = 1.0

func travel(animation_name: String) -> void:
	playback.travel(animation_name)
	
func is_idle() -> bool:
	return playback.get_current_node() == 'MoveSpace'

func is_slashing() -> bool:
	return playback.get_current_node() == 'light_attack'
	
func is_overhead() -> bool:
	return playback.get_current_node() == 'heavy_attack'
	
func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	# Use the actual animation clip names from your AnimationPlayer
	if anim_name == 'StandingMeleeAttackDownward':
		enemy_light_attack.emit()
	elif anim_name == 'StandingMeleeAttack360High':
		enemy_heavy_attack.emit()
