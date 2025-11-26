extends Node3D

signal heavy_attack
signal light_attack

@export var animation_speed: float = 20.0

@onready var animation_tree: AnimationTree = $AuxScene2/AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree['parameters/playback']
@onready var skeleton_3d: Skeleton3D = $AuxScene2/Node/Skeleton3D

var run_path: String = 'parameters/MoveSpace/blend_position' 
var run_weight_target := -1.0

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
	return playback.get_current_node() == 'Light_Attack'

func is_overhead() -> bool:
	return playback.get_current_node() == 'Heavy_Attack'
	
func is_dashing() -> bool:
	return playback.get_current_node() == 'FastRun'

func is_rolling() -> bool:
	return playback.get_current_node() == 'Roll'

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if anim_name == 'Heavy_Attack':
		heavy_attack.emit() 
	elif anim_name == 'Light_Attack':
		light_attack.emit()
