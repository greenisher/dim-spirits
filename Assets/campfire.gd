extends Node3D

@onready var save_zone: ShapeCast3D = %Save_Zone
@onready var campfire_menu: Control = $Campfire_Menu
@export var player: Player

var player_in_range: bool = false
var menu_open: bool = false
var _closing: bool = false  # Recursion guard

func _ready() -> void:
	if campfire_menu:
		campfire_menu.visible = false

func _physics_process(delta: float) -> void:
	check_for_player()

func _input(event: InputEvent) -> void:
	if player_in_range and not menu_open:
		if event.is_action_pressed("interact"):  
			open_menu()
	
	if menu_open and event.is_action_pressed("ui_cancel"):
		close_menu()

func check_for_player() -> void:
	var was_in_range = player_in_range
	player_in_range = false
	
	for collision_id in save_zone.get_collision_count():
		var collider = save_zone.get_collider(collision_id)
		if collider is Player:
			player_in_range = true
			if not player:
				player = collider
			break
	
	if player_in_range and not was_in_range:
		show_interaction_prompt()
	elif not player_in_range and was_in_range:
		hide_interaction_prompt()

func show_interaction_prompt() -> void:
	# TODO: Show "Press E to rest at campfire" prompt
	print("Press Enter to rest at campfire")

func hide_interaction_prompt() -> void:
	# TODO: Hide interaction prompt
	pass

func open_menu() -> void:
	if not player:
		print("No player reference!")
		return
	
	menu_open = true
	campfire_menu.visible = true
	
	if campfire_menu.has_method("open_menu"):
		campfire_menu.open_menu(player)
	
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	print("Campfire menu opened")
	
	heal_player()
	
	# TODO: Save game automatically
	auto_save()

func close_menu() -> void:
	if _closing:
		return  # Already closing, prevent recursion
	
	_closing = true
	menu_open = false
	campfire_menu.visible = false
	
	if campfire_menu.has_method("close_menu"):
		campfire_menu.close_menu()
	
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	print("Campfire menu closed")
	_closing = false

func heal_player() -> void:
	if not player or not player.health_component:
		print("Cannot heal: No player or health component")
		return
	
	# Check if HealthComponent has a heal method (preferred)
	if player.health_component.has_method("heal"):
		var heal_amount = player.health_component.max_health
		player.health_component.heal(heal_amount)
		print("Player healed using heal() method")
	# Otherwise set current_health directly
	else:
		player.health_component.current_health = player.health_component.max_health
		print("Player healed to full HP: %d/%d" % [
			player.health_component.current_health, 
			player.health_component.max_health
		])

func auto_save() -> void:
	if has_node("/root/SaveManager"):
		var save_mgr = get_node("/root/SaveManager")
		if save_mgr.has_method("save_game"):
			save_mgr.save_game()
			print("Game auto-saved at campfire")
		else:
			print("SaveManager exists but has no save_game method")
	else:
		print("No SaveManager autoload found - skipping auto-save")
