extends Area3D
class_name SceneTransition

# ==================== EXPORTS ====================

@export_group("Transition Settings")
@export_file("*.tscn") var target_scene: String = ""
@export var spawn_point_name: String = "SpawnPoint"
@export var one_shot: bool = false  # Only trigger once

@export_group("Visual Feedback")
@export var show_prompt: bool = true
@export var prompt_text: String = "Press E to enter"
@export var auto_trigger: bool = false  # Trigger on enter (no button press)

@export_group("Effects")
@export var fade_duration: float = 0.5

# ==================== STATE ====================

var player_in_area: bool = false
var can_trigger: bool = true
var has_triggered: bool = false

# ==================== SIGNALS ====================

signal transition_triggered()

# ==================== INITIALIZATION ====================

func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Validation
	if target_scene.is_empty():
		push_warning("SceneTransition: No target scene set!")
	
	# Set up collision
	collision_layer = 0
	collision_mask = 1  # Player layer
	
	monitoring = true
	monitorable = false

func _process(_delta: float) -> void:
	if player_in_area and not auto_trigger:
		# Check for interaction input
		if Input.is_action_just_pressed("interact") and can_trigger:
			trigger_transition()

# ==================== COLLISION DETECTION ====================

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		
		if show_prompt:
			show_interaction_prompt()
		
		if auto_trigger and can_trigger:
			trigger_transition()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		
		if show_prompt:
			hide_interaction_prompt()

# ==================== TRANSITION ====================

func trigger_transition() -> void:
	"""Trigger the scene transition"""
	if not can_trigger:
		return
	
	if has_triggered and one_shot:
		return
	
	if target_scene.is_empty():
		push_error("SceneTransition: Cannot transition - no target scene set!")
		return
	
	can_trigger = false
	has_triggered = true
	
	print("SceneTransition: Triggering transition to %s" % target_scene)
	transition_triggered.emit()
	
	# Hide prompt
	if show_prompt:
		hide_interaction_prompt()
	
	# Perform transition
	if fade_duration > 0:
		await fade_out()
	
	# Use SceneManager for proper data persistence
	SceneManager.change_scene(target_scene, spawn_point_name)
	
	if fade_duration > 0:
		await get_tree().create_timer(0.1).timeout
		await fade_in()
	
	# Re-enable if not one-shot
	if not one_shot:
		can_trigger = true

# ==================== VISUAL EFFECTS ====================

func show_interaction_prompt() -> void:
	"""Show interaction prompt to player"""
	# TODO: Connect to your UI system
	# Example: UI.show_prompt(prompt_text)
	print("Interaction available: ", prompt_text)

func hide_interaction_prompt() -> void:
	"""Hide interaction prompt"""
	# TODO: Connect to your UI system
	# Example: UI.hide_prompt()
	pass

func fade_out() -> void:
	"""Fade screen to black"""
	# TODO: Implement fade effect
	# Example: TransitionEffect.fade_out(fade_duration)
	await get_tree().create_timer(fade_duration).timeout

func fade_in() -> void:
	"""Fade screen from black"""
	# TODO: Implement fade effect
	# Example: TransitionEffect.fade_in(fade_duration)
	await get_tree().create_timer(fade_duration).timeout

# ==================== DEBUG ====================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if target_scene.is_empty():
		warnings.append("No target scene set. This transition won't work!")
	elif not ResourceLoader.exists(target_scene):
		warnings.append("Target scene does not exist: " + target_scene)
	
	if spawn_point_name.is_empty():
		warnings.append("No spawn point name set. Player will spawn at origin.")
	
	return warnings
