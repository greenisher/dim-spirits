@tool
extends Resource
class_name BossCombo

## A combo is a sequence of attacks with conditions for when to use it
## The boss AI selects combos based on these conditions

@export_category("Identity")
@export var combo_name: String = "Combo"
@export var attacks: Array[BossAttack] = []
@export var weight: float = 1.0  ## Higher = more likely to be selected

@export_category("Trigger Conditions")
## Distance-based triggers
@export var min_distance: float = 0.0      ## Minimum distance to player
@export var max_distance: float = 100.0    ## Maximum distance to player

## Health-based triggers (0.0 to 1.0)
@export var min_health_percent: float = 0.0   ## Only use above this HP %
@export var max_health_percent: float = 1.0   ## Only use below this HP %

## Phase-based triggers
@export var required_phase: int = -1  ## -1 = any phase, otherwise specific phase

## Situational triggers
@export var use_when_player_healing: bool = false  ## Punish estus
@export var use_when_player_far: bool = false      ## Gap closer
@export var use_when_player_close: bool = false    ## Point blank defense
@export var use_as_opener: bool = false            ## First attack of fight

@export_category("Combo Properties")
@export var is_interruptible: bool = true   ## Can be staggered out of
@export var cooldown: float = 0.0           ## Time before can use again
@export var max_uses_per_phase: int = -1    ## -1 = unlimited

## Runtime tracking (not exported)
var _times_used: int = 0
var _last_use_time: float = 0.0


## Check if combo can be used given current conditions
func can_use(distance: float, health_percent: float, phase: int, context: Dictionary = {}) -> bool:
	# Distance check
	if distance < min_distance or distance > max_distance:
		return false
	
	# Health check
	if health_percent < min_health_percent or health_percent > max_health_percent:
		return false
	
	# Phase check
	if required_phase != -1 and phase != required_phase:
		return false
	
	# Cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if cooldown > 0 and (current_time - _last_use_time) < cooldown:
		return false
	
	# Usage limit check
	if max_uses_per_phase != -1 and _times_used >= max_uses_per_phase:
		return false
	
	# Context checks
	if use_when_player_healing and not context.get("player_healing", false):
		return false
	
	return true


## Mark combo as used
func mark_used() -> void:
	_times_used += 1
	_last_use_time = Time.get_ticks_msec() / 1000.0


## Reset usage tracking (call on phase change)
func reset_usage() -> void:
	_times_used = 0


## Get the total duration of all attacks in combo
func get_total_duration() -> float:
	var total := 0.0
	for attack in attacks:
		total += attack.get_total_duration()
	return total


## Get number of attacks in combo
func get_attack_count() -> int:
	return attacks.size()


## Get attack at index
func get_attack(index: int) -> BossAttack:
	if index >= 0 and index < attacks.size():
		return attacks[index]
	return null


## Get combo description for debug
func get_description() -> String:
	var attack_names = []
	for attack in attacks:
		attack_names.append(attack.attack_name)
	return "%s: %s (weight: %.1f)" % [combo_name, " -> ".join(attack_names), weight]
