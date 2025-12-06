extends Control
## Simplified Campfire Menu - No separate selection UI needed

@onready var level_button: TextureButton = %LevelButton
@onready var level_up_panel: Control = $Level_up_choice

@onready var save_button: TextureButton = %SaveButton if has_node("%SaveButton") else null
@onready var rest_button: TextureButton = %RestButton if has_node("%RestButton") else null
@onready var exit_button: TextureButton = %ExitButton if has_node("%ExitButton") else null

# Romance character invite buttons (add these to your scene)
@onready var invite_asumi_button: TextureButton = %InviteAsumiButton if has_node("%InviteAsumiButton") else null
@onready var invite_rhea_button: TextureButton = %InviteRheaButton if has_node("%InviteRheaButton") else null
@onready var invite_skoll_button: TextureButton = %InviteSkollButton if has_node("%InviteSkollButton") else null

var player: Player
var _closing: bool = false  

# Track invitations per character
var invitation_counts: Dictionary = {
	"Rhea": 0,
	"Asumi": 0,
	"Skoll": 0
}

# ==================== INITIALIZATION ====================

func _ready() -> void:
	if level_button:
		level_button.pressed.connect(_on_level_button_pressed)
	
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if rest_button:
		rest_button.pressed.connect(_on_rest_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
	
	# Connect romance invite buttons
	if invite_asumi_button:
		invite_asumi_button.pressed.connect(_on_invite_character_pressed.bind("Asumi"))
	if invite_rhea_button:
		invite_rhea_button.pressed.connect(_on_invite_character_pressed.bind("Rhea"))
	if invite_skoll_button:
		invite_skoll_button.pressed.connect(_on_invite_character_pressed.bind("Skoll"))
	
	if level_up_panel:
		if level_up_panel.has_signal("level_up_completed"):
			level_up_panel.level_up_completed.connect(_on_level_up_completed)
		if level_up_panel.has_signal("stat_increased"):
			level_up_panel.stat_increased.connect(_on_stat_increased)
	
	# Load invitation counts from GameState story flags
	_load_invitation_counts()

# ==================== STORY FLAG MANAGEMENT ====================

func _load_invitation_counts() -> void:
	"""Load invitation counts from story flags on initialization"""
	for character_name in invitation_counts.keys():
		invitation_counts[character_name] = _get_invitation_count_from_flags(character_name)

func _get_invitation_count_from_flags(character_name: String) -> int:
	"""Get invitation count based on story flags"""
	var char_lower = character_name.to_lower()
	
	if GameState.has_story_flag("%s_invited_thrice" % char_lower):
		return 3
	elif GameState.has_story_flag("%s_invited_twice" % char_lower):
		return 2
	elif GameState.has_story_flag("%s_invited_once" % char_lower):
		return 1
	else:
		return 0

func _update_invitation_flags(character_name: String) -> void:
	"""Update story flags based on invitation count"""
	var count = invitation_counts[character_name]
	var char_lower = character_name.to_lower()
	
	match count:
		1:
			GameState.set_story_flag("%s_invited_once" % char_lower)
			print("Story flag set: %s_invited_once" % char_lower)
		2:
			GameState.set_story_flag("%s_invited_twice" % char_lower)
			print("Story flag set: %s_invited_twice" % char_lower)
		3:
			GameState.set_story_flag("%s_invited_thrice" % char_lower)
			print("Story flag set: %s_invited_thrice" % char_lower)

func mark_character_met(character_name: String) -> void:
	"""Mark a character as met (sets met_[name] flag)"""
	var char_lower = character_name.to_lower()
	
	# Check if already marked (either lowercase or capitalized version)
	if not GameState.has_story_flag("met_%s" % char_lower) and not GameState.has_story_flag("met_%s" % character_name):
		GameState.set_story_flag("met_%s" % char_lower)
		print("Story flag set: met_%s" % char_lower)

# ==================== BUTTON HANDLERS ====================

func _on_level_button_pressed() -> void:
	if not player or not player.stats:
		print("No player or stats found!")
		return
	
	if not player.stats.can_level_up():
		print("Not enough XP to level up!")
		show_notification("Not enough XP to level up!")
		return
	
	if level_up_panel and level_up_panel.has_method("open"):
		level_up_panel.open(player)
	else:
		print("ERROR: Level-up panel not found or doesn't have open() method")

func _on_save_button_pressed() -> void:
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		if save_mgr.save_game():
			show_notification("Game Saved!")
		else:
			show_notification("Save Failed!")
	else:
		print("SaveManager not found!")

func _on_rest_button_pressed() -> void:
	if player and player.health_component:
		player.health_component.current_health = player.health_component.max_health
		show_notification("You rest at the campfire. HP restored!")

func _on_exit_button_pressed() -> void:
	close_menu()

# ==================== ROMANCE INVITE HANDLERS ====================

func _on_invite_character_pressed(character_name: String) -> void:
	"""Called when player clicks an invite button for a specific character"""
	
	print("Inviting %s to campfire..." % character_name)
	
	# Mark character as met
	mark_character_met(character_name)
	
	# Increment invitation count
	if invitation_counts.has(character_name):
		invitation_counts[character_name] += 1
		_update_invitation_flags(character_name)
		
		print("%s has been invited %d time(s)" % [character_name, invitation_counts[character_name]])
	
	# Update spawners so NPCs can move to campfire location
	NpcSpawnManager.refresh_all_spawners()
	
	# Play the romance rest scene
	_play_romance_scene(character_name)
	
	# Update button states
	update_invite_buttons()

func _play_romance_scene(character_name: String) -> void:
	"""Play the romance rest scene for a character"""
	
	var invitation_count = invitation_counts[character_name]
	var scene_id = "%s_scene_%d" % [character_name.to_lower(), invitation_count]
	
	print("Playing romance scene: %s" % scene_id)
	
	# Option 1: Load a dialogue tree for this scene
	# if has_node("/root/DialogueManager"):
	#     var dialogue_mgr = get_node("/root/DialogueManager")
	#     # Find the NPC and start dialogue
	#     var npc = get_tree().get_first_node_in_group("npc_" + character_name.to_lower())
	#     if npc:
	#         dialogue_mgr.start_dialogue_with(npc)
	
	# Option 2: Load a cutscene
	# if has_node("/root/CutsceneManager"):
	#     var cutscene_mgr = get_node("/root/CutsceneManager")
	#     cutscene_mgr.play_cutscene(scene_id)
	
	# Option 3: Just show notification (placeholder)
	show_notification("Spending time with %s at the campfire..." % character_name)
	
	# Increase romance value
	if has_node("/root/RomanceManager"):
		var romance_mgr = get_node("/root/RomanceManager")
		romance_mgr.add_reputation(character_name, 5)  # +5 romance for spending time
	
	# Auto-save after scene
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.save_game()

# ==================== SIGNAL HANDLERS FROM LEVEL_UP_PANEL ====================

func _on_level_up_completed() -> void:
	print("Level-up completed!")
	update_level_button()

func _on_stat_increased(stat_name: String) -> void:
	print("Stat increased: ", stat_name)
	update_level_button()

# ==================== MENU MANAGEMENT ====================

func open_menu(player_ref: Player) -> void:
	player = player_ref
	visible = true
	
	# Reload invitation counts in case flags changed
	_load_invitation_counts()
	
	update_level_button()
	update_invite_buttons()
	
	print("Campfire menu opened")

func close_menu() -> void:
	if _closing:
		return  
	
	_closing = true
	visible = false
	
	if level_up_panel and level_up_panel.visible:
		if level_up_panel.has_method("close"):
			level_up_panel.close()
	
	if get_parent().has_method("close_menu"):
		get_parent().close_menu()
	
	print("Campfire menu closed")
	_closing = false

# ==================== UI UPDATE FUNCTIONS ====================

func update_level_button() -> void:
	if not level_button:
		return
	
	if not player or not player.stats:
		level_button.disabled = true
		return
	
	var can_level = player.stats.can_level_up()
	level_button.disabled = not can_level
	
	if can_level:
		level_button.modulate = Color.WHITE
	else:
		level_button.modulate = Color(0.5, 0.5, 0.5)

func update_invite_buttons() -> void:
	"""Update all invite buttons based on whether characters have been met"""
	
	_update_single_invite_button(invite_asumi_button, "Asumi")
	_update_single_invite_button(invite_rhea_button, "Rhea")
	_update_single_invite_button(invite_skoll_button, "Skoll")

func _update_single_invite_button(button: TextureButton, character_name: String) -> void:
	"""Update a single invite button's availability"""
	if not button:
		return
	
	var char_lower = character_name.to_lower()
	
	# Check both lowercase and capitalized versions of the flag for compatibility
	var has_met = GameState.has_story_flag("met_%s" % char_lower) or GameState.has_story_flag("met_%s" % character_name)
	
	# Only enable button if player has met the character
	button.disabled = not has_met
	
	if has_met:
		button.modulate = Color.WHITE
		
		# Optional: Update button text to show invitation count
		var count = invitation_counts.get(character_name, 0)
		if button.has_node("Label"):
			var label = button.get_node("Label")
			if count > 0:
				label.text = "%s (%d)" % [character_name, count]
			else:
				label.text = character_name
	else:
		button.modulate = Color(0.3, 0.3, 0.3)  # Greyed out

func show_notification(message: String) -> void:
	print("NOTIFICATION: ", message)
	# TODO: Implement actual notification UI

# ==================== PROCESS ====================

func _process(_delta: float) -> void:
	if visible and player:
		update_level_button()

# ==================== INPUT HANDLING ====================

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if level_up_panel and level_up_panel.visible:
			if level_up_panel.has_method("close"):
				level_up_panel.close()
			get_viewport().set_input_as_handled()
		else:
			close_menu()
			get_viewport().set_input_as_handled()

# ==================== DEBUG HELPERS ====================

func debug_print_invitation_status() -> void:
	"""Debug: Print current invitation status for all characters"""
	print("=== Invitation Status ===")
	for character_name in invitation_counts.keys():
		var count = invitation_counts[character_name]
		var char_lower = character_name.to_lower()
		print("%s: %d invitations" % [character_name, count])
		print("  - met_%s: %s" % [char_lower, GameState.has_story_flag("met_%s" % char_lower)])
		print("  - %s_invited_once: %s" % [char_lower, GameState.has_story_flag("%s_invited_once" % char_lower)])
		print("  - %s_invited_twice: %s" % [char_lower, GameState.has_story_flag("%s_invited_twice" % char_lower)])
		print("  - %s_invited_thrice: %s" % [char_lower, GameState.has_story_flag("%s_invited_thrice" % char_lower)])
