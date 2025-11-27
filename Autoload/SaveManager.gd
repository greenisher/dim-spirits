extends Node

# Save file path
const SAVE_DIR = "user://saves/"
const SAVE_FILE_EXTENSION = ".save"

# Current save slot (1-3 for multiple save slots)
var current_save_slot: int = 1

# Maximum save slots
const MAX_SAVE_SLOTS = 3

func _ready():
	# Create save directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

# ==================== SAVE FUNCTIONS ====================

## Main save function - saves entire game state
func save_game(slot: int = current_save_slot) -> bool:
	var save_data = {}
	
	# Get player data
	save_data["player"] = get_player_data()
	
	# Get inventory data
	save_data["inventory"] = get_inventory_data()
	
	# Get ALL relationship data (Romance, Reputation, Relationship, and Romance Rest)
	save_data["relationships"] = get_all_relationship_data()
	
	# Get world state (quest progress, defeated enemies, opened chests, etc.)
	save_data["world_state"] = get_world_state()
	
	# Save metadata
	save_data["metadata"] = {
		"save_date": Time.get_datetime_string_from_system(),
		"play_time": get_play_time(),
		"game_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"slot": slot
	}
	
	# Write to file
	var save_path = get_save_path(slot)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file == null:
		push_error("Failed to open save file: " + save_path)
		return false
	
	# Convert to JSON and save
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("Game saved to slot ", slot, " at ", save_path)
	return true

## Save player data (stats, position, health, etc.)
func get_player_data() -> Dictionary:
	var player = get_player_node()
	if not player:
		return {}
	
	var data = {
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z
		},
		"rotation": player.rotation.y,
		"current_scene": get_tree().current_scene.scene_file_path,
	}
	
	# Save stats if available
	if player.has_node("Stats") or player.get("stats"):
		var stats = player.stats if player.get("stats") else player.get_node("Stats")
		data["stats"] = {
			"level": stats.level,
			"xp": stats.xp,
			"strength": stats.strength.ability_score,
			"endurance": stats.endurance.ability_score,
			"agility": stats.agility.ability_score,
			"intelligence": stats.intelligence.ability_score,
		}
	
	# Save health if available
	if player.has_node("HealthComponent") or player.get("health_component"):
		var health = player.health_component if player.get("health_component") else player.get_node("HealthComponent")
		data["health"] = {
			"current": health.current_health,
			"maximum": health.max_health
		}
	
	return data

## Save inventory data
func get_inventory_data() -> Dictionary:
	if not has_node("/root/InventoryManager"):
		return {}
	
	var inv_mgr = get_node("/root/InventoryManager")
	var inventory_items = []
	
	# Save each item in inventory
	for stack in inv_mgr.inventory:
		inventory_items.append({
			"item_id": stack.item.item_id if stack.item.get("item_id") else stack.item.item_name,
			"quantity": stack.quantity
		})
	
	# Save equipped items
	var equipped = {}
	if inv_mgr.get("equipped_weapon"):
		equipped["weapon"] = inv_mgr.equipped_weapon.item_id if inv_mgr.equipped_weapon else null
	if inv_mgr.get("equipped_armor"):
		equipped["armor"] = inv_mgr.equipped_armor.item_id if inv_mgr.equipped_armor else null
	
	return {
		"items": inventory_items,
		"equipped": equipped
	}

## Save ALL relationship data (RomanceManager, ReputationManager, RelationshipManager, RomanceRestManager)
func get_all_relationship_data() -> Dictionary:
	var data = {}
	
	# Save RomanceManager data
	if has_node("/root/RomanceManager"):
		var rom_mgr = get_node("/root/RomanceManager")
		data["romance"] = rom_mgr.romance_partner.duplicate()
		print("Saved ", data["romance"].size(), " romance relationships")
	
	# Save ReputationManager data
	if has_node("/root/ReputationManager"):
		var rep_mgr = get_node("/root/ReputationManager")
		data["reputation"] = rep_mgr.reputations.duplicate()
		print("Saved ", data["reputation"].size(), " reputation values")
	
	# Save RelationshipManager data (trust, fear, friendship, flags)
	if has_node("/root/RelationshipManager"):
		var rel_mgr = get_node("/root/RelationshipManager")
		data["npc_relationships"] = rel_mgr.get_all_relationships()
		print("Saved ", rel_mgr.relationships.size(), " NPC relationship records")
	
	# Save RomanceRestManager data (NEW - Romance Rest System)
	if has_node("/root/RomanceRestManager"):
		var rest_mgr = get_node("/root/RomanceRestManager")
		data["romance_rest"] = rest_mgr.get_save_data()
		print("Saved RomanceRest data: ", data["romance_rest"]["met_romance_options"].size(), " met characters, ", 
			  rest_mgr.get_total_scenes_viewed(), " scenes viewed")
	
	return data

## Save world state (quests, defeated enemies, opened chests, etc.)
func get_world_state() -> Dictionary:
	var state = {
		"quests": {},
		"defeated_enemies": [],
		"opened_chests": [],
		"unlocked_areas": [],
		"story_flags": {}
	}
	
	# Save quest progress if QuestManager exists
	if has_node("/root/QuestManager"):
		var quest_mgr = get_node("/root/QuestManager")
		state["quests"] = quest_mgr.get_quest_states() if quest_mgr.has_method("get_quest_states") else {}
	
	# Save defeated enemies if tracking
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		if game_state.get("defeated_enemies"):
			state["defeated_enemies"] = game_state.defeated_enemies
		if game_state.get("opened_chests"):
			state["opened_chests"] = game_state.opened_chests
		if game_state.get("unlocked_areas"):
			state["unlocked_areas"] = game_state.unlocked_areas
		if game_state.get("picked_up_items"):
			state["picked_up_items"] = game_state.picked_up_items
		if game_state.get("story_flags"):
			state["story_flags"] = game_state.story_flags
	
	return state

# ==================== LOAD FUNCTIONS ====================

## Main load function - loads entire game state
func load_game(slot: int = current_save_slot) -> bool:
	var save_path = get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist: " + save_path)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: " + save_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse save file JSON")
		return false
	
	var save_data = json.data
	
	# Load player data
	if save_data.has("player"):
		load_player_data(save_data["player"])
	
	# Load inventory
	if save_data.has("inventory"):
		load_inventory_data(save_data["inventory"])
	
	# Load ALL relationship data
	if save_data.has("relationships"):
		load_all_relationship_data(save_data["relationships"])
	
	# Load world state
	if save_data.has("world_state"):
		load_world_state(save_data["world_state"])
	
	current_save_slot = slot
	print("Game loaded from slot ", slot)
	return true

## Load player data
func load_player_data(data: Dictionary) -> void:
	# Load scene first if different
	if data.has("current_scene"):
		var current_scene_path = get_tree().current_scene.scene_file_path
		if current_scene_path != data["current_scene"]:
			get_tree().change_scene_to_file(data["current_scene"])
			await get_tree().process_frame
			await get_tree().process_frame  # Wait for scene to fully load
	
	var player = get_player_node()
	if not player:
		push_error("Player node not found")
		return
	
	# Restore position
	if data.has("position"):
		player.global_position = Vector3(
			data["position"]["x"],
			data["position"]["y"],
			data["position"]["z"]
		)
	
	# Restore rotation
	if data.has("rotation"):
		player.rotation.y = data["rotation"]
	
	# Restore stats
	if data.has("stats") and player.get("stats"):
		var stats = player.stats
		stats.level = data["stats"]["level"]
		stats.xp = data["stats"]["xp"]
		stats.strength.ability_score = data["stats"]["strength"]
		stats.endurance.ability_score = data["stats"]["endurance"]
		stats.agility.ability_score = data["stats"]["agility"]
		stats.intelligence.ability_score = data["stats"]["intelligence"]
		stats.update_derived_stats()
	
	# Restore health
	if data.has("health") and player.get("health_component"):
		var health = player.health_component
		health.max_health = data["health"]["maximum"]
		health.current_health = data["health"]["current"]

## Load inventory data
func load_inventory_data(data: Dictionary) -> void:
	if not has_node("/root/InventoryManager"):
		return
	
	var inv_mgr = get_node("/root/InventoryManager")
	
	# Clear current inventory
	inv_mgr.inventory.clear()
	
	# Load items
	if data.has("items"):
		for item_data in data["items"]:
			var item = load_item_from_id(item_data["item_id"])
			if item:
				inv_mgr.add_item(item, item_data["quantity"])
	
	# Load equipped items
	if data.has("equipped"):
		if data["equipped"].has("weapon") and data["equipped"]["weapon"]:
			var weapon = load_item_from_id(data["equipped"]["weapon"])
			if weapon:
				inv_mgr.equip_item(weapon)
		if data["equipped"].has("armor") and data["equipped"]["armor"]:
			var armor = load_item_from_id(data["equipped"]["armor"])
			if armor:
				inv_mgr.equip_item(armor)

## Load ALL relationship data (RomanceManager, ReputationManager, RelationshipManager, RomanceRestManager)
func load_all_relationship_data(data: Dictionary) -> void:
	# Load RomanceManager data
	if data.has("romance") and has_node("/root/RomanceManager"):
		var rom_mgr = get_node("/root/RomanceManager")
		rom_mgr.romance_partner = data["romance"].duplicate()
		print("Loaded ", rom_mgr.romance_partner.size(), " romance relationships")
	
	# Load ReputationManager data
	if data.has("reputation") and has_node("/root/ReputationManager"):
		var rep_mgr = get_node("/root/ReputationManager")
		rep_mgr.reputations = data["reputation"].duplicate()
		print("Loaded ", rep_mgr.reputations.size(), " reputation values")
	
	# Load RelationshipManager data
	if data.has("npc_relationships") and has_node("/root/RelationshipManager"):
		var rel_mgr = get_node("/root/RelationshipManager")
		rel_mgr.load_relationships(data["npc_relationships"])
	
	# Load RomanceRestManager data (NEW - Romance Rest System)
	if data.has("romance_rest") and has_node("/root/RomanceRestManager"):
		var rest_mgr = get_node("/root/RomanceRestManager")
		rest_mgr.load_save_data(data["romance_rest"])
		print("Loaded RomanceRest data: ", rest_mgr.get_available_romance_options().size(), " met characters, ",
			  rest_mgr.get_total_scenes_viewed(), " scenes viewed")

## Load world state
func load_world_state(data: Dictionary) -> void:
	# Load quests
	if data.has("quests") and has_node("/root/QuestManager"):
		var quest_mgr = get_node("/root/QuestManager")
		if quest_mgr.has_method("load_quest_states"):
			quest_mgr.load_quest_states(data["quests"])
	
	# Load game state
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		
		# Handle typed arrays properly (Godot 4)
		if data.has("defeated_enemies"):
			game_state.defeated_enemies.clear()
			for enemy_id in data["defeated_enemies"]:
				game_state.defeated_enemies.append(enemy_id)
		
		if data.has("opened_chests"):
			game_state.opened_chests.clear()
			for chest_id in data["opened_chests"]:
				game_state.opened_chests.append(chest_id)
		
		if data.has("unlocked_areas"):
			game_state.unlocked_areas.clear()
			for area_id in data["unlocked_areas"]:
				game_state.unlocked_areas.append(area_id)
		
		if data.has("picked_up_items"):
			game_state.picked_up_items.clear()
			for item_id in data["picked_up_items"]:
				game_state.picked_up_items.append(item_id)
		
		# Dictionary can be assigned directly
		if data.has("story_flags"):
			game_state.story_flags = data["story_flags"].duplicate()

# ==================== UTILITY FUNCTIONS ====================

## Get save file path for a slot
func get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_" + str(slot) + SAVE_FILE_EXTENSION

## Check if a save exists
func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

## Delete a save
func delete_save(slot: int) -> bool:
	var save_path = get_save_path(slot)
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(SAVE_DIR)
		return dir.remove(save_path.get_file()) == OK
	return false

## Get save metadata without loading full game (ENHANCED - now includes romance rest stats)
func get_save_metadata(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {}
	
	var file = FileAccess.open(get_save_path(slot), FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var save_data = json.data
	var metadata = save_data.get("metadata", {})
	
	# Add romance rest stats to metadata for display in save slot UI
	if save_data.has("relationships") and save_data["relationships"].has("romance_rest"):
		var rest_data = save_data["relationships"]["romance_rest"]
		var met_count = rest_data.get("met_romance_options", []).size()
		var scene_count = 0
		for count in rest_data.get("scene_progress", {}).values():
			scene_count += count
		
		metadata["romance_rest_met"] = met_count
		metadata["romance_rest_scenes"] = scene_count
	
	return metadata

## Get list of all save slots with metadata
func get_all_saves() -> Array:
	var saves = []
	for i in range(1, MAX_SAVE_SLOTS + 1):
		var save_info = {
			"slot": i,
			"exists": save_exists(i),
			"metadata": get_save_metadata(i) if save_exists(i) else {}
		}
		saves.append(save_info)
	return saves

## Get player node (customize based on your scene structure)
func get_player_node():
	# Try common player locations
	if has_node("/root/Main/Player"):
		return get_node("/root/Main/Player")
	if has_node("/root/Game/Player"):
		return get_node("/root/Game/Player")
	
	# Search current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		var player = current_scene.find_child("Player", true, false)
		if player:
			return player
	
	return null

## Load item from ID (you'll need to implement this based on your item system)
func load_item_from_id(item_id: String):
	# Option 1: Load from resource path
	var item_path = "res://items/" + item_id + ".tres"
	if ResourceLoader.exists(item_path):
		return load(item_path)
	
	# Option 2: Use ItemDatabase singleton if you have one
	if has_node("/root/ItemDatabase"):
		var item_db = get_node("/root/ItemDatabase")
		if item_db.has_method("get_item_by_id"):
			return item_db.get_item_by_id(item_id)
	
	push_warning("Could not load item: " + item_id)
	return null

func get_play_time() -> float:
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		if "play_time" in game_state:
			return game_state.play_time
	return 0.0

# ==================== AUTO-SAVE ====================

## Auto-save timer
var auto_save_timer: Timer

## Enable auto-save every X seconds
func enable_auto_save(interval_seconds: float = 300.0) -> void:
	if auto_save_timer:
		return  # Already enabled
	
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = interval_seconds
	auto_save_timer.one_shot = false
	auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(auto_save_timer)
	auto_save_timer.start()
	print("Auto-save enabled (every ", interval_seconds, " seconds)")

func _on_auto_save_timeout() -> void:
	print("Auto-saving...")
	save_game(current_save_slot)

## Disable auto-save
func disable_auto_save() -> void:
	if auto_save_timer:
		auto_save_timer.queue_free()
		auto_save_timer = null
