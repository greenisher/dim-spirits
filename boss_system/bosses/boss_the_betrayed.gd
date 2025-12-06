extends BossBase
class_name BossTheBetrayed

## BOSS 4: THE BETRAYED
## The final boss - a mirror of the player, consumed by vengeance
## Design: Three distinct phases, each completely changes combat style
## Purpose: Tests everything the player has learned

# ==================== PHASE DESIGN ====================
# Phase 1 (100-70%): Knight - Methodical, honorable combat
# Phase 2 (70-35%): Assassin - Fast, dirty, desperate
# Phase 3 (35-0%): Abomination - Unpredictable, monstrous

# ==================== ATTACK RESOURCES ====================

# Phase 1: Knight attacks
var attack_knight_slash: BossAttack
var attack_knight_thrust: BossAttack
var attack_knight_overhead: BossAttack
var attack_parry_riposte: BossAttack

# Phase 2: Assassin attacks
var attack_assassin_flurry_1: BossAttack
var attack_assassin_flurry_2: BossAttack
var attack_assassin_flurry_3: BossAttack
var attack_shadow_step: BossAttack
var attack_backstab: BossAttack
var attack_throwing_knife: BossAttack

# Phase 3: Abomination attacks
var attack_tendril_sweep: BossAttack
var attack_tendril_stab: BossAttack
var attack_corruption_burst: BossAttack
var attack_scream: BossAttack
var attack_consume: BossAttack
var attack_mirror_player: BossAttack  # Copies player's last attack!

# ==================== COMBOS ====================

# Phase 1 combos
var combo_knight_basic: BossCombo
var combo_knight_punish: BossCombo
var combo_honorable_duel: BossCombo

# Phase 2 combos
var combo_assassin_rush: BossCombo
var combo_shadow_ambush: BossCombo
var combo_knife_into_melee: BossCombo

# Phase 3 combos
var combo_tendril_assault: BossCombo
var combo_corruption_wave: BossCombo
var combo_consume_soul: BossCombo
var combo_mirror_revenge: BossCombo

# ==================== BETRAYED-SPECIFIC STATE ====================

var player_last_attack: String = ""  # Track for mirror mechanic
var times_parried: int = 0
var rage_building: float = 0.0
var in_shadow_form: bool = false
var corruption_level: float = 0.0

# ==================== INITIALIZATION ====================

func _on_boss_activated() -> void:
	boss_name = "The Betrayed"
	boss_subtitle = "What You Could Have Become"
	
	# Two phase transitions
	phase_thresholds = [0.7, 0.35]
	
	_create_attacks()
	_create_combos()
	
	# Start as honorable knight
	_apply_phase_1_stats()

func _apply_phase_1_stats() -> void:
	max_health = 800.0  # Final boss health
	poise = 100.0
	poise_regen_rate = 15.0
	aggression = 0.5  # Measured
	patience = 2.5
	preferred_distance = 3.0
	walk_speed = 3.0
	run_speed = 5.0
	rotation_speed = 4.0
	circle_chance = 0.4  # Circles like a duelist

func _apply_phase_2_stats() -> void:
	poise = 50.0  # Much easier to stagger
	poise_regen_rate = 40.0  # But recovers fast
	aggression = 0.9
	patience = 0.8
	preferred_distance = 2.0
	walk_speed = 5.0
	run_speed = 9.0
	rotation_speed = 8.0
	circle_chance = 0.6

func _apply_phase_3_stats() -> void:
	poise = 150.0  # Tanky abomination
	poise_regen_rate = 5.0  # Slow recovery
	aggression = 1.0  # Relentless
	patience = 0.3
	preferred_distance = 4.0  # Tendril range
	walk_speed = 4.0
	run_speed = 7.0
	rotation_speed = 3.0  # Slower, more monstrous
	circle_chance = 0.1

func _create_attacks() -> void:
	# ========== PHASE 1: KNIGHT ==========
	
	attack_knight_slash = BossAttack.new()
	attack_knight_slash.attack_name = "Knight Slash"
	attack_knight_slash.animation_name = "knight_slash"
	attack_knight_slash.windup_time = 0.5
	attack_knight_slash.active_time = 0.2
	attack_knight_slash.recovery_time = 0.4
	attack_knight_slash.base_damage = 20.0
	attack_knight_slash.movement_type = 3  # Tracking
	attack_knight_slash.hitbox_range = 2.5
	
	attack_knight_thrust = BossAttack.new()
	attack_knight_thrust.attack_name = "Knight Thrust"
	attack_knight_thrust.animation_name = "knight_thrust"
	attack_knight_thrust.windup_time = 0.4
	attack_knight_thrust.active_time = 0.15
	attack_knight_thrust.recovery_time = 0.5
	attack_knight_thrust.base_damage = 18.0
	attack_knight_thrust.movement_type = 1
	attack_knight_thrust.movement_speed = 6.0
	attack_knight_thrust.hitbox_type = 2
	attack_knight_thrust.hitbox_range = 3.5
	
	attack_knight_overhead = BossAttack.new()
	attack_knight_overhead.attack_name = "Knight Overhead"
	attack_knight_overhead.animation_name = "knight_overhead"
	attack_knight_overhead.windup_time = 0.9
	attack_knight_overhead.active_time = 0.2
	attack_knight_overhead.recovery_time = 0.7
	attack_knight_overhead.base_damage = 30.0
	attack_knight_overhead.is_heavy = true
	attack_knight_overhead.movement_type = 1
	attack_knight_overhead.movement_speed = 4.0
	attack_knight_overhead.hitbox_type = 3
	attack_knight_overhead.hitbox_range = 2.0
	
	attack_parry_riposte = BossAttack.new()
	attack_parry_riposte.attack_name = "Parry Riposte"
	attack_parry_riposte.animation_name = "parry_riposte"
	attack_parry_riposte.windup_time = 0.1  # Near instant after parry
	attack_parry_riposte.active_time = 0.2
	attack_parry_riposte.recovery_time = 0.6
	attack_parry_riposte.base_damage = 40.0
	attack_parry_riposte.is_heavy = true
	attack_parry_riposte.hitbox_range = 2.0
	
	# ========== PHASE 2: ASSASSIN ==========
	
	attack_assassin_flurry_1 = BossAttack.new()
	attack_assassin_flurry_1.attack_name = "Assassin Flurry 1"
	attack_assassin_flurry_1.animation_name = "assassin_flurry_1"
	attack_assassin_flurry_1.windup_time = 0.2
	attack_assassin_flurry_1.active_time = 0.1
	attack_assassin_flurry_1.recovery_time = 0.05
	attack_assassin_flurry_1.base_damage = 10.0
	attack_assassin_flurry_1.movement_type = 3
	attack_assassin_flurry_1.hitbox_range = 2.0
	
	attack_assassin_flurry_2 = BossAttack.new()
	attack_assassin_flurry_2.attack_name = "Assassin Flurry 2"
	attack_assassin_flurry_2.animation_name = "assassin_flurry_2"
	attack_assassin_flurry_2.windup_time = 0.15
	attack_assassin_flurry_2.active_time = 0.1
	attack_assassin_flurry_2.recovery_time = 0.05
	attack_assassin_flurry_2.base_damage = 10.0
	attack_assassin_flurry_2.movement_type = 3
	attack_assassin_flurry_2.hitbox_range = 2.0
	
	attack_assassin_flurry_3 = BossAttack.new()
	attack_assassin_flurry_3.attack_name = "Assassin Flurry 3"
	attack_assassin_flurry_3.animation_name = "assassin_flurry_3"
	attack_assassin_flurry_3.windup_time = 0.4
	attack_assassin_flurry_3.windup_variance = 0.2
	attack_assassin_flurry_3.active_time = 0.15
	attack_assassin_flurry_3.recovery_time = 0.5
	attack_assassin_flurry_3.base_damage = 18.0
	attack_assassin_flurry_3.is_heavy = true
	attack_assassin_flurry_3.movement_type = 1
	attack_assassin_flurry_3.movement_speed = 8.0
	attack_assassin_flurry_3.hitbox_range = 2.5
	
	attack_shadow_step = BossAttack.new()
	attack_shadow_step.attack_name = "Shadow Step"
	attack_shadow_step.animation_name = "shadow_step"
	attack_shadow_step.windup_time = 0.25
	attack_shadow_step.active_time = 0.15
	attack_shadow_step.recovery_time = 0.3
	attack_shadow_step.base_damage = 15.0
	attack_shadow_step.movement_type = 1
	attack_shadow_step.movement_speed = 15.0
	attack_shadow_step.hitbox_range = 2.0
	
	attack_backstab = BossAttack.new()
	attack_backstab.attack_name = "Backstab"
	attack_backstab.animation_name = "backstab"
	attack_backstab.windup_time = 0.1
	attack_backstab.active_time = 0.3
	attack_backstab.recovery_time = 0.5
	attack_backstab.base_damage = 35.0
	attack_backstab.is_heavy = true
	attack_backstab.hitbox_range = 1.5
	
	attack_throwing_knife = BossAttack.new()
	attack_throwing_knife.attack_name = "Throwing Knife"
	attack_throwing_knife.animation_name = "throwing_knife"
	attack_throwing_knife.windup_time = 0.3
	attack_throwing_knife.active_time = 0.1
	attack_throwing_knife.recovery_time = 0.2
	attack_throwing_knife.base_damage = 8.0
	attack_throwing_knife.movement_type = 0
	
	# ========== PHASE 3: ABOMINATION ==========
	
	attack_tendril_sweep = BossAttack.new()
	attack_tendril_sweep.attack_name = "Tendril Sweep"
	attack_tendril_sweep.animation_name = "tendril_sweep"
	attack_tendril_sweep.windup_time = 0.6
	attack_tendril_sweep.active_time = 0.4
	attack_tendril_sweep.recovery_time = 0.6
	attack_tendril_sweep.base_damage = 22.0
	attack_tendril_sweep.movement_type = 0
	attack_tendril_sweep.hitbox_type = 0
	attack_tendril_sweep.hitbox_range = 5.0  # Long tendrils!
	attack_tendril_sweep.hitbox_arc = 270.0
	
	attack_tendril_stab = BossAttack.new()
	attack_tendril_stab.attack_name = "Tendril Stab"
	attack_tendril_stab.animation_name = "tendril_stab"
	attack_tendril_stab.windup_time = 0.4
	attack_tendril_stab.active_time = 0.15
	attack_tendril_stab.recovery_time = 0.4
	attack_tendril_stab.base_damage = 18.0
	attack_tendril_stab.movement_type = 3
	attack_tendril_stab.hitbox_type = 2
	attack_tendril_stab.hitbox_range = 6.0
	
	attack_corruption_burst = BossAttack.new()
	attack_corruption_burst.attack_name = "Corruption Burst"
	attack_corruption_burst.animation_name = "corruption_burst"
	attack_corruption_burst.windup_time = 0.8
	attack_corruption_burst.active_time = 0.3
	attack_corruption_burst.recovery_time = 1.0
	attack_corruption_burst.base_damage = 35.0
	attack_corruption_burst.is_heavy = true
	attack_corruption_burst.can_be_parried = false
	attack_corruption_burst.movement_type = 0
	attack_corruption_burst.hitbox_type = 1
	attack_corruption_burst.hitbox_range = 6.0
	
	attack_scream = BossAttack.new()
	attack_scream.attack_name = "Anguished Scream"
	attack_scream.animation_name = "scream"
	attack_scream.windup_time = 1.0
	attack_scream.active_time = 0.5
	attack_scream.recovery_time = 0.8
	attack_scream.base_damage = 15.0  # Low damage but staggers player
	attack_scream.movement_type = 0
	attack_scream.hitbox_type = 1
	attack_scream.hitbox_range = 10.0
	
	attack_consume = BossAttack.new()
	attack_consume.attack_name = "Consume"
	attack_consume.animation_name = "consume"
	attack_consume.windup_time = 1.2
	attack_consume.active_time = 0.3
	attack_consume.recovery_time = 1.5
	attack_consume.base_damage = 50.0  # Devastating grab
	attack_consume.is_heavy = true
	attack_consume.can_be_parried = false
	attack_consume.movement_type = 1
	attack_consume.movement_speed = 8.0
	attack_consume.hitbox_range = 2.0
	
	# MIRROR - Uses player's last attack timing
	attack_mirror_player = BossAttack.new()
	attack_mirror_player.attack_name = "Mirrored Strike"
	attack_mirror_player.animation_name = "mirror_strike"
	attack_mirror_player.windup_time = 0.5  # Will be modified
	attack_mirror_player.active_time = 0.2
	attack_mirror_player.recovery_time = 0.4
	attack_mirror_player.base_damage = 25.0
	attack_mirror_player.movement_type = 3
	attack_mirror_player.hitbox_range = 2.5

func _create_combos() -> void:
	# ========== PHASE 1: KNIGHT COMBOS ==========
	
	combo_knight_basic = BossCombo.new()
	combo_knight_basic.combo_name = "Knight Basic"
	combo_knight_basic.attacks = [attack_knight_slash, attack_knight_thrust]
	combo_knight_basic.required_phase = 1
	combo_knight_basic.max_distance = 4.0
	combo_knight_basic.selection_weight = 2.0
	combo_knight_basic.cooldown = 2.0
	combos.append(combo_knight_basic)
	
	combo_knight_punish = BossCombo.new()
	combo_knight_punish.combo_name = "Knight Punish"
	combo_knight_punish.attacks = [attack_knight_overhead]
	combo_knight_punish.required_phase = 1
	combo_knight_punish.max_distance = 3.5
	combo_knight_punish.selection_weight = 1.5
	combo_knight_punish.cooldown = 4.0
	combos.append(combo_knight_punish)
	
	combo_honorable_duel = BossCombo.new()
	combo_honorable_duel.combo_name = "Honorable Duel"
	combo_honorable_duel.attacks = [attack_knight_slash, attack_knight_slash, attack_knight_overhead]
	combo_honorable_duel.required_phase = 1
	combo_honorable_duel.max_distance = 3.0
	combo_honorable_duel.selection_weight = 2.5
	combo_honorable_duel.cooldown = 5.0
	combos.append(combo_honorable_duel)
	
	# ========== PHASE 2: ASSASSIN COMBOS ==========
	
	combo_assassin_rush = BossCombo.new()
	combo_assassin_rush.combo_name = "Assassin Rush"
	combo_assassin_rush.attacks = [
		attack_assassin_flurry_1,
		attack_assassin_flurry_2,
		attack_assassin_flurry_3
	]
	combo_assassin_rush.required_phase = 2
	combo_assassin_rush.max_distance = 3.5
	combo_assassin_rush.selection_weight = 3.0
	combo_assassin_rush.cooldown = 3.0
	combos.append(combo_assassin_rush)
	
	combo_shadow_ambush = BossCombo.new()
	combo_shadow_ambush.combo_name = "Shadow Ambush"
	combo_shadow_ambush.attacks = [attack_shadow_step, attack_backstab]
	combo_shadow_ambush.required_phase = 2
	combo_shadow_ambush.min_distance = 4.0
	combo_shadow_ambush.max_distance = 12.0
	combo_shadow_ambush.selection_weight = 4.0
	combo_shadow_ambush.cooldown = 5.0
	combos.append(combo_shadow_ambush)
	
	combo_knife_into_melee = BossCombo.new()
	combo_knife_into_melee.combo_name = "Knife Into Melee"
	combo_knife_into_melee.attacks = [attack_throwing_knife, attack_shadow_step, attack_assassin_flurry_1, attack_assassin_flurry_2]
	combo_knife_into_melee.required_phase = 2
	combo_knife_into_melee.min_distance = 3.0
	combo_knife_into_melee.max_distance = 10.0
	combo_knife_into_melee.selection_weight = 2.5
	combo_knife_into_melee.cooldown = 4.0
	combos.append(combo_knife_into_melee)
	
	# ========== PHASE 3: ABOMINATION COMBOS ==========
	
	combo_tendril_assault = BossCombo.new()
	combo_tendril_assault.combo_name = "Tendril Assault"
	combo_tendril_assault.attacks = [attack_tendril_sweep, attack_tendril_stab, attack_tendril_sweep]
	combo_tendril_assault.required_phase = 3
	combo_tendril_assault.max_distance = 6.0
	combo_tendril_assault.selection_weight = 3.0
	combo_tendril_assault.cooldown = 4.0
	combos.append(combo_tendril_assault)
	
	combo_corruption_wave = BossCombo.new()
	combo_corruption_wave.combo_name = "Corruption Wave"
	combo_corruption_wave.attacks = [attack_scream, attack_corruption_burst]
	combo_corruption_wave.required_phase = 3
	combo_corruption_wave.max_distance = 8.0
	combo_corruption_wave.selection_weight = 2.0
	combo_corruption_wave.cooldown = 8.0
	combos.append(combo_corruption_wave)
	
	combo_consume_soul = BossCombo.new()
	combo_consume_soul.combo_name = "Consume Soul"
	combo_consume_soul.attacks = [attack_consume]
	combo_consume_soul.required_phase = 3
	combo_consume_soul.max_distance = 4.0
	combo_consume_soul.health_threshold = 0.2  # Desperate move at low HP
	combo_consume_soul.selection_weight = 5.0
	combo_consume_soul.cooldown = 10.0
	combos.append(combo_consume_soul)
	
	combo_mirror_revenge = BossCombo.new()
	combo_mirror_revenge.combo_name = "Mirror Revenge"
	combo_mirror_revenge.attacks = [attack_mirror_player, attack_tendril_stab]
	combo_mirror_revenge.required_phase = 3
	combo_mirror_revenge.max_distance = 5.0
	combo_mirror_revenge.selection_weight = 2.0
	combo_mirror_revenge.cooldown = 6.0
	combos.append(combo_mirror_revenge)

# ==================== PHASE TRANSITIONS ====================

func _on_phase_change(new_phase: int) -> void:
	match new_phase:
		2:
			_apply_phase_2_stats()
			print("[%s] 'YOU THINK THIS IS HONOR?! THIS IS SURVIVAL!'" % boss_name)
			# TODO: Visual transformation, remove armor
		3:
			_apply_phase_3_stats()
			print("[%s] 'IF I CANNOT DEFEAT YOU... I WILL BECOME SOMETHING THAT CAN.'" % boss_name)
			# TODO: Full body horror transformation

# ==================== CUSTOM BEHAVIORS ====================

func _idle_behavior(delta: float) -> void:
	orient_toward_player(delta)
	
	match current_phase:
		1:
			# Knight bows/salutes occasionally
			pass
		2:
			# Assassin is restless, fidgets
			var sway = sin(Time.get_ticks_msec() * 0.005) * 0.3
			velocity.x += boss_rig.global_transform.basis.x.x * sway
			velocity.z += boss_rig.global_transform.basis.x.z * sway
		3:
			# Abomination twitches, corruption pulses
			corruption_level += delta * 0.1
			if corruption_level > 1.0:
				corruption_level = 0.0
				# TODO: Pulse VFX

func _on_damage_taken(damage: float, is_critical: bool) -> void:
	super._on_damage_taken(damage, is_critical)
	
	# Track rage in phase 2
	if current_phase == 2:
		rage_building += damage * 0.01
		if rage_building > 1.0:
			rage_building = 0.0
			# Go berserk briefly
			aggression = 1.0
			patience = 0.2
			await get_tree().create_timer(3.0).timeout
			aggression = 0.9
			patience = 0.8

# ==================== MIRROR MECHANIC ====================

func register_player_attack(attack_name: String) -> void:
	# Called when player attacks (connect to player signals)
	player_last_attack = attack_name
	
	# Modify mirror attack based on what player did
	match attack_name:
		"Light_Attack":
			attack_mirror_player.windup_time = 0.3
			attack_mirror_player.base_damage = 15.0
		"Heavy_Attack":
			attack_mirror_player.windup_time = 0.8
			attack_mirror_player.base_damage = 30.0
		_:
			attack_mirror_player.windup_time = 0.5
			attack_mirror_player.base_damage = 20.0

# ==================== SPECIAL ATTACK HANDLING ====================

func _on_attack_active(attack: BossAttack) -> void:
	# Backstab teleport
	if attack == attack_backstab:
		_execute_backstab_teleport()
	
	# Consume heals the boss
	if attack == attack_consume:
		# If hit lands, heal
		pass  # Handled in damage dealing
	
	super._on_attack_active(attack)

func _execute_backstab_teleport() -> void:
	var behind_offset = -player.global_transform.basis.z * 1.5
	global_position = player.global_position + behind_offset
	global_position.y = player.global_position.y
	look_at(player.global_position, Vector3.UP)

func _deal_attack_damage(attack: BossAttack) -> void:
	super._deal_attack_damage(attack)
	
	# Consume heals
	if attack == attack_consume:
		var heal_amount = attack.base_damage * 0.5
		health_component.heal(heal_amount)
		print("[%s] drains life from the player! Healed %.0f" % [boss_name, heal_amount])

# ==================== CUSTOM COMBO SELECTION ====================

func _select_combo() -> BossCombo:
	var distance = get_distance_to_player()
	var health_pct = health_component.get_health_percentage()
	
	match current_phase:
		1:
			return _select_knight_combo(distance, health_pct)
		2:
			return _select_assassin_combo(distance, health_pct)
		3:
			return _select_abomination_combo(distance, health_pct)
	
	return _default_combo_selection()

func _select_knight_combo(distance: float, health_pct: float) -> BossCombo:
	# Knight fights honorably, alternates attacks
	if distance > 4.0:
		return null  # Approach first
	
	# Prefer the full duel combo
	if randf() < 0.4 and combo_honorable_duel.can_use(distance, health_pct, current_phase, false):
		return combo_honorable_duel
	
	return _default_combo_selection()

func _select_assassin_combo(distance: float, health_pct: float) -> BossCombo:
	# Assassin is aggressive, uses gap closers
	if distance > 5.0:
		if combo_shadow_ambush.can_use(distance, health_pct, current_phase, false):
			return combo_shadow_ambush
	
	# Up close, flurry
	if distance < 4.0 and randf() < 0.6:
		if combo_assassin_rush.can_use(distance, health_pct, current_phase, false):
			return combo_assassin_rush
	
	return _default_combo_selection()

func _select_abomination_combo(distance: float, health_pct: float) -> BossCombo:
	# Abomination is chaotic
	
	# Desperate consume at low HP
	if health_pct < 0.2 and randf() < 0.5:
		if combo_consume_soul.can_use(distance, health_pct, current_phase, false):
			return combo_consume_soul
	
	# Mirror player if they attacked recently
	if player_last_attack != "" and randf() < 0.3:
		if combo_mirror_revenge.can_use(distance, health_pct, current_phase, false):
			return combo_mirror_revenge
	
	# Corruption wave for AOE clear
	if distance < 7.0 and randf() < 0.3:
		if combo_corruption_wave.can_use(distance, health_pct, current_phase, false):
			return combo_corruption_wave
	
	return _default_combo_selection()
