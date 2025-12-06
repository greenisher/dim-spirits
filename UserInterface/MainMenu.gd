extends Control
## Main Menu - Start screen with New Game and Continue options
##
## Integrates with SaveManager to check for existing saves
## and handle game start flow

# ==================== NODE REFERENCES ====================

@onready var new_game_button: Button = %NewGameButton if has_node("%NewGameButton") else null
@onready var continue_button: Button = %ContinueButton if has_node("%ContinueButton") else null
@onready var load_game_button: Button = %LoadGameButton if has_node("%LoadGameButton") else null
@onready var settings_button: Button = %SettingsButton if has_node("%SettingsButton") else null
@onready var quit_button: Button = %QuitButton if has_node("%QuitButton") else null

# Optional panels
@onready var save_slot_panel: Control = %SaveSlotPanel if has_node("%SaveSlotPanel") else null
@onready var new_game_confirm_panel: Control = %NewGameConfirmPanel if has_node("%NewGameConfirmPanel") else null

# ==================== CONFIGURATION ====================

## First scene to load when starting a new game
@export var first_game_scene: String = "res://Levels/lostburg_ground.tscn"

## Default save slot to use for quick continue (1-3)
@export var default_save_slot: int = 1

## Should Continue button load the most recent save automatically?
@export var auto_load_recent_save: bool = true

# ==================== INITIALIZATION ====================

func _ready() -> void:
	# Connect buttons
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if load_game_button:
		load_game_button.pressed.connect(_on_load_game_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# Update UI based on save file existence
	_update_menu_state()
	
	# Hide optional panels
	if save_slot_panel:
		save_slot_panel.visible = false
	if new_game_confirm_panel:
		new_game_confirm_panel.visible = false
	
	# Focus the first available button
	_set_initial_focus()

# ==================== MENU STATE ====================

## Update menu buttons based on save file existence
func _update_menu_state() -> void:
	if not has_node("/root/SaveManager"):
		push_warning("SaveManager not found - Continue button may not work correctly")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	# Check if any saves exist
	var has_any_save = false
	for slot in range(1, save_mgr.MAX_SAVE_SLOTS + 1):
		if save_mgr.save_exists(slot):
			has_any_save = true
			break
	
	# Enable/disable continue button
	if continue_button:
		continue_button.disabled = not has_any_save
		
		# Visual feedback
		if has_any_save:
			continue_button.modulate = Color.WHITE
		else:
			continue_button.modulate = Color(0.5, 0.5, 0.5)
	
	# Enable/disable load game button
	if load_game_button:
		load_game_button.disabled = not has_any_save
		
		if has_any_save:
			load_game_button.modulate = Color.WHITE
		else:
			load_game_button.modulate = Color(0.5, 0.5, 0.5)

## Set initial button focus for controller/keyboard navigation
func _set_initial_focus() -> void:
	# Try to focus continue if available, otherwise new game
	if continue_button and not continue_button.disabled:
		continue_button.grab_focus()
	elif new_game_button:
		new_game_button.grab_focus()

# ==================== BUTTON HANDLERS ====================

func _on_new_game_pressed() -> void:
	print("New Game pressed")
	
	# Check if save slot 1 already has a save
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		if save_mgr.save_exists(default_save_slot):
			# Show confirmation dialog if save exists
			_show_new_game_confirmation()
			return
	
	# ✅ Play intro cutscene FIRST
	_play_intro_cutscene()
	SceneManager.start_new_game("res://Levels/lostburg_ground.tscn", "SpawnPoint")

func _play_intro_cutscene() -> void:
	print("Playing intro cutscene...")
	var cutscene = preload("res://Resources/CutscenePlayer.tscn").instantiate()
	add_child(cutscene)
	
	# Connect to callback that starts the game
	cutscene.cutscene_finished.connect(_on_intro_cutscene_finished)
	
	# Play the cutscene
	cutscene.play_cutscene_from_file("res://CutScenes/cutscene_intro.json")

func _on_intro_cutscene_finished() -> void:
	print("Intro cutscene finished, starting game...")
	
	# NOW start the game (only called once)
	_start_new_game()

## Start a new game (unchanged - no cutscene code here)
func _start_new_game() -> void:
	print("Starting new game...")
	
	# Clear all manager states for new game
	_clear_game_state()
	
	# Set the active save slot
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		save_mgr.current_save_slot = default_save_slot
	
	# Load the first game scene
	_transition_to_game_scene(first_game_scene)

func _on_continue_pressed() -> void:
	print("Continue pressed")
	
	if not has_node("/root/SaveManager"):
		push_error("SaveManager not found!")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	if auto_load_recent_save:
		# Load the most recent save automatically
		var most_recent_slot = _get_most_recent_save_slot()
		if most_recent_slot > 0:
			_load_game(most_recent_slot)
		else:
			push_error("No saves found to continue")
	else:
		# Load the default save slot
		if save_mgr.save_exists(default_save_slot):
			_load_game(default_save_slot)
		else:
			push_error("Default save slot %d does not exist" % default_save_slot)

func _on_load_game_pressed() -> void:
	print("Load Game pressed")
	
	# Show save slot selection panel
	if save_slot_panel:
		_show_save_slot_selection()
	else:
		# Fallback: just load default slot
		_on_continue_pressed()

func _on_settings_pressed() -> void:
	print("Settings pressed")
	# Load settings menu scene or show settings panel
	# get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")
	pass

func _on_quit_pressed() -> void:
	print("Quit pressed")
	get_tree().quit()

# ==================== GAME START ====================

## Load an existing save game
func _load_game(slot: int) -> void:
	print("Loading game from slot ", slot)
	
	if not has_node("/root/SaveManager"):
		push_error("SaveManager not found!")
		return
	
	var save_mgr = get_node("/root/SaveManager")
	
	if not save_mgr.save_exists(slot):
		push_error("Save slot %d does not exist" % slot)
		return
	
	# Load the save file
	if save_mgr.load_game(slot):
		print("Game loaded successfully from slot ", slot)
		# SaveManager will change scene automatically based on saved scene
	else:
		push_error("Failed to load game from slot ", slot)

## Clear all game state for a fresh start
func _clear_game_state() -> void:
	# Clear GameState
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		if game_state.has_method("clear_all_state"):
			game_state.clear_all_state()
	
	# Clear RomanceRestManager
	if has_node("/root/RomanceRestManager"):
		var rest_mgr = get_node("/root/RomanceRestManager")
		if rest_mgr.has_method("clear_all_data"):
			rest_mgr.clear_all_data()
	
	# Clear RelationshipManager
	if has_node("/root/RelationshipManager"):
		var rel_mgr = get_node("/root/RelationshipManager")
		if rel_mgr.has_method("clear_all_relationships"):
			rel_mgr.clear_all_relationships()
	
	# Reset RomanceManager to default values
	if has_node("/root/RomanceManager"):
		var rom_mgr = get_node("/root/RomanceManager")
		rom_mgr.romance_partner = {
			'Asumi': 10,
			'Rhea': 10,
			'Skoll': 10
		}
	
	# Note: Add any other managers that need clearing here
	
	print("Game state cleared for new game")

	
## Transition to the game scene with optional fade effect
func _transition_to_game_scene(scene_path: String) -> void:
	# Option 1: Direct scene change
	get_tree().change_scene_to_file(scene_path)
	
	# Option 2: Fade transition (if you have a transition manager)
	# if has_node("/root/TransitionManager"):
	#     var transition = get_node("/root/TransitionManager")
	#     transition.fade_to_scene(scene_path)

# ==================== SAVE SLOT SELECTION ====================

## Show the save slot selection panel
func _show_save_slot_selection() -> void:
	if not save_slot_panel:
		push_warning("Save slot panel not found")
		return
	
	save_slot_panel.visible = true
	_populate_save_slots()

func _close_save_slot_selection() -> void:
	if not save_slot_panel:
		push_warning("Save slot panel not found")
		return
	
	save_slot_panel.visible = false

## Populate save slot information
func _populate_save_slots() -> void:
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var all_saves = save_mgr.get_all_saves()
	
	# You'll need to create UI elements for each save slot
	# This is just an example structure
	for save_info in all_saves:
		print("Slot %d: %s" % [save_info["slot"], 
			"Exists" if save_info["exists"] else "Empty"])
		
		if save_info["exists"]:
			var metadata = save_info["metadata"]
			print("  Save date: ", metadata.get("save_date", "Unknown"))
			print("  Play time: ", metadata.get("play_time", 0))

## Get the most recent save slot based on save date
func _get_most_recent_save_slot() -> int:
	if not has_node("/root/SaveManager"):
		return 0
	
	var save_mgr = get_node("/root/SaveManager")
	var all_saves = save_mgr.get_all_saves()
	
	var most_recent_slot = 0
	var most_recent_time = ""
	
	for save_info in all_saves:
		if save_info["exists"]:
			var save_date = save_info["metadata"].get("save_date", "")
			if save_date > most_recent_time:
				most_recent_time = save_date
				most_recent_slot = save_info["slot"]
	
	return most_recent_slot

# ==================== CONFIRMATION DIALOGS ====================

## Show confirmation before overwriting an existing save
func _show_new_game_confirmation() -> void:
	if new_game_confirm_panel:
		new_game_confirm_panel.visible = true
	else:
		# Fallback: Use AcceptDialog
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Starting a new game will overwrite your existing save. Continue?"
		dialog.add_cancel_button("Cancel")
		dialog.confirmed.connect(_start_new_game)
		add_child(dialog)
		dialog.popup_centered()

## Called when player confirms they want to overwrite save
func _on_new_game_confirmed() -> void:
	if new_game_confirm_panel:
		new_game_confirm_panel.visible = false
	_start_new_game()

## Called when player cancels new game
func _on_new_game_cancelled() -> void:
	if new_game_confirm_panel:
		new_game_confirm_panel.visible = false

# ==================== INPUT HANDLING ====================

func _input(event: InputEvent) -> void:
	# Close panels with ESC/Back button
	if event.is_action_pressed("ui_cancel"):
		if save_slot_panel and save_slot_panel.visible:
			save_slot_panel.visible = false
			get_viewport().set_input_as_handled()
		elif new_game_confirm_panel and new_game_confirm_panel.visible:
			_on_new_game_cancelled()
			get_viewport().set_input_as_handled()

# ==================== DEBUGGING ====================

## Print all available saves (for debugging)
func debug_print_saves() -> void:
	if not has_node("/root/SaveManager"):
		return
	
	var save_mgr = get_node("/root/SaveManager")
	var all_saves = save_mgr.get_all_saves()
	
	print("=== Available Save Slots ===")
	for save_info in all_saves:
		if save_info["exists"]:
			var meta = save_info["metadata"]
			print("Slot %d: %s | Play time: %.1f hours" % [
				save_info["slot"],
				meta.get("save_date", "Unknown"),
				meta.get("play_time", 0) / 3600.0
			])
		else:
			print("Slot %d: Empty" % save_info["slot"])
