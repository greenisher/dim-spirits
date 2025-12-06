extends Resource
class_name NPCSpawnCondition

## Condition types
enum ConditionType {
	STORY_FLAG,          # Check GameState story flag
	QUEST_COMPLETED,     # Check if quest is done
	REPUTATION,          # Check reputation level
	ROMANCE_LEVEL,       # Check romance level
	TIME_OF_DAY,         # Check time of day
	CUSTOM               # Custom script-based condition
}

@export var condition_id: String = ""
@export var condition_type: ConditionType = ConditionType.STORY_FLAG

## Priority (higher values evaluated first)
@export var priority: int = 0

## Despawn NPC when this condition becomes invalid
@export var despawn_when_invalid: bool = false

# ==================== SPAWN CONFIGURATION ====================
@export_group("Spawn Configuration")
@export var spawn_position: Vector3 = Vector3.ZERO
@export var spawn_rotation_y: float = 0.0

# ==================== NPC OVERRIDES ====================
@export_group("NPC Overrides")
@export var override_dialogue_tree: Resource = null
@export_multiline var override_greeting: String = ""
@export var override_portrait: Texture2D = null

# ==================== STORY FLAG ====================
@export_group("Story Flag")
@export var story_flag: String = ""
@export var invert_flag: bool = false  ## If true, condition passes when flag is NOT set

# ==================== QUEST ====================
@export_group("Quest")
@export var quest_id: String = ""

# ==================== REPUTATION ====================
@export_group("Reputation")
@export var reputation_npc_id: String = ""
@export var min_reputation: int = 0

# ==================== ROMANCE ====================
@export_group("Romance")
@export var romance_npc_id: String = ""
@export var min_romance: int = 0

# ==================== TIME ====================
@export_group("Time")
@export var required_time_of_day: String = ""  # "day", "night", "morning", "evening"

# ==================== CUSTOM ====================
@export_group("Custom")
@export var custom_condition_script: GDScript

## Check if this condition is met
func is_met() -> bool:
	match condition_type:
		ConditionType.STORY_FLAG:
			return check_story_flag()
		ConditionType.QUEST_COMPLETED:
			return check_quest()
		ConditionType.REPUTATION:
			return check_reputation()
		ConditionType.ROMANCE_LEVEL:
			return check_romance()
		ConditionType.TIME_OF_DAY:
			return check_time()
		ConditionType.CUSTOM:
			return check_custom()
	
	return false

func check_story_flag() -> bool:
	# Access GameState autoload directly
	var has_flag = GameState.has_story_flag(story_flag)
	
	# Apply inversion if needed
	if invert_flag:
		return not has_flag
	else:
		return has_flag

func check_quest() -> bool:
	# Access GameState autoload directly
	return GameState.is_quest_completed(quest_id)

func check_reputation() -> bool:
	# Access ReputationManager autoload directly
	var reputation = ReputationManager.get_reputation(reputation_npc_id)
	return reputation >= min_reputation

func check_romance() -> bool:
	# Access RomanceManager autoload directly
	if RomanceManager.romance_partner.has(romance_npc_id):
		var romance = RomanceManager.romance_partner[romance_npc_id]
		return romance >= min_romance
	
	return false

func check_time() -> bool:
	# Implement time checking if you have a time system
	# if not has_node("/root/TimeManager"):
	#     return false
	# return TimeManager.get_time_of_day() == required_time_of_day
	return true

func check_custom() -> bool:
	if custom_condition_script and custom_condition_script.has_method("check"):
		return custom_condition_script.check()
	return false

## Get a human-readable description of this condition
func get_description() -> String:
	match condition_type:
		ConditionType.STORY_FLAG:
			if invert_flag:
				return "Does NOT have flag: %s" % story_flag
			else:
				return "Has flag: %s" % story_flag
		ConditionType.QUEST_COMPLETED:
			return "Quest completed: %s" % quest_id
		ConditionType.REPUTATION:
			return "Reputation with %s >= %d" % [reputation_npc_id, min_reputation]
		ConditionType.ROMANCE_LEVEL:
			return "Romance with %s >= %d" % [romance_npc_id, min_romance]
		ConditionType.TIME_OF_DAY:
			return "Time is: %s" % required_time_of_day
		ConditionType.CUSTOM:
			return "Custom condition"
	
	return "Unknown condition"
