extends Resource
class_name NPCSpawnCondition

## Unique identifier for this spawn condition
@export var condition_id: String = ""

## Priority (higher = checked first, allows overriding default spawns)
@export var priority: int = 0

## Description for editor (not used at runtime)
@export_multiline var description: String = ""

# ==================== LOCATION SETTINGS ====================

@export_group("Spawn Location")
## Scene path where NPC should spawn
@export var spawn_scene: String = ""

## Position in the scene (set to Vector3.ZERO to use spawner's position)
@export var spawn_position: Vector3 = Vector3.ZERO

## Rotation in degrees
@export var spawn_rotation_y: float = 0.0

# ==================== STORY/QUEST CONDITIONS ====================

@export_group("Story Conditions")
## Required story flags (ALL must be true)
@export var required_story_flags: Array[String] = []

## Forbidden story flags (NONE can be true)
@export var forbidden_story_flags: Array[String] = []

## Required defeated enemies
@export var required_defeated_enemies: Array[String] = []

## Required opened chests
@export var required_opened_chests: Array[String] = []

## Required unlocked areas
@export var required_unlocked_areas: Array[String] = []

## Minimum player level
@export var min_player_level: int = 0

## Maximum player level (0 = no max)
@export var max_player_level: int = 0

# ==================== RELATIONSHIP CONDITIONS ====================

@export_group("Relationship Conditions")
## NPC ID for relationship checks (usually the spawned NPC's ID)
@export var npc_id: String = ""

## Minimum romance level (0-100)
@export var min_romance_level: int = 0

## Minimum friendship level (0-100)
@export var min_friendship_level: int = 0

## Minimum trust level (0-100)
@export var min_trust_level: int = 0

## Minimum reputation (can be negative)
@export var min_reputation: int = -100

## Has been invited to campfire (uses RomanceRestManager)
@export var requires_campfire_invitation: bool = false

## Minimum number of campfire scenes viewed
@export var min_campfire_scenes: int = 0

# ==================== TIME CONDITIONS ====================

@export_group("Time Conditions")
## Only spawn during specific time range (if your game has day/night cycle)
@export var time_restricted: bool = false
@export var min_hour: int = 0
@export var max_hour: int = 24

## Only spawn on specific days (if your game has a calendar)
@export var day_restricted: bool = false
@export var allowed_days: Array[int] = []

# ==================== CUSTOM CONDITIONS ====================

@export_group("Custom Conditions")
## Custom condition keys to check in GameState.story_flags
## Example: ["boss_defeated", "secret_revealed"]
@export var custom_conditions: Dictionary = {}

# ==================== DIALOGUE OVERRIDE ====================

@export_group("Dialogue Configuration")
## Override NPC's dialogue tree for this spawn condition
@export var override_dialogue_tree: Resource = null

## Override NPC's greeting text
@export var override_greeting: String = ""

## Override NPC's portrait
@export var override_portrait: Texture2D = null

# ==================== SPAWN BEHAVIOR ====================

@export_group("Spawn Behavior")
## Should this spawn be permanent once conditions are met?
@export var permanent_spawn: bool = false

## Should NPC despawn if conditions are no longer met?
@export var despawn_when_invalid: bool = false

## Cooldown in seconds before checking conditions again
@export var check_cooldown: float = 5.0

# ==================== CONDITION EVALUATION ====================

## Check if all conditions are met
func evaluate_conditions() -> bool:
	# Check scene requirement
	if not spawn_scene.is_empty():
		var current_scene = Engine.get_main_loop().current_scene.scene_file_path
		if current_scene != spawn_scene:
			return false
	
	# Check story flags
	if not _check_story_flags():
		return false
	
	# Check game state conditions
	if not _check_game_state():
		return false
	
	# Check player level
	if not _check_player_level():
		return false
	
	# Check relationship conditions
	if not _check_relationships():
		return false
	
	# Check romance rest conditions
	if not _check_romance_rest():
		return false
	
	# Check time conditions
	if not _check_time_conditions():
		return false
	
	# Check custom conditions
	if not _check_custom_conditions():
		return false
	
	return true

func _check_story_flags() -> bool:
	var game_state = _get_autoload("GameState")
	if not game_state:
		return true
	
	# Check required flags
	for flag in required_story_flags:
		if not game_state.has_story_flag(flag):
			return false
	
	# Check forbidden flags
	for flag in forbidden_story_flags:
		if game_state.has_story_flag(flag):
			return false
	
	return true

func _check_game_state() -> bool:
	var game_state = _get_autoload("GameState")
	if not game_state:
		return true
	
	# Check defeated enemies
	for enemy_id in required_defeated_enemies:
		if not game_state.is_enemy_defeated(enemy_id):
			return false
	
	# Check opened chests
	for chest_id in required_opened_chests:
		if not game_state.is_chest_opened(chest_id):
			return false
	
	# Check unlocked areas
	for area_id in required_unlocked_areas:
		if not game_state.is_area_unlocked(area_id):
			return false
	
	return true

func _check_player_level() -> bool:
	# Get player node
	var player = _get_player()
	if not player or not player.get("stats"):
		return true
	
	var level = player.stats.level
	
	if min_player_level > 0 and level < min_player_level:
		return false
	
	if max_player_level > 0 and level > max_player_level:
		return false
	
	return true

func _check_relationships() -> bool:
	if npc_id.is_empty():
		return true
	
	var rel_mgr = _get_autoload("RelationshipManager")
	if not rel_mgr:
		return true
	
	# Check romance level
	if min_romance_level > 0:
		if not rel_mgr.is_romance_option(npc_id):
			return false
		if rel_mgr.get_romance(npc_id) < min_romance_level:
			return false
	
	# Check friendship
	if min_friendship_level > 0:
		if rel_mgr.get_stat(npc_id, "friendship") < min_friendship_level:
			return false
	
	# Check trust
	if min_trust_level > 0:
		if rel_mgr.get_stat(npc_id, "trust") < min_trust_level:
			return false
	
	# Check reputation
	if min_reputation > -100:
		if rel_mgr.get_reputation(npc_id) < min_reputation:
			return false
	
	return true

func _check_romance_rest() -> bool:
	if not requires_campfire_invitation and min_campfire_scenes == 0:
		return true
	
	if npc_id.is_empty():
		return true
	
	var rest_mgr = _get_autoload("RomanceRestManager")
	if not rest_mgr:
		return true
	
	# Check if player has met this NPC
	if requires_campfire_invitation:
		if not rest_mgr.has_met_character(npc_id):
			return false
	
	# Check campfire scenes viewed
	if min_campfire_scenes > 0:
		if rest_mgr.get_scenes_viewed(npc_id) < min_campfire_scenes:
			return false
	
	return true

func _check_time_conditions() -> bool:
	if not time_restricted and not day_restricted:
		return true
	
	# Get time from GameState or TimeManager if you have one
	var game_state = _get_autoload("GameState")
	if not game_state:
		return true
	
	# Check hour restriction
	if time_restricted and game_state.has("current_hour"):
		var hour = game_state.current_hour
		if hour < min_hour or hour > max_hour:
			return false
	
	# Check day restriction
	if day_restricted and game_state.has("current_day"):
		var day = game_state.current_day
		if not day in allowed_days:
			return false
	
	return true

func _check_custom_conditions() -> bool:
	if custom_conditions.is_empty():
		return true
	
	var game_state = _get_autoload("GameState")
	if not game_state:
		return true
	
	for key in custom_conditions.keys():
		var expected_value = custom_conditions[key]
		var actual_value = game_state.get_story_flag(key)
		
		if actual_value != expected_value:
			return false
	
	return true

## Helper function to get autoload nodes from a Resource
func _get_autoload(autoload_name: String) -> Node:
	var tree = Engine.get_main_loop()
	if not tree:
		return null
	var root = tree.root
	if not root:
		return null
	return root.get_node_or_null("/root/" + autoload_name)

func _get_player() -> Node:
	var tree = Engine.get_main_loop()
	if not tree:
		return null
	
	# Try to find player in current scene
	var current_scene = tree.current_scene
	if current_scene:
		var player = current_scene.find_child("Player", true, false)
		if player:
			return player
	
	# Try common player locations
	var root = tree.root
	if not root:
		return null
	
	var main = root.get_node_or_null("/root/Main")
	if main:
		var player = main.find_child("Player", true, false)
		if player:
			return player
	
	var game = root.get_node_or_null("/root/Game")
	if game:
		var player = game.find_child("Player", true, false)
		if player:
			return player
	
	return null
