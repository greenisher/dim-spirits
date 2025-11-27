extends NPC

func _ready():
	super._ready()  # Call parent's _ready()
	
	# Override animation player reference
	if has_node("AuxScene/AnimationPlayer"):
		animation_player = $AuxScene/AnimationPlayer
