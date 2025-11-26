extends Node

# ==================== WORLD STATE ====================

# Track defeated enemies (by their unique IDs)
var defeated_enemies: Array[String] = []

# Track opened chests/containers (by position or ID)
var opened_chests: Array[String] = []

# Track unlocked areas/doors
var unlocked_areas: Array[String] = []

# Track picked up items (by their unique IDs)
var picked_up_items: Array[String] = []

# Story flags for branching narratives
var story_flags: Dictionary = {}

# ==================== PLAY TIME ====================

var play_time: float = 0.0
var session_start_time: float = 0.0

func _ready():
	session_start_time = Time.get_ticks_msec() / 1000.0

func _process(delta):
	play_time += delta

func get_formatted_play_time() -> String:
	var total_seconds = int(play_time)
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var seconds = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

# ==================== ENEMY TRACKING ====================

## Mark enemy as defeated
func mark_enemy_defeated(enemy_id: String) -> void:
	if not defeated_enemies.has(enemy_id):
		defeated_enemies.append(enemy_id)
		print("Enemy defeated: ", enemy_id)

## Check if enemy was defeated
func is_enemy_defeated(enemy_id: String) -> bool:
	return defeated_enemies.has(enemy_id)

## Remove enemy from defeated list (for respawning)
func respawn_enemy(enemy_id: String) -> void:
	defeated_enemies.erase(enemy_id)

# ==================== CHEST TRACKING ====================

## Mark chest as opened
func mark_chest_opened(chest_id: String) -> void:
	if not opened_chests.has(chest_id):
		opened_chests.append(chest_id)
		print("Chest opened: ", chest_id)

## Check if chest was opened
func is_chest_opened(chest_id: String) -> bool:
	return opened_chests.has(chest_id)

## Generate chest ID from position (helper)
func generate_chest_id(position: Vector3) -> String:
	return "chest_%d_%d_%d" % [int(position.x), int(position.y), int(position.z)]

# ==================== PICKUP ITEM TRACKING ====================

## Mark item as picked up
func mark_item_picked_up(item_id: String) -> void:
	if not picked_up_items.has(item_id):
		picked_up_items.append(item_id)
		print("Item picked up: ", item_id)

## Check if item was picked up
func is_item_picked_up(item_id: String) -> bool:
	return picked_up_items.has(item_id)

## Respawn item (remove from picked up list)
func respawn_item(item_id: String) -> void:
	picked_up_items.erase(item_id)
	print("Item respawned: ", item_id)

## Generate item ID from position (helper)
func generate_item_id(position: Vector3, item_name: String = "") -> String:
	if not item_name.is_empty():
		return "item_%s_%d_%d_%d" % [item_name, int(position.x), int(position.y), int(position.z)]
	return "item_%d_%d_%d" % [int(position.x), int(position.y), int(position.z)]

# ==================== AREA TRACKING ====================

## Unlock an area
func unlock_area(area_id: String) -> void:
	if not unlocked_areas.has(area_id):
		unlocked_areas.append(area_id)
		print("Area unlocked: ", area_id)

## Check if area is unlocked
func is_area_unlocked(area_id: String) -> bool:
	return unlocked_areas.has(area_id)

# ==================== STORY FLAGS ====================

## Set story flag
func set_story_flag(flag_name: String, value = true) -> void:
	story_flags[flag_name] = value
	print("Story flag set: ", flag_name, " = ", value)

## Get story flag
func get_story_flag(flag_name: String, default = false):
	return story_flags.get(flag_name, default)

## Check if story flag exists and is true
func has_story_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false) == true

## Remove story flag
func clear_story_flag(flag_name: String) -> void:
	story_flags.erase(flag_name)

# ==================== COMMON STORY EVENTS ====================

## Story progression flags
func start_quest(quest_id: String) -> void:
	set_story_flag("quest_" + quest_id + "_started")

func complete_quest(quest_id: String) -> void:
	set_story_flag("quest_" + quest_id + "_completed")

func is_quest_completed(quest_id: String) -> bool:
	return has_story_flag("quest_" + quest_id + "_completed")

## Character met flags
func mark_character_met(character_id: String) -> void:
	set_story_flag("met_" + character_id)

func has_met_character(character_id: String) -> bool:
	return has_story_flag("met_" + character_id)

# ==================== RESET/CLEAR ====================

## Clear all game state (new game)
func clear_all_state() -> void:
	defeated_enemies.clear()
	opened_chests.clear()
	unlocked_areas.clear()
	picked_up_items.clear()
	story_flags.clear()
	play_time = 0.0
	session_start_time = Time.get_ticks_msec() / 1000.0
	print("Game state cleared")

# ==================== DEBUG ====================

func print_state_summary() -> void:
	print("=== Game State Summary ===")
	print("Play time: ", get_formatted_play_time())
	print("Defeated enemies: ", defeated_enemies.size())
	print("Opened chests: ", opened_chests.size())
	print("Unlocked areas: ", unlocked_areas.size())
	print("Picked up items: ", picked_up_items.size())
	print("Story flags: ", story_flags.size())
