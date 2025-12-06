extends Control

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var portrait_rect: TextureRect = $DialoguePanel/HBoxContainer/Portrait
@onready var npc_name_label: Label = $DialoguePanel/HBoxContainer/DialogueContent/NPCName
@onready var dialogue_text: RichTextLabel = $DialoguePanel/HBoxContainer/DialogueContent/DialogueText
@onready var responses_container: VBoxContainer = $DialoguePanel/HBoxContainer/DialogueContent/ResponsesContainer

var current_npc

func _ready() -> void:
	visible = false
	# Allow this UI to process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_dialogue(npc) -> void:
	if not npc:
		push_error("show_dialogue called with null NPC")
		return
	
	current_npc = npc
	var dialogue_data = npc.get_current_dialogue()
	
	# Setup UI
	if npc_name_label:
		npc_name_label.text = dialogue_data.npc_name
	
	if dialogue_text:
		dialogue_text.text = dialogue_data.text
	
	if portrait_rect and dialogue_data.portrait:
		portrait_rect.texture = dialogue_data.portrait
		portrait_rect.visible = true
	elif portrait_rect:
		portrait_rect.visible = false
	
	# Clear old responses
	if responses_container:
		for child in responses_container.get_children():
			child.queue_free()
		
		# Wait a frame for old buttons to be removed
		await get_tree().process_frame
		
		# Add response buttons
		for response in dialogue_data.responses:
			add_response_button(response)
	
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func add_response_button(response: Dictionary) -> void:
	# Create button manually
	var button = Button.new()
	button.custom_minimum_size = Vector2(400, 50)
	
	# Check if this is a continue button or end button
	var is_continue = response.get("is_continue", false)
	var is_end_button = response.get("is_end_button", false)
	
	# Build button text with effect indicators
	var button_text = response.text
	var effects = []
	
	# Only show effect indicators for normal response buttons
	if not is_continue and not is_end_button:
		# Check for affection change
		if response.has("affection_change") and response.affection_change != 0:
			var affection = response.affection_change
			if affection > 0:
				effects.append("♥+%d" % affection)
			elif affection < 0:
				effects.append("♥%d" % affection)
		
		# Check for reputation change
		if response.has("reputation_change") and response.reputation_change != 0:
			var reputation = response.reputation_change
			if reputation > 0:
				effects.append("★+%d" % reputation)
			elif reputation < 0:
				effects.append("★%d" % reputation)
		
		# Add effects to button text
		if effects.size() > 0:
			button_text += " [" + ", ".join(effects) + "]"
	
	button.text = button_text
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Style the continue button differently
	if is_continue:
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.3, 0.5, 0.7, 0.8)  # Blue-ish tint
		style_normal.border_width_left = 2
		style_normal.border_width_top = 2
		style_normal.border_width_right = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color(0.5, 0.7, 0.9, 1.0)
		style_normal.corner_radius_top_left = 5
		style_normal.corner_radius_top_right = 5
		style_normal.corner_radius_bottom_left = 5
		style_normal.corner_radius_bottom_right = 5
		
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.4, 0.6, 0.8, 0.9)  # Lighter blue on hover
		style_hover.border_width_left = 2
		style_hover.border_width_top = 2
		style_hover.border_width_right = 2
		style_hover.border_width_bottom = 2
		style_hover.border_color = Color(0.6, 0.8, 1.0, 1.0)
		style_hover.corner_radius_top_left = 5
		style_hover.corner_radius_top_right = 5
		style_hover.corner_radius_bottom_left = 5
		style_hover.corner_radius_bottom_right = 5
		
		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_hover)
		
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = "> " + button.text
	
	# Style the end button differently (red-ish)
	elif is_end_button:
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.6, 0.3, 0.3, 0.8)  # Red-ish tint
		style_normal.border_width_left = 2
		style_normal.border_width_top = 2
		style_normal.border_width_right = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color(0.8, 0.4, 0.4, 1.0)
		style_normal.corner_radius_top_left = 5
		style_normal.corner_radius_top_right = 5
		style_normal.corner_radius_bottom_left = 5
		style_normal.corner_radius_bottom_right = 5
		
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.7, 0.4, 0.4, 0.9)  # Lighter red on hover
		style_hover.border_width_left = 2
		style_hover.border_width_top = 2
		style_hover.border_width_right = 2
		style_hover.border_width_bottom = 2
		style_hover.border_color = Color(0.9, 0.5, 0.5, 1.0)
		style_hover.corner_radius_top_left = 5
		style_hover.corner_radius_top_right = 5
		style_hover.corner_radius_bottom_left = 5
		style_hover.corner_radius_bottom_right = 5
		
		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_hover)
		
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = "X " + button.text
	
	# Make button process during pause
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	button.pressed.connect(_on_response_selected.bind(response.next_id, response))
	
	if responses_container:
		responses_container.add_child(button)

func _on_response_selected(response_id: String, response_data: Dictionary = {}) -> void:
	if not current_npc:
		return
	
	var next_dialogue = current_npc.handle_response(response_id, response_data)
	
	if next_dialogue.text.is_empty():
		# End dialogue
		hide_dialogue()
	else:
		# Show next dialogue
		if dialogue_text:
			dialogue_text.text = next_dialogue.text
		
		# Clear old responses
		if responses_container:
			for child in responses_container.get_children():
				child.queue_free()
			
			# Wait a frame for old buttons to be removed
			await get_tree().process_frame
			
			# Add new response buttons
			for response in next_dialogue.responses:
				add_response_button(response)

func hide_dialogue() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	
	if current_npc:
		current_npc.end_dialogue()
	
	current_npc = null

func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("ui_cancel"):
			hide_dialogue()
			get_viewport().set_input_as_handled()
