extends CharacterBody3D
class_name BossBase

## Base class for all bosses
## Handles state machine, combo selection, and common boss behaviors

signal phase_changed(new_phase: int)
signal boss_defeated()
signal combo_started(combo: BossCombo)
signal attack_started(attack: BossAttack)

enum BossState {
	IDLE,
	APPROACHING,
	ATTACKING,
	RECOVERING,
	STAGGERED,
	PHASE_TRANSITION,
	DEFEATED,
}

@export_category("Boss Stats")
@export var boss_name: String = "Boss"
@export var max_health: float = 500.0
@export var poise: float = 100.0           ## Stagger threshold
@export var poise_regen_rate: float = 20.0 ## Poise recovered per second
@export var xp_reward: int = 1000

@export_category("Movement")
@export var walk_speed: float = 2.5
@export var run_speed: float = 5.0
@export var rotation_speed: float = 3.0
@export var preferred_distance: float = 3.0  ## Ideal combat distance

@export_category("Combat")
@export var attack_cooldown: float = 1.0     ## Min time between combos
@export var aggression: float = 0.7          ## 0-1, higher = attacks more often
@export var combo_pool: Array[BossCombo] = []

@export_category("Phases")
@export var phase_thresholds: Array[float] = [0.5]  ## HP % to trigger phases
@export var phase_combos: Array[Array] = []         ## Combos added per phase

@export_category("References")
@export var rig: BossRig
@export var health_component: HealthComponent
@export var attack_area: ShapeCast3D
@export var navigation_agent: NavigationAgent3D

## Runtime state
var current_state: BossState = BossState.IDLE
var current_phase: int = 0
var current_combo: BossCombo = null
var current_combo_index: int = 0
var current_poise: float = 100.0

var player: Player
var gravity: float = ProjectSettings.get_setting('physics/3d/default_gravity')

## Timers
var _attack_cooldown_timer: float = 0.0
var _state_timer: float = 0.0
var _decision_timer: float = 0.0

## Combat tracking
var _damaged_bodies: Array = []


func _ready() -> void:
	add_to_group("Boss")
	
	# Find player
	player = get_tree().get_first_node_in_group("Player")
	
	# Initialize health
	if health_component:
		health_component.body = self
		health_component.initialize(max_health)
		health_component.defeat.connect(_on_defeated)
		health_component.damage_taken.connect(_on_damage_taken)
	
	current_poise = poise
	
	# Connect rig signals
	if rig:
		rig.attack_windup_complete.connect(_on_attack_windup_complete)
		rig.attack_active_complete.connect(_on_attack_active_complete)
		rig.attack_recovery_complete.connect(_on_attack_recovery_complete)
		rig.phase_transition_complete.connect(_on_phase_transition_complete)
		rig.stagger_complete.connect(_on_stagger_complete)
	
	# Call boss-specific setup
	_setup_boss()


## Override in subclasses for boss-specific initialization
func _setup_boss() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not player or current_state == BossState.DEFEATED:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Update timers
	_attack_cooldown_timer = max(0, _attack_cooldown_timer - delta)
	_state_timer += delta
	_decision_timer -= delta
	
	# Regenerate poise
	current_poise = min(poise, current_poise + poise_regen_rate * delta)
	
	# State machine
	match current_state:
		BossState.IDLE:
			_process_idle(delta)
		BossState.APPROACHING:
			_process_approaching(delta)
		BossState.ATTACKING:
			_process_attacking(delta)
		BossState.RECOVERING:
			_process_recovering(delta)
		BossState.STAGGERED:
			_process_staggered(delta)
		BossState.PHASE_TRANSITION:
			_process_phase_transition(delta)
	
	move_and_slide()


# =============================================================================
# STATE PROCESSING
# =============================================================================

func _process_idle(delta: float) -> void:
	var distance = _get_distance_to_player()
	
	# Face player
	_rotate_toward_player(delta)
	
	# Make decision
	if _decision_timer <= 0:
		_decision_timer = randf_range(0.2, 0.5)
		
		if _attack_cooldown_timer <= 0 and _should_attack(distance):
			_select_and_start_combo(distance)
		elif distance > preferred_distance + 1.0:
			_change_state(BossState.APPROACHING)


func _process_approaching(delta: float) -> void:
	var distance = _get_distance_to_player()
	
	# Update navigation
	if navigation_agent:
		navigation_agent.target_position = player.global_position
		
		if not navigation_agent.is_navigation_finished():
			var next_pos = navigation_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			
			velocity.x = direction.x * run_speed
			velocity.z = direction.z * run_speed
			
			_rotate_toward_player(delta)
			
			if rig:
				rig.set_movement_weight(1.0)
	
	# Check if close enough to attack
	if distance <= preferred_distance:
		velocity.x = 0
		velocity.z = 0
		if rig:
			rig.set_movement_weight(0.0)
		_change_state(BossState.IDLE)
	
	# Opportunistic attack while approaching
	if _attack_cooldown_timer <= 0 and distance <= preferred_distance + 2.0:
		if randf() < aggression * 0.5:
			_select_and_start_combo(distance)


func _process_attacking(delta: float) -> void:
	if not current_combo or not rig:
		_change_state(BossState.IDLE)
		return
	
	var current_attack = current_combo.get_attack(current_combo_index)
	if not current_attack:
		_change_state(BossState.RECOVERING)
		return
	
	# Handle movement during attack
	_process_attack_movement(current_attack, delta)


func _process_attack_movement(attack: BossAttack, delta: float) -> void:
	match attack.movement_type:
		BossAttack.MovementType.STATIONARY:
			velocity.x = 0
			velocity.z = 0
		
		BossAttack.MovementType.LUNGE_FORWARD:
			if rig.is_in_windup() or rig.is_attack_active():
				var direction = _get_direction_to_player()
				velocity.x = direction.x * attack.movement_speed
				velocity.z = direction.z * attack.movement_speed
			else:
				velocity.x = 0
				velocity.z = 0
		
		BossAttack.MovementType.LUNGE_BACKWARD:
			if rig.is_attack_active():
				var direction = -_get_direction_to_player()
				velocity.x = direction.x * attack.movement_speed
				velocity.z = direction.z * attack.movement_speed
			else:
				velocity.x = 0
				velocity.z = 0
		
		BossAttack.MovementType.TRACKING:
			if rig.is_in_windup():
				_rotate_toward_player(delta * attack.tracking_speed)
			velocity.x = 0
			velocity.z = 0
		
		BossAttack.MovementType.LEAP:
			# Leap logic handled separately
			pass


func _process_recovering(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	# Recovery period after combo
	if _state_timer >= 0.5:
		_attack_cooldown_timer = attack_cooldown
		_change_state(BossState.IDLE)


func _process_staggered(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	# Wait for stagger animation to complete


func _process_phase_transition(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	# Wait for transition animation


# =============================================================================
# COMBO SYSTEM
# =============================================================================

func _select_and_start_combo(distance: float) -> void:
	var health_percent = health_component.get_health_percentage()
	var context = _get_combat_context()
	
	# Get all valid combos
	var valid_combos: Array[BossCombo] = []
	var total_weight: float = 0.0
	
	for combo in combo_pool:
		if combo.can_use(distance, health_percent, current_phase, context):
			valid_combos.append(combo)
			total_weight += combo.weight
	
	if valid_combos.is_empty():
		return
	
	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative: float = 0.0
	
	for combo in valid_combos:
		cumulative += combo.weight
		if roll <= cumulative:
			_start_combo(combo)
			return
	
	# Fallback to last valid combo
	_start_combo(valid_combos[-1])


func _start_combo(combo: BossCombo) -> void:
	current_combo = combo
	current_combo_index = 0
	combo.mark_used()
	
	combo_started.emit(combo)
	_change_state(BossState.ATTACKING)
	
	_execute_current_attack()


func _execute_current_attack() -> void:
	if not current_combo:
		return
	
	var attack = current_combo.get_attack(current_combo_index)
	if not attack:
		_end_combo()
		return
	
	attack_started.emit(attack)
	_damaged_bodies.clear()
	
	if rig:
		rig.execute_attack(attack)
	
	print("[%s] Executing: %s" % [boss_name, attack.attack_name])


func _advance_combo() -> void:
	current_combo_index += 1
	
	if current_combo_index >= current_combo.get_attack_count():
		_end_combo()
	else:
		_execute_current_attack()


func _end_combo() -> void:
	current_combo = null
	current_combo_index = 0
	_change_state(BossState.RECOVERING)


## Override to add boss-specific context
func _get_combat_context() -> Dictionary:
	return {
		"player_healing": false,  # TODO: detect estus use
		"player_attacking": false,
		"player_staggered": false,
	}


# =============================================================================
# DAMAGE DEALING
# =============================================================================

func _on_attack_windup_complete() -> void:
	# Hitbox becomes active
	pass


func _on_attack_active_complete() -> void:
	# Hitbox deactivates, deal damage
	if current_combo and attack_area:
		var attack = current_combo.get_attack(current_combo_index)
		if attack:
			_deal_attack_damage(attack)


func _on_attack_recovery_complete() -> void:
	# Attack finished, advance combo
	_advance_combo()


func _deal_attack_damage(attack: BossAttack) -> void:
	if not attack_area:
		return
	
	attack_area.force_shapecast_update()
	
	for i in attack_area.get_collision_count():
		var collider = attack_area.get_collider(i)
		
		if collider in _damaged_bodies:
			continue
		
		if collider.has_node("HealthComponent"):
			var health_comp: HealthComponent = collider.get_node("HealthComponent")
			var is_crit = randf() < 0.1  # 10% crit chance
			health_comp.take_damage(attack.base_damage, is_crit)
			_damaged_bodies.append(collider)
			
			print("[%s] Hit %s for %.0f damage!" % [boss_name, collider.name, attack.base_damage])
			
			if attack.knockback_force > 0:
				_apply_knockback(collider, attack.knockback_force)


func _apply_knockback(target: Node3D, force: float) -> void:
	if target is CharacterBody3D:
		var direction = (target.global_position - global_position).normalized()
		target.velocity += direction * force


# =============================================================================
# DAMAGE RECEIVING & PHASES
# =============================================================================

func _on_damage_taken(amount: float, is_critical: bool) -> void:
	# Reduce poise
	current_poise -= amount * 0.5
	
	# Check for stagger
	if current_poise <= 0 and current_state != BossState.STAGGERED:
		_trigger_stagger()
	
	# Check for phase transition
	_check_phase_transition()
	
	# Spawn damage numbers
	if VfxManager:
		VfxManager.spawn_damage_text(amount, is_critical, global_position + Vector3.UP * 2)


func _trigger_stagger() -> void:
	current_poise = poise  # Reset poise
	
	if rig:
		rig.interrupt_attack()
	
	current_combo = null
	current_combo_index = 0
	_change_state(BossState.STAGGERED)
	
	print("[%s] STAGGERED!" % boss_name)


func _on_stagger_complete() -> void:
	_change_state(BossState.IDLE)


func _check_phase_transition() -> void:
	var health_percent = health_component.get_health_percentage()
	
	for i in phase_thresholds.size():
		if current_phase <= i and health_percent <= phase_thresholds[i]:
			_trigger_phase_transition(i + 1)
			break


func _trigger_phase_transition(new_phase: int) -> void:
	current_phase = new_phase
	
	if rig:
		rig.play_phase_transition()
	
	current_combo = null
	_change_state(BossState.PHASE_TRANSITION)
	
	# Reset combo usage for new phase
	for combo in combo_pool:
		combo.reset_usage()
	
	# Add phase-specific combos
	if new_phase - 1 < phase_combos.size():
		for combo in phase_combos[new_phase - 1]:
			if combo not in combo_pool:
				combo_pool.append(combo)
	
	phase_changed.emit(new_phase)
	print("[%s] PHASE %d!" % [boss_name, new_phase])
	
	# Override for phase-specific behavior
	_on_phase_changed(new_phase)


func _on_phase_transition_complete() -> void:
	_change_state(BossState.IDLE)


## Override for boss-specific phase behavior
func _on_phase_changed(phase: int) -> void:
	pass


func _on_defeated() -> void:
	_change_state(BossState.DEFEATED)
	
	if rig:
		rig.play_death()
	
	# Award XP
	if player and player.stats:
		player.stats.xp += xp_reward
	
	boss_defeated.emit()
	print("[%s] DEFEATED!" % boss_name)
	
	# Disable collision after short delay
	await get_tree().create_timer(0.5).timeout
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true


# =============================================================================
# UTILITY
# =============================================================================

func _change_state(new_state: BossState) -> void:
	current_state = new_state
	_state_timer = 0.0


func _get_distance_to_player() -> float:
	if not player:
		return 999.0
	return global_position.distance_to(player.global_position)


func _get_direction_to_player() -> Vector3:
	if not player:
		return Vector3.FORWARD
	return (player.global_position - global_position).normalized()


func _rotate_toward_player(delta: float) -> void:
	if not player:
		return
	
	var target_pos = player.global_position
	target_pos.y = global_position.y
	
	var direction = (target_pos - global_position).normalized()
	if direction.length_squared() < 0.01:
		return
	
	var target_transform = global_transform.looking_at(target_pos, Vector3.UP)
	global_transform = global_transform.interpolate_with(
		target_transform, 
		1.0 - exp(-rotation_speed * delta)
	)


func _should_attack(distance: float) -> bool:
	# Base attack decision on distance and aggression
	if distance > preferred_distance + 3.0:
		return false
	
	var attack_chance = aggression
	
	# More likely to attack at preferred distance
	if abs(distance - preferred_distance) < 1.0:
		attack_chance *= 1.5
	
	return randf() < attack_chance * 0.5  # Scale down for frame rate
