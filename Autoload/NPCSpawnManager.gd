extends Node

## Emitted when an NPC is spawned by any spawner
signal npc_spawned(spawner_id: String, npc: NPC, condition: NPCSpawnCondition)

## Emitted when an NPC is despawned by any spawner
signal npc_despawned(spawner_id: String, npc: NPC)

## Emitted when scene changes and spawners need refresh
signal spawners_refreshed()

## All registered spawners
var spawners: Dictionary = {}

## Currently spawned NPCs by spawner_id
var spawned_npcs: Dictionary = {}

## Track which conditions were last used for each spawner
var spawner_conditions: Dictionary = {}

func _ready() -> void:
	# Connect to scene changes
	get_tree().node_added.connect(_on_node_added)
	
	# Listen for game load
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		if save_mgr.has_signal("game_loaded"):
			save_mgr.game_loaded.connect(_on_game_loaded)

func _on_node_added(node: Node) -> void:
	# Auto-register spawners as they're added
	if node is ConditionalNPCSpawner:
		register_spawner(node)

## Register a spawner
func register_spawner(spawner: ConditionalNPCSpawner) -> void:
	if spawner.spawner_id.is_empty():
		push_warning("NPCSpawnManager: Spawner has no ID, generating one")
		spawner.spawner_id = "spawner_" + str(spawner.get_instance_id())
	
	spawners[spawner.spawner_id] = spawner
	print("NPCSpawnManager: Registered spawner '%s'" % spawner.spawner_id)

## Unregister a spawner
func unregister_spawner(spawner_id: String) -> void:
	if spawners.has(spawner_id):
		spawners.erase(spawner_id)
		spawned_npcs.erase(spawner_id)
		spawner_conditions.erase(spawner_id)
		print("NPCSpawnManager: Unregistered spawner '%s'" % spawner_id)

## Get a spawner by ID
func get_spawner(spawner_id: String) -> ConditionalNPCSpawner:
	return spawners.get(spawner_id, null)

## Get all spawners
func get_all_spawners() -> Array:
	return spawners.values()

## Get spawned NPC by spawner ID
func get_spawned_npc(spawner_id: String) -> NPC:
	return spawned_npcs.get(spawner_id, null)

## Get all currently spawned NPCs
func get_all_spawned_npcs() -> Array:
	return spawned_npcs.values()

## Refresh all spawners (useful after loading game or major state change)
func refresh_all_spawners() -> void:
	print("NPCSpawnManager: Refreshing all spawners")
	for spawner in spawners.values():
		if is_instance_valid(spawner):
			spawner.force_refresh()
	spawners_refreshed.emit()

## Refresh specific spawner
func refresh_spawner(spawner_id: String) -> void:
	var spawner = get_spawner(spawner_id)
	if spawner:
		spawner.force_refresh()

## Find spawners for a specific NPC ID
func get_spawners_for_npc(npc_id: String) -> Array:
	var result = []
	for spawner in spawners.values():
		if spawner.npc_id == npc_id:
			result.append(spawner)
	return result

## Check if an NPC is currently spawned anywhere
func is_npc_spawned(npc_id: String) -> bool:
	for spawner in spawners.values():
		if spawner.npc_id == npc_id and spawner.is_npc_spawned():
			return true
	return false

## Get the location where an NPC is currently spawned
func get_npc_location(npc_id: String) -> Vector3:
	for spawner in spawners.values():
		if spawner.npc_id == npc_id and spawner.is_npc_spawned():
			return spawner.global_position
	return Vector3.ZERO

## Despawn all NPCs with a specific NPC ID
func despawn_npc_by_id(npc_id: String) -> void:
	for spawner in spawners.values():
		if spawner.npc_id == npc_id:
			spawner.manual_despawn()

## Force spawn an NPC at a specific spawner (ignores conditions)
func force_spawn_at(spawner_id: String) -> void:
	var spawner = get_spawner(spawner_id)
	if spawner:
		spawner.manual_spawn()

## Called when game is loaded
func _on_game_loaded() -> void:
	print("NPCSpawnManager: Game loaded, refreshing spawners")
	# Wait a frame for all managers to finish loading
	await get_tree().process_frame
	refresh_all_spawners()

## Debug: Print all spawner states
func debug_print_spawners() -> void:
	print("=== NPCSpawnManager Debug ===")
	print("Total spawners: ", spawners.size())
	for spawner_id in spawners:
		var spawner = spawners[spawner_id]
		if is_instance_valid(spawner):
			print("  Spawner '%s':" % spawner_id)
			print("    NPC ID: ", spawner.npc_id)
			print("    Spawned: ", spawner.is_npc_spawned())
			if spawner.is_npc_spawned():
				print("    NPC Name: ", spawner.get_spawned_npc().npc_name)
				print("    Position: ", spawner.global_position)
			if spawner.get_current_condition():
				print("    Condition: ", spawner.get_current_condition().condition_id)

## Get statistics about spawned NPCs
func get_spawn_stats() -> Dictionary:
	var stats = {
		"total_spawners": spawners.size(),
		"active_spawns": 0,
		"npcs_by_scene": {}
	}
	
	for spawner in spawners.values():
		if is_instance_valid(spawner) and spawner.is_npc_spawned():
			stats["active_spawns"] += 1
	
	return stats
