extends Node
class_name MagicSystem

## Magic system component - handles spell casting, targeting, and cooldowns

signal spell_cast(spell: Spell)
signal spell_failed(reason: String)
signal target_locked(target: Node3D)
signal target_unlocked()
signal equipped_spell_changed(slot: int, spell: Spell)

# ==================== CONFIGURATION ====================

@export var stats: CharacterStats
@export var cast_origin: Node3D  # Where spells spawn from (usually hand/staff)
@export var max_equipped_spells: int = 4

# ==================== STATE ====================

var equipped_spells: Array[Spell] = []
var current_spell_index: int = 0
var spell_cooldowns: Dictionary = {}  # spell_name -> time_remaining
var is_casting: bool = false
var cast_timer: float = 0.0
var pending_spell: Spell = null

# Lock-on targeting
var locked_target: Node3D = null
var potential_targets: Array[Node3D] = []

# ==================== INITIALIZATION ====================

func _ready() -> void:
	# Initialize equipped spells array
	equipped_spells.resize(max_equipped_spells)

func _process(delta: float) -> void:
	# Update cooldowns
	_update_cooldowns(delta)
	
	# Update casting
	if is_casting:
		_update_casting(delta)
	
	# Update potential targets
	_update_potential_targets()

# ==================== SPELL EQUIPPING ====================

func equip_spell(spell: Spell, slot: int = -1) -> bool:
	"""Equip a spell to a slot"""
	if slot == -1:
		# Find first empty slot
		for i in range(max_equipped_spells):
			if equipped_spells[i] == null:
				slot = i
				break
	
	if slot < 0 or slot >= max_equipped_spells:
		return false
	
	equipped_spells[slot] = spell
	equipped_spell_changed.emit(slot, spell)
	print("Equipped %s to slot %d" % [spell.spell_name, slot])
	return true

func unequip_spell(slot: int) -> bool:
	"""Unequip spell from slot"""
	if slot < 0 or slot >= max_equipped_spells:
		return false
	
	equipped_spells[slot] = null
	equipped_spell_changed.emit(slot, null)
	return true

func get_equipped_spell(slot: int) -> Spell:
	"""Get spell in specific slot"""
	if slot < 0 or slot >= max_equipped_spells:
		return null
	return equipped_spells[slot]

func get_current_spell() -> Spell:
	"""Get currently selected spell"""
	return equipped_spells[current_spell_index]

func cycle_spell(direction: int = 1) -> void:
	"""Cycle through equipped spells"""
	var start_index = current_spell_index
	
	while true:
		current_spell_index = (current_spell_index + direction) % max_equipped_spells
		if current_spell_index < 0:
			current_spell_index = max_equipped_spells - 1
		
		# Found a spell or cycled back to start
		if equipped_spells[current_spell_index] != null or current_spell_index == start_index:
			break
	
	var spell = get_current_spell()
	if spell:
		print("Selected spell: %s" % spell.spell_name)

# ==================== SPELL CASTING ====================

func cast_current_spell() -> bool:
	"""Attempt to cast the currently selected spell"""
	var spell = get_current_spell()
	if not spell:
		spell_failed.emit("No spell equipped")
		return false
	
	return cast_spell(spell)

func cast_spell(spell: Spell) -> bool:
	"""Attempt to cast a specific spell"""
	# Check if already casting
	if is_casting:
		spell_failed.emit("Already casting")
		return false
	
	# Check cooldown
	if is_on_cooldown(spell):
		spell_failed.emit("Spell on cooldown")
		return false
	
	# Check mana
	if not stats.consume_mana(spell.mana_cost):
		spell_failed.emit("Not enough mana")
		return false
	
	# Check targeting requirements
	if spell.can_lock_on and not locked_target and spell.spell_type == Spell.SpellType.PROJECTILE:
		# Try to auto-lock nearest target
		auto_lock_nearest_target(spell.lock_on_range)
	
	# Start casting
	if spell.cast_time > 0:
		is_casting = true
		cast_timer = spell.cast_time
		pending_spell = spell
		print("Casting %s..." % spell.spell_name)
	else:
		# Instant cast
		_execute_spell(spell)
	
	return true

func _update_casting(delta: float) -> void:
	"""Update casting progress"""
	if not is_casting:
		return
	
	cast_timer -= delta
	
	if cast_timer <= 0:
		is_casting = false
		if pending_spell:
			_execute_spell(pending_spell)
			pending_spell = null

func cancel_cast() -> void:
	"""Cancel current spell cast"""
	if is_casting and pending_spell:
		# Refund mana
		stats.restore_mana(pending_spell.mana_cost)
		is_casting = false
		pending_spell = null
		print("Spell cast cancelled")

func _execute_spell(spell: Spell) -> void:
	"""Execute the spell effect"""
	# Start cooldown
	if spell.cooldown > 0:
		spell_cooldowns[spell.spell_name] = spell.cooldown
	
	# Calculate damage
	var final_damage = spell.calculate_damage(stats.get_spell_damage_modifier())
	
	# Execute based on spell type
	match spell.spell_type:
		Spell.SpellType.PROJECTILE:
			_cast_projectile_spell(spell, final_damage)
		Spell.SpellType.AOE:
			_cast_aoe_spell(spell, final_damage)
		Spell.SpellType.BUFF:
			_cast_buff_spell(spell)
		Spell.SpellType.HEAL:
			_cast_heal_spell(spell)
	
	# Emit signal
	spell_cast.emit(spell)
	print("Cast %s! Damage: %.1f" % [spell.spell_name, final_damage])

# ==================== SPELL TYPE IMPLEMENTATIONS ====================

func _cast_projectile_spell(spell: Spell, damage: float) -> void:
	"""Cast a projectile spell"""
	if not spell.projectile_scene:
		push_error("Projectile spell %s has no projectile scene!" % spell.spell_name)
		return
	
	if not cast_origin:
		push_error("No cast_origin set for magic system!")
		return
	
	# Spawn projectile
	var projectile = spell.projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	# Position at cast origin
	projectile.global_position = cast_origin.global_position
	
	# Set direction
	var direction: Vector3
	if locked_target and is_instance_valid(locked_target):
		direction = (locked_target.global_position - cast_origin.global_position).normalized()
	else:
		direction = -cast_origin.global_transform.basis.z
	
	# Initialize projectile
	if projectile.has_method("initialize"):
		projectile.initialize(damage, direction, locked_target if spell.is_homing else null, spell)

func _cast_aoe_spell(spell: Spell, damage: float) -> void:
	"""Cast an AOE spell"""
	if not cast_origin:
		return
	
	var impact_position: Vector3
	
	if locked_target and is_instance_valid(locked_target):
		impact_position = locked_target.global_position
	else:
		# Cast forward from player
		impact_position = cast_origin.global_position + (-cast_origin.global_transform.basis.z * 10.0)
	
	# Find all enemies in radius
	var space_state = cast_origin.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = spell.aoe_radius
	query.shape = sphere
	query.transform.origin = impact_position
	query.collision_mask = 2  # Enemy layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result["collider"]
		if body.has_method("take_damage"):
			body.take_damage(damage)
	
	# Spawn visual effect
	if spell.cast_effect:
		var effect = spell.cast_effect.instantiate()
		get_tree().root.add_child(effect)
		effect.global_position = impact_position

func _cast_buff_spell(spell: Spell) -> void:
	"""Cast a buff spell (e.g., Magic Shield)"""
	# This would add a buff to the player
	# You'll need a BuffManager or similar system
	print("Casting buff: %s for %.1fs" % [spell.spell_name, spell.duration])
	
	# Example: Add shield that absorbs damage
	# if has_node("/root/BuffManager"):
	#     BuffManager.add_buff("magic_shield", spell.duration, spell.shield_absorption)

func _cast_heal_spell(spell: Spell) -> void:
	"""Cast a healing spell"""
	# Start healing over time
	print("Casting heal: %s for %.1fs" % [spell.spell_name, spell.duration])
	
	# Create heal timer
	var heal_timer = Timer.new()
	add_child(heal_timer)
	heal_timer.wait_time = spell.heal_tick_interval
	heal_timer.timeout.connect(_on_heal_tick.bind(spell, heal_timer, spell.duration))
	heal_timer.start()

func _on_heal_tick(spell: Spell, timer: Timer, remaining: float) -> void:
	"""Heal tick callback"""
	# Heal player
	var player = get_parent()
	if player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		health.heal(spell.heal_per_tick)
	
	remaining -= spell.heal_tick_interval
	if remaining <= 0:
		timer.queue_free()

# ==================== TARGETING SYSTEM ====================

func _update_potential_targets() -> void:
	"""Update list of potential lock-on targets"""
	if not cast_origin:
		return
	
	potential_targets.clear()
	
	# Find all enemies in range
	var space_state = cast_origin.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 30.0  # Max lock-on range
	query.shape = sphere
	query.transform.origin = cast_origin.global_position
	query.collision_mask = 2  # Enemy layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result["collider"]
		if body != get_parent():  # Don't target self
			potential_targets.append(body)

func toggle_lock_on() -> void:
	"""Toggle lock-on to nearest target"""
	if locked_target:
		unlock_target()
	else:
		auto_lock_nearest_target()

func auto_lock_nearest_target(max_range: float = 30.0) -> bool:
	"""Automatically lock onto nearest target"""
	if not cast_origin:
		return false
	
	var nearest_target: Node3D = null
	var nearest_distance: float = max_range
	
	for target in potential_targets:
		if not is_instance_valid(target):
			continue
		
		var distance = cast_origin.global_position.distance_to(target.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_target = target
	
	if nearest_target:
		lock_target(nearest_target)
		return true
	
	return false

func lock_target(target: Node3D) -> void:
	"""Lock onto a specific target"""
	locked_target = target
	target_locked.emit(target)
	print("Locked onto target: %s" % target.name)

func unlock_target() -> void:
	"""Unlock current target"""
	locked_target = null
	target_unlocked.emit()
	print("Target unlocked")

func get_locked_target() -> Node3D:
	"""Get currently locked target"""
	return locked_target

func has_locked_target() -> bool:
	"""Check if a target is locked"""
	return locked_target != null and is_instance_valid(locked_target)

# ==================== COOLDOWN SYSTEM ====================

func _update_cooldowns(delta: float) -> void:
	"""Update spell cooldowns"""
	var to_remove = []
	
	for spell_name in spell_cooldowns:
		spell_cooldowns[spell_name] -= delta
		if spell_cooldowns[spell_name] <= 0:
			to_remove.append(spell_name)
	
	for spell_name in to_remove:
		spell_cooldowns.erase(spell_name)

func is_on_cooldown(spell: Spell) -> bool:
	"""Check if spell is on cooldown"""
	return spell_cooldowns.has(spell.spell_name)

func get_cooldown_remaining(spell: Spell) -> float:
	"""Get remaining cooldown time"""
	return spell_cooldowns.get(spell.spell_name, 0.0)

func get_cooldown_percentage(spell: Spell) -> float:
	"""Get cooldown as percentage (0-100)"""
	if not is_on_cooldown(spell):
		return 0.0
	
	var remaining = get_cooldown_remaining(spell)
	return (remaining / spell.cooldown) * 100.0
