extends Node

## Scene Manager - Handles scene transitions with player data persistence

# ==================== PLAYER DATA PERSISTENCE ====================

var player_data: Dictionary = {
	"stats": null,  # CharacterStats resource (persists automatically)
	"current_hp": 100.0,
	"current_mana": 100.0,
	"position": Vector3.ZERO,
	"equipped_spells": [],
	"inventory_items": [],
	"active_buffs": [],
	"spell_cooldowns": {},
	"spawn_point_name": "SpawnPoint",
	"romance_states": {},
	"quest_progress": {},
}

var current_scene_path: String = ""
var is_transitioning: bool = false

# ==================== SIGNALS ====================

signal scene_transition_started(from_scene: String, to_scene: String)
signal scene_transition_finished(scene_path: String)
signal player_state_saved()
signal player_state_restored()

# ==================== INITIALIZATION ====================

func _ready() -> void:
	print("SceneManager initialized")

# ==================== PLAYER STATE MANAGEMENT ====================

func save_player_state(player: CharacterBody3D) -> void:
	"""Save all player state before scene transition"""
	if not player:
		push_warning("SceneManager: No player to save state from")
		return
	
	print("SceneManager: Saving player state...")
	
	# Save position
	player_data.position = player.global_position
	
	# Save CharacterStats resource (automatically persists)
	if player.has_meta("stats") or "stats" in player:
		player_data.stats = player.stats
	
	# Save current HP
	if player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		player_data.current_hp = health.current_health
	
	# Save current mana
	if player_data.stats:
		player_data.current_mana = player_data.stats.current_mana
	
	# Save equipped spells
	if player.has_node("MagicSystem"):
		var magic = player.get_node("MagicSystem")
		player_data.equipped_spells = magic.equipped_spells.duplicate()
		player_data.spell_cooldowns = magic.spell_cooldowns.duplicate()
	
	# Save inventory
	if player.has_node("Inventory"):
		var inventory = player.get_node("Inventory")
		player_data.inventory_items = inventory.items.duplicate() if "items" in inventory else []
	
	# Save any active buffs/debuffs
	# TODO: Add buff system saving if you implement it
	
	player_state_saved.emit()
	print("SceneManager: Player state saved successfully")

func restore_player_state(player: CharacterBody3D) -> void:
	"""Restore all player state after scene transition"""
	if not player:
		push_warning("SceneManager: No player to restore state to")
		return
	
	print("SceneManager: Restoring player state...")
	
	# Restore CharacterStats resource
	if player_data.stats:
		player.stats = player_data.stats
	
	# Restore current HP
	if player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		health.current_health = player_data.current_hp
		# Emit signal to update UI
		if health.has_signal("health_changed"):
			health.health_changed.emit(health.current_health, health.max_health)
	
	# Restore current mana
	if player.stats:
		player.stats.current_mana = player_data.current_mana
	
	# Restore equipped spells
	if player.has_node("MagicSystem"):
		var magic = player.get_node("MagicSystem")
		magic.equipped_spells = player_data.equipped_spells.duplicate()
		magic.spell_cooldowns = player_data.spell_cooldowns.duplicate()
		
		# Emit signals to update UI
		for i in magic.equipped_spells.size():
			if magic.equipped_spells[i]:
				magic.equipped_spell_changed.emit(i, magic.equipped_spells[i])
	
	# Restore inventory
	if player.has_node("Inventory"):
		var inventory = player.get_node("Inventory")
		if "items" in inventory:
			inventory.items = player_data.inventory_items.duplicate()
	
	player_state_restored.emit()
	print("SceneManager: Player state restored successfully")

# ==================== SCENE TRANSITION ====================

func change_scene(scene_path: String, spawn_point_name: String = "SpawnPoint") -> void:
	"""Change to a new scene while preserving player data"""
	if is_transitioning:
		push_warning("SceneManager: Transition already in progress")
		return
	
	if not ResourceLoader.exists(scene_path):
		push_error("SceneManager: Scene not found: " + scene_path)
		return
	
	is_transitioning = true
	var from_scene = current_scene_path
	
	print("SceneManager: Transitioning from '%s' to '%s'" % [from_scene, scene_path])
	scene_transition_started.emit(from_scene, scene_path)
	
	# Save current player state
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		save_player_state(player)
	
	# Store spawn point for new scene
	player_data.spawn_point_name = spawn_point_name
	
	# Change scene
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneManager: Failed to change scene: " + str(error))
		is_transitioning = false
		return
	
	current_scene_path = scene_path
	
	# Wait for scene to load
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for stability
	
	# Restore player state in new scene
	player = get_tree().get_first_node_in_group("Player")
	if player:
		restore_player_state(player)
		
		# Move player to spawn point
		move_player_to_spawn(player, spawn_point_name)
	else:
		push_warning("SceneManager: No player found in new scene")
	if has_node("/root/TransitionScreen"):
		await TransitionScreen.fade_in(0.5)
	is_transitioning = false
	scene_transition_finished.emit(scene_path)
	print("SceneManager: Transition complete")

func move_player_to_spawn(player: CharacterBody3D, spawn_name: String) -> void:
	"""Move player to specified spawn point"""
	var spawn = get_tree().root.find_child(spawn_name, true, false)
	
	if spawn and spawn is Node3D:
		player.global_position = spawn.global_position
		
		# Also set rotation if spawn point has it
		if spawn is Marker3D or spawn is Node3D:
			player.global_rotation = spawn.global_rotation
		
		print("SceneManager: Player moved to spawn point '%s'" % spawn_name)
	else:
		push_warning("SceneManager: Spawn point '%s' not found, using saved position" % spawn_name)
		player.global_position = player_data.position

# ==================== UTILITY FUNCTIONS ====================

func get_player() -> CharacterBody3D:
	"""Get the current player node"""
	return get_tree().get_first_node_in_group("Player")

func get_player_data() -> Dictionary:
	"""Get current player data dictionary"""
	return player_data

func set_player_data(key: String, value) -> void:
	"""Set a specific player data value"""
	player_data[key] = value

func clear_player_data() -> void:
	"""Clear all player data (use when starting new game)"""
	player_data = {
		"stats": null,
		"current_hp": 100.0,
		"current_mana": 100.0,
		"position": Vector3.ZERO,
		"equipped_spells": [],
		"inventory_items": [],
		"active_buffs": [],
		"spell_cooldowns": {},
		"spawn_point_name": "SpawnPoint",
		"romance_states": {},
		"quest_progress": {},
	}
	print("SceneManager: Player data cleared")

func get_current_scene_path() -> String:
	"""Get the path of the current scene"""
	return current_scene_path

func is_scene_transitioning() -> bool:
	"""Check if a scene transition is in progress"""
	return is_transitioning

# ==================== SAVE/LOAD INTEGRATION ====================

func get_save_data() -> Dictionary:
	"""Get data to save to file"""
	return {
		"player_data": player_data,
		"current_scene": current_scene_path,
	}

func load_save_data(data: Dictionary) -> void:
	"""Load data from save file"""
	if data.has("player_data"):
		player_data = data.player_data
	
	if data.has("current_scene"):
		current_scene_path = data.current_scene
	
	print("SceneManager: Save data loaded")
	
func start_new_game(first_level: String = "res://Levels/lostburg_ground.tscn", spawn_point: String = "StartPoint") -> void:
	"""Start a new game with clean state"""
	# Clear all persistent data
	clear_player_data()
	
	if has_node("/root/GameState"):
		GameState.clear_all_state()
	
	if has_node("/root/RelationshipManager"):
		RelationshipManager.clear_all_relationships()
	
	if has_node("/root/RomanceRestManager"):
		RomanceRestManager.clear_all_data()
	
	# Set initial player stats
	player_data.spawn_point_name = spawn_point
	
	# Load first level
	change_scene(first_level, spawn_point)
