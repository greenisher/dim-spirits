extends Node

signal dialogue_started(npc: NPC)
signal dialogue_ended(npc: NPC)

var dialogue_ui: Control
var current_npc: NPC
var is_dialogue_active: bool = false

func _ready() -> void:

	create_dialogue_ui()
	
	get_tree().node_added.connect(_on_node_added)

func create_dialogue_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DialogueUILayer"
	canvas_layer.layer = 100  # High layer to ensure it's on top
	add_child(canvas_layer)
	
	# Load the pre-made UI scene
	var dialogue_ui_scene = load("res://UserInterface/DialogueUI.tscn")
	if dialogue_ui_scene:
		dialogue_ui = dialogue_ui_scene.instantiate()
		canvas_layer.add_child(dialogue_ui)
	else:
		push_error("DialogueUI scene not found at res://UserInterface/dialogue_ui.tscn")

func setup_dialogue_ui() -> void:

	dialogue_ui.name = "DialogueUI"
	dialogue_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_ui.visible = false
	
	

func _on_node_added(node: Node) -> void:
	# Auto-connect to NPCs as they're added to the scene
	if node is NPC:
		connect_npc(node)

func connect_npc(npc: NPC) -> void:
	if not npc.dialogue_started.is_connected(_on_npc_dialogue_started):
		npc.dialogue_started.connect(_on_npc_dialogue_started)
	if not npc.dialogue_ended.is_connected(_on_npc_dialogue_ended):
		npc.dialogue_ended.connect(_on_npc_dialogue_ended)

func _on_npc_dialogue_started(npc: NPC) -> void:
	if is_dialogue_active:
		return
	
	current_npc = npc
	is_dialogue_active = true
	
	if dialogue_ui:
		dialogue_ui.show_dialogue(npc)
	
	dialogue_started.emit(npc)

func _on_npc_dialogue_ended(npc: NPC) -> void:
	is_dialogue_active = false
	current_npc = null
	dialogue_ended.emit(npc)

func end_dialogue() -> void:
	if dialogue_ui:
		dialogue_ui.hide_dialogue()
	
	if current_npc:
		current_npc.end_dialogue()
	
	is_dialogue_active = false
	current_npc = null

func is_in_dialogue() -> bool:
	return is_dialogue_active

# Helper function to start dialogue programmatically
func start_dialogue_with(npc: NPC) -> void:
	if not is_dialogue_active:
		npc.start_dialogue()
