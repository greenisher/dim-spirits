extends Node3D
class_name PickupSpell

@export var spell: Spell
@export var auto_pickup: bool = false

@export var rotation_speed: float = 0.5
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.3

# ==================== PERSISTENCE ====================

## Unique ID for this pickup spell 
@export var unique_id: String = ""

## Auto-generate ID from position if not set
@export var auto_generate_id: bool = true

@onready var interaction_area: Area3D = $InteractionArea
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_prompt: Label3D = $InteractionPrompt
@onready var visual_effect: Node3D = $VisualEffect  

var player_in_range: bool = false

func _ready() -> void:
	if unique_id.is_empty() and auto_generate_id:
		_generate_unique_id()
	
	# Check if this spell was already picked up
	if _was_already_picked_up():
		print("Spell '%s' was already picked up, removing from scene" % unique_id)
		queue_free()
		return
	
	# Setup interactions
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	
	if interaction_prompt:
		interaction_prompt.visible = false
		if spell:
			interaction_prompt.text = "Press Enter to learn %s" % spell.spell_name
	
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# Rotate spell
	rotate_y(delta * rotation_speed)
	
	# Bob up and down
	var bob_amount = sin(Time.get_ticks_msec() * 0.001 * bob_speed) * bob_height
	if mesh_instance:
		mesh_instance.position.y = bob_amount
	
	# Show/hide prompt
	if interaction_prompt:
		interaction_prompt.visible = player_in_range and not auto_pickup

func _process(_delta: float) -> void:
	if player_in_range and not auto_pickup:
		if Input.is_action_just_pressed("interact"):
			pickup()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_in_range = true
		if auto_pickup:
			pickup()

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_in_range = false

func pickup() -> void:
	if not spell:
		queue_free()
		return
	
	# Find player
	var player = _find_player()
	if not player:
		print("Could not find player to add spell to")
		queue_free()
		return
	
	# Try to add spell to player's collection
	var added = _add_spell_to_player(player)
	
	if added:
		print("Learned spell: %s" % spell.spell_name)
		
		# Show visual feedback
		_play_pickup_effect()
		
		# Mark as picked up in GameState
		_mark_as_picked_up()
		
		# Remove from scene
		queue_free()
	else:
		print("Spell already known: %s" % spell.spell_name)

func _find_player() -> Player:
	"""Find the player node"""
	# Method 1: Check the body that entered
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			return body
	
	# Method 2: Search for player in scene
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		return players[0]
	
	return null

func _add_spell_to_player(player: Player) -> bool:
	"""Add spell to player's collection via inventory or magic system"""
	
	# Method 1: Try via Inventory (if using inventory spell system)
	var ui = player.get_node_or_null("UserInterface")
	if ui:
		var inventory = ui.get_node_or_null("Inventory")
		if inventory and inventory.has_method("add_spell_to_collection"):
			inventory.add_spell_to_collection(spell)
			return true
	
	# Method 2: Try via parent's inventory
	if player.get_parent():
		var parent_inventory = player.get_parent().get_node_or_null("UserInterface/Inventory")
		if parent_inventory and parent_inventory.has_method("add_spell_to_collection"):
			parent_inventory.add_spell_to_collection(spell)
			return true
	
	# Method 3: Search for inventory in scene
	var inventories = get_tree().get_nodes_in_group("Inventory")
	for inv in inventories:
		if inv.has_method("add_spell_to_collection"):
			inv.add_spell_to_collection(spell)
			return true
	
	# Method 4: Try to equip directly to MagicSystem
	var magic_system = player.get_node_or_null("MagicSystem")
	if magic_system and magic_system.has_method("equip_spell"):
		# Find first empty slot
		for i in range(magic_system.max_equipped_spells):
			if magic_system.get_equipped_spell(i) == null:
				magic_system.equip_spell(spell, i)
				return true
	
	print("⚠️ Could not add spell - no valid spell collection system found")
	return false

func _play_pickup_effect() -> void:
	"""Play visual/audio feedback for spell pickup"""
	
	# Play particle effect if it exists
	if visual_effect:
		# If it's a GPUParticles3D, trigger it
		for child in visual_effect.get_children():
			if child is GPUParticles3D:
				child.emitting = true
				child.one_shot = true
	
	# Could also play a sound here
	# if $AudioStreamPlayer3D:
	#     $AudioStreamPlayer3D.play()

# ==================== PERSISTENCE HELPERS ====================

func _generate_unique_id() -> void:
	"""Generate a unique ID based on position and spell name"""
	if spell:
		# Use spell name in ID for clarity
		var pos_str = "%.0f_%.0f_%.0f" % [global_position.x, global_position.y, global_position.z]
		unique_id = "spell_%s_%s" % [spell.spell_name.to_lower().replace(" ", "_"), pos_str]
	else:
		# Generic ID if no spell assigned
		var pos_str = "%.0f_%.0f_%.0f" % [global_position.x, global_position.y, global_position.z]
		unique_id = "spell_unknown_%s" % pos_str
	
	print("Auto-generated ID for pickup spell: ", unique_id)

func _was_already_picked_up() -> bool:
	"""Check if this spell was already picked up in a previous session"""
	if unique_id.is_empty():
		push_warning("PickupSpell has no unique_id! Spell will respawn on reload.")
		return false
	
	if not has_node("/root/GameState"):
		push_warning("GameState not found! Spells will respawn on reload.")
		return false
	
	return GameState.is_spell_picked_up(unique_id)

func _mark_as_picked_up() -> void:
	"""Mark this spell as picked up in GameState"""
	if unique_id.is_empty():
		push_warning("Cannot mark spell as picked up - no unique_id set!")
		return
	
	if has_node("/root/GameState"):
		GameState.mark_spell_picked_up(unique_id)
