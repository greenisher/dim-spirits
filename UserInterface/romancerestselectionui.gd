extends Control
## Romance Rest Character Selection UI
##
## This panel allows players to select which romance options to invite
## to rest with them at the campfire.

# ==================== NODE REFERENCES ====================

@onready var title_label: Label = %TitleLabel if has_node("%TitleLabel") else null
@onready var character_container: VBoxContainer = %CharacterContainer if has_node("%CharacterContainer") else null
@onready var selected_label: Label = %SelectedLabel if has_node("%SelectedLabel") else null
@onready var confirm_button: Button = %ConfirmButton if has_node("%ConfirmButton") else null
@onready var reset_button: Button = %ResetButton if has_node("%ResetButton") else null
@onready var back_button: Button = %BackButton if has_node("%BackButton") else null

# ==================== CONFIGURATION ====================

@export var character_item_scene: PackedScene
@export var available_color: Color = Color.WHITE
@export var unavailable_color: Color = Color(0.5, 0.5, 0.5)

# ==================== STATE ====================

var selected_characters: Array[String] = []
var character_checkboxes: Dictionary = {}  # character_name -> CheckBox
var romance_rest_manager: Node = null

# ==================== SIGNALS ====================

signal invitation_confirmed(characters: Array)
signal back_pressed()

# ==================== INITIALIZATION ====================

func _ready() -> void:
	if has_node("/root/RomanceRestManager"):
		romance_rest_manager = get_node("/root/RomanceRestManager")
	else:
		push_error("RomanceRestManager not found! Make sure it's added as an autoload.")
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	visible = false

# ==================== PUBLIC METHODS ====================

func open() -> void:
	if not romance_rest_manager:
		push_error("RomanceRestManager not available")
		return
	
	visible = true
	selected_characters.clear()
	_populate_character_list()
	_update_ui()

func close() -> void:
	visible = false
	selected_characters.clear()

# ==================== CHARACTER LIST ====================

func _populate_character_list() -> void:
	if not character_container:
		push_error("CharacterContainer not found!")
		return
	
	for child in character_container.get_children():
		child.queue_free()
	character_checkboxes.clear()
	
	var available_characters = romance_rest_manager.get_available_romance_options()
	
	if available_characters.is_empty():
		_show_no_characters_message()
		return
	
	for character in available_characters:
		_create_character_item(character)

func _create_character_item(character_name: String) -> void:
	var item: Control
	
	if character_item_scene:
		item = character_item_scene.instantiate()
	else:
		item = _create_default_character_item(character_name)
	
	character_container.add_child(item)
	
	var checkbox: CheckBox = null
	if item is CheckBox:
		checkbox = item
	else:
		checkbox = item.find_child("*", true, false) as CheckBox
		if not checkbox:
			if item.has_node("CheckBox"):
				checkbox = item.get_node("CheckBox")
	
	if not checkbox:
		push_error("Could not find CheckBox in character item for: " + character_name)
		return
	
	checkbox.text = character_name
	checkbox.toggled.connect(_on_character_toggled.bind(character_name))
	character_checkboxes[character_name] = checkbox
	
	var has_solo_scenes = romance_rest_manager.has_scenes_remaining([character_name])
	if not has_solo_scenes:
		var label = checkbox
		label.text += " (No more solo scenes)"
		label.modulate = unavailable_color

func _create_default_character_item(character_name: String) -> CheckBox:
	var checkbox = CheckBox.new()
	checkbox.text = character_name
	checkbox.custom_minimum_size = Vector2(0, 32)
	return checkbox

func _show_no_characters_message() -> void:
	var label = Label.new()
	label.text = "You haven't met any romance options yet."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_container.add_child(label)
	
	if confirm_button:
		confirm_button.disabled = true

# ==================== SELECTION HANDLING ====================

func _on_character_toggled(is_selected: bool, character_name: String) -> void:
	if is_selected:
		if not selected_characters.has(character_name):
			selected_characters.append(character_name)
	else:
		selected_characters.erase(character_name)
	
	_update_ui()

func _update_ui() -> void:
	_update_selected_label()
	_update_confirm_button()

func _update_selected_label() -> void:
	if not selected_label:
		return
	
	if selected_characters.is_empty():
		selected_label.text = "No one selected"
		selected_label.modulate = unavailable_color
	else:
		var display_name = " & ".join(selected_characters)
		selected_label.text = "Selected: " + display_name
		selected_label.modulate = available_color
		
		if romance_rest_manager:
			var has_scenes = romance_rest_manager.has_scenes_remaining(selected_characters)
			if not has_scenes:
				selected_label.text += "\n(No scenes available for this combination)"
				selected_label.modulate = Color(1.0, 0.5, 0.5)  # Red-ish

func _update_confirm_button() -> void:
	if not confirm_button:
		return
	
	var can_confirm = false
	
	if not selected_characters.is_empty() and romance_rest_manager:
		can_confirm = romance_rest_manager.has_scenes_remaining(selected_characters)
	
	confirm_button.disabled = not can_confirm

# ==================== BUTTON HANDLERS ====================

func _on_confirm_pressed() -> void:
	if selected_characters.is_empty():
		return
	
	if not romance_rest_manager:
		push_error("RomanceRestManager not available")
		return
			
	if not romance_rest_manager.has_scenes_remaining(selected_characters):
		_show_no_scenes_message()
		return
	
	invitation_confirmed.emit(selected_characters.duplicate())
	close()

func _on_reset_pressed() -> void:
	selected_characters.clear()
	
	for checkbox in character_checkboxes.values():
		checkbox.button_pressed = false
	
	_update_ui()

func _on_back_pressed() -> void:
	back_pressed.emit()
	close()

# ==================== MESSAGES ====================

func _show_no_scenes_message() -> void:
	print("No more scenes available for this combination!")
	# TODO: Show a proper notification panel
	# For now, just print and disable confirm
	if confirm_button:
		confirm_button.disabled = true

# ==================== INPUT HANDLING ====================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
