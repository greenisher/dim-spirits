extends Node

var romance_partner: Dictionary = {
	'Asumi': 10,
	'Rhea': 10,
	'Skoll': 10
}

const MAX_ROMANCE = 100
const MIN_ROMANCE = -100

func add_reputation(partner: String, amount: int) -> void:
	if !romance_partner.has(partner):
		push_warning("partner '%s' not found in romance_partner dictionary." % partner)
		return

	romance_partner[partner] = clamp(romance_partner[partner] + amount, MIN_ROMANCE, MAX_ROMANCE)
	print("Romance with %s: %d" % [partner, romance_partner[partner]])
	emit_signal("reputation_changed", partner, romance_partner[partner])
