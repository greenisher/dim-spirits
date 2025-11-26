extends Node

# NPC relationship data (trust, fear, friendship, custom flags)
# Romance and Reputation are handled by their dedicated managers
var relationships: Dictionary = {}

# Relationship levels
enum RelationshipLevel {
	HATED = 0,      # -100 to -60
	DISLIKED = 1,   # -59 to -20
	NEUTRAL = 2,    # -19 to 20
	LIKED = 3,      # 21 to 60
	LOVED = 4       # 61 to 100
}

# Signals
signal relationship_changed(npc_id: String, stat_name: String, old_value: float, new_value: float)
signal relationship_level_changed(npc_id: String, stat_name: String, level: RelationshipLevel)

const MAX_STAT = 100
const MIN_STAT = -100

# ==================== CORE FUNCTIONS ====================

## Initialize relationship for an NPC if doesn't exist
func initialize_npc(npc_id: String) -> void:
	if relationships.has(npc_id):
		return
	
	relationships[npc_id] = {
		"trust": 0,           # How much NPC trusts player
		"fear": 0,            # How afraid of player (0-100, always positive)
		"friendship": 0,      # Personal friendship level
		"custom_flags": {},   # Custom story flags
		"last_interaction": Time.get_datetime_string_from_system(),
		"interaction_count": 0
	}

## Get relationship stat value
func get_stat(npc_id: String, stat_name: String) -> float:
	if not relationships.has(npc_id):
		initialize_npc(npc_id)
	
	if relationships[npc_id].has(stat_name):
		return relationships[npc_id][stat_name]
	
	return 0.0

## Set relationship stat value
func set_stat(npc_id: String, stat_name: String, value: float) -> void:
	initialize_npc(npc_id)
	
	var old_value = get_stat(npc_id, stat_name)
	
	# Fear is always 0-100 (positive)
	var new_value
	if stat_name == "fear":
		new_value = clampf(value, 0.0, 100.0)
	else:
		new_value = clampf(value, MIN_STAT, MAX_STAT)
	
	var old_level = get_relationship_level(old_value)
	var new_level = get_relationship_level(new_value)
	
	relationships[npc_id][stat_name] = new_value
	
	# Emit signals
	relationship_changed.emit(npc_id, stat_name, old_value, new_value)
	
	if old_level != new_level:
		relationship_level_changed.emit(npc_id, stat_name, new_level)

## Modify relationship stat (add/subtract)
func modify_stat(npc_id: String, stat_name: String, amount: float) -> void:
	var current = get_stat(npc_id, stat_name)
	set_stat(npc_id, stat_name, current + amount)

## Get all stats for an NPC
func get_all_stats(npc_id: String) -> Dictionary:
	initialize_npc(npc_id)
	return relationships[npc_id].duplicate()

# ==================== INTEGRATION WITH EXISTING MANAGERS ====================

## Get NPC's reputation (from ReputationManager)
func get_reputation(npc_id: String) -> int:
	if has_node("/root/ReputationManager"):
		var rep_mgr = get_node("/root/ReputationManager")
		return rep_mgr.get_reputation(npc_id)
	return 0

## Modify NPC's reputation (via ReputationManager)
func modify_reputation(npc_id: String, amount: int) -> void:
	if has_node("/root/ReputationManager"):
		var rep_mgr = get_node("/root/ReputationManager")
		rep_mgr.add_reputation(npc_id, amount)

## Get NPC's romance level (from RomanceManager)
func get_romance(npc_id: String) -> int:
	if has_node("/root/RomanceManager"):
		var rom_mgr = get_node("/root/RomanceManager")
		if rom_mgr.romance_partner.has(npc_id):
			return rom_mgr.romance_partner[npc_id]
	return 0

## Modify NPC's romance (via RomanceManager)
func modify_romance(npc_id: String, amount: int) -> void:
	if has_node("/root/RomanceManager"):
		var rom_mgr = get_node("/root/RomanceManager")
		rom_mgr.add_reputation(npc_id, amount)  # Note: their function is named add_reputation

## Check if NPC is a romance option
func is_romance_option(npc_id: String) -> bool:
	if has_node("/root/RomanceManager"):
		var rom_mgr = get_node("/root/RomanceManager")
		return rom_mgr.romance_partner.has(npc_id)
	return false

# ==================== CONVENIENCE FUNCTIONS ====================

## Increase trust
func increase_trust(npc_id: String, amount: float = 5.0) -> void:
	modify_stat(npc_id, "trust", amount)

## Decrease trust (betrayal)
func decrease_trust(npc_id: String, amount: float = 10.0) -> void:
	modify_stat(npc_id, "trust", -amount)

## Increase fear
func increase_fear(npc_id: String, amount: float = 10.0) -> void:
	modify_stat(npc_id, "fear", amount)

## Decrease fear (reassurance)
func decrease_fear(npc_id: String, amount: float = 5.0) -> void:
	modify_stat(npc_id, "fear", -amount)

## Increase friendship
func increase_friendship(npc_id: String, amount: float = 5.0) -> void:
	modify_stat(npc_id, "friendship", amount)
	# Also increase reputation if available
	modify_reputation(npc_id, int(amount * 0.5))

## Decrease friendship
func decrease_friendship(npc_id: String, amount: float = 5.0) -> void:
	modify_stat(npc_id, "friendship", -amount)
	# Also decrease reputation if available
	modify_reputation(npc_id, -int(amount * 0.5))

# ==================== INTERACTION TRACKING ====================

## Record an interaction with an NPC
func record_interaction(npc_id: String) -> void:
	initialize_npc(npc_id)
	relationships[npc_id]["interaction_count"] += 1
	relationships[npc_id]["last_interaction"] = Time.get_datetime_string_from_system()

## Get interaction count
func get_interaction_count(npc_id: String) -> int:
	if not relationships.has(npc_id):
		return 0
	return relationships[npc_id].get("interaction_count", 0)

# ==================== CUSTOM FLAGS ====================

## Set custom story flag for NPC
func set_custom_flag(npc_id: String, flag_name: String, value) -> void:
	initialize_npc(npc_id)
	relationships[npc_id]["custom_flags"][flag_name] = value

## Get custom story flag
func get_custom_flag(npc_id: String, flag_name: String, default = null):
	if not relationships.has(npc_id):
		return default
	return relationships[npc_id]["custom_flags"].get(flag_name, default)

## Check if custom flag exists and is true
func has_flag(npc_id: String, flag_name: String) -> bool:
	return get_custom_flag(npc_id, flag_name, false) == true

# ==================== LEVEL CHECKING ====================

## Get relationship level from value
func get_relationship_level(value: float) -> RelationshipLevel:
	if value <= -60:
		return RelationshipLevel.HATED
	elif value <= -20:
		return RelationshipLevel.DISLIKED
	elif value <= 20:
		return RelationshipLevel.NEUTRAL
	elif value <= 60:
		return RelationshipLevel.LIKED
	else:
		return RelationshipLevel.LOVED

## Check if NPC likes player (friendship > 20)
func is_liked(npc_id: String) -> bool:
	return get_stat(npc_id, "friendship") > 20

## Check if NPC hates player (friendship < -20)
func is_hated(npc_id: String) -> bool:
	return get_stat(npc_id, "friendship") < -20

## Check if NPC trusts player (trust > 50)
func is_trusted(npc_id: String) -> bool:
	return get_stat(npc_id, "trust") > 50

## Check if NPC fears player (fear > 50)
func is_feared(npc_id: String) -> bool:
	return get_stat(npc_id, "fear") > 50

## Check if NPC is in love (romance > 60 via RomanceManager)
func is_in_love(npc_id: String) -> bool:
	return get_romance(npc_id) > 60

# ==================== ACTIONS & CONSEQUENCES ====================

## Player helped NPC
func player_helped(npc_id: String) -> void:
	modify_reputation(npc_id, 10)
	increase_trust(npc_id, 5)
	increase_friendship(npc_id, 10)
	record_interaction(npc_id)
	print(npc_id, " appreciates your help!")

## Player betrayed/harmed NPC
func player_betrayed(npc_id: String) -> void:
	modify_reputation(npc_id, -20)
	decrease_trust(npc_id, 30)
	decrease_friendship(npc_id, 15)
	increase_fear(npc_id, 15)
	record_interaction(npc_id)
	print(npc_id, " feels betrayed!")

## Player was kind to NPC
func player_was_kind(npc_id: String) -> void:
	increase_friendship(npc_id, 5)
	modify_reputation(npc_id, 3)
	record_interaction(npc_id)

## Player was rude to NPC
func player_was_rude(npc_id: String) -> void:
	decrease_friendship(npc_id, 5)
	modify_reputation(npc_id, -3)
	record_interaction(npc_id)

## Player gave gift to NPC
func player_gave_gift(npc_id: String, gift_value: float = 10.0) -> void:
	increase_friendship(npc_id, gift_value)
	increase_trust(npc_id, gift_value * 0.5)
	
	# If romance option, increase romance
	if is_romance_option(npc_id):
		modify_romance(npc_id, int(gift_value * 0.5))
	
	record_interaction(npc_id)
	print(npc_id, " liked your gift!")

## Player threatened NPC
func player_threatened(npc_id: String) -> void:
	increase_fear(npc_id, 20)
	decrease_trust(npc_id, 10)
	decrease_friendship(npc_id, 10)
	modify_reputation(npc_id, -5)
	record_interaction(npc_id)
	print(npc_id, " is afraid of you!")

## Player completed quest for NPC
func quest_completed(npc_id: String, importance: float = 1.0) -> void:
	modify_reputation(npc_id, int(15 * importance))
	increase_trust(npc_id, 10 * importance)
	increase_friendship(npc_id, 20 * importance)
	
	# Romance boost if romance option
	if is_romance_option(npc_id):
		modify_romance(npc_id, int(10 * importance))
	
	record_interaction(npc_id)
	print(npc_id, " is grateful for completing their quest!")

## Player failed quest for NPC
func quest_failed(npc_id: String, importance: float = 1.0) -> void:
	modify_reputation(npc_id, int(-10 * importance))
	decrease_trust(npc_id, 15 * importance)
	decrease_friendship(npc_id, 10 * importance)
	record_interaction(npc_id)
	print(npc_id, " is disappointed in you")

# ==================== ROMANTIC ACTIONS ====================

## Player flirted with NPC (only works for romance options)
func player_flirted(npc_id: String) -> void:
	if not is_romance_option(npc_id):
		print(npc_id, " is not interested in romance.")
		return
	
	var romance_level = get_romance(npc_id)
	
	if romance_level > 20:
		modify_romance(npc_id, 5)
		increase_friendship(npc_id, 2)
		print(npc_id, " enjoyed the flirting!")
	elif romance_level < -20:
		modify_romance(npc_id, -5)
		decrease_friendship(npc_id, 3)
		print(npc_id, " didn't appreciate that.")
	else:
		# Neutral - small increase
		modify_romance(npc_id, 2)
	
	record_interaction(npc_id)

## Player went on date with NPC
func player_dated(npc_id: String, date_quality: float = 1.0) -> void:
	if not is_romance_option(npc_id):
		return
	
	modify_romance(npc_id, int(15 * date_quality))
	increase_friendship(npc_id, 10 * date_quality)
	increase_trust(npc_id, 5 * date_quality)
	record_interaction(npc_id)
	print("Date with ", npc_id, " went well!")

# ==================== DIALOGUE CHOICES ====================

## Process dialogue choice that affects relationship
func process_dialogue_choice(npc_id: String, choice_type: String) -> void:
	record_interaction(npc_id)
	
	match choice_type:
		"friendly":
			increase_friendship(npc_id, 3)
		"flirty":
			if is_romance_option(npc_id) and get_romance(npc_id) > 20:
				modify_romance(npc_id, 5)
				increase_friendship(npc_id, 2)
		"aggressive":
			increase_fear(npc_id, 5)
			decrease_friendship(npc_id, 3)
		"honest":
			increase_trust(npc_id, 5)
		"lie":
			# Risk: might get caught
			if randf() < 0.3:  # 30% chance caught
				decrease_trust(npc_id, 15)
				print(npc_id, " caught your lie!")
		"intimidating":
			increase_fear(npc_id, 10)
			decrease_trust(npc_id, 5)

# ==================== COMPREHENSIVE STATUS ====================

## Get complete relationship summary for an NPC
func get_complete_summary(npc_id: String) -> Dictionary:
	return {
		"trust": get_stat(npc_id, "trust"),
		"fear": get_stat(npc_id, "fear"),
		"friendship": get_stat(npc_id, "friendship"),
		"reputation": get_reputation(npc_id),
		"romance": get_romance(npc_id) if is_romance_option(npc_id) else null,
		"interaction_count": get_interaction_count(npc_id),
		"is_liked": is_liked(npc_id),
		"is_trusted": is_trusted(npc_id),
		"is_feared": is_feared(npc_id),
		"is_romance_option": is_romance_option(npc_id),
		"is_in_love": is_in_love(npc_id) if is_romance_option(npc_id) else false
	}

## Get relationship summary text (for UI)
func get_relationship_summary_text(npc_id: String) -> String:
	var friendship = get_stat(npc_id, "friendship")
	var trust = get_stat(npc_id, "trust")
	var fear = get_stat(npc_id, "fear")
	var reputation = get_reputation(npc_id)
	
	var text = ""
	
	# Primary feeling based on friendship
	if friendship > 60:
		text = "They consider you a close friend."
	elif friendship > 20:
		text = "They seem to like you."
	elif friendship < -20:
		text = "They dislike you."
	else:
		text = "They're neutral toward you."
	
	# Trust modifier
	if trust > 50:
		text += " They trust you."
	elif trust < -30:
		text += " They don't trust you at all."
	
	# Fear modifier
	if fear > 60:
		text += " They seem very afraid of you."
	elif fear > 30:
		text += " They're wary around you."
	
	# Reputation
	if reputation > 60:
		text += " Your reputation with them is excellent."
	elif reputation < -30:
		text += " Your reputation with them is poor."
	
	# Romance
	if is_romance_option(npc_id):
		var romance = get_romance(npc_id)
		if romance > 60:
			text += " They seem to have romantic feelings for you."
		elif romance < -30:
			text += " They've made it clear they're not interested in romance."
	
	return text

# ==================== SAVE/LOAD ====================

## Get all relationships for saving
func get_all_relationships() -> Dictionary:
	return {
		"npc_relationships": relationships.duplicate(true)
	}

## Load relationships from save data
func load_relationships(data: Dictionary) -> void:
	if data.has("npc_relationships"):
		relationships = data["npc_relationships"].duplicate(true)
	print("Loaded ", relationships.size(), " NPC relationships")

## Clear all relationships (for new game)
func clear_all_relationships() -> void:
	relationships.clear()

# ==================== DEBUG/TESTING ====================

## Print relationship summary for NPC
func print_relationship_summary(npc_id: String) -> void:
	if not relationships.has(npc_id):
		print("No relationship data for: ", npc_id)
		return
	
	print("=== Relationship Summary: ", npc_id, " ===")
	print("  Trust: ", get_stat(npc_id, "trust"))
	print("  Fear: ", get_stat(npc_id, "fear"))
	print("  Friendship: ", get_stat(npc_id, "friendship"))
	print("  Reputation: ", get_reputation(npc_id))
	if is_romance_option(npc_id):
		print("  Romance: ", get_romance(npc_id))
	print("  Interactions: ", get_interaction_count(npc_id))
	print("  Custom flags: ", relationships[npc_id].get("custom_flags", {}))
