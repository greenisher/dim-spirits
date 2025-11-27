extends Control

# ==================== NODE REFERENCES ====================

@onready var background: TextureRect = %Background if has_node("%Background") else null
@onready var dialogue_label: RichTextLabel = %DialogueLabel if has_node("%DialogueLabel") else null
@onready var speaker_label: Label = %SpeakerLabel if has_node("%SpeakerLabel") else null
@onready var character_portrait: TextureRect = %CharacterPortrait if has_node("%CharacterPortrait") else null
@onready var continue_button: Button = %ContinueButton if has_node("%ContinueButton") else null
@onready var skip_button: Button = %SkipButton if has_node("%SkipButton") else null
@onready var dialogue_box: Control = %DialogueBox if has_node("%DialogueBox") else null

# ==================== SIGNALS ====================

signal cutscene_started()
signal cutscene_finished()
signal line_displayed(line_index: int)
signal line_completed(line_index: int)

# ==================== CONFIGURATION ====================

@export var text_speed: float = 40.0
@export var auto_advance_time: float = 0.0
@export var fade_duration: float = 0.5
@export var can_skip_cutscene: bool = true
@export var show_skip_button: bool = true

# ==================== AUDIO ====================

@onready var typing_sound: AudioStreamPlayer = $TypingSound if has_node("TypingSound") else null
@onready var advance_sound: AudioStreamPlayer = $AdvanceSound if has_node("AdvanceSound") else null

# ==================== STATE ====================

var current_lines: Array[Dictionary] = []
var current_line_index: int = 0
var is_typing: bool = false
var is_active: bool = false

# ==================== INITIALIZATION ====================

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		skip_button.visible = show_skip_button and can_skip_cutscene
	
	visible = false
	modulate.a = 0.0

# ==================== PUBLIC API ====================

func play_cutscene(lines: Array[Dictionary]) -> void:
	if is_active:
		push_warning("Cutscene already playing")
		return
	
	current_lines = lines
	current_line_index = 0
	is_active = true
	
	visible = true
	cutscene_started.emit()
	
	await fade_in()
	_display_next_line()

func play_cutscene_from_file(json_path: String) -> void:
	var lines = load_cutscene_from_json(json_path)
	if lines.is_empty():
		push_error("Failed to load cutscene from: " + json_path)
		cutscene_finished.emit()
		return
	
	play_cutscene(lines)

func skip_current_line() -> void:
	if is_typing:
		_finish_typing()

func skip_cutscene() -> void:
	if can_skip_cutscene and is_active:
		_end_cutscene()

# ==================== LINE DISPLAY ====================

func _display_next_line() -> void:
	if current_line_index >= current_lines.size():
		_end_cutscene()
		return
	
	var line_data = current_lines[current_line_index]
	
	# Update speaker
	if speaker_label and line_data.has("speaker"):
		speaker_label.text = line_data["speaker"]
		speaker_label.visible = not line_data["speaker"].is_empty()
	
	# Update portrait
	if character_portrait:
		if line_data.has("portrait") and line_data["portrait"] != null:
			character_portrait.texture = line_data["portrait"]
			character_portrait.visible = true
		else:
			character_portrait.visible = false
	
	# Update background
	if background and line_data.has("background") and line_data["background"] != null:
		background.texture = line_data["background"]
	
	# Play voice line if specified
	if line_data.has("voice") and line_data["voice"] != null:
		_play_voice(line_data["voice"])
	
	line_displayed.emit(current_line_index)
	
	# Animate text
	await _type_text(line_data.get("text", ""))
	
	line_completed.emit(current_line_index)
	
	# Auto-advance or wait for input
	if auto_advance_time > 0:
		await get_tree().create_timer(auto_advance_time).timeout
		_advance_line()
	else:
		_show_continue_prompt()

func _type_text(text: String) -> void:
	if not dialogue_label:
		return
	
	is_typing = true
	dialogue_label.visible_characters = 0
	dialogue_label.text = text
	
	if continue_button:
		continue_button.visible = false
	
	var total_chars = text.length()
	var chars_per_frame = text_speed / Engine.get_frames_per_second()
	var char_counter: float = 0.0
	
	while dialogue_label.visible_characters < total_chars:
		if not is_typing:  # Skip was pressed
			break
		
		char_counter += chars_per_frame
		var new_visible = int(char_counter)
		
		if new_visible > dialogue_label.visible_characters:
			dialogue_label.visible_characters = new_visible
			_play_typing_sound()
		
		await get_tree().process_frame
	
	dialogue_label.visible_characters = -1  # Show all
	is_typing = false

func _finish_typing() -> void:
	is_typing = false
	if dialogue_label:
		dialogue_label.visible_characters = -1

func _show_continue_prompt() -> void:
	if continue_button:
		continue_button.visible = true

func _advance_line() -> void:
	_play_advance_sound()
	current_line_index += 1
	_display_next_line()

func _end_cutscene() -> void:
	is_active = false
	await fade_out()
	visible = false
	cutscene_finished.emit()

# ==================== TRANSITIONS ====================

func fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	await tween.finished

func fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished

# ==================== AUDIO ====================

func _play_typing_sound() -> void:
	if typing_sound and typing_sound.stream:
		typing_sound.play()

func _play_advance_sound() -> void:
	if advance_sound and advance_sound.stream:
		advance_sound.play()

func _play_voice(audio_stream: AudioStream) -> void:
	pass

# ==================== INPUT ====================

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Advance/skip with standard inputs
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if is_typing:
			skip_current_line()
		else:
			_advance_line()
		get_viewport().set_input_as_handled()
	
	# Skip cutscene with ESC
	elif event.is_action_pressed("ui_cancel") and can_skip_cutscene:
		skip_cutscene()
		get_viewport().set_input_as_handled()

func _on_continue_pressed() -> void:
	_advance_line()

func _on_skip_pressed() -> void:
	skip_cutscene()

# ==================== LOADING FROM JSON ====================

## Load cutscene from JSON file
## Returns Array[Dictionary] with dialogue lines
func load_cutscene_from_json(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		push_error("Cutscene file not found: " + path)
		return []
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open cutscene file: " + path)
		return []
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse cutscene JSON: " + path)
		return []
	
	var data = json.data
	
	var lines: Array[Dictionary] = []
	for line_data in data.get("lines", []):
		var line = line_data.duplicate()
		
		if line.has("portrait_path") and not line["portrait_path"].is_empty():
			if ResourceLoader.exists(line["portrait_path"]):
				line["portrait"] = load(line["portrait_path"])
			else:
				push_warning("Portrait not found: " + line["portrait_path"])
		
		if line.has("background_path") and not line["background_path"].is_empty():
			if ResourceLoader.exists(line["background_path"]):
				line["background"] = load(line["background_path"])
			else:
				push_warning("Background not found: " + line["background_path"])
		
		if line.has("voice_path") and not line["voice_path"].is_empty():
			if ResourceLoader.exists(line["voice_path"]):
				line["voice"] = load(line["voice_path"])
			else:
				push_warning("Voice file not found: " + line["voice_path"])
		
		lines.append(line)
	
	return lines

# ==================== HELPER FUNCTIONS ====================

static func create_line(speaker: String, text: String, portrait: Texture2D = null, background: Texture2D = null) -> Dictionary:
	return {
		"speaker": speaker,
		"text": text,
		"portrait": portrait,
		"background": background
	}

func test_cutscene() -> void:
	var test_lines: Array[Dictionary] = [
		create_line("System", "This is a test cutscene."),
		create_line("Hero", "Testing dialogue line 1."),
		create_line("Hero", "Testing dialogue line 2."),
		create_line("Narrator", "The test is complete!")
	]
	play_cutscene(test_lines)
