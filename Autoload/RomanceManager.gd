extends Node

signal romance_changed(partner: String, new_value: int)

var romance_partner: Dictionary = {
	'Asumi': 10,
	'Rhea': 10,
	'Skoll': 10
}

const MAX_ROMANCE = 100
const MIN_ROMANCE = -100

func _ready() -> void:
	# Mark any romance partners as met if they have romance values
	# (This is a fallback - ideally this happens during first dialogue)
	for partner_name in romance_partner.keys():
		if not GameState.has_story_flag("met_%s" % partner_name.to_lower()):
			pass

func add_reputation(partner: String, amount: int) -> void:
	"""Add/subtract romance points for a partner"""
	if !romance_partner.has(partner):
		push_warning("partner '%s' not found in romance_partner dictionary." % partner)
		return

	romance_partner[partner] = clamp(romance_partner[partner] + amount, MIN_ROMANCE, MAX_ROMANCE)
	print("Romance with %s: %d" % [partner, romance_partner[partner]])
	romance_changed.emit(partner, romance_partner[partner])

func get_romance(partner: String) -> int:
	"""Get current romance value for a partner"""
	return romance_partner.get(partner, 0)

func set_romance(partner: String, value: int) -> void:
	"""Set romance value directly"""
	if !romance_partner.has(partner):
		push_warning("partner '%s' not found in romance_partner dictionary." % partner)
		return
	
	romance_partner[partner] = clamp(value, MIN_ROMANCE, MAX_ROMANCE)
	print("Romance with %s set to: %d" % [partner, romance_partner[partner]])
	romance_changed.emit(partner, romance_partner[partner])

# ==================== STORY FLAG INTEGRATION ====================

func mark_met(partner: String) -> void:
	"""Mark a romance partner as met (sets met_[name] flag)"""
	var partner_lower = partner.to_lower()
	
	if not GameState.has_story_flag("met_%s" % partner_lower):
		GameState.set_story_flag("met_%s" % partner_lower)
		print("Romance partner met: %s" % partner)

func has_met(partner: String) -> bool:
	"""Check if player has met this romance partner"""
	return GameState.has_story_flag("met_%s" % partner.to_lower())

func get_invitation_count(partner: String) -> int:
	"""Get how many times a partner has been invited to campfire"""
	var partner_lower = partner.to_lower()
	
	if GameState.has_story_flag("%s_invited_thrice" % partner_lower):
		return 3
	elif GameState.has_story_flag("%s_invited_twice" % partner_lower):
		return 2
	elif GameState.has_story_flag("%s_invited_once" % partner_lower):
		return 1
	else:
		return 0

func has_been_invited(partner: String) -> bool:
	"""Check if partner has been invited at least once"""
	return get_invitation_count(partner) > 0

# ==================== ROMANCE LEVEL CHECKS ====================

func get_romance_level(partner: String) -> String:
	"""Get romance level as string (for dialogue conditions, etc.)"""
	var romance_value = get_romance(partner)
	
	if romance_value >= 80:
		return "in_love"
	elif romance_value >= 60:
		return "romantic"
	elif romance_value >= 40:
		return "interested"
	elif romance_value >= 20:
		return "friendly"
	elif romance_value >= 0:
		return "neutral"
	elif romance_value >= -20:
		return "distant"
	else:
		return "rejected"

func is_in_love(partner: String) -> bool:
	"""Check if romance is at 'in love' level (80+)"""
	return get_romance(partner) >= 80

func is_romantic(partner: String) -> bool:
	"""Check if romance is at 'romantic' level (60+)"""
	return get_romance(partner) >= 60

func is_interested(partner: String) -> bool:
	"""Check if there's romantic interest (40+)"""
	return get_romance(partner) >= 40

func is_rejected(partner: String) -> bool:
	"""Check if romance is in rejection territory (-20 or lower)"""
	return get_romance(partner) <= -20

# ==================== ROMANCE MILESTONES ====================

func check_romance_milestone(partner: String, old_value: int, new_value: int) -> void:
	"""Check if romance crossed a milestone threshold"""
	var milestones = [20, 40, 60, 80]  # Key romance thresholds
	
	for milestone in milestones:
		if old_value < milestone and new_value >= milestone:
			trigger_romance_milestone(partner, milestone, true)
		elif old_value >= milestone and new_value < milestone:
			trigger_romance_milestone(partner, milestone, false)

func trigger_romance_milestone(partner: String, milestone: int, increased: bool) -> void:
	"""Trigger events when romance milestone is reached"""
	var direction = "increased" if increased else "decreased"
	print("Romance milestone: %s romance %s to %d" % [partner, direction, milestone])
	
	# Set story flags for major milestones
	match milestone:
		40:  # Romantic interest begins
			if increased:
				GameState.set_story_flag("%s_romantic_interest" % partner.to_lower())
		60:  # Committed relationship
			if increased:
				GameState.set_story_flag("%s_relationship" % partner.to_lower())
		80:  # In love
			if increased:
				GameState.set_story_flag("%s_in_love" % partner.to_lower())

# ==================== SAVE/LOAD SUPPORT ====================

func get_save_data() -> Dictionary:
	"""Get romance data for saving"""
	return {
		"romance_values": romance_partner.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	"""Load romance data from save"""
	if data.has("romance_values"):
		romance_partner = data["romance_values"].duplicate()
		print("Loaded romance data for %d partners" % romance_partner.size())

# ==================== DEBUG ====================

func debug_print_romance_status() -> void:
	"""Debug: Print all romance statuses"""
	print("=== Romance Status ===")
	for partner in romance_partner.keys():
		var value = romance_partner[partner]
		var level = get_romance_level(partner)
		var met = has_met(partner)
		var invitations = get_invitation_count(partner)
		
		print("%s:" % partner)
		print("  Value: %d (%s)" % [value, level])
		print("  Met: %s" % met)
		print("  Campfire invitations: %d" % invitations)
