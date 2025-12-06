extends Node3D
class_name BossRig

## Animation controller for bosses
## Emits signals at key animation points for attack timing

signal attack_windup_complete()   ## Windup phase ended, hitbox should activate
signal attack_active_complete()   ## Active phase ended, hitbox should deactivate
signal attack_recovery_complete() ## Full attack finished
signal combo_complete()           ## All attacks in combo finished
signal phase_transition_complete()
signal death_complete()
signal stagger_complete()

@export_category("Animation")
@export var animation_speed: float = 1.0

@export_category("Node Paths")
@export var animation_tree_path: NodePath
@export var skeleton_path: NodePath

var animation_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var skeleton: Skeleton3D

## Current state tracking
var current_attack: BossAttack = null
var _attack_timer: float = 0.0
var _attack_phase: int = 0  ## 0=idle, 1=windup, 2=active, 3=recovery

## Movement blend
var run_path: String = 'parameters/MoveSpace/blend_position'
var run_weight_target := 0.0


func _ready() -> void:
	# Get nodes from paths or find them automatically
	if animation_tree_path:
		animation_tree = get_node(animation_tree_path)
	else:
		animation_tree = _find_animation_tree(self)
	
	if animation_tree:
		playback = animation_tree['parameters/playback']
		animation_tree.animation_finished.connect(_on_animation_finished)
	
	if skeleton_path:
		skeleton = get_node(skeleton_path)
	else:
		skeleton = _find_skeleton(self)


func _find_animation_tree(node: Node) -> AnimationTree:
	for child in node.get_children():
		if child is AnimationTree:
			return child
		var result = _find_animation_tree(child)
		if result:
			return result
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	for child in node.get_children():
		if child is Skeleton3D:
			return child
		var result = _find_skeleton(child)
		if result:
			return result
	return null


func _physics_process(delta: float) -> void:
	# Handle movement blend
	if animation_tree and run_path in animation_tree:
		animation_tree[run_path] = move_toward(
			animation_tree[run_path],
			run_weight_target,
			delta * 10.0
		)
	
	# Handle attack timing
	_process_attack_timing(delta)


func _process_attack_timing(delta: float) -> void:
	if current_attack == null or _attack_phase == 0:
		return
	
	_attack_timer -= delta
	
	if _attack_timer <= 0:
		match _attack_phase:
			1:  # Windup complete
				_attack_phase = 2
				_attack_timer = current_attack.active_time
				attack_windup_complete.emit()
			2:  # Active complete
				_attack_phase = 3
				_attack_timer = current_attack.recovery_time
				attack_active_complete.emit()
			3:  # Recovery complete
				_attack_phase = 0
				current_attack = null
				attack_recovery_complete.emit()


## Start an attack animation with timing
func execute_attack(attack: BossAttack) -> void:
	current_attack = attack
	_attack_phase = 1
	_attack_timer = attack.get_actual_windup()
	
	# Travel to animation state
	if playback and attack.animation_name != "":
		playback.travel(attack.animation_name)
	
	animation_tree.set("parameters/TimeScale/scale", animation_speed)


## Play a specific animation state
func travel(animation_name: String) -> void:
	if playback:
		playback.travel(animation_name)


## Update movement animation blend
func set_movement_weight(weight: float) -> void:
	run_weight_target = weight


## Check current state
func is_idle() -> bool:
	if not playback:
		return true
	var current = playback.get_current_node()
	return current == 'MoveSpace' or current == 'Idle'


func is_attacking() -> bool:
	return _attack_phase > 0


func is_in_windup() -> bool:
	return _attack_phase == 1


func is_attack_active() -> bool:
	return _attack_phase == 2


func is_in_recovery() -> bool:
	return _attack_phase == 3


func get_current_animation() -> String:
	if playback:
		return playback.get_current_node()
	return ""


## Interrupt current attack (for stagger)
func interrupt_attack() -> void:
	if _attack_phase > 0:
		_attack_phase = 0
		current_attack = null
		travel("Stagger")


func play_death() -> void:
	_attack_phase = 0
	current_attack = null
	travel("Death")


func play_phase_transition() -> void:
	_attack_phase = 0
	current_attack = null
	travel("PhaseTransition")


func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Death":
			death_complete.emit()
		"PhaseTransition":
			phase_transition_complete.emit()
		"Stagger":
			stagger_complete.emit()
