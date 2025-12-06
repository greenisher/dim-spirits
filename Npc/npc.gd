extends CharacterBody3D
class_name NPC

signal dialogue_started(npc: NPC)
signal dialogue_ended(npc: NPC)
signal animation_triggered(animation_name: String)

@export var npc_name: String = "Villager"
@export var portrait: Texture2D
@export_multiline var greeting: String = "Hello there, traveler!"
@export var dialogue_tree: Resource  # Can be set manually or auto-assigned by DialogueTreeManager
@export var approval_score: int = 10
@export var faction: String = 'Rags'

## Use DialogueTreeManager to automatically select dialogue tree based on game state
@export var use_dynamic_dialogue: bool = true

# ==================== ANIMATION CONFIGURATION ====================

@export_group("Animation Settings")
@export var play_greeting_animation: bool = true
@export var greeting_animation: String = "wave"
@export var nearby_idle_animation: String = "idle_friendly"
@export var default_idle_animation: String = "idle"
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
	# Add to NPC group for easy finding
	add_to_group("npc")
	add_to_group("npc_" + npc_name.to_lower())
	
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
	
	# Set AnimationPlayer to work during pause
	if animation_player:
		animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Get dialogue tree from DialogueTreeManager if using dynamic dialogue
	if use_dynamic_dialogue and has_node("/root/DialogueTreeManager"):
		var tree_manager = get_node("/root/DialogueTreeManager")
		var assigned_tree = tree_manager.get_dialogue_tree_for_npc(npc_name)
		if assigned_tree:
			dialogue_tree = assigned_tree
			print("[NPC:%s] Assigned dialogue tree via DialogueTreeManager" % npc_name)
		else:
			push_warning("[NPC:%s] No dialogue tree found via DialogueTreeManager, using manual assignment" % npc_name)
	
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
	if play_greeting_animation and not is_talking:
		var time_since_last_greeting = Time.get_ticks_msec() / 1000.0 - last_greeting_time
		
		if not has_greeted_player or time_since_last_greeting > greeting_cooldown:
			play_animation(greeting_animation, false)
			has_greeted_player = true
			last_greeting_time = Time.get_ticks_msec() / 1000.0
			
			await get_tree().create_timer(1.0).timeout
			if player_in_range and not is_talking:
				play_animation(nearby_idle_animation, true)
	elif not is_talking:
		play_animation(nearby_idle_animation, true)

func _on_player_exited_range() -> void:
	if not is_talking:
		play_animation(default_idle_animation, true)

# ==================== ANIMATION SYSTEM ====================

func play_animation(anim_name: String, loop: bool = false) -> void:
	if not animation_player or anim_name.is_empty():
		return
	
	if not animation_player.has_animation(anim_name):
		push_warning("Animation '%s' not found on NPC '%s'" % [anim_name, npc_name])
		return
	
	var anim = animation_player.get_animation(anim_name)
	if anim:
		if loop:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
	
	animation_player.play(anim_name)
	animation_triggered.emit(anim_name)

func queue_animation(anim_name: String, wait_for_completion: bool = false, delay_after: float = 0.0) -> void:
	if anim_name.is_empty():
		return
	
	animation_queue.append({
		"animation": anim_name,
		"wait": wait_for_completion,
		"delay": delay_after
	})

func _process_animation_queue() -> void:
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
	if animation_player:
		animation_player.stop()

func get_current_animation() -> String:
	if animation_player:
		return animation_player.current_animation
	return ""

# ==================== DIALOGUE FUNCTIONS ====================

func start_dialogue() -> void:
	if is_talking:
		return
	
	# Update dialogue tree before starting (in case game state changed)
	if use_dynamic_dialogue and has_node("/root/DialogueTreeManager"):
		var tree_manager = get_node("/root/DialogueTreeManager")
		var updated_tree = tree_manager.get_dialogue_tree_for_npc(npc_name)
		if updated_tree:
			dialogue_tree = updated_tree
	
	# Mark character as met (for first meeting dialogue tracking)
	if not GameState.has_met_character(npc_name):
		GameState.mark_character_met(npc_name)
	
	is_talking = true
	current_node_id = "start"
	
	play_animation("talk", true)
	
	dialogue_started.emit(self)

func end_dialogue() -> void:
	is_talking = false
	current_node_id = "start"
	
	if player_in_range:
		play_animation(nearby_idle_animation, true)
	else:
		play_animation(default_idle_animation, true)
	
	dialogue_ended.emit(self)

func get_current_dialogue() -> Dictionary:
	if dialogue_tree:
		var node = dialogue_tree.get_node_by_id(current_node_id)
		
		if not node:
			node = dialogue_tree.get_start_node()
			if node:
				current_node_id = node.id
		
		if node:
			# Play node animation if specified
			if node.npc_animation and not node.npc_animation.is_empty():
				if node.wait_for_animation:
					queue_animation(node.npc_animation, true)
				else:
					play_animation(node.npc_animation, false)
			
			var responses_array = []
			
			if node.responses != null and node.responses.size() > 0:
				for i in range(node.responses.size()):
					var response = node.responses[i]
					if response != null:
						responses_array.append({
							"text": response.text,
							"next_id": response.next_node_id,
							"affection_change": response.affection_change if response.affection_change else 0,
							"reputation_change": response.reputation_change if response.reputation_change else 0,
							"faction_id": response.faction_id if response.faction_id else "",
							"npc_reaction_animation": response.npc_reaction_animation if response.npc_reaction_animation else "",
							"animation_delay": response.animation_delay if response.animation_delay else 0.0
						})
			
			# Handle auto-continue
			if responses_array.is_empty():
				if node.auto_continue and node.auto_continue_node_id and not node.auto_continue_node_id.is_empty():
					responses_array.append({
						"text": "Continue...",
						"next_id": node.auto_continue_node_id,
						"affection_change": 0,
						"reputation_change": 0,
						"faction_id": "",
						"npc_reaction_animation": "",
						"animation_delay": 0.0,
						"is_continue": true
					})
				elif not node.end_dialogue:
					responses_array.append({
						"text": "End Conversation",
						"next_id": "_END_",
						"affection_change": 0,
						"reputation_change": 0,
						"faction_id": "",
						"npc_reaction_animation": "",
						"animation_delay": 0.0,
						"is_end_button": true
					})
			
			if node.end_dialogue:
				responses_array = [{
					"text": "End Conversation",
					"next_id": "_END_",
					"affection_change": 0,
					"reputation_change": 0,
					"faction_id": "",
					"npc_reaction_animation": "",
					"animation_delay": 0.0,
					"is_end_button": true
				}]
			
			return {
				"npc_name": npc_name,
				"portrait": portrait,
				"text": node.text,
				"responses": responses_array,
				"npc_animation": node.npc_animation if node.npc_animation else "",
				"wait_for_animation": node.wait_for_animation if node.wait_for_animation else false,
				"auto_continue": node.auto_continue if node.auto_continue else false
			}
	
	# Fallback
	return {
		"npc_name": npc_name,
		"portrait": portrait,
		"text": greeting,
		"responses": get_available_responses()
	}

func get_available_responses() -> Array:
	return [
		{"text": "Tell me about yourself.", "next_id": "about"},
		{"text": "What's happening around here?", "next_id": "news"},
		{"text": "Goodbye.", "next_id": "end"}
	]

func handle_response(response_id: String, response_data: Dictionary = {}) -> Dictionary:
	# Play reaction animation
	if response_data.has("npc_reaction_animation") and not response_data["npc_reaction_animation"].is_empty():
		var anim_delay = response_data.get("animation_delay", 0.0)
		queue_animation(response_data["npc_reaction_animation"], true, anim_delay)
	
	# Handle special _END_ response
	if response_id == "_END_":
		end_dialogue()
		return {"text": "", "responses": []}
	
	if dialogue_tree:
		if response_id == "end":
			end_dialogue()
			return {"text": "", "responses": []}
		
		# Apply response effects
		var current_node = dialogue_tree.get_node_by_id(current_node_id)
		if current_node and current_node.responses:
			for response in current_node.responses:
				if response and response.next_node_id == response_id:
					if response.affection_change != 0:
						apply_affection_change(response.affection_change)
					
					if response.reputation_change != 0:
						apply_reputation_change(response.reputation_change, response.faction_id)
					break
		
		current_node_id = response_id
		return get_current_dialogue()
	
	# Fallback hardcoded dialogue
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
	approval_score += amount
	
	if has_node("/root/RomanceManager"):
		var romance_manager = get_node("/root/RomanceManager")
		if romance_manager.romance_partner.has(npc_name):
			romance_manager.add_reputation(npc_name, amount)
	
	print("%s affection changed by %d (now: %d)" % [npc_name, amount, approval_score])

func apply_reputation_change(amount: int, faction_name: String = "") -> void:
	var target_faction = faction_name if not faction_name.is_empty() else faction
	
	if has_node("/root/ReputationManager"):
		var reputation_manager = get_node("/root/ReputationManager")
		reputation_manager.add_reputation(target_faction, amount)
	
	print("%s faction reputation changed by %d" % [target_faction, amount])

func increase_approval(amount: int) -> void:
	approval_score = approval_score + amount
	print(approval_score)
	
func decrease_approval(amount: int) -> void:
	approval_score = approval_score - amount
	print(approval_score)
