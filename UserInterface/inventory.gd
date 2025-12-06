extends Control

@onready var endurance_value: Label = %EnduranceValue
@onready var intelligence_value: Label = %IntelligenceValue
@onready var agility_value: Label = %AgilityValue
@onready var strength_value: Label = %StrengthValue
@onready var level_label: Label = %LevelLabel
@onready var attack_value: Label = %AttackValue
@onready var health_value: Label = %HealthValue
@onready var xp_value: Label = %XPValue
@onready var next_xp_value: Label = %NextXPValue

@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var equip_button: Button = %EquipButton
@onready var use_button: Button = %UseButton
@onready var drop_button: Button = %DropButton
@onready var description_label: RichTextLabel = %DescriptionPanel
@onready var back_button: Button = %BackButton

# Better player reference handling
var player: Player = null

# Export starting items so you can configure them in the editor
@export var starting_items: Array[Item] = []

var selected_item: Item = null
var selected_slot: Control = null
var last_hovered_button = null
var starting_items_added: bool = false

# Manual hover detection - processes every frame to check mouse position
func _process(_delta: float) -> void:
	if not visible or not inventory_grid:
		return
	
	var mouse_pos = get_global_mouse_position()
	var found_hover = false
	
	for child in inventory_grid.get_children():
		if not child is Button:
			continue
		if not child.has_meta("is_item_slot"):
			continue
		
		var button_rect = child.get_global_rect()
		if button_rect.has_point(mouse_pos):
			found_hover = true
			if child != last_hovered_button:
				# Newly hovered
				var item = child.get_meta("item_data") as Item
				_on_slot_hovered(item)
				last_hovered_button = child
			break
	
	if not found_hover and last_hovered_button:
		_on_slot_unhovered()
		last_hovered_button = null

# Manual click detection because automatic isnt working
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	if not visible:
		return
	
	var click_pos = event.global_position
	
	# Check each button in the grid
	if inventory_grid:
		for child in inventory_grid.get_children():
			if not child is Button:
				continue
			if not child.has_meta("is_item_slot"):
				continue
			
			var button_rect = child.get_global_rect()
			if button_rect.has_point(click_pos):
				print("✅ Manual click detected on item slot!")
				var item = child.get_meta("item_data") as Item
				_on_slot_pressed(item, child)
				get_viewport().set_input_as_handled()
				return

func _ready() -> void:
	print("Inventory _ready called")
	
	# Allow processing when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# CRITICAL: Remember to set parent to ALWAYS mode too
	var parent = get_parent()
	if parent:
		parent.process_mode = Node.PROCESS_MODE_ALWAYS
		print("Set parent (", parent.name, ") process_mode to ALWAYS")
	
	await get_tree().process_frame
	
	if inventory_grid:
		inventory_grid.process_mode = Node.PROCESS_MODE_ALWAYS
		inventory_grid.mouse_filter = Control.MOUSE_FILTER_STOP
		print("InventoryGrid process_mode set to ALWAYS")
		print("InventoryGrid mouse_filter set to STOP")
	
	# Better player reference acquisition
	find_player_reference()
	
	if player and player.health_component:
		player.health_component.health_changed.connect(_on_health_changed)
		update_stats()
	
	# Connect to InventoryManager
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		if inv_mgr.has_signal("inventory_updated"):
			inv_mgr.inventory_updated.connect(refresh_inventory)
			print("Inventory connected to InventoryManager")
		
		# Add starting items to inventory (only once)
		add_starting_items()
	
	# Connect buttons
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)
		equip_button.disabled = true
		equip_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
		use_button.disabled = true
		use_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if drop_button:
		drop_button.pressed.connect(_on_drop_pressed)
		drop_button.disabled = true
		drop_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect back button properly
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		back_button.process_mode = Node.PROCESS_MODE_ALWAYS
		print("✓ Back button connected")
	else:
		print("⚠️ Back button not found! Make sure it has unique name %BackButton")
	
	# Initialize description panel
	if description_label:
		description_label.text = "Hover over or click an item to see details."
		description_label.visible = true
		description_label.process_mode = Node.PROCESS_MODE_ALWAYS
		print("✓ Description label initialized")
	
	# Connect visibility changed to update stats when opened
	visibility_changed.connect(_on_visibility_changed)
	
	refresh_inventory()

# ==================== IMPROVED PLAYER REFERENCE ====================

func find_player_reference() -> void:
	"""Find the player node with multiple fallback methods"""
	print("=== Finding Player Reference ===")
	
	# Method 1: Try parent.player
	var parent = get_parent()
	if parent and "player" in parent:
		player = parent.player
		if player:
			print("✅ Found player via parent.player")
			return
	
	# Method 2: Search for Player in scene tree
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]
		print("✅ Found player via 'Player' group")
		return
	
	# Method 3: Find by class name
	for node in get_tree().get_nodes_in_group("Player"):
		if node is Player:
			player = node
			print("✅ Found player by class type")
			return
	
	# Method 4: Search parent chain
	var current = get_parent()
	while current:
		if current.name == "Player" or current is Player:
			player = current
			print("✅ Found player in parent chain")
			return
		if "player" in current:
			player = current.player
			if player:
				print("✅ Found player via parent chain property")
				return
		current = current.get_parent()
	
	print("❌ Could not find player reference!")
	print("   Make sure Player node is in 'Player' group or accessible via parent")

# ==================== FIXED UPDATE_STATS FUNCTION ====================

func update_stats() -> void:
	"""Update all stat displays with improved error handling"""
	print("=== Updating Stats ===")
	
	# Verify player reference
	if not player:
		print("❌ No player reference!")
		find_player_reference()
		if not player:
			print("❌ Still no player - cannot update stats")
			return
	
	print("✓ Player found:", player.name)
	
	# Check player.stats
	if not player.stats:
		print("❌ Player has no stats!")
		return
	
	print("✓ Player.stats found")
	
	# Check health component
	if not player.health_component:
		print("❌ Player has no health_component!")
	else:
		print("✓ Player.health_component found")
	
	# Update each stat individually with error handling
	update_strength()
	update_endurance()
	update_agility()
	update_intelligence()
	update_level()
	update_xp()
	update_next_xp()
	update_health()
	
	print("=== Stats Update Complete ===")

# Individual stat update functions
func update_strength() -> void:
	if not strength_value:
		print("⚠️ Label not found: Strength")
		return
	if not player.stats.strength:
		print("❌ Error: strength stat doesn't exist")
		strength_value.text = "Error"
		return
	var value = str(player.stats.strength.ability_score)
	strength_value.text = value
	print("✓ Updated Strength: %s" % value)

func update_endurance() -> void:
	if not endurance_value:
		print("⚠️ Label not found: Endurance")
		return
	if not player.stats.endurance:
		print("❌ Error: endurance stat doesn't exist")
		endurance_value.text = "Error"
		return
	var value = str(player.stats.endurance.ability_score)
	endurance_value.text = value
	print("✓ Updated Endurance: %s" % value)

func update_agility() -> void:
	if not agility_value:
		print("⚠️ Label not found: Agility")
		return
	if not player.stats.agility:
		print("❌ Error: agility stat doesn't exist")
		agility_value.text = "Error"
		return
	var value = str(player.stats.agility.ability_score)
	agility_value.text = value
	print("✓ Updated Agility: %s" % value)

func update_intelligence() -> void:
	if not intelligence_value:
		print("⚠️ Label not found: Intelligence")
		return
	if not player.stats.intelligence:
		print("❌ Error: intelligence stat doesn't exist")
		intelligence_value.text = "Error"
		return
	var value = str(player.stats.intelligence.ability_score)
	intelligence_value.text = value
	print("✓ Updated Intelligence: %s" % value)

func update_level() -> void:
	if not level_label:
		print("⚠️ Label not found: Level")
		return
	var value = "Level %s" % str(player.stats.level)
	level_label.text = value
	print("✓ Updated Level: %s" % value)

func update_xp() -> void:
	if not xp_value:
		print("⚠️ Label not found: XP")
		return
	var value = str(player.stats.xp)
	xp_value.text = value
	print("✓ Updated XP: %s" % value)

func update_next_xp() -> void:
	if not next_xp_value:
		print("⚠️ Label not found: Next XP")
		return
	if not player.stats.has_method("get_xp_to_next_level"):
		print("❌ Error: percentage_level_up_boundary method doesn't exist")
		next_xp_value.text = "Error"
		return
	var value = str(player.stats.get_xp_to_next_level())
	next_xp_value.text = value
	print("✓ Updated Next XP: %s" % value)

func update_health() -> void:
	if not health_value:
		print("⚠️ Label not found: Health")
		return
	
	if not player.health_component:
		health_value.text = "N/A"
		return
	
	if not player.health_component.has_method("get_health_string"):
		print("❌ Error: get_health_string method doesn't exist")
		health_value.text = "Error"
		return
	
	var value = player.health_component.get_health_string()
	health_value.text = value
	print("✓ Updated Health: %s" % value)

# ==================== VISIBILITY HANDLING ====================

func _on_visibility_changed() -> void:
	"""Update stats whenever inventory becomes visible"""
	if visible:
		print("Inventory became visible - updating stats")
		update_stats()
		update_gear_stats()

# ==================== STARTING ITEMS SYSTEM ====================

func add_starting_items() -> void:
	"""Add starting items to the inventory (only called once)"""
	if starting_items_added:
		return
	
	if not has_node("/root/InventoryManager"):
		print("⚠️ InventoryManager not found, cannot add starting items")
		return
	
	var inv_mgr = get_node("/root/InventoryManager")
	
	# Add BridsBlade by default (hardcoded path)
	var brids_blade = load("res://Items/brids_blade.tres")
	if brids_blade:
		inv_mgr.add_item(brids_blade, 1)
		print("✅ Added starting weapon: BridsBlade")
	else:
		print("⚠️ Could not load BridsBlade from res://items/weapons/BridsBlade.tres")
		print("   Make sure the path is correct!")
	
	# Add any additional starting items from the exported array
	for item in starting_items:
		if item:
			inv_mgr.add_item(item, 1)
			print("✅ Added starting item: ", item.item_name)
	
	starting_items_added = true
	print("Starting items added to inventory")

# ==================== ORIGINAL FUNCTIONS ====================

# Called when inventory is opened
func open_inventory() -> void:
	print("Inventory opened, refreshing...")
	refresh_inventory()
	update_stats()
	update_gear_stats()

func _on_health_changed(current: float, maximum: float) -> void:
	if health_value:
		health_value.text = "%d/%d" % [int(current), int(maximum)]

# Original gear stats function
func update_gear_stats() -> void:
	if attack_value:
		attack_value.text = str(get_weapon_value())
	else:
		print("⚠️ Attack value label not found")

func get_weapon_value() -> float:
	if not player or not player.stats:
		return 0.0
	var damage = 10.0 
	damage += player.stats.get_damage_modifier()
	return damage

# New inventory grid functions
func refresh_inventory() -> void:
	print("Refreshing inventory grid")
	
	if not inventory_grid:
		print("ERROR: inventory_grid not found")
		return
	
	# Clear existing items
	for child in inventory_grid.get_children():
		child.queue_free()
	
	if not has_node("/root/InventoryManager"):
		return
	
	var inv_mgr = get_node("/root/InventoryManager")
	print("Found ", inv_mgr.inventory.size(), " items in inventory")
	
	# Create slots
	for stack in inv_mgr.inventory:
		create_item_slot(stack.item, stack.quantity)

func create_item_slot(item: Item, quantity: int) -> void:
	print("Creating slot for: ", item.item_name)
	
	# Create a Button
	var slot = Button.new()
	slot.custom_minimum_size = Vector2(80, 80)
	slot.process_mode = Node.PROCESS_MODE_ALWAYS
	slot.focus_mode = Control.FOCUS_NONE
	slot.flat = true
	
	slot.set_meta("item_data", item)
	slot.set_meta("is_item_slot", true)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)
	
	# Add icon or placeholder
	if item.icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = item.icon
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_rect)
	else:
		var placeholder = Label.new()
		placeholder.text = item.item_name.substr(0, 1)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.custom_minimum_size = Vector2(64, 64)
		placeholder.add_theme_font_size_override("font_size", 32)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(placeholder)
	
	# Add quantity if stackable
	if item.max_stack_size > 1:
		var qty_label = Label.new()
		qty_label.text = "x%d" % quantity
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(qty_label)
	
	inventory_grid.add_child(slot)

func _on_slot_pressed(item: Item, slot: Control) -> void:
	print("=== ITEM CLICKED: ", item.item_name, " ===")
	
	# Deselect previous
	if selected_slot and selected_slot != slot:
		selected_slot.modulate = Color.WHITE
	
	selected_item = item
	selected_slot = slot
	slot.modulate = Color(1.3, 1.3, 0.8)
	
	print("Updating description for: ", item.item_name)
	update_description(item)
	
	# Update buttons
	if equip_button:
		equip_button.disabled = item.item_type not in [Item.ItemType.WEAPON, Item.ItemType.ARMOR]
		print("Equip button enabled: ", not equip_button.disabled)
	if use_button:
		use_button.disabled = item.item_type != Item.ItemType.CONSUMABLE
	if drop_button:
		drop_button.disabled = false

func update_description(item: Item) -> void:
	if not description_label:
		return
	
	description_label.visible = true
	
	description_label.text = item.get_tooltip_text()

func _on_slot_hovered(item: Item) -> void:
	print("Hovering: ", item.item_name)
	update_description(item)

func _on_slot_unhovered() -> void:
	if not selected_item and description_label:
		description_label.text = "Hover over or click an item to see details."

# ==================== REFACTORED EQUIP FUNCTION ====================
func _on_equip_pressed() -> void:
	if not selected_item:
		return
	
	print("Equipping: ", selected_item.item_name)
	
	# Check if the item is a weapon and has a packed scene path
	if selected_item.item_type == Item.ItemType.WEAPON:
		if "weapon_scene_path" in selected_item and selected_item.weapon_scene_path != "":
			# Load and equip the weapon scene
			if player:
				player.equip_weapon(selected_item.weapon_scene_path)
				print("Loaded weapon scene: ", selected_item.weapon_scene_path)
			else:
				print("❌ Cannot equip weapon - no player reference!")
		else:
			print("WARNING: Weapon item has no weapon_scene_path property!")
	
	# Also notify the inventory manager
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		inv_mgr.equip_item(selected_item)
	
	# Clear selection
	selected_item = null
	if selected_slot:
		selected_slot.modulate = Color.WHITE
	selected_slot = null
	
	# Update UI
	update_gear_stats()

func _on_use_pressed() -> void:
	if not selected_item:
		return
	
	print("Using: ", selected_item.item_name)
	
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		inv_mgr.use_item(selected_item)
		selected_item = null
		if selected_slot:
			selected_slot.modulate = Color.WHITE
		selected_slot = null

func _on_drop_pressed() -> void:
	if not selected_item:
		return
	
	print("Dropping: ", selected_item.item_name)
	
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		inv_mgr.remove_item(selected_item, 1)
		
		# Spawn in world
		if player:
			var pickup_scene = load("res://items/pickup_item.tscn")
			if pickup_scene:
				var pickup = pickup_scene.instantiate()
				pickup.item = selected_item
				pickup.global_position = player.global_position + player.global_transform.basis.z * 2
				get_tree().current_scene.add_child(pickup)
		
		selected_item = null
		if selected_slot:
			selected_slot.modulate = Color.WHITE
		selected_slot = null

func _on_back_button_pressed() -> void:
	print("Back button pressed!")
	get_parent().close_menu()
