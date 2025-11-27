extends Resource
class_name Spell


# ==================== IDENTIFICATION ====================

@export var spell_name: String = "Magic Spell"
@export_multiline var description: String = "A magical spell"
@export var icon: Texture2D

# ==================== SPELL TYPE ====================

enum SpellType {
	PROJECTILE,  # Flies toward target (Dart, Spear)
	AOE,         # Area of effect (Meteor)
	BUFF,        # Self buff (Magic Shield)
	HEAL         # Healing spell (Healing Aura)
}

@export var spell_type: SpellType = SpellType.PROJECTILE

# ==================== COSTS ====================

@export_group("Costs")
@export var mana_cost: float = 20.0
@export var cast_time: float = 0.5
@export var cooldown: float = 0.0

# ==================== DAMAGE ====================

@export_group("Damage")
@export var base_damage: float = 5.0
@export var scales_with_intelligence: bool = true
@export_enum("Magic", "Fire", "Lightning", "Dark") var damage_type: String = "Magic"

# ==================== TARGETING ====================

@export_group("Targeting")
@export var can_lock_on: bool = true
@export var is_homing: bool = false
@export var lock_on_range: float = 30.0
@export var aoe_radius: float = 0.0

# ==================== PROJECTILE PROPERTIES ====================

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 20.0
@export var projectile_lifetime: float = 5.0
@export var homing_strength: float = 0.5

# ==================== BUFF/HEAL PROPERTIES ====================

@export_group("Buff/Heal")
@export var duration: float = 10.0
@export var shield_absorption: float = 50.0
@export var heal_per_tick: float = 5.0
@export var heal_tick_interval: float = 1.0

# ==================== VISUAL/AUDIO ====================

@export_group("Effects")
@export var cast_effect: PackedScene
@export var cast_sound: AudioStream
@export var spell_color: Color = Color.CYAN

# ==================== METHODS ====================

func calculate_damage(intelligence_modifier: float) -> float:
	"""Calculate final damage including intelligence scaling"""
	if scales_with_intelligence:
		return base_damage + intelligence_modifier
	return base_damage

func can_cast(current_mana: float) -> bool:
	"""Check if player has enough mana to cast"""
	return current_mana >= mana_cost

func get_spell_info() -> String:
	"""Get formatted spell information"""
	var info = "[b]%s[/b]\n" % spell_name
	info += "%s\n\n" % description
	info += "Mana Cost: %.0f\n" % mana_cost
	info += "Base Damage: %.0f" % base_damage
	if scales_with_intelligence:
		info += " + INT"
	info += "\n"
	
	match spell_type:
		SpellType.PROJECTILE:
			info += "Type: Projectile"
			if can_lock_on:
				info += " (Lock-on)"
		SpellType.AOE:
			info += "Type: Area of Effect (%.1fm radius)" % aoe_radius
		SpellType.BUFF:
			info += "Type: Buff (%.1fs duration)" % duration
		SpellType.HEAL:
			info += "Type: Healing (%.1fs duration)" % duration
	
	return info
