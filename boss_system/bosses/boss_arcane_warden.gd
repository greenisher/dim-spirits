extends BossBase
class_name BossArcaneWarden

## BOSS 3: THE ARCANE WARDEN
## A mage-knight hybrid that controls space
## 
## Design Philosophy:
## - Ranged spells when player is far
## - Devastating melee when player is close
## - Forces player to find the "sweet spot" distance
## - Teaches: spacing, closing gaps during casts, positioning
##
## Signature Moves:
## - Soul Arrow: Fast projectile
## - Crystal Barrage: Spread of projectiles
## - Gravity Well: AOE that pulls player
## - Staff Slam: Melee punish for getting close
## - Arcane Explosion: Point-blank AOE
## - Teleport: Repositioning tool

const PROJECTILE_SCENE = "res://bosses/projectiles/soul_arrow.tscn"

## Attacks
var soul_arrow: BossAttack
var crystal_barrage: BossAttack
var gravity_well: BossAttack
var staff_slam: BossAttack
var arcane_explosion: BossAttack
var teleport_away: BossAttack
var homing_orbs: BossAttack
var meteor_call: BossAttack

## Combos
var poke_combo: BossCombo
var barrage_combo: BossCombo
var close_quarters: BossCombo
var space_control: BossCombo
var punish_approach: BossCombo
var arcane_storm: BossCombo  # Phase 2


func _setup_boss() -> void:
	boss_name = "Arcane Warden"
	max_health = 450.0
	poise = 60.0
	xp_reward = 1000
	
	walk_speed = 2.0
	run_speed = 3.5  # Slow movement
	rotation_speed = 4.0
	preferred_distance = 8.0  # Wants to be far
	attack_cooldown = 1.2
	aggression = 0.6
	
	phase_thresholds = [0.5]  # Phase 2 at 50%
	
	_create_attacks()
	_create_combos()
	
	print("[Arcane Warden] \"The arcane arts shall be your end.\"")


func _create_attacks() -> void:
	# SOUL ARROW - Basic ranged attack
	soul_arrow = BossAttack.new()
	soul_arrow.attack_name = "Soul Arrow"
	soul_arrow.animation_name = "SoulArrow"
	soul_arrow.attack_type = BossAttack.AttackType.RANGED
	soul_arrow.windup_time = 0.6
	soul_arrow.active_time = 0.1
	soul_arrow.recovery_time = 0.4
	soul_arrow.base_damage = 25.0
	soul_arrow.movement_type = BossAttack.MovementType.STATIONARY
	
	# CRYSTAL BARRAGE - Spread shot
	crystal_barrage = BossAttack.new()
	crystal_barrage.attack_name = "Crystal Barrage"
	crystal_barrage.animation_name = "CrystalBarrage"
	crystal_barrage.attack_type = BossAttack.AttackType.RANGED
	crystal_barrage.windup_time = 0.8
	crystal_barrage.active_time = 0.3  # Fires multiple projectiles
	crystal_barrage.recovery_time = 0.6
	crystal_barrage.base_damage = 15.0  # Per crystal
	crystal_barrage.movement_type = BossAttack.MovementType.STATIONARY
	
	# GRAVITY WELL - AOE pull
	gravity_well = BossAttack.new()
	gravity_well.attack_name = "Gravity Well"
	gravity_well.animation_name = "GravityWell"
	gravity_well.attack_type = BossAttack.AttackType.AOE
	gravity_well.windup_time = 1.0
	gravity_well.active_time = 1.5  # Long duration pull
	gravity_well.recovery_time = 0.8
	gravity_well.base_damage = 5.0  # Low damage, mainly utility
	gravity_well.movement_type = BossAttack.MovementType.STATIONARY
	gravity_well.hitbox_scale = Vector3(8.0, 3.0, 8.0)
	
	# STAFF SLAM - Melee punish
	staff_slam = BossAttack.new()
	staff_slam.attack_name = "Staff Slam"
	staff_slam.animation_name = "StaffSlam"
	staff_slam.windup_time = 0.5
	staff_slam.active_time = 0.2
	staff_slam.recovery_time = 0.5
	staff_slam.base_damage = 35.0
	staff_slam.movement_type = BossAttack.MovementType.TRACKING
	staff_slam.tracking_speed = 2.0
	staff_slam.staggers_player = true
	staff_slam.knockback_force = 8.0  # Knocks player back to range
	
	# ARCANE EXPLOSION - Point blank AOE
	arcane_explosion = BossAttack.new()
	arcane_explosion.attack_name = "Arcane Explosion"
	arcane_explosion.animation_name = "ArcaneExplosion"
	arcane_explosion.attack_type = BossAttack.AttackType.AOE
	arcane_explosion.windup_time = 0.4  # Fast when player is close
	arcane_explosion.active_time = 0.2
	arcane_explosion.recovery_time = 0.8
	arcane_explosion.base_damage = 40.0
	arcane_explosion.movement_type = BossAttack.MovementType.STATIONARY
	arcane_explosion.hitbox_scale = Vector3(5.0, 3.0, 5.0)
	arcane_explosion.knockback_force = 10.0
	
	# TELEPORT AWAY - Escape tool
	teleport_away = BossAttack.new()
	teleport_away.attack_name = "Teleport"
	teleport_away.animation_name = "Teleport"
	teleport_away.windup_time = 0.3
	teleport_away.active_time = 0.0
	teleport_away.recovery_time = 0.2
	teleport_away.base_damage = 0.0
	teleport_away.movement_type = BossAttack.MovementType.LEAP
	
	# HOMING ORBS - Phase 2 tracking projectiles
	homing_orbs = BossAttack.new()
	homing_orbs.attack_name = "Homing Orbs"
	homing_orbs.animation_name = "HomingOrbs"
	homing_orbs.attack_type = BossAttack.AttackType.RANGED
	homing_orbs.windup_time = 1.2
	homing_orbs.active_time = 0.5
	homing_orbs.recovery_time = 0.6
	homing_orbs.base_damage = 20.0
	homing_orbs.movement_type = BossAttack.MovementType.STATIONARY
	
	# METEOR CALL - Phase 2 ultimate
	meteor_call = BossAttack.new()
	meteor_call.attack_name = "Meteor Call"
	meteor_call.animation_name = "MeteorCall"
	meteor_call.attack_type = BossAttack.AttackType.AOE
	meteor_call.windup_time = 2.0  # Very telegraphed
	meteor_call.active_time = 0.5
	meteor_call.recovery_time = 1.5
	meteor_call.base_damage = 80.0
	meteor_call.movement_type = BossAttack.MovementType.STATIONARY
	meteor_call.hitbox_scale = Vector3(6.0, 10.0, 6.0)


func _create_combos() -> void:
	# POKE COMBO - Basic ranged harassment
	poke_combo = BossCombo.new()
	poke_combo.combo_name = "Soul Poke"
	poke_combo.attacks = [soul_arrow, soul_arrow]
	poke_combo.weight = 3.0
	poke_combo.min_distance = 5.0
	poke_combo.max_distance = 20.0
	
	# BARRAGE COMBO - Heavy ranged pressure
	barrage_combo = BossCombo.new()
	barrage_combo.combo_name = "Crystal Storm"
	barrage_combo.attacks = [crystal_barrage, soul_arrow, crystal_barrage]
	barrage_combo.weight = 2.0
	barrage_combo.min_distance = 6.0
	barrage_combo.max_distance = 15.0
	barrage_combo.cooldown = 6.0
	
	# CLOSE QUARTERS - Melee when player gets in
	close_quarters = BossCombo.new()
	close_quarters.combo_name = "Close Quarters"
	close_quarters.attacks = [staff_slam, arcane_explosion]
	close_quarters.weight = 4.0  # High priority when close
	close_quarters.max_distance = 4.0
	close_quarters.cooldown = 2.0
	
	# SPACE CONTROL - Create distance
	space_control = BossCombo.new()
	space_control.combo_name = "Space Control"
	space_control.attacks = [arcane_explosion, teleport_away]
	space_control.weight = 3.0
	space_control.max_distance = 3.0  # When player is too close
	space_control.cooldown = 8.0
	
	# PUNISH APPROACH - Gravity well into barrage
	punish_approach = BossCombo.new()
	punish_approach.combo_name = "Approach Punish"
	punish_approach.attacks = [gravity_well, crystal_barrage, soul_arrow]
	punish_approach.weight = 2.0
	punish_approach.min_distance = 4.0
	punish_approach.max_distance = 10.0
	punish_approach.cooldown = 10.0
	
	# ARCANE STORM - Phase 2 ultimate combo
	arcane_storm = BossCombo.new()
	arcane_storm.combo_name = "Arcane Storm"
	arcane_storm.attacks = [homing_orbs, crystal_barrage, meteor_call]
	arcane_storm.weight = 2.5
	arcane_storm.min_distance = 6.0
	arcane_storm.max_distance = 20.0
	arcane_storm.required_phase = 1
	arcane_storm.cooldown = 15.0
	arcane_storm.max_uses_per_phase = 3
	
	# Base combos
	combo_pool = [poke_combo, barrage_combo, close_quarters, space_control, punish_approach]
	
	# Phase additions
	phase_combos = [[arcane_storm]]


func _on_phase_changed(phase: int) -> void:
	match phase:
		1:
			# Phase 2: More aggressive magic
			attack_cooldown = 0.8
			aggression = 0.8
			preferred_distance = 10.0  # Wants even more distance
			
			# Faster casts
			soul_arrow.windup_time = 0.4
			crystal_barrage.windup_time = 0.6
			
			# Add homing orbs to basic rotation
			var orb_poke = BossCombo.new()
			orb_poke.combo_name = "Orb Poke"
			orb_poke.attacks = [homing_orbs, soul_arrow]
			orb_poke.weight = 2.5
			orb_poke.min_distance = 5.0
			orb_poke.max_distance = 20.0
			combo_pool.append(orb_poke)
			
			print("[Arcane Warden] \"Witness true power!\"")


## Custom teleport logic
func _process_attack_movement(attack: BossAttack, delta: float) -> void:
	if attack.attack_name == "Teleport":
		if rig and rig.is_in_windup():
			# Teleport to a position away from player
			var away_dir = -_get_direction_to_player()
			var teleport_pos = global_position + away_dir * 8.0
			
			# Clamp to arena bounds (you'd need to implement this)
			global_position = teleport_pos
	else:
		super._process_attack_movement(attack, delta)


## Override damage dealing to spawn projectiles for ranged attacks
func _on_attack_active_complete() -> void:
	if current_combo:
		var attack = current_combo.get_attack(current_combo_index)
		if attack and attack.attack_type == BossAttack.AttackType.RANGED:
			_spawn_projectile(attack)
		else:
			super._on_attack_active_complete()
	else:
		super._on_attack_active_complete()


func _spawn_projectile(attack: BossAttack) -> void:
	# Spawn projectile(s) based on attack type
	match attack.attack_name:
		"Soul Arrow":
			_spawn_soul_arrow(1)
		"Crystal Barrage":
			_spawn_crystal_barrage()
		"Homing Orbs":
			_spawn_homing_orbs()
	
	print("[%s] Fired %s!" % [boss_name, attack.attack_name])


func _spawn_soul_arrow(count: int = 1) -> void:
	# TODO: Instantiate actual projectile scene
	# For now, do direct damage if player is in line of fire
	var direction = _get_direction_to_player()
	var distance = _get_distance_to_player()
	
	if distance < 20.0:  # Range check
		# Simple raycast damage for now
		if player and player.has_node("HealthComponent"):
			var health_comp: HealthComponent = player.get_node("HealthComponent")
			health_comp.take_damage(soul_arrow.base_damage, false)


func _spawn_crystal_barrage() -> void:
	# Spawn 5 crystals in a spread pattern
	# TODO: Actual projectiles
	if player and player.has_node("HealthComponent"):
		var health_comp: HealthComponent = player.get_node("HealthComponent")
		# 3 out of 5 crystals might hit
		var hits = randi_range(1, 3)
		health_comp.take_damage(crystal_barrage.base_damage * hits, false)


func _spawn_homing_orbs() -> void:
	# Spawn 3 homing orbs
	# TODO: Actual homing projectile AI
	if player and player.has_node("HealthComponent"):
		var health_comp: HealthComponent = player.get_node("HealthComponent")
		health_comp.take_damage(homing_orbs.base_damage * 2, false)


## Special: Gravity well pulls player
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Handle gravity well pull effect
	if current_combo and rig and rig.is_attack_active():
		var attack = current_combo.get_attack(current_combo_index)
		if attack and attack.attack_name == "Gravity Well":
			_apply_gravity_pull(delta)


func _apply_gravity_pull(delta: float) -> void:
	if not player:
		return
	
	var distance = _get_distance_to_player()
	if distance < 10.0 and distance > 2.0:
		var pull_direction = (global_position - player.global_position).normalized()
		var pull_strength = (10.0 - distance) * 2.0  # Stronger when closer
		player.velocity += pull_direction * pull_strength * delta
