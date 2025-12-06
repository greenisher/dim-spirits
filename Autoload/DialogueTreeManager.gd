extends Node

# Store dialogue tree configurations for each NPC
var npc_dialogue_configs: Dictionary = {}

# Cache loaded trees
var loaded_trees: Dictionary = {}

# ==================== SETUP ====================

func _ready() -> void:
	# Define dialogue trees for each NPC and their conditions
	setup_npc_dialogues()
	print("DialogueTreeManager initialized with %d NPCs" % npc_dialogue_configs.size())

func setup_npc_dialogues() -> void:
	"""Configure dialogue trees for all NPCs"""
	
	# Example: Rags dialogue progression
	npc_dialogue_configs["Rags"] = [
		{
			"tree_path": "res://Npc/rags_dialogue/rags_dialogue.tres",
			"conditions": {
				"flags_all": [],  # Must have all these flags
				"flags_none": ["met_Rags"],  # Must NOT have these flags
				"min_reputation": null,
				"min_romance": null
			},
			"priority": 100  # Higher priority = checked first
		}]
	npc_dialogue_configs["Discouraged Fighter"] = [
		{
			"tree_path": "res://Npc/df_dialogue/df_dialogue.tres",
			"conditions": {
				"flags_all": [],  # Must have all these flags
				"flags_none": [],  # Must NOT have these flags
				"min_reputation": null,
				"min_romance": null
			},
			"priority": 100  # Higher priority = checked first
		}]
	# Example: Asumi (romance character) dialogue progression
	npc_dialogue_configs["Asumi"] = [
		{
			"tree_path": "res://Dialogues/NPCs/Asumi/asumi_first_meeting.tres",
			"conditions": {
				"flags_all": [],
				"flags_none": ["met_Asumi"],
				"min_reputation": null,
				"min_romance": null
			},
			"priority": 100
		},
		{
			"tree_path": "res://Dialogues/NPCs/Asumi/asumi_dating.tres",
			"conditions": {
				"flags_all": ["met_Asumi"],
				"flags_none": ["asumi_rejected"],
				"min_reputation": null,
				"min_romance": 40  # High romance required
			},
			"priority": 60
		},
		{
			"tree_path": "res://Dialogues/NPCs/Asumi/asumi_friend.tres",
			"conditions": {
				"flags_all": ["met_Asumi"],
				"flags_none": [],
				"min_reputation": 30,
				"min_romance": null  # Good reputation but not dating
			},
			"priority": 50
		},
		{
			"tree_path": "res://Dialogues/NPCs/Asumi/asumi_default.tres",
			"conditions": {
				"flags_all": ["met_Asumi"],
				"flags_none": [],
				"min_reputation": null,
				"min_romance": null
			},
			"priority": 0
		}
	]
	
	# Add more NPCs here...
	npc_dialogue_configs["Berard"] = [
		{
			"tree_path": "res://Dialogues/NPCs/Berard/berard_default.tres",
			"conditions": {},
			"priority": 0
		}
	]
	npc_dialogue_configs["Faithless"] = [
		{
			"tree_path": "res://Npc/faithless_dialogue/faithless_dialogue.tres",
			"conditions": {},
			"priority": 0
		},
		{
			"tree_path": "res://Npc/faithless_dialogue/faithless_dialogue.tres",
			"conditions": {
				"flags_all": ["boss_1"]
				},
			"priority": 0
		},
		{
			"tree_path": "res://Npc/faithless_dialogue/faithless_dialogue.tres",
			"conditions": {
				"flags_all": ["boss_2"]
				},
			"priority": 0
		}
	]

# ==================== CORE FUNCTIONS ====================

func get_dialogue_tree_for_npc(npc_name: String) -> Resource:
	"""Get the appropriate dialogue tree based on current game state"""
	
	if not npc_dialogue_configs.has(npc_name):
		push_warning("DialogueTreeManager: No dialogue config for NPC '%s'" % npc_name)
		return null
	
	var configs = npc_dialogue_configs[npc_name]
	
	# Sort by priority (highest first)
	configs.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Find first matching tree
	for config in configs:
		if check_conditions(npc_name, config.conditions):
			var tree = load_tree(config.tree_path)
			if tree:
				print("DialogueTreeManager: Selected tree '%s' for %s" % [config.tree_path.get_file(), npc_name])
				return tree
	
	push_warning("DialogueTreeManager: No matching dialogue tree for '%s'" % npc_name)
	return null

func check_conditions(npc_name: String, conditions: Dictionary) -> bool:
	"""Check if all conditions are met for a dialogue tree"""
	
	# Check required flags (must have ALL)
	if conditions.has("flags_all"):
		for flag in conditions.flags_all:
			if not GameState.has_story_flag(flag):
				return false
	
	# Check forbidden flags (must have NONE)
	if conditions.has("flags_none"):
		for flag in conditions.flags_none:
			if GameState.has_story_flag(flag):
				return false
	
	# Check minimum reputation
	if conditions.has("min_reputation") and conditions.min_reputation != null:
		var reputation = ReputationManager.get_reputation(npc_name)
		if reputation < conditions.min_reputation:
			return false
	
	# Check minimum romance
	if conditions.has("min_romance") and conditions.min_romance != null:
		if RomanceManager.romance_partner.has(npc_name):
			var romance = RomanceManager.romance_partner[npc_name]
			if romance < conditions.min_romance:
				return false
		else:
			# NPC isn't a romance option
			return false
	
	# Check minimum friendship
	if conditions.has("min_friendship") and conditions.min_friendship != null:
		if RelationshipManager.relationships.has(npc_name):
			var friendship = RelationshipManager.get_stat(npc_name, "friendship")
			if friendship < conditions.min_friendship:
				return false
	
	# Check quest completion
	if conditions.has("quest_completed") and conditions.quest_completed:
		if not GameState.is_quest_completed(conditions.quest_completed):
			return false
	
	# All conditions met!
	return true

func load_tree(tree_path: String) -> Resource:
	"""Load and cache a dialogue tree"""
	
	# Return cached if available
	if loaded_trees.has(tree_path):
		return loaded_trees[tree_path]
	
	# Load from disk
	if ResourceLoader.exists(tree_path):
		var tree = load(tree_path)
		loaded_trees[tree_path] = tree
		return tree
	
	push_error("DialogueTreeManager: Tree not found: %s" % tree_path)
	return null

# ==================== DYNAMIC TREE UPDATES ====================

func update_npc_dialogue(npc_name: String) -> void:
	"""Force an NPC to update their dialogue tree (call after major events)"""
	
	var npc = get_tree().get_first_node_in_group("npc_" + npc_name.to_lower())
	if not npc:
		# Try to find NPC by searching
		npc = find_npc_in_scene(npc_name)
	
	if npc:
		var new_tree = get_dialogue_tree_for_npc(npc_name)
		if new_tree:
			npc.dialogue_tree = new_tree
			print("DialogueTreeManager: Updated dialogue tree for %s" % npc_name)
		else:
			push_warning("DialogueTreeManager: No valid tree found for %s" % npc_name)
	else:
		print("DialogueTreeManager: NPC '%s' not in current scene" % npc_name)

func update_all_npcs_in_scene() -> void:
	"""Update dialogue trees for all NPCs in the current scene"""
	
	for npc_name in npc_dialogue_configs.keys():
		update_npc_dialogue(npc_name)

func find_npc_in_scene(npc_name: String) -> Node:
	"""Search for NPC by name in current scene"""
	
	var scene = get_tree().current_scene
	if not scene:
		return null
	
	# Try to find by group first
	var npc_group = "npc_" + npc_name.to_lower()
	var npc = get_tree().get_first_node_in_group(npc_group)
	if npc:
		return npc
	
	# Search by property
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc_node in npcs:
		if npc_node.get("npc_name") == npc_name:
			return npc_node
	
	return null

# ==================== CONVENIENCE FUNCTIONS ====================

func register_npc_dialogue(npc_name: String, tree_configs: Array) -> void:
	"""Dynamically register dialogue trees for an NPC at runtime"""
	npc_dialogue_configs[npc_name] = tree_configs
	print("DialogueTreeManager: Registered dialogue for %s with %d trees" % [npc_name, tree_configs.size()])

func mark_npc_met(npc_name: String) -> void:
	"""Convenience function to mark NPC as met and update their dialogue"""
	GameState.mark_character_met(npc_name)
	update_npc_dialogue(npc_name)

func progress_npc_story(npc_name: String, story_flag: String) -> void:
	"""Set a story flag and update NPC dialogue"""
	GameState.set_story_flag(story_flag)
	update_npc_dialogue(npc_name)

# ==================== SCENE TRANSITION HANDLING ====================

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		# When scene loads, update all NPC dialogues
		call_deferred("update_all_npcs_in_scene")

# ==================== DEBUG ====================

func print_npc_dialogue_options(npc_name: String) -> void:
	"""Debug: Print all possible dialogue trees and their conditions"""
	
	if not npc_dialogue_configs.has(npc_name):
		print("No dialogue config for %s" % npc_name)
		return
	
	print("=== Dialogue Options for %s ===" % npc_name)
	
	var configs = npc_dialogue_configs[npc_name]
	for i in range(configs.size()):
		var config = configs[i]
		var matches = check_conditions(npc_name, config.conditions)
		var status = "[MATCHES]" if matches else "[BLOCKED]"
		
		print("%d. %s %s (Priority: %d)" % [i, status, config.tree_path.get_file(), config.priority])
		print("   Conditions: %s" % str(config.conditions))

func list_all_loaded_trees() -> void:
	"""Debug: List all currently loaded trees"""
	print("=== Loaded Dialogue Trees ===")
	for path in loaded_trees.keys():
		print("  - %s" % path.get_file())
