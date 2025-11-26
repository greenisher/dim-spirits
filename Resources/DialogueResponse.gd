extends Resource
class_name DialogueResponse

@export var text: String = ""
@export var next_node_id: String = ""


@export_group("Effects")
@export var affection_change: int = 0 
@export var reputation_change: int = 0  
@export var faction_id: String = ""  

@export_group("Animation")
## Animation to play when player selects this response
## Examples: "nod", "shake_head", "agree", "disagree", "laugh", "think"
@export var npc_reaction_animation: String = ""

## How long to wait after animation before showing next dialogue (seconds)
@export var animation_delay: float = 0.0
