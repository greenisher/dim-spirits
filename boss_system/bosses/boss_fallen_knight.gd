extends BossBase
class_name BossFallenKnight

## BOSS 1: THE FALLEN KNIGHT
## A tragic warrior who teaches players the fundamentals
## 
## Design Philosophy:
## - Slow, heavily telegraphed attacks
## - Clear punish windows after every combo
## - 2-hit combos maximum
## - Teaches: reading windups, dodging, punishing recovery
##
## Signature Moves:
## - Overhead Slam: Huge windup, massive damage, long recovery
## - Horizontal Sweep: Faster, lower damage, medium recovery
## - Shield Bash: Quick interrupt, sets up combos
## - Mourning Charge: Gap closer used when player is far

## Attack definitions (created in _setup_boss)
var overhead_slam: BossAttack
var horizontal_sweep: BossAttack
var shield_bash: BossAttack
var mourning_charge: BossAttack
var rising_slash: BossAttack

## Combos
var basic_sweep: BossCombo
var slam_combo: BossCombo
var bash_into_slam: BossCombo
var charge_sweep: BossCombo
var desperation_flurry: BossCombo  # Phase 2 only


func _setup_boss() -> void:
	boss_name = "Fallen Knight"
	max_health = 400.0
	poise = 80.0
	xp_reward = 500
	
	walk_speed = 2.0
	run_speed = 4.0
	preferred_distance = 2.5
	attack_cooldown = 1.5
	aggression = 0.5  # Relatively passive, lets player breathe
	
	phase_thresholds = [0.5]  # Phase 2 at 50% HP
	
	_create_attacks()
	_create_combos()
	
	print("[Fallen Knight] Ready to teach you the dance of death...")


func _create_attacks() -> void:
	# OVERHEAD SLAM - The signature "learn to dodge" attack
	overhead_slam = BossAttack.new()
	overhead_slam.attack_name = "Overhead Slam"
	overhead_slam.animation_name = "OverheadSlam"
	overhead_slam.windup_time = 1.2      # VERY telegraphed
	overhead_slam.active_time = 0.3
	overhead_slam.recovery_time = 1.0    # Big punish window
	overhead_slam.base_damage = 45.0
	overhead_slam.movement_type = BossAttack.MovementType.TRACKING
	overhead_slam.tracking_speed = 1.5
	overhead_slam.staggers_player = true
	overhead_slam.knockback_force = 5.0
	
	# HORIZONTAL SWEEP - Faster but weaker
	horizontal_sweep = BossAttack.new()
	horizontal_sweep.attack_name = "Horizontal Sweep"
	horizontal_sweep.animation_name = "HorizontalSweep"
	horizontal_sweep.windup_time = 0.6
	horizontal_sweep.active_time = 0.25
	horizontal_sweep.recovery_time = 0.6
	horizontal_sweep.base_damage = 25.0
	horizontal_sweep.movement_type = BossAttack.MovementType.LUNGE_FORWARD
	horizontal_sweep.movement_speed = 4.0
	horizontal_sweep.hitbox_scale = Vector3(3.0, 1.5, 2.0)  # Wide arc
	
	# SHIELD BASH - Quick interrupt
	shield_bash = BossAttack.new()
	shield_bash.attack_name = "Shield Bash"
	shield_bash.animation_name = "ShieldBash"
	shield_bash.windup_time = 0.4
	shield_bash.active_time = 0.15
	shield_bash.recovery_time = 0.4
	shield_bash.base_damage = 15.0
	shield_bash.movement_type = BossAttack.MovementType.LUNGE_FORWARD
	shield_bash.movement_speed = 6.0
	shield_bash.staggers_player = true
	shield_bash.knockback_force = 3.0
	
	# MOURNING CHARGE - Gap closer
	mourning_charge = BossAttack.new()
	mourning_charge.attack_name = "Mourning Charge"
	mourning_charge.animation_name = "MourningCharge"
	mourning_charge.windup_time = 0.8
	mourning_charge.active_time = 0.4
	mourning_charge.recovery_time = 0.8
	mourning_charge.base_damage = 30.0
	mourning_charge.movement_type = BossAttack.MovementType.LUNGE_FORWARD
	mourning_charge.movement_speed = 12.0
	mourning_charge.movement_distance = 8.0
	
	# RISING SLASH - Phase 2 only, faster combo ender
	rising_slash = BossAttack.new()
	rising_slash.attack_name = "Rising Slash"
	rising_slash.animation_name = "RisingSlash"
	rising_slash.windup_time = 0.5
	rising_slash.active_time = 0.2
	rising_slash.recovery_time = 0.5
	rising_slash.base_damage = 35.0
	rising_slash.movement_type = BossAttack.MovementType.STATIONARY
	rising_slash.knockback_force = 8.0


func _create_combos() -> void:
	# BASIC SWEEP - Simple 1-hit, most common
	basic_sweep = BossCombo.new()
	basic_sweep.combo_name = "Basic Sweep"
	basic_sweep.attacks = [horizontal_sweep]
	basic_sweep.weight = 3.0
	basic_sweep.max_distance = 4.0
	
	# SLAM COMBO - Sweep into Slam, teaches combo awareness
	slam_combo = BossCombo.new()
	slam_combo.combo_name = "Slam Combo"
	slam_combo.attacks = [horizontal_sweep, overhead_slam]
	slam_combo.weight = 2.0
	slam_combo.max_distance = 3.5
	slam_combo.cooldown = 5.0  # Don't spam this
	
	# BASH INTO SLAM - Shield bash sets up big damage
	bash_into_slam = BossCombo.new()
	bash_into_slam.combo_name = "Bash Into Slam"
	bash_into_slam.attacks = [shield_bash, overhead_slam]
	bash_into_slam.weight = 1.5
	bash_into_slam.max_distance = 3.0
	bash_into_slam.cooldown = 8.0
	
	# CHARGE SWEEP - Gap closer combo
	charge_sweep = BossCombo.new()
	charge_sweep.combo_name = "Charge Sweep"
	charge_sweep.attacks = [mourning_charge, horizontal_sweep]
	charge_sweep.weight = 2.5
	charge_sweep.min_distance = 5.0  # Only when far
	charge_sweep.max_distance = 15.0
	
	# DESPERATION FLURRY - Phase 2 only, 3-hit combo
	desperation_flurry = BossCombo.new()
	desperation_flurry.combo_name = "Desperation Flurry"
	desperation_flurry.attacks = [shield_bash, horizontal_sweep, rising_slash]
	desperation_flurry.weight = 2.0
	desperation_flurry.max_distance = 3.5
	desperation_flurry.required_phase = 1
	desperation_flurry.max_health_percent = 0.5
	
	# Add base combos to pool
	combo_pool = [basic_sweep, slam_combo, bash_into_slam, charge_sweep]
	
	# Phase 2 combos added via phase_combos array
	phase_combos = [[desperation_flurry]]


func _on_phase_changed(phase: int) -> void:
	match phase:
		1:
			# Phase 2: Faster, more aggressive
			attack_cooldown = 1.0
			aggression = 0.7
			
			# Speed up some attacks
			horizontal_sweep.windup_time = 0.5
			horizontal_sweep.recovery_time = 0.5
			
			print("[Fallen Knight] \"I won't hold back any longer!\"")


## Override to detect healing (for future estus punish)
func _get_combat_context() -> Dictionary:
	var context = super._get_combat_context()
	
	# TODO: Detect if player is healing
	# context["player_healing"] = player.is_healing
	
	return context
