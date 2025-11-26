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

@onready var player: Player = get_parent().player

var selected_item: Item = null
var selected_slot: Control = null
var last_hovered_button = null

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

# Manual click detection
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
	
	# CRITICAL: Set parent to ALWAYS mode too
	var parent = get_parent()
	if parent:
		parent.process_mode = Node.PROCESS_MODE_ALWAYS
		print("Set parent (", parent.name, ") process_mode to ALWAYS")
	
	await get_tree().process_frame
	
	# Set inventory grid to process when paused
	if inventory_grid:
		inventory_grid.process_mode = Node.PROCESS_MODE_ALWAYS
		inventory_grid.mouse_filter = Control.MOUSE_FILTER_STOP
		print("InventoryGrid process_mode set to ALWAYS")
		print("InventoryGrid mouse_filter set to STOP")
	
	if player and player.health_component:
		player.health_component.health_changed.connect(_on_health_changed)
		update_stats()
	
	# Connect to InventoryManager
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		if inv_mgr.has_signal("inventory_updated"):
			inv_mgr.inventory_updated.connect(refresh_inventory)
			print("Inventory connected to InventoryManager")
	
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
	
	# Initialize description panel
	if description_label:
		description_label.text = "Hover over or click an item to see details."
		description_label.visible = true
		description_label.process_mode = Node.PROCESS_MODE_ALWAYS
		print("✓ Description label initialized")
	
	refresh_inventory()

# Called when inventory is opened
func open_inventory() -> void:
	print("Inventory opened, refreshing...")
	refresh_inventory()
	update_stats()
	update_gear_stats()

func _on_health_changed(current: float, maximum: float) -> void:
	if health_value:
		health_value.text = "%d/%d" % [int(current), int(maximum)]
	if health_value:
		health_value.text = "%d/%d" % [int(current), int(maximum)]

# Original stats update function
func update_stats() -> void:
	if not player or not player.stats or not player.health_component:
		return
	
	strength_value.text = str(player.stats.strength.ability_score)
	endurance_value.text = str(player.stats.endurance.ability_score)
	agility_value.text = str(player.stats.agility.ability_score)
	intelligence_value.text = str(player.stats.intelligence.ability_score)
	level_label.text = "Level %s" % str(player.stats.level)
	health_value.text = player.health_component.get_health_string()
	xp_value.text = str(player.stats.xp)
	next_xp_value.text = str(player.stats.percentage_level_up_boundary())

# Original gear stats function
func update_gear_stats() -> void:
	attack_value.text = str(get_weapon_value())

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
	
	# Store item data in metadata for manual input handling
	slot.set_meta("item_data", item)
	slot.set_meta("is_item_slot", true)
	
	# Create visual container
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
	# Show item description
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
	
	# Make sure the panel is visible
	description_label.visible = true
	
	# Show full item info
	description_label.text = item.get_tooltip_text()

func _on_slot_hovered(item: Item) -> void:
	print("Hovering: ", item.item_name)
	# Show item description on hover
	update_description(item)

func _on_slot_unhovered() -> void:
	# Only clear if no item is selected
	if not selected_item and description_label:
		description_label.text = "Hover over or click an item to see details."

func _on_equip_pressed() -> void:
	if not selected_item:
		return
	
	print("Equipping: ", selected_item.item_name)
	
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		inv_mgr.equip_item(selected_item)
		selected_item = null
		if selected_slot:
			selected_slot.modulate = Color.WHITE
		selected_slot = null

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
	get_parent().close_menu()
