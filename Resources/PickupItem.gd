extends Node3D
class_name PickupItem

@export var item: Item
@export var quantity: int = 1
@export var auto_pickup: bool = false

# ==================== PERSISTENCE ====================

## Unique ID for this pickup item (IMPORTANT: Must be unique per item in the scene!)
## Examples: "sword_village_001", "potion_cave_entrance", "gold_forest_clearing"
@export var unique_id: String = ""

## Auto-generate ID from position if not set
@export var auto_generate_id: bool = true

@onready var interaction_area: Area3D = $InteractionArea
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_prompt: Label3D = $InteractionPrompt

var player_in_range: bool = false

func _ready() -> void:
	# Generate unique ID if needed
	if unique_id.is_empty() and auto_generate_id:
		_generate_unique_id()
	
	# Check if this item was already picked up
	if _was_already_picked_up():
		print("Item '%s' was already picked up, removing from scene" % unique_id)
		queue_free()
		return
	
	# Setup interactions
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	
	if interaction_prompt:
		interaction_prompt.visible = false
		if item:
			interaction_prompt.text = "Press Enter to pick up %s" % item.item_name
	
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# Rotate item
	rotate_y(delta * 0.5)
	
	# Bob up and down
	var bob_amount = sin(Time.get_ticks_msec() * 0.002) * 0.3
	if mesh_instance:
		mesh_instance.position.y = bob_amount
	
	# Show/hide prompt
	if interaction_prompt:
		interaction_prompt.visible = player_in_range and not auto_pickup

func _process(_delta: float) -> void:
	if player_in_range and not auto_pickup:
		if Input.is_action_just_pressed("interact"):
			pickup()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_in_range = true
		if auto_pickup:
			pickup()

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_in_range = false

func pickup() -> void:
	if not item:
		queue_free()
		return
	
	# Try to add to inventory
	if has_node("/root/InventoryManager"):
		var inventory_manager = get_node("/root/InventoryManager")
		if inventory_manager.add_item(item, quantity):
			print("Picked up %d x %s" % [quantity, item.item_name])
			
			# Mark as picked up in GameState
			_mark_as_picked_up()
			
			# Remove from scene
			queue_free()
		else:
			print("Could not pick up item - inventory full")
	else:
		# No inventory manager, just remove
		print("Picked up %d x %s (no inventory manager)" % [quantity, item.item_name])
		_mark_as_picked_up()
		queue_free()

# ==================== PERSISTENCE HELPERS ====================

func _generate_unique_id() -> void:
	"""Generate a unique ID based on position and item name"""
	if item:
		unique_id = GameState.generate_item_id(global_position, item.item_name)
	else:
		unique_id = GameState.generate_item_id(global_position)
	
	print("Auto-generated ID for pickup item: ", unique_id)

func _was_already_picked_up() -> bool:
	"""Check if this item was already picked up in a previous session"""
	if unique_id.is_empty():
		push_warning("PickupItem has no unique_id! Item will respawn on reload.")
		return false
	
	if not has_node("/root/GameState"):
		push_warning("GameState not found! Items will respawn on reload.")
		return false
	
	return GameState.is_item_picked_up(unique_id)

func _mark_as_picked_up() -> void:
	"""Mark this item as picked up in GameState"""
	if unique_id.is_empty():
		push_warning("Cannot mark item as picked up - no unique_id set!")
		return
	
	if has_node("/root/GameState"):
		GameState.mark_item_picked_up(unique_id)
