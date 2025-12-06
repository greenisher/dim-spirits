extends Resource
class_name CharacterStats

signal level_up_available()  
signal stat_increased(stat_name: String)
signal xp_changed(current_xp: int, xp_to_next_level: int)
signal level_changed(new_level: int)
signal update_stats()  # Emitted when derived stats need recalculation
signal mana_changed(current_mana: float, max_mana: float)

# Recursion guard to prevent infinite loops
var _updating: bool = false

class Ability:
	var min_modifier: float
	var max_modifier: float
	var ability_score: int = 10:
		set(value):
			ability_score = clamp(value, 0, 100)
			
	func _init(min: float, max: float) -> void:
		min_modifier = min
		max_modifier = max
	
	func percentile_lerp(min_bound: float, max_bound: float) -> float:
		return lerp(min_bound, max_bound, ability_score / 100.0)
	
	func get_modifier() -> float:
		return percentile_lerp(min_modifier, max_modifier)
	
	func increase(amount: int = 1) -> void:
		ability_score += amount

var level := 1:
	set(value):
		if _updating:
			return
		_updating = true
		level = value
		level_changed.emit(level)
		_updating = false

var xp := 0:
	set(value):
		if _updating:
			return
		_updating = true
		xp = value
		xp_changed.emit(xp, get_xp_to_next_level())
		check_for_level_up()
		_updating = false

# ==================== ABILITIES ====================

var strength := Ability.new(2.0, 12.0)      # Physical damage
var endurance := Ability.new(5.0, 25.0)     # Max HP
var intelligence := Ability.new(2.0, 12.0)  # Magic damage scaling
var agility := Ability.new(0.05, 0.25)      # Critical chance
var spirit := Ability.new(5.0, 30.0)        # Max mana & mana regen (NEW!)

func get_damage_modifier() -> float:
	return strength.get_modifier()

func get_spell_damage_modifier() -> float:
	return intelligence.get_modifier()

func get_crit_chance() -> float:
	return agility.get_modifier()

# ==================== MANA SYSTEM ====================

var current_mana: float = 100.0:
	set(value):
		current_mana = clampf(value, 0.0, get_max_mana())
		mana_changed.emit(current_mana, get_max_mana())

## Base mana regeneration per second (scales with spirit)
var base_mana_regen_rate: float = 5.0

func get_max_mana() -> float:
	"""Max mana scales with Spirit ability"""
	# Base mana (100) + spirit scaling
	# Spirit 10 → 150 max mana
	# Spirit 30 → 250 max mana
	# Spirit 50 → 350 max mana
	# Spirit 70 → 450 max mana
	return 100.0 + (spirit.ability_score * 5.0)

func get_mana_regen_rate() -> float:
	"""Mana regen scales with Spirit ability"""
	# Base regen (5) + spirit bonus (0.5 to 15.0 per second)
	# Spirit 10 → 5.5/sec
	# Spirit 30 → 10/sec
	# Spirit 50 → 15/sec
	# Spirit 70 → 20/sec
	return base_mana_regen_rate + spirit.get_modifier()

func regenerate_mana(delta: float) -> void:
	"""Call this in _process to regenerate mana over time"""
	if current_mana < get_max_mana():
		current_mana += get_mana_regen_rate() * delta

func consume_mana(amount: float) -> bool:
	"""Try to consume mana. Returns true if successful, false if not enough mana"""
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false

func restore_mana(amount: float) -> void:
	"""Restore mana (e.g., from potion)"""
	current_mana += amount

func get_mana_percentage() -> float:
	"""Get mana as percentage (0-100)"""
	return (current_mana / get_max_mana()) * 100.0

# ==================== HP SYSTEM ====================

func get_max_hp() -> float:
	"""Max HP scales with Endurance ability"""
	# Base HP (100) + endurance scaling
	# Endurance 10 → 150 HP
	# Endurance 30 → 250 HP
	# Endurance 50 → 350 HP
	# Endurance 70 → 450 HP
	return 100.0 + (endurance.ability_score * 5.0)

func update_derived_stats() -> void:
	"""Force update all derived stats and emit signals"""
	# This is useful when stats change outside of normal level-up flow
	# or when you need to refresh all dependent systems
	
	# Emit update signal for systems that depend on stats
	update_stats.emit()
	
	# Update mana to match new maximum if needed
	if current_mana > get_max_mana():
		current_mana = get_max_mana()
	else:
		# Emit mana changed to update UI even if value didn't change
		mana_changed.emit(current_mana, get_max_mana())

# ==================== LEVELING SYSTEM ====================

func get_xp_to_next_level() -> int:
	return int(50 * pow(1.2, level))

func can_level_up() -> bool:
	return xp >= get_xp_to_next_level()

func check_for_level_up() -> void:
	if can_level_up():
		level_up_available.emit()

func spend_level() -> bool:
	if not can_level_up():
		return false
	
	var cost = get_xp_to_next_level()
	xp -= cost
	level += 1
	
	print("Level up! Now level ", level)
	print("XP spent: ", cost, " | Remaining XP: ", xp)
	
	return true

# ==================== STAT INCREASE FUNCTIONS (CALL FROM CAMPFIRE MENU) ====================

func level_up_strength() -> bool:
	if not can_level_up():
		return false
	
	if spend_level():
		strength.increase()
		stat_increased.emit("Strength")
		update_stats.emit()
		print("Strength increased to ", strength.ability_score)
		return true
	
	return false

func level_up_endurance() -> bool:
	if not can_level_up():
		return false
	
	if spend_level():
		endurance.increase()
		stat_increased.emit("Endurance")
		update_stats.emit()
		print("Endurance increased to ", endurance.ability_score)
		return true
	
	return false

func level_up_intelligence() -> bool:
	if not can_level_up():
		return false
	
	if spend_level():
		intelligence.increase()
		stat_increased.emit("Intelligence")
		update_stats.emit()
		print("Intelligence increased to ", intelligence.ability_score)
		return true
	
	return false

func level_up_agility() -> bool:
	if not can_level_up():
		return false
	
	if spend_level():
		agility.increase()
		stat_increased.emit("Agility")
		update_stats.emit()
		print("Agility increased to ", agility.ability_score)
		return true
	
	return false

func level_up_spirit() -> bool:
	"""NEW: Level up Spirit to increase max mana and mana regeneration"""
	if not can_level_up():
		return false
	
	if spend_level():
		spirit.increase()
		stat_increased.emit("Spirit")
		update_stats.emit()
		
		# Restore mana to new maximum when leveling Spirit
		current_mana = get_max_mana()
		
		print("Spirit increased to ", spirit.ability_score)
		print("Max mana is now: ", get_max_mana())
		print("Mana regen is now: ", get_mana_regen_rate(), "/sec")
		return true
	
	return false

# ==================== STAT GETTERS ====================

func get_strength() -> float:
	return strength.get_modifier()

func get_endurance() -> float:
	return endurance.get_modifier()

func get_intelligence() -> float:
	return intelligence.get_modifier()

func get_agility() -> float:
	return agility.get_modifier()

func get_spirit() -> float:
	"""NEW: Get spirit modifier for mana calculations"""
	return spirit.get_modifier()

func get_all_stats() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"xp_to_next_level": get_xp_to_next_level(),
		"strength": strength.ability_score,
		"endurance": endurance.ability_score,
		"intelligence": intelligence.ability_score,
		"agility": agility.ability_score,
		"spirit": spirit.ability_score,
		"strength_modifier": get_strength(),
		"endurance_modifier": get_endurance(),
		"intelligence_modifier": get_intelligence(),
		"agility_modifier": get_agility(),
		"spirit_modifier": get_spirit(),
		"max_hp": get_max_hp(),  # NEW
		"current_mana": current_mana,
		"max_mana": get_max_mana(),
		"mana_regen_rate": get_mana_regen_rate()
	}
