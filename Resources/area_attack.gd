extends ShapeCast3D

var _damaged_bodies: Array = []

func deal_damage(damage: float, crit_chance: float) -> void:
	_damaged_bodies.clear()
	
	for collision in get_collision_count():
		var collider = get_collider(collision)
		
		# Skip if we already damaged this body this frame
		if collider in _damaged_bodies:
			continue
		
		print("AreaAttack hit: ", collider.name, " (", collider.get_class(), ")")

		
		if collider.has_node("HealthComponent"):
			var is_critical = randf() <= crit_chance
			var health_component: HealthComponent = collider.get_node("HealthComponent")
			print("Dealing ", damage, " damage (crit: ", is_critical, ") to ", collider.name)
			health_component.take_damage(damage, is_critical)
			_damaged_bodies.append(collider)
		else:
			print("No HealthComponent found on ", collider.name)

func reset_damage_tracking() -> void:
	_damaged_bodies.clear()
