extends Node
class_name HealthComponent

signal defeat()
signal health_changed()
signal damage_taken()

@export var body: PhysicsBody3D

var max_health: float
var current_health: float: 
	set(value):
		var old_health = current_health
		current_health = clamp(value, 0.0, max_health)
		
		if current_health < old_health:
			damage_taken.emit(old_health - current_health, false)
			
		if current_health == 0.0 and old_health > 0.0:
			defeat.emit()
		
		health_changed.emit(current_health, max_health)

func _ready() -> void:
	if body:
		body.add_to_group("damageable")

func initialize(max_hp: float) -> void:
	max_health = max_hp
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(damage_in: float, is_critical: bool) -> void:
	if current_health <= 0.0:
		return
		
	var damage = damage_in
	if is_critical:
		damage *= 2.0
	current_health -= damage
	damage_taken.emit(damage, is_critical)

func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = min(current_health + amount, max_health)

func get_health_percentage() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health

func is_alive() -> bool:
	return current_health > 0.0

func get_health_string() -> String:
	return "%d/%d" % [int(current_health), int(max_health)]
