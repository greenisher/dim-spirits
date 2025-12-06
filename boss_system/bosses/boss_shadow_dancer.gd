extends BossBase
class_name BossShadowDancer

## BOSS 2: THE SHADOW DANCER
## A deadly assassin with fast, flowing combos
## 
## Design Philosophy:
## - Fast multi-hit combos (4-5 attacks)
## - Delayed finisher to catch panic rollers
## - Small punish windows - must wait for full combo
## - Teaches: patience, counting attacks, not panic rolling
##
## Signature Moves:
## - Quick Slash: Fast opener, low damage
## - Twin Fangs: Double slash, medium damage
## - Shadow Step: Teleport behind player
## - Executioner: Delayed heavy finisher with huge damage
## - Venom Thrust: Poison-applying thrust

## Attacks
var quick_slash: BossAttack
var twin_fangs: BossAttack
var shadow_step: BossAttack
var executioner: BossAttack
var venom_thrust: BossAttack
var backflip_slash: BossAttack
var whirlwind: BossAttack

## Combos
var probing_strikes: BossCombo
var dancer_flurry: BossCombo
var shadow_ambush: BossCombo
var execution_combo: BossCombo
var venom_dance: BossCombo
var endless_waltz: BossCombo  # Phase 2


func _setup_boss() -> void:
	boss_name = "Shadow Dancer"
	max_health = 350.0
	poise = 40.0  # Low poise - can be staggered
	poise_regen_rate = 30.0  # But recovers fast
	xp_reward = 750
	
	walk_speed = 3.5
	run_speed = 7.0
	rotation_speed = 5.0  # Very quick turning
	preferred_distance = 2.0  # Likes to be close
	attack_cooldown = 0.8
	aggression = 0.8  # Very aggressive
	
	phase_thresholds = [0.6, 0.3]  # Phase 2 at 60%, Phase 3 at 30%
	
	_create_attacks()
	_create_combos()
	
	print("[Shadow Dancer] \"Let's dance...\"")


func _create_attacks() -> void:
	# QUICK SLASH - Fast opener
	quick_slash = BossAttack.new()
	quick_slash.attack_name = "Quick Slash"
	quick_slash.animation_name = "QuickSlash"
	quick_slash.windup_time = 0.2
	quick_slash.active_time = 0.1
	quick_slash.recovery_time = 0.2
	quick_slash.base_damage = 12.0
	quick_slash.movement_type = BossAttack.MovementType.LUNGE_FORWARD
	quick_slash.movement_speed = 8.0
	
	# TWIN FANGS - Double hit
	twin_fangs = BossAttack.new()
	twin_fangs.attack_name = "Twin Fangs"
	twin_fangs.animation_name = "TwinFangs"
	twin_fangs.windup_time = 0.25
	twin_fangs.active_time = 0.2  # Two hits in quick succession
	twin_fangs.recovery_time = 0.25
	twin_fangs.base_damage = 18.0  # Per hit
	twin_fangs.movement_type = BossAttack.MovementType.TRACKING
	twin_fangs.tracking_speed = 3.0
	
	# SHADOW STEP - Teleport/dash behind player
	shadow_step = BossAttack.new()
	shadow_step.attack_name = "Shadow Step"
	shadow_step.animation_name = "ShadowStep"
	shadow_step.windup_time = 0.15  # Almost instant
	shadow_step.active_time = 0.0  # No hitbox, it's a reposition
	shadow_step.recovery_time = 0.1
	shadow_step.base_damage = 0.0
	shadow_step.movement_type = BossAttack.MovementType.LEAP
	shadow_step.movement_speed = 20.0
	
	# EXECUTIONER - Delayed finisher (THE MIXUP)
	executioner = BossAttack.new()
	executioner.attack_name = "Executioner"
	executioner.animation_name = "Executioner"
	executioner.windup_time = 0.8  # Long pause - catches panic rollers
	executioner.delay_variance = 0.3  # Random delay adds mixup
	executioner.active_time = 0.15
	executioner.recovery_time = 0.6
	executioner.base_damage = 55.0  # Huge damage
	executioner.movement_type = BossAttack.MovementType.LUNGE_FORWARD
	executioner.movement_speed = 15.0
	executioner.staggers_player = true
	executioner.knockback_force = 6.0
	
	# VENOM THRUST - Applies poison (status effect)
	venom_thrust = BossAttack.new()
	venom_thrust.attack_name = "Venom Thrust"
	venom_thrust.animation_name = "VenomThrust"
	venom_thrust.windup_time = 0.3
	venom_thrust.active_time = 0.1
	venom_thrust.recovery_time = 0.35
	venom_thrust.base_damage = 15.0
	venom_thrust.movement_type = BossAttack.MovementType.LUNGE_FORWARD
	venom_thrust.movement_speed = 10.0
	# TODO: Add poison status effect
	
	# BACKFLIP SLASH - Attack while retreating
	backflip_slash = BossAttack.new()
	backflip_slash.attack_name = "Backflip Slash"
	backflip_slash.animation_name = "BackflipSlash"
	backflip_slash.windup_time = 0.2
	backflip_slash.active_time = 0.15
	backflip_slash.recovery_time = 0.3
	backflip_slash.base_damage = 20.0
	backflip_slash.movement_type = BossAttack.MovementType.LUNGE_BACKWARD
	backflip_slash.movement_speed = 8.0
	
	# WHIRLWIND - Phase 3 AOE spin
	whirlwind = BossAttack.new()
	whirlwind.attack_name = "Whirlwind"
	whirlwind.animation_name = "Whirlwind"
	whirlwind.attack_type = BossAttack.AttackType.AOE
	whirlwind.windup_time = 0.5
	whirlwind.active_time = 0.8  # Long active window
	whirlwind.recovery_time = 0.8
	whirlwind.base_damage = 25.0
	whirlwind.movement_type = BossAttack.MovementType.STATIONARY
	whirlwind.hitbox_scale = Vector3(4.0, 2.0, 4.0)  # 360 degree


func _create_combos() -> void:
	# PROBING STRIKES - Quick 2-hit to test defenses
	probing_strikes = BossCombo.new()
	probing_strikes.combo_name = "Probing Strikes"
	probing_strikes.attacks = [quick_slash, quick_slash]
	probing_strikes.weight = 3.0
	probing_strikes.max_distance = 3.5
	
	# DANCER FLURRY - 4-hit combo, the bread and butter
	dancer_flurry = BossCombo.new()
	dancer_flurry.combo_name = "Dancer Flurry"
	dancer_flurry.attacks = [quick_slash, twin_fangs, quick_slash, backflip_slash]
	dancer_flurry.weight = 2.5
	dancer_flurry.max_distance = 3.0
	dancer_flurry.cooldown = 3.0
	
	# SHADOW AMBUSH - Teleport behind and strike
	shadow_ambush = BossCombo.new()
	shadow_ambush.combo_name = "Shadow Ambush"
	shadow_ambush.attacks = [shadow_step, twin_fangs, quick_slash]
	shadow_ambush.weight = 2.0
	shadow_ambush.min_distance = 3.0  # Used when player backs off
	shadow_ambush.max_distance = 10.0
	shadow_ambush.cooldown = 5.0
	
	# EXECUTION COMBO - The signature delayed finisher combo
	execution_combo = BossCombo.new()
	execution_combo.combo_name = "Execution"
	execution_combo.attacks = [quick_slash, quick_slash, twin_fangs, executioner]
	execution_combo.weight = 2.0
	execution_combo.max_distance = 3.5
	execution_combo.cooldown = 8.0
	execution_combo.max_health_percent = 0.8  # More likely as fight goes on
	
	# VENOM DANCE - Poison application combo
	venom_dance = BossCombo.new()
	venom_dance.combo_name = "Venom Dance"
	venom_dance.attacks = [venom_thrust, quick_slash, venom_thrust]
	venom_dance.weight = 1.5
	venom_dance.max_distance = 3.0
	venom_dance.cooldown = 10.0
	
	# ENDLESS WALTZ - Phase 2/3 extended combo
	endless_waltz = BossCombo.new()
	endless_waltz.combo_name = "Endless Waltz"
	endless_waltz.attacks = [quick_slash, twin_fangs, quick_slash, twin_fangs, executioner]
	endless_waltz.weight = 2.5
	endless_waltz.max_distance = 3.5
	endless_waltz.required_phase = 1
	endless_waltz.cooldown = 6.0
	
	# Base combos
	combo_pool = [probing_strikes, dancer_flurry, shadow_ambush, execution_combo, venom_dance]
	
	# Phase-specific additions
	phase_combos = [
		[endless_waltz],  # Phase 2
		[],  # Phase 3 adds whirlwind via _on_phase_changed
	]


func _on_phase_changed(phase: int) -> void:
	match phase:
		1:
			# Phase 2: Even faster
			attack_cooldown = 0.5
			aggression = 0.9
			
			# Speed up attacks slightly
			quick_slash.windup_time = 0.15
			twin_fangs.windup_time = 0.2
			
			print("[Shadow Dancer] \"You're keeping up... impressive.\"")
		
		2:
			# Phase 3: Desperate, adds whirlwind
			attack_cooldown = 0.3
			aggression = 1.0
			poise = 60.0  # Harder to stagger
			
			# Add whirlwind combo
			var desperate_spin = BossCombo.new()
			desperate_spin.combo_name = "Desperate Spin"
			desperate_spin.attacks = [shadow_step, whirlwind, backflip_slash]
			desperate_spin.weight = 3.0
			desperate_spin.max_distance = 6.0
			desperate_spin.cooldown = 4.0
			combo_pool.append(desperate_spin)
			
			print("[Shadow Dancer] \"ENOUGH!\"")


## Shadow Dancer has special teleport logic
func _process_attack_movement(attack: BossAttack, delta: float) -> void:
	if attack.attack_name == "Shadow Step":
		# Teleport behind player
		if rig and rig.is_in_windup():
			var behind_player = player.global_position - player.global_transform.basis.z * 2.0
			global_position = global_position.lerp(behind_player, 0.3)
			_rotate_toward_player(delta * 10.0)
	else:
		super._process_attack_movement(attack, delta)
