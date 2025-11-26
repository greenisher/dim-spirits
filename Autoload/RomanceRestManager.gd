extends Node
## Romance Rest System - Manages campfire rest scenes with romance options
##
## This system tracks which romance options the player has met and ensures
## each combination of characters has exactly 3 unique scenes that play sequentially
## and never repeat.

# ==================== CONFIGURATION ====================

const SCENES_PER_COMBINATION = 3

# Available romance options (must match RomanceManager keys)
const ROMANCE_OPTIONS = ["Asumi", "Rhea", "Skoll"]

# ==================== STATE ====================

# Track which romance options have been met
var met_romance_options: Array[String] = []

# Track scene progress: { "Asumi_Rhea": 2, "Skoll": 1, etc. }
# Key is sorted character names joined with underscore, value is scenes viewed (0-3)
var scene_progress: Dictionary = {}

# ==================== SIGNALS ====================

signal romance_option_met(character_name: String)
signal rest_scene_played(scene_id: String, characters: Array)
signal all_scenes_completed(combination: Array)

# ==================== INITIALIZATION ====================

func _ready() -> void:
	# Auto-discover met characters from GameState if available
	if has_node("/root/GameState"):
		_sync_met_characters()

# ==================== MEETING CHARACTERS ====================

## Call this when the player meets a romance option for the first time
func meet_romance_option(character_name: String) -> void:
	if not ROMANCE_OPTIONS.has(character_name):
		push_warning("Unknown romance option: %s" % character_name)
		return
	
	if met_romance_options.has(character_name):
		return  # Already met
	
	met_romance_options.append(character_name)
	
	# Also mark in GameState for persistence
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		game_state.mark_character_met(character_name)
	
	print("Met romance option: ", character_name)
	romance_option_met.emit(character_name)

## Get all romance options the player has met
func get_available_romance_options() -> Array[String]:
	return met_romance_options.duplicate()

## Check if a specific character has been met
func has_met_character(character_name: String) -> bool:
	return met_romance_options.has(character_name)

## Sync met characters from GameState
func _sync_met_characters() -> void:
	var game_state = get_node("/root/GameState")
	for character in ROMANCE_OPTIONS:
		if game_state.has_met_character(character) and not met_romance_options.has(character):
			met_romance_options.append(character)
			print("Synced met character from GameState: ", character)

# ==================== SCENE MANAGEMENT ====================

## Try to play a rest scene with the selected characters
## Returns the scene identifier if successful, empty string if no scenes available
func try_play_rest_scene(selected_characters: Array) -> String:
	# Validate all characters have been met
	for character in selected_characters:
		if not met_romance_options.has(character):
			push_error("Cannot invite %s - not yet met" % character)
			return ""
	
	# Get the combination key
	var combo_key = _get_combination_key(selected_characters)
	var current_scene = scene_progress.get(combo_key, 0)
	
	# Check if all scenes have been played
	if current_scene >= SCENES_PER_COMBINATION:
		return ""  # No more scenes for this combination
	
	# Increment scene counter
	scene_progress[combo_key] = current_scene + 1
	
	# Generate scene ID
	var scene_id = "%s_Scene%d" % [combo_key, current_scene + 1]
	
	print("Playing rest scene: ", scene_id)
	rest_scene_played.emit(scene_id, selected_characters)
	
	# Check if this was the last scene
	if scene_progress[combo_key] >= SCENES_PER_COMBINATION:
		all_scenes_completed.emit(selected_characters)
	
	return scene_id

## Check if a specific combination has any scenes remaining
func has_scenes_remaining(characters: Array) -> bool:
	var combo_key = _get_combination_key(characters)
	var current_scene = scene_progress.get(combo_key, 0)
	return current_scene < SCENES_PER_COMBINATION

## Get the current scene number for a combination (0-based)
func get_current_scene_number(characters: Array) -> int:
	var combo_key = _get_combination_key(characters)
	return scene_progress.get(combo_key, 0)

## Get all valid combinations that still have scenes available
func get_combinations_with_scenes_available() -> Array:
	var available_combos: Array = []
	var met_options = met_romance_options.duplicate()
	
	# Generate all possible combinations of met romance options
	for size in range(1, met_options.size() + 1):
		var combinations = _generate_combinations(met_options, size)
		for combo in combinations:
			if has_scenes_remaining(combo):
				available_combos.append(combo)
	
	return available_combos

# ==================== PROGRESS TRACKING ====================

## Get progress for all combinations (for UI/gallery)
func get_all_combination_progress() -> Array:
	var progress_list: Array = []
	var met_options = met_romance_options.duplicate()
	
	# Generate all possible combinations
	for size in range(1, met_options.size() + 1):
		var combinations = _generate_combinations(met_options, size)
		for combo in combinations:
			var combo_key = _get_combination_key(combo)
			var scenes_viewed = scene_progress.get(combo_key, 0)
			
			progress_list.append({
				"characters": combo,
				"scenes_viewed": scenes_viewed,
				"total_scenes": SCENES_PER_COMBINATION,
				"has_scenes_remaining": scenes_viewed < SCENES_PER_COMBINATION,
				"display_name": _get_display_name(combo),
				"progress_text": "%d/%d" % [scenes_viewed, SCENES_PER_COMBINATION]
			})
	
	return progress_list

## Get total number of scenes viewed across all combinations
func get_total_scenes_viewed() -> int:
	var total = 0
	for count in scene_progress.values():
		total += count
	return total

## Get total possible scenes
func get_total_possible_scenes() -> int:
	# Calculate based on number of met characters
	var num_met = met_romance_options.size()
	if num_met == 0:
		return 0
	
	# Solo scenes (n), duo scenes (n choose 2), trio scenes (n choose 3), etc.
	var total = 0
	for size in range(1, num_met + 1):
		var combos = _generate_combinations(met_romance_options, size)
		total += combos.size() * SCENES_PER_COMBINATION
	
	return total

# ==================== HELPER FUNCTIONS ====================

## Create a consistent key for a combination of characters
## Characters are sorted alphabetically to ensure consistency
func _get_combination_key(characters: Array) -> String:
	var sorted_chars = characters.duplicate()
	sorted_chars.sort()
	return "_".join(sorted_chars)

## Get display name for a combination
func _get_display_name(characters: Array) -> String:
	if characters.is_empty():
		return "None"
	return " & ".join(characters)

## Generate all combinations of a specific size from the list
func _generate_combinations(list: Array, size: int) -> Array:
	var result: Array = []
	
	if size == 0:
		result.append([])
		return result
	
	if list.is_empty():
		return result
	
	_generate_combinations_recursive(list, size, 0, [], result)
	return result

func _generate_combinations_recursive(
	remaining: Array, 
	size: int, 
	start: int, 
	current: Array, 
	result: Array
) -> void:
	if current.size() == size:
		result.append(current.duplicate())
		return
	
	for i in range(start, remaining.size()):
		current.append(remaining[i])
		_generate_combinations_recursive(remaining, size, i + 1, current, result)
		current.pop_back()

# ==================== SAVE/LOAD ====================

## Get save data for this system
func get_save_data() -> Dictionary:
	return {
		"met_romance_options": met_romance_options.duplicate(),
		"scene_progress": scene_progress.duplicate()
	}

## Load save data
func load_save_data(data: Dictionary) -> void:
	if data.has("met_romance_options"):
		# Clear and repopulate to handle Godot 4 typed array conversion
		met_romance_options.clear()
		for character in data["met_romance_options"]:
			met_romance_options.append(character)
	
	if data.has("scene_progress"):
		scene_progress = data["scene_progress"].duplicate()
	
	print("Loaded RomanceRest data: %d met characters, %d scene records" % [
		met_romance_options.size(),
		scene_progress.size()
	])

## Clear all data (for new game)
func clear_all_data() -> void:
	met_romance_options.clear()
	scene_progress.clear()
	print("RomanceRest data cleared")

# ==================== DEBUG ====================

func print_state_summary() -> void:
	print("=== Romance Rest System Summary ===")
	print("Met characters: ", met_romance_options)
	print("Total scenes viewed: %d / %d" % [get_total_scenes_viewed(), get_total_possible_scenes()])
	print("Scene progress:")
	for combo_key in scene_progress:
		print("  %s: %d/%d" % [combo_key, scene_progress[combo_key], SCENES_PER_COMBINATION])
