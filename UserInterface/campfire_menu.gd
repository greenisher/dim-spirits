extends Control
## Updated Campfire Menu with Romance Rest System Integration

@onready var level_button: TextureButton = %LevelButton
@onready var level_up_panel: Control = $Level_up_choice

@onready var save_button: TextureButton = %SaveButton if has_node("%SaveButton") else null
@onready var rest_button: TextureButton = %RestButton if has_node("%RestButton") else null
@onready var invite_button: TextureButton = %InviteButton if has_node("%InviteButton") else null  # NEW
@onready var exit_button: TextureButton = %ExitButton if has_node("%ExitButton") else null

# Reference to the romance rest selection UI (should be a child of this menu or separate)
@onready var romance_selection_panel: Control = $RomanceRestSelectionUI if has_node("RomanceRestSelectionUI") else null

var player: Player
var _closing: bool = false  

# ==================== INITIALIZATION ====================

func _ready() -> void:
	if level_button:
		level_button.pressed.connect(_on_level_button_pressed)
	
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if rest_button:
		rest_button.pressed.connect(_on_rest_button_pressed)
	if invite_button:
		invite_button.pressed.connect(_on_invite_button_pressed)  # NEW
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
	
	if level_up_panel:
		if level_up_panel.has_signal("level_up_completed"):
			level_up_panel.level_up_completed.connect(_on_level_up_completed)
		if level_up_panel.has_signal("stat_increased"):
			level_up_panel.stat_increased.connect(_on_stat_increased)
	
	# Connect romance selection panel signals
	if romance_selection_panel:
		if romance_selection_panel.has_signal("invitation_confirmed"):
			romance_selection_panel.invitation_confirmed.connect(_on_invitation_confirmed)
		if romance_selection_panel.has_signal("back_pressed"):
			romance_selection_panel.back_pressed.connect(_on_selection_back_pressed)

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
	
	# TODO: Replenish other resources

## NEW: Handle invite button press
func _on_invite_button_pressed() -> void:
	# Check if RomanceRestManager is available
	if not has_node("/root/RomanceRestManager"):
		push_error("RomanceRestManager not found! Make sure it's added as an autoload.")
		show_notification("Romance system not available.")
		return
	
	var romance_manager = get_node("/root/RomanceRestManager")
	var available_characters = romance_manager.get_available_romance_options()
	
	# Check if any romance options are available
	if available_characters.is_empty():
		show_notification("You haven't met any romance options yet.")
		return
	
	# Open the character selection panel
	if romance_selection_panel and romance_selection_panel.has_method("open"):
		romance_selection_panel.open()
	else:
		push_error("Romance selection panel not found or doesn't have open() method")
		show_notification("Selection UI not available.")

func _on_exit_button_pressed() -> void:
	close_menu()

# ==================== ROMANCE REST HANDLERS ====================

## Called when player confirms their character selection
func _on_invitation_confirmed(selected_characters: Array) -> void:
	if not has_node("/root/RomanceRestManager"):
		return
	
	var romance_manager = get_node("/root/RomanceRestManager")
	
	# Try to play the scene
	var scene_id = romance_manager.try_play_rest_scene(selected_characters)
	
	if scene_id.is_empty():
		show_notification("No more scenes available for this combination.")
		return
	
	# Close the campfire menu
	close_menu()
	
	# Load and play the romance rest scene
	_load_romance_scene(scene_id, selected_characters)

## Called when player presses back in the selection UI
func _on_selection_back_pressed() -> void:
	# Just return to main campfire menu (selection panel closes itself)
	pass

# ==================== ROMANCE SCENE LOADING ====================

func _load_romance_scene(scene_id: String, characters: Array) -> void:
	print("Loading romance rest scene: ", scene_id, " with ", characters)
	
	# Option 1: Load a scene file
	# var scene_path = "res://scenes/romance_rest/%s.tscn" % scene_id.to_lower()
	# if ResourceLoader.exists(scene_path):
	#     get_tree().change_scene_to_file(scene_path)
	#     return
	
	# Option 2: Trigger a cutscene/dialogue system
	# if has_node("/root/CutsceneManager"):
	#     var cutscene_mgr = get_node("/root/CutsceneManager")
	#     cutscene_mgr.play_cutscene(scene_id)
	#     return
	
	# Option 3: Trigger dialogue system
	# if has_node("/root/DialogueManager"):
	#     var dialogue_mgr = get_node("/root/DialogueManager")
	#     dialogue_mgr.start_dialogue(scene_id)
	#     return
	
	# Fallback: Just show a notification (you should implement one of the above)
	show_notification("Playing scene: %s with %s" % [scene_id, " & ".join(characters)])
	
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
	
	update_level_button()
	update_invite_button()  # NEW
	
	print("Campfire menu opened")

func close_menu() -> void:
	if _closing:
		return  
	
	_closing = true
	visible = false
	
	if level_up_panel and level_up_panel.visible:
		if level_up_panel.has_method("close"):
			level_up_panel.close()
	
	if romance_selection_panel and romance_selection_panel.visible:
		if romance_selection_panel.has_method("close"):
			romance_selection_panel.close()
	
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
		var xp_cost = player.stats.get_xp_to_next_level()
		level_button.modulate = Color.WHITE
	else:
		level_button.modulate = Color(0.5, 0.5, 0.5)

## NEW: Update invite button availability
func update_invite_button() -> void:
	if not invite_button:
		return
	
	# Check if any romance options are available
	if has_node("/root/RomanceRestManager"):
		var romance_manager = get_node("/root/RomanceRestManager")
		var available = romance_manager.get_available_romance_options()
		
		invite_button.disabled = available.is_empty()
		
		if available.is_empty():
			invite_button.modulate = Color(0.5, 0.5, 0.5)
		else:
			invite_button.modulate = Color.WHITE
	else:
		invite_button.disabled = true

## Show notification to player
func show_notification(message: String) -> void:
	print("NOTIFICATION: ", message)
	# TODO: Implement actual notification UI
	# Example:
	# $NotificationLabel.text = message
	# $NotificationLabel.visible = true
	# await get_tree().create_timer(2.0).timeout
	# $NotificationLabel.visible = false

# ==================== PROCESS ====================

func _process(_delta: float) -> void:
	if visible and player:
		update_level_button()
		update_invite_button()  # NEW

# ==================== INPUT HANDLING ====================

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		# Check if romance selection is open
		if romance_selection_panel and romance_selection_panel.visible:
			# Let the selection panel handle it
			return
		
		if level_up_panel and level_up_panel.visible:
			if level_up_panel.has_method("close"):
				level_up_panel.close()
			get_viewport().set_input_as_handled()
		else:
			close_menu()
			get_viewport().set_input_as_handled()
