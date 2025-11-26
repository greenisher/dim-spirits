extends Area3D
class_name SpellProjectile

## Spell projectile - flies toward target and deals damage

signal hit_target(target: Node3D, damage: float)
signal projectile_expired()

# ==================== CONFIGURATION ====================

@export var visual_mesh: MeshInstance3D
@export var particles: GPUParticles3D
@export var trail: GPUParticles3D

# ==================== STATE ====================

var damage: float = 5.0
var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var lifetime: float = 5.0
var homing_target: Node3D = null
var homing_strength: float = 0.5
var spell_data: Spell = null

var time_alive: float = 0.0
var has_hit: bool = false
var damaged_targets: Array[Node3D] = []  # Prevent multi-hit

# ==================== INITIALIZATION ====================

func _ready() -> void:
	# Connect area signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Set collision layers
	collision_layer = 0  # Projectile layer (optional)
	collision_mask = 2 | 4  # Enemy layer (2) + Player layer (4) if friendly fire

func initialize(proj_damage: float, proj_direction: Vector3, target: Node3D = null, spell: Spell = null) -> void:
	"""Initialize projectile with damage, direction, and optional homing target"""
	damage = proj_damage
	direction = proj_direction.normalized()
	homing_target = target
	spell_data = spell
	
	if spell_data:
		speed = spell_data.projectile_speed
		lifetime = spell_data.projectile_lifetime
		homing_strength = spell_data.homing_strength
		
		# Apply spell color to visual
		if visual_mesh and spell_data.spell_color:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = spell_data.spell_color
			mat.emission_enabled = true
			mat.emission = spell_data.spell_color
			mat.emission_energy_multiplier = 2.0
			visual_mesh.set_surface_override_material(0, mat)
	
	# Orient projectile
	look_at(global_position + direction, Vector3.UP)

# ==================== UPDATE ====================

func _process(delta: float) -> void:
	time_alive += delta
	
	# Check lifetime
	if time_alive >= lifetime:
		_expire()
		return
	
	# Update homing
	if homing_target and is_instance_valid(homing_target):
		_update_homing(delta)
	
	# Move forward
	global_position += direction * speed * delta
	
	# Update rotation to match direction
	if direction.length_squared() > 0.01:
		look_at(global_position + direction, Vector3.UP)

func _update_homing(delta: float) -> void:
	"""Update direction to home toward target"""
	if not homing_target or not is_instance_valid(homing_target):
		return
	
	var to_target = (homing_target.global_position - global_position).normalized()
	direction = direction.lerp(to_target, homing_strength * delta * 5.0).normalized()

# ==================== COLLISION ====================

func _on_body_entered(body: Node) -> void:
	"""Hit a physics body"""
	if has_hit:
		return
	
	# Check if already damaged this target
	if damaged_targets.has(body):
		return
	
	# Check if target can take damage
	if body.has_method("take_damage"):
		body.take_damage(damage)
		damaged_targets.append(body)
		hit_target.emit(body, damage)
		print("Spell hit %s for %.1f damage" % [body.name, damage])
		_on_hit()
	elif body is StaticBody3D or body is CharacterBody3D:
		# Hit environment
		_on_hit()

func _on_area_entered(area: Area3D) -> void:
	"""Hit an area (e.g., hurtbox)"""
	if has_hit:
		return
	
	# Check if area's parent can take damage
	var target = area.get_parent()
	if target and target.has_method("take_damage"):
		if not damaged_targets.has(target):
			target.take_damage(damage)
			damaged_targets.append(target)
			hit_target.emit(target, damage)
			print("Spell hit %s for %.1f damage" % [target.name, damage])
			_on_hit()

func _on_hit() -> void:
	"""Called when projectile hits something"""
	if has_hit:
		return
	
	has_hit = true
	
	# Spawn impact effect
	if spell_data and spell_data.cast_effect:
		var effect = spell_data.cast_effect.instantiate()
		get_tree().root.add_child(effect)
		effect.global_position = global_position
	
	# Hide visual
	if visual_mesh:
		visual_mesh.visible = false
	
	# Let particles finish
	if particles:
		particles.emitting = false
	
	if trail:
		trail.emitting = false
	
	# Destroy after particles finish
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _expire() -> void:
	"""Projectile reached max lifetime"""
	projectile_expired.emit()
	queue_free()
