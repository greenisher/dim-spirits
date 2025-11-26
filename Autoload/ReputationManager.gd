extends Node

signal reputation_changed(faction: String, new_value: int)

var reputations: Dictionary = {
	'Rags': 10,
	'Berard': 10,
	'Adventurers': 10,
	'Boss': 0
}

const MAX_REPUTATION = 100
const MIN_REPUTATION = -100

func add_reputation(faction: String, amount: int) -> void:
	if !reputations.has(faction):
		push_warning("Faction '%s' not found in reputations dictionary." % faction)
		return

	reputations[faction] = clamp(reputations[faction] + amount, MIN_REPUTATION, MAX_REPUTATION)
	print("Reputation with %s: %d" % [faction, reputations[faction]])
	emit_signal("reputation_changed", faction, reputations[faction])

func get_reputation(faction: String) -> int:
	if reputations.has(faction):
		return reputations[faction]
	return 0
	
