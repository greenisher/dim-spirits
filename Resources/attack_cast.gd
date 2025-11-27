extends RayCast3D

func deal_damage(damage: float, crit_chance: float) -> void:
	if not is_colliding():
		return
	
	var collider = get_collider()
	if collider and collider.has_node("HealthComponent"):
		var is_critical = randf() <= crit_chance
		var health_component: HealthComponent = collider.get_node("HealthComponent")
		health_component.take_damage(damage, is_critical)
		add_exception(collider)

func reset_damage_tracking() -> void:
	clear_exceptions()
