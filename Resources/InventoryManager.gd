extends Node

signal inventory_updated()
signal item_equipped(item: Item, slot: String)
signal item_unequipped(slot: String)
signal item_added(item: Item, quantity: int)
signal item_removed(item: Item, quantity: int)

const MAX_INVENTORY_SIZE = 50

var inventory: Array[Dictionary] = []  # {item: Item, quantity: int}
var equipped_items: Dictionary = {}  # {slot_name: Item}

var player: Player

func _ready() -> void:
	print("InventoryManager initialized")
	# Find player reference
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")
	if player:
		print("InventoryManager found player: ", player.name)
	else:
		print("WARNING: InventoryManager could not find player!")

func add_item(item: Item, quantity: int = 1) -> bool:
	if not item:
		push_error("Trying to add null item")
		return false
	
	# Check if item can stack
	if item.max_stack_size > 1:
		# Find existing stack
		for stack in inventory:
			if stack.item.item_id == item.item_id:
				stack.quantity += quantity
				inventory_updated.emit()
				item_added.emit(item, quantity)
				print("Added %d x %s (now have %d)" % [quantity, item.item_name, stack.quantity])
				return true
	
	# Add as new stack
	if inventory.size() >= MAX_INVENTORY_SIZE:
		print("Inventory full!")
		return false
	
	inventory.append({"item": item, "quantity": quantity})
	inventory_updated.emit()
	item_added.emit(item, quantity)
	print("Added %d x %s to inventory" % [quantity, item.item_name])
	return true

func remove_item(item: Item, quantity: int = 1) -> bool:
	for i in range(inventory.size()):
		var stack = inventory[i]
		if stack.item.item_id == item.item_id:
			if stack.quantity > quantity:
				stack.quantity -= quantity
				inventory_updated.emit()
				item_removed.emit(item, quantity)
				return true
			elif stack.quantity == quantity:
				inventory.remove_at(i)
				inventory_updated.emit()
				item_removed.emit(item, quantity)
				return true
			else:
				# Not enough items
				return false
	return false

func get_item_count(item_id: String) -> int:
	var count = 0
	for stack in inventory:
		if stack.item.item_id == item_id:
			count += stack.quantity
	return count

func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

func equip_item(item: Item) -> bool:
	if not item or not player:
		print("Cannot equip - missing item or player")
		return false
	
	var slot_name = ""
	
	match item.item_type:
		Item.ItemType.WEAPON:
			slot_name = "weapon"
		Item.ItemType.ARMOR:
			match item.armor_slot:
				Item.ArmorSlot.HEAD:
					slot_name = "head"
				Item.ArmorSlot.CHEST:
					slot_name = "chest"
				Item.ArmorSlot.LEGS:
					slot_name = "legs"
				Item.ArmorSlot.HANDS:
					slot_name = "hands"
				Item.ArmorSlot.FEET:
					slot_name = "feet"
		_:
			print("Cannot equip this item type")
			return false
	
	# Unequip existing item in slot
	if equipped_items.has(slot_name):
		unequip_item(slot_name)
	
	# Equip new item
	equipped_items[slot_name] = item
	apply_item_stats(item, true)
	item_equipped.emit(item, slot_name)
	print("Equipped %s in %s slot" % [item.item_name, slot_name])
	return true

func unequip_item(slot_name: String) -> bool:
	if not equipped_items.has(slot_name):
		return false
	
	var item = equipped_items[slot_name]
	apply_item_stats(item, false)
	equipped_items.erase(slot_name)
	item_unequipped.emit(slot_name)
	print("Unequipped %s from %s slot" % [item.item_name, slot_name])
	return true

func apply_item_stats(item: Item, apply: bool) -> void:
	if not player or not player.stats:
		print("Cannot apply stats - missing player or stats")
		return
	
	var multiplier = 1 if apply else -1
	
	# Apply stat bonuses
	player.stats.strength.ability_score += item.strength_bonus * multiplier
	player.stats.endurance.ability_score += item.endurance_bonus * multiplier
	player.stats.agility.ability_score += item.agility_bonus * multiplier
	player.stats.intelligence.ability_score += item.intelligence_bonus * multiplier
	
	# Update health if max health changed
	if item.max_health_bonus != 0:
		var new_max = player.stats.get_max_hp()
		player.health_component.max_health = new_max
		# Don't let current health exceed new max
		player.health_component.current_health = min(player.health_component.current_health, new_max)

func use_item(item: Item) -> bool:
	if item.item_type != Item.ItemType.CONSUMABLE:
		print("Cannot use this item")
		return false
	
	if not player or not player.health_component:
		print("Cannot use item - missing player or health component")
		return false
	
	# Apply consumable effects
	if item.health_restore > 0:
		player.health_component.heal(item.health_restore)
		print("Restored %.0f health" % item.health_restore)
	
	# Remove consumed item
	remove_item(item, 1)
	return true

func get_equipped_weapon() -> Item:
	return equipped_items.get("weapon", null)

func get_total_damage_bonus() -> float:
	var weapon = get_equipped_weapon()
	if weapon:
		return weapon.damage
	return 0.0

func get_total_defense() -> float:
	var defense = 0.0
	for item in equipped_items.values():
		if item.item_type == Item.ItemType.ARMOR:
			defense += item.defense
	return defense

func clear_inventory() -> void:
	inventory.clear()
	inventory_updated.emit()
	print("Inventory cleared")
