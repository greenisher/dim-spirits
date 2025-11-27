extends CharacterBody3D
class_name NPC

signal dialogue_started(npc: NPC)
signal dialogue_ended(npc: NPC)
signal animation_triggered(animation_name: String)

@export var npc_name: String = "Villager"
@export var portrait: Texture2D
@export_multiline var greeting: String = "Hello there, traveler!"
@export var dialogue_tree: Resource
@export var approval_score: int = 10
@export var faction: String = 'Rags'

# ==================== ANIMATION CONFIGURATION ====================

@export_group("Animation Settings")
## Should NPC play greeting animation when player enters range?
@export var play_greeting_animation: bool = true

## Animation to play when player first enters interaction range
@export var greeting_animation: String = "wave"

## Idle animation to loop while player is nearby
@export var nearby_idle_animation: String = "idle_friendly"

## Default idle animation
@export var default_idle_animation: String = "idle"

## Time to wait before playing greeting again (prevents spam)
@export var greeting_cooldown: float = 10.0

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Label3D = $InteractionPrompt
@onready var animation_player: AnimationPlayer = $rags/AnimationPlayer if has_node("rags/AnimationPlayer") else null

var player_in_range: bool = false
var is_talking: bool = false
var current_node_id: String = "start"

# Animation state
var has_greeted_player: bool = false
var last_greeting_time: float = 0.0
var animation_queue: Array[Dictionary] = []
var is_playing_animation: bool = false

func _ready() -> void:
	# Connect interaction area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	
	# Hide prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Ensure DialogueManager knows about this NPC
	if DialogueManager:
		DialogueManager.connect_npc(self)
	
	# Start with default idle animation
	play_animation(default_idle_animation, true)

func _process(_delta: float) -> void:
	# Show prompt when player is in range and not talking
	if interaction_prompt:
		interaction_prompt.visible = player_in_range and not is_talking and not DialogueManager.is_in_dialogue()
	
	# Check for interaction input
	if player_in_range and not is_talking and not DialogueManager.is_in_dialogue():
		if Input.is_action_just_pressed("interact"):
			start_dialogue()
	
	# Process animation queue
	_process_animation_queue()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_in_range = true
		_on_player_entered_range()

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_in_range = false
		_on_player_exited_range()

# ==================== PLAYER DETECTION ANIMATIONS ====================

func _on_player_entered_range() -> void:
	"""Called when player enters interaction range"""
	
	# Play greeting animation if enabled and not on cooldown
	if play_greeting_animation and not is_talking:
		var time_since_last_greeting = Time.get_ticks_msec() / 1000.0 - last_greeting_time
		
		if not has_greeted_player or time_since_last_greeting > greeting_cooldown:
			play_animation(greeting_animation, false)
			has_greeted_player = true
			last_greeting_time = Time.get_ticks_msec() / 1000.0
			
			# After greeting, switch to nearby idle
			await get_tree().create_timer(1.0).timeout
			if player_in_range and not is_talking:
				play_animation(nearby_idle_animation, true)
	elif not is_talking:
		# Just switch to nearby idle animation
		play_animation(nearby_idle_animation, true)

func _on_player_exited_range() -> void:
	"""Called when player exits interaction range"""
	
	# Return to default idle when player leaves
	if not is_talking:
		play_animation(default_idle_animation, true)

# ==================== ANIMATION SYSTEM ====================

func play_animation(anim_name: String, loop: bool = false) -> void:
	"""Play an animation immediately"""
	if not animation_player or anim_name.is_empty():
		return
	
	if not animation_player.has_animation(anim_name):
		push_warning("Animation '%s' not found on NPC '%s'" % [anim_name, npc_name])
		return
	
	# Godot 4: Set loop mode on the Animation resource
	var anim = animation_player.get_animation(anim_name)
	if anim:
		if loop:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
	
	animation_player.play(anim_name)
	animation_triggered.emit(anim_name)

func queue_animation(anim_name: String, wait_for_completion: bool = false, delay_after: float = 0.0) -> void:
	"""Add animation to queue to play in sequence"""
	if anim_name.is_empty():
		return
	
	animation_queue.append({
		"animation": anim_name,
		"wait": wait_for_completion,
		"delay": delay_after
	})

func _process_animation_queue() -> void:
	"""Process queued animations"""
	if animation_queue.is_empty() or is_playing_animation:
		return
	
	var anim_data = animation_queue.pop_front()
	is_playing_animation = true
	
	play_animation(anim_data["animation"], false)
	
	if anim_data["wait"]:
		await animation_player.animation_finished
	
	if anim_data["delay"] > 0:
		await get_tree().create_timer(anim_data["delay"]).timeout
	
	is_playing_animation = false

func stop_animation() -> void:
	"""Stop current animation"""
	if animation_player:
		animation_player.stop()

func get_current_animation() -> String:
	"""Get currently playing animation name"""
	if animation_player:
		return animation_player.current_animation
	return ""

# ==================== DIALOGUE FUNCTIONS ====================

func start_dialogue() -> void:
	if is_talking:
		return
	
	is_talking = true
	current_node_id = "start"
	
	# Stop any idle animations and switch to talk animation
	play_animation("talk", true)
	
	dialogue_started.emit(self)

func end_dialogue() -> void:
	is_talking = false
	current_node_id = "start"
	
	# Return to appropriate idle animation
	if player_in_range:
		play_animation(nearby_idle_animation, true)
	else:
		play_animation(default_idle_animation, true)
	
	dialogue_ended.emit(self)

func get_current_dialogue() -> Dictionary:
	# If we have a dialogue tree, use it
	if dialogue_tree:
		var node = dialogue_tree.get_node_by_id(current_node_id)
		
		# Fallback to start node if current node not found
		if not node:
			node = dialogue_tree.get_start_node()
			if node:
				current_node_id = node.id
		
		if node:
			# Play node animation if specified
			if node.has("npc_animation") and not node.npc_animation.is_empty():
				if node.get("wait_for_animation", false):
					queue_animation(node.npc_animation, true)
				else:
					play_animation(node.npc_animation, false)
			
			# Convert DialogueNode to dictionary format
			var responses_array = []
			
			# Access the responses property directly
			if node.responses:
				for response in node.responses:
					if response:
						responses_array.append({
							"text": response.text,
							"next_id": response.next_node_id,
							"affection_change": response.affection_change,
							"reputation_change": response.reputation_change,
							"faction_id": response.faction_id,
							"npc_reaction_animation": response.get("npc_reaction_animation", ""),
							"animation_delay": response.get("animation_delay", 0.0)
						})
			
			# Check if this node ends dialogue
			if node.end_dialogue:
				responses_array = []
			
			return {
				"npc_name": npc_name,
				"portrait": portrait,
				"text": node.text,
				"responses": responses_array,
				"npc_animation": node.get("npc_animation", ""),
				"wait_for_animation": node.get("wait_for_animation", false)
			}
	
	# Fallback to hardcoded dialogue if no tree
	return {
		"npc_name": npc_name,
		"portrait": portrait,
		"text": greeting,
		"responses": get_available_responses()
	}

func get_available_responses() -> Array:
	# This will be expanded with the dialogue tree system
	return [
		{"text": "Tell me about yourself.", "next_id": "about"},
		{"text": "What's happening around here?", "next_id": "news"},
		{"text": "Goodbye.", "next_id": "end"}
	]

func handle_response(response_id: String, response_data: Dictionary = {}) -> Dictionary:
	# Play reaction animation if specified
	if response_data.has("npc_reaction_animation") and not response_data["npc_reaction_animation"].is_empty():
		var anim_delay = response_data.get("animation_delay", 0.0)
		queue_animation(response_data["npc_reaction_animation"], true, anim_delay)
	
	# If using dialogue tree, navigate to next node
	if dialogue_tree:
		if response_id == "end":
			end_dialogue()
			return {"text": "", "responses": []}
		
		# Find the response that was selected to get its effects
		var current_node = dialogue_tree.get_node_by_id(current_node_id)
		if current_node and current_node.responses:
			for response in current_node.responses:
				if response and response.next_node_id == response_id:
					# Apply affection change
					if response.affection_change != 0:
						apply_affection_change(response.affection_change)
					
					# Apply reputation change
					if response.reputation_change != 0:
						apply_reputation_change(response.reputation_change, response.faction_id)
					break
		
		# Update current node ID
		current_node_id = response_id
		
		# Get the new node's dialogue
		return get_current_dialogue()
	
	# Fallback to hardcoded dialogue
	match response_id:
		"about":
			return {
				"text": "I'm just a simple villager living in these parts. I've been here all my life!",
				"responses": [
					{"text": "Interesting. What else?", "next_id": "news"},
					{"text": "Goodbye.", "next_id": "end"}
				]
			}
		"news":
			return {
				"text": "There's been strange activity in the forest lately. Best be careful if you venture out there!",
				"responses": [
					{"text": "Tell me more.", "next_id": "about"},
					{"text": "Thanks for the warning.", "next_id": "end"}
				]
			}
		"end":
			end_dialogue()
			return {"text": "", "responses": []}
		_:
			return {"text": greeting, "responses": get_available_responses()}

func apply_affection_change(amount: int) -> void:
	# Update approval score
	approval_score += amount
	
	# Notify RomanceManager if it exists
	if has_node("/root/RomanceManager"):
		var romance_manager = get_node("/root/RomanceManager")
		if romance_manager.has_method("modify_affection"):
			romance_manager.modify_affection(npc_name, amount)
	
	print("%s affection changed by %d (now: %d)" % [npc_name, amount, approval_score])

func apply_reputation_change(amount: int, faction_name: String = "") -> void:
	# Use the NPC's faction if no specific faction provided
	var target_faction = faction_name if not faction_name.is_empty() else faction
	
	# Notify ReputationManager if it exists
	if has_node("/root/ReputationManager"):
		var reputation_manager = get_node("/root/ReputationManager")
		if reputation_manager.has_method("modify_reputation"):
			reputation_manager.modify_reputation(target_faction, amount)
	
	print("%s faction reputation changed by %d" % [target_faction, amount])

func increase_approval(amount: int) -> void:
	approval_score = approval_score + amount
	print(approval_score)
	
func decrease_approval(amount: int) -> void:
	approval_score = approval_score - amount
	print(approval_score)
