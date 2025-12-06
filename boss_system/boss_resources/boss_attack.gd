@tool
extends Resource
class_name BossAttack

## Individual attack definition for boss combos
## Each attack has timing windows that create the "Souls-like" feel

enum MovementType {
	STATIONARY,      ## Boss doesn't move during attack
	LUNGE_FORWARD,   ## Boss moves toward player
	LUNGE_BACKWARD,  ## Boss retreats while attacking
	TRACKING,        ## Boss rotates to face player during windup
	LEAP,            ## Boss jumps to player location
}

enum AttackType {
	MELEE,           ## Close range physical
	RANGED,          ## Projectile attack
	AOE,             ## Area of effect around boss
	GRAB,            ## Unblockable grab attack
}

@export_category("Identity")
@export var attack_name: String = "Attack"
@export var animation_name: String = ""  ## Must match AnimationTree state name
@export var attack_type: AttackType = AttackType.MELEE

@export_category("Timing (seconds)")
@export var windup_time: float = 0.5      ## Telegraph - player reads this
@export var active_time: float = 0.2       ## Hitbox is active
@export var recovery_time: float = 0.4     ## Punish window after attack
@export var delay_variance: float = 0.0    ## Random delay added to windup (mixup)

@export_category("Damage")
@export var base_damage: float = 20.0
@export var is_unblockable: bool = false
@export var staggers_player: bool = false
@export var knockback_force: float = 0.0

@export_category("Movement")
@export var movement_type: MovementType = MovementType.STATIONARY
@export var movement_speed: float = 5.0    ## Speed during lunge
@export var movement_distance: float = 3.0 ## Max distance for lunge
@export var tracking_speed: float = 2.0    ## Rotation speed during tracking

@export_category("Hitbox")
@export var hitbox_scale: Vector3 = Vector3(1.5, 1.5, 2.0)  ## Size of attack area
@export var hitbox_offset: Vector3 = Vector3(0, 1, 1.5)     ## Offset from boss

@export_category("Chaining")
@export var can_be_first: bool = true            ## Can start a combo
@export var chain_window: float = 0.3            ## Time after recovery to chain
@export var followup_attacks: Array[String] = [] ## Names of attacks that can follow

@export_category("VFX/SFX")
@export var windup_vfx: String = ""
@export var attack_vfx: String = ""
@export var hit_vfx: String = ""
@export var windup_sfx: String = ""
@export var attack_sfx: String = ""


## Get total duration of the attack
func get_total_duration() -> float:
	return windup_time + active_time + recovery_time


## Get actual windup with variance applied
func get_actual_windup() -> float:
	if delay_variance > 0:
		return windup_time + randf_range(0, delay_variance)
	return windup_time


## Check if this attack can chain into another
func can_chain_to(attack_name: String) -> bool:
	return attack_name in followup_attacks


## Get a description for debug purposes
func get_description() -> String:
	return "%s [W:%.1f A:%.1f R:%.1f] DMG:%.0f" % [
		attack_name, windup_time, active_time, recovery_time, base_damage
	]
