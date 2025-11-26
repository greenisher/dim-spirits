extends Node3D

const DEATH_LABEL = preload("res://UserInterface/death_label.tscn")

func spawn_death_text(color: Color, position_in: Vector3) -> void:
	var new_death_text = DEATH_LABEL.instantiate()
	new_death_text.setup(color, position_in)
	add_child(new_death_text)
