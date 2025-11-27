extends SpringArm3D

# No script needed! The SpringArm3D already follows its parent (VerticalPivot)
# through the scene tree hierarchy. Remove the target export entirely.

func _ready():
	# Ensure mouse is captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Camera arm ready - mouse captured")
