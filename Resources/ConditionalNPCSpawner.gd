extends Node3D
class_name ConditionalNPCSpawner

@export var npc_scene: PackedScene

@export var spawner_id: String = ""

## NPC ID (used for relationship tracking)
@export var npc_id: String = ""

## Default NPC name
@export var default_npc_name: String = "NPC"

## Spawn conditions (ordered by priority)
@export var spawn_conditions: Array[Resource] = []

## Fallback condition if none match (always spawn here with default settings)
@export var use_fallback: bool = true

## Visual marker in editor
@export var show_debug_marker: bool = true

@export_group("Default Configuration")
## Default dialogue tree
@export var default_dialogue_tree: Resource = null

## Default greeting
@export_multiline var default_greeting: String = "Hello!"

## Default portrait
@export var default_portrait: Texture2D = null

@export_group("Spawn Behavior")
## Check conditions every frame (expensive, but responsive)
@export var continuous_check: bool = false

## Check cooldown in seconds (if not continuous)
@export var check_interval: float = 5.0

## Auto-spawn on ready
@export var auto_spawn_on_ready: bool = true

# Runtime state
var spawned_npc: NPC = null
var current_condition: NPCSpawnCondition = null
var last_check_time: float = 0.0
var is_initialized: bool = false

func _ready() -> void:
	# Register with NPCSpawnManager
	if has_node("/root/NPCSpawnManager"):
		var spawn_manager = get_node("/root/NPCSpawnManager")
		spawn_manager.register_spawner(self)
	
	# Sort conditions by priority
	_sort_conditions()
	
	# Draw debug marker
	if show_debug_marker and Engine.is_editor_hint():
		_draw_debug_marker()
	
	is_initialized = true
	
	if auto_spawn_on_ready:
		await get_tree().process_frame
		check_and_spawn()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not continuous_check:
		return
	
	check_and_spawn()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if continuous_check:
		return
	
	# Check on interval
	last_check_time += delta
	if last_check_time >= check_interval:
		last_check_time = 0.0
		check_and_spawn()

## Main function to check conditions and spawn/despawn NPC
func check_and_spawn() -> void:
	if not is_initialized:
		return
	
	# Find best matching condition
	var best_condition = _find_best_condition()
	
	# If condition changed, handle respawn
	if best_condition != current_condition:
		_handle_condition_change(best_condition)
	
	# If no NPC spawned but should be, spawn it
	if not spawned_npc and best_condition:
		_spawn_npc(best_condition)
	
	# If NPC spawned but condition no longer valid, despawn
	if spawned_npc and not best_condition:
		_despawn_npc()
	
	# If condition has despawn_when_invalid, check if still valid
	if spawned_npc and current_condition and current_condition.despawn_when_invalid:
		if not current_condition.is_met():
			_despawn_npc()

## Find the best matching condition based on priority
func _find_best_condition() -> NPCSpawnCondition:
	for condition in spawn_conditions:
		if condition and condition.is_met():
			return condition
	
	# No condition matched, use fallback
	if use_fallback:
		return _create_fallback_condition()
	
	return null

## Sort conditions by priority (highest first)
func _sort_conditions() -> void:
	spawn_conditions.sort_custom(func(a, b):
		return a.priority > b.priority
	)

## Handle condition change (respawn NPC with new settings)
func _handle_condition_change(new_condition: NPCSpawnCondition) -> void:
	if spawned_npc:
		# Despawn old NPC
		_despawn_npc()
	
	current_condition = new_condition
	
	# Spawn with new condition
	if new_condition:
		_spawn_npc(new_condition)

## Spawn NPC with given condition
func _spawn_npc(condition: NPCSpawnCondition) -> void:
	if not npc_scene:
		push_error("ConditionalNPCSpawner: No NPC scene set!")
		return
	
	# Instantiate NPC
	spawned_npc = npc_scene.instantiate() as NPC
	if not spawned_npc:
		push_error("ConditionalNPCSpawner: Failed to instantiate NPC!")
		return
	
	# Add to scene
	add_child(spawned_npc)
	
	# Apply position and rotation
	var spawn_pos = condition.spawn_position if condition.spawn_position != Vector3.ZERO else Vector3.ZERO
	spawned_npc.position = spawn_pos
	spawned_npc.rotation.y = deg_to_rad(condition.spawn_rotation_y)
	
	# Apply NPC configuration
	_configure_npc(spawned_npc, condition)
	
	# Store current condition
	current_condition = condition
	
	print("ConditionalNPCSpawner: Spawned NPC '%s' at %s" % [spawned_npc.npc_name, global_position])
	
	# Emit signal if NPCSpawnManager exists
	if has_node("/root/NPCSpawnManager"):
		var spawn_manager = get_node("/root/NPCSpawnManager")
		spawn_manager.npc_spawned.emit(spawner_id, spawned_npc, condition)

## Configure spawned NPC with condition overrides
func _configure_npc(npc: NPC, condition: NPCSpawnCondition) -> void:
	# Set NPC name
	if not default_npc_name.is_empty():
		npc.npc_name = default_npc_name
	
	# Override with condition settings
	if condition.override_dialogue_tree:
		npc.dialogue_tree = condition.override_dialogue_tree
	elif default_dialogue_tree:
		npc.dialogue_tree = default_dialogue_tree
	
	if not condition.override_greeting.is_empty():
		npc.greeting = condition.override_greeting
	elif not default_greeting.is_empty():
		npc.greeting = default_greeting
	
	if condition.override_portrait:
		npc.portrait = condition.override_portrait
	elif default_portrait:
		npc.portrait = default_portrait
	
	# Store NPC ID for relationship tracking
	if not npc_id.is_empty():
		npc.set_meta("npc_id", npc_id)

## Despawn NPC
func _despawn_npc() -> void:
	if not spawned_npc:
		return
	
	print("ConditionalNPCSpawner: Despawning NPC '%s'" % spawned_npc.npc_name)
	
	# Emit signal if NPCSpawnManager exists
	if has_node("/root/NPCSpawnManager"):
		var spawn_manager = get_node("/root/NPCSpawnManager")
		spawn_manager.npc_despawned.emit(spawner_id, spawned_npc)
	
	spawned_npc.queue_free()
	spawned_npc = null
	current_condition = null

## Force check and respawn (useful for when player loads game)
func force_refresh() -> void:
	check_and_spawn()

## Create fallback condition
func _create_fallback_condition() -> NPCSpawnCondition:
	var condition = NPCSpawnCondition.new()
	condition.condition_id = "fallback"
	condition.priority = -999
	condition.spawn_position = Vector3.ZERO
	condition.spawn_rotation_y = 0.0
	return condition

## Draw debug marker in editor
func _draw_debug_marker() -> void:
	# This would need to be implemented with ImmediateMesh or similar
	# For now, just print debug info
	pass

## Get current spawned NPC
func get_spawned_npc() -> NPC:
	return spawned_npc

## Get current condition
func get_current_condition() -> NPCSpawnCondition:
	return current_condition

## Check if NPC is currently spawned
func is_npc_spawned() -> bool:
	return spawned_npc != null

## Manual spawn (ignores conditions)
func manual_spawn() -> void:
	if spawned_npc:
		return
	
	var fallback = _create_fallback_condition()
	_spawn_npc(fallback)

## Manual despawn
func manual_despawn() -> void:
	_despawn_npc()
