extends Resource
class_name DialogueNode

@export var id: String = ""
@export_multiline var text: String = ""
@export var responses: Array[Resource] = []  
@export var end_dialogue: bool = false

## If true and no responses exist, automatically show a "Continue" button that goes to auto_continue_node_id
@export var auto_continue: bool = false

## The node ID to go to when player clicks "Continue" (only used if auto_continue is true)
@export var auto_continue_node_id: String = ""

@export var required_quest_flag: String = ""  # Only show if this flag is set
@export var sets_quest_flag: String = ""  # Set this flag when node is shown

@export_group("Animation")
## Animation to play when this dialogue node is shown
## Examples: "talk", "explain", "laugh", "surprised", "angry"
@export var npc_animation: String = ""

## Wait for animation to finish before showing text?
@export var wait_for_animation: bool = false

## Optional animation speed multiplier (1.0 = normal speed)
@export var animation_speed: float = 1.0
