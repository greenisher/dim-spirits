extends Control

@onready var inventory_grid: GridContainer = $MarginContainer/VBoxContainer/HeldItems/InventoryGrid
@onready var equip_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/EquipButton
@onready var use_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/UseButton
@onready var drop_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/DropButton

var selected_item: Item = null
var selected_slot: Control = null

func _ready() -> void:
	print("=== INVENTORY _ready() START ===")
	
	await get_tree().process_frame
	
	# Connect to inventory manager
	if has_node("/root/InventoryManager"):
		var inv_mgr = get_node("/root/InventoryManager")
		inv_mgr.inventory_updated.connect(refresh_inventory)
		print("Connected to InventoryManager")
	
	# Connect buttons
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	if drop_button:
		drop_button.pressed.connect(_on_drop_pressed)
	
	refresh_inventory()
	print("=== INVENTORY _ready() END ===")

func open_inventory() -> void:
	print("=== OPEN INVENTORY CALLED ===")
	refresh_inventory()
	visible = true

func refresh_inventory() -> void:
	print("=== REFRESH START ===")
	
	if not inventory_grid:
		print("ERROR: No inventory_grid!")
		return
	
	# Clear
	for child in inventory_grid.get_children():
		child.queue_free()
	
	if not has_node("/root/InventoryManager"):
		print("ERROR: No InventoryManager!")
		return
	
	var inv_mgr = get_node("/root/InventoryManager")
	print("Inventory size: ", inv_mgr.inventory.size())
	
	for stack in inv_mgr.inventory:
		print("Processing stack: ", stack.item.item_name)
		var success = create_item_slot(stack.item, stack.quantity)
		print("Slot creation result: ", success)
	
	print("=== REFRESH END ===")

func create_item_slot(item: Item, quantity: int) -> bool:
	print(">>> create_item_slot START for: ", item.item_name)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.text = item.item_name
	
	btn.pressed.connect(func(): print("CLICKED: ", item.item_name))
	btn.mouse_entered.connect(func(): print("HOVER: ", item.item_name))
	btn.mouse_exited.connect(func(): print("UNHOVER"))
	
	inventory_grid.add_child(btn)
	
	print(">>> create_item_slot END")
	return true

func _on_equip_pressed() -> void:
	print("Equip pressed")

func _on_use_pressed() -> void:
	print("Use pressed")

func _on_drop_pressed() -> void:
	print("Drop pressed")
