extends Resource
class_name Item

enum ItemType {
	WEAPON,
	ARMOR,
	CONSUMABLE,
	QUEST,
	MATERIAL
}

enum WeaponType {
	SWORD,
	AXE,
	BOW,
	STAFF
}

enum ArmorSlot {
	HEAD,
	CHEST,
	LEGS,
	HANDS,
	FEET
}

@export var item_name: String = "Item"
@export var item_id: String = ""  # Unique identifier
@export_multiline var description: String = "A mysterious item."
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.WEAPON
@export var max_stack_size: int = 1
@export var value: int = 10  # Sell/buy price

# Weapon stats
@export_group("Weapon Stats")
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var damage: float = 0.0
@export var attack_speed: float = 1.0
@export var crit_chance_bonus: float = 0.0

# Armor stats
@export_group("Armor Stats")
@export var armor_slot: ArmorSlot = ArmorSlot.CHEST
@export var defense: float = 0.0
@export var max_health_bonus: float = 0.0

# Stat modifiers
@export_group("Stat Bonuses")
@export var strength_bonus: int = 0
@export var endurance_bonus: int = 0
@export var agility_bonus: int = 0
@export var intelligence_bonus: int = 0

# Consumable effects
@export_group("Consumable Effects")
@export var health_restore: float = 0.0
@export var stamina_restore: float = 0.0

func get_tooltip_text() -> String:
	var tooltip = "[b][color=gold]%s[/color][/b]\n" % item_name
	
	# Add description
	if not description.is_empty():
		tooltip += "[i]%s[/i]\n\n" % description
	
	# Add item type
	match item_type:
		ItemType.WEAPON:
			tooltip += "[color=orange]Weapon - %s[/color]\n" % WeaponType.keys()[weapon_type]
			if damage > 0:
				tooltip += "Damage: %.1f\n" % damage
			if attack_speed != 1.0:
				tooltip += "Attack Speed: %.1fx\n" % attack_speed
			if crit_chance_bonus > 0:
				tooltip += "Crit Chance: +%.1f%%\n" % (crit_chance_bonus * 100)
		ItemType.ARMOR:
			tooltip += "[color=silver]Armor - %s[/color]\n" % ArmorSlot.keys()[armor_slot]
			if defense > 0:
				tooltip += "Defense: %.1f\n" % defense
			if max_health_bonus > 0:
				tooltip += "Max Health: +%.0f\n" % max_health_bonus
		ItemType.CONSUMABLE:
			tooltip += "[color=green]Consumable[/color]\n"
			if health_restore > 0:
				tooltip += "Restores %.0f Health\n" % health_restore
			if stamina_restore > 0:
				tooltip += "Restores %.0f Stamina\n" % stamina_restore
		ItemType.QUEST:
			tooltip += "[color=yellow]Quest Item[/color]\n"
		ItemType.MATERIAL:
			tooltip += "[color=gray]Crafting Material[/color]\n"
	
	# Add stat bonuses if any exist
	var has_bonuses = false
	if strength_bonus != 0 or endurance_bonus != 0 or agility_bonus != 0 or intelligence_bonus != 0:
		tooltip += "\n[color=cyan]Stat Bonuses:[/color]\n"
		has_bonuses = true
	
	if strength_bonus != 0:
		tooltip += "Strength: %+d\n" % strength_bonus
	if endurance_bonus != 0:
		tooltip += "Endurance: %+d\n" % endurance_bonus
	if agility_bonus != 0:
		tooltip += "Agility: %+d\n" % agility_bonus
	if intelligence_bonus != 0:
		tooltip += "Intelligence: %+d\n" % intelligence_bonus
	
	# Add value at the bottom
	tooltip += "\n[color=gold]Value: %d gold[/color]" % value
	
	return tooltip
