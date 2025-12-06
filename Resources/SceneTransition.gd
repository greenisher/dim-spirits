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
@export var fade_duration: float = 0.0  # Set to 0 by default (no fade)

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
	# Support both "Player" and "player" groups
	if body.is_in_group("Player") or body.is_in_group("player"):
		player_in_area = true
		
		if show_prompt:
			show_interaction_prompt()
		
		if auto_trigger and can_trigger:
			trigger_transition()

func _on_body_exited(body: Node3D) -> void:
	# Support both "Player" and "player" groups
	if body.is_in_group("Player") or body.is_in_group("player"):
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
	
	# Optional: Fade out BEFORE scene change
	if fade_duration > 0 and has_node("/root/TransitionScreen"):
		# Use persistent TransitionScreen autoload if available
		await TransitionScreen.fade_out(fade_duration)
	
	# Change scene
	# NOTE: After this line, this node will be DESTROYED as part of the old scene!
	# DO NOT PUT ANY CODE AFTER THIS that uses this node!
	SceneManager.change_scene(target_scene, spawn_point_name)
	
	# ❌ NOTHING AFTER SceneManager.change_scene() ❌
	# The node is destroyed when the scene changes!
	# Any code here will cause "get_tree() is null" crash!

# ==================== VISUAL EFFECTS ====================

func show_interaction_prompt() -> void:
	"""Show interaction prompt to player"""
	# TODO: Connect to your UI system
	print("Interaction available: ", prompt_text)

func hide_interaction_prompt() -> void:
	"""Hide interaction prompt"""
	# TODO: Connect to your UI system
	pass

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
