extends Control

signal stat_increased(stat_name: String)
signal level_up_completed()
signal cannot_level_up()

@onready var strength_button: TextureButton = %LevelupStrength
@onready var endurance_button: TextureButton = %LevelupEndurance
@onready var agility_button: TextureButton = %LevelupAgility
@onready var intelligence_button: TextureButton = %LevelupIntelligence
@onready var spirit_button: TextureButton = %LevelupSpirit

@onready var current_level_label: Label = %CurrentLevelLabel
@onready var xp_label: Label = %XPLabel
@onready var strength_label: Label = %StrengthLabel
@onready var endurance_label: Label = %EnduranceLabel
@onready var intelligence_label: Label = %IntelligenceLabel
@onready var agility_label: Label = %AgilityLabel
@onready var spirit_label: Label = %SpiritLabel

@onready var max_hp_label: Label = %MaxHPLabel if has_node("%MaxHPLabel") else null
@onready var damage_label: Label = %DamageLabel if has_node("%DamageLabel") else null
@onready var crit_label: Label = %CritLabel if has_node("%CritLabel") else null

@onready var close_button: Button = %CloseButton if has_node("%CloseButton") else null

@export var player: Player

func _ready() -> void:
	if strength_button:
		strength_button.pressed.connect(_on_strength_button_pressed)
	if endurance_button:
		endurance_button.pressed.connect(_on_endurance_button_pressed)
	if agility_button:
		agility_button.pressed.connect(_on_agility_button_pressed)
	if intelligence_button:
		intelligence_button.pressed.connect(_on_intelligence_button_pressed)
	if spirit_button:
		spirit_button.pressed.connect(_on_spirit_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	visible = false

# ==================== BUTTON PRESS HANDLERS ====================

func _on_strength_button_pressed() -> void:
	if not player or not player.stats:
		print("No player or stats found!")
		return
	
	if not player.stats.can_level_up():
		print("Not enough XP to level up!")
		show_notification("Not enough XP!")
		cannot_level_up.emit()
		return
	
	if player.stats.level_up_strength():
		print("Strength increased to ", player.stats.strength.ability_score)
		update_display()
		update_player_stats()
		stat_increased.emit("Strength")
		
		show_notification("Strength increased!")
		play_level_up_effect("Strength")
		
		if not player.stats.can_level_up():
			level_up_completed.emit()
			await get_tree().create_timer(0.5).timeout
			close()

func _on_endurance_button_pressed() -> void:
	if not player or not player.stats:
		print("No player or stats found!")
		return
	
	if not player.stats.can_level_up():
		print("Not enough XP to level up!")
		show_notification("Not enough XP!")
		cannot_level_up.emit()
		return
	
	if player.stats.level_up_endurance():
		print("Endurance increased to ", player.stats.endurance.ability_score)
		update_display()
		
		update_player_health()
		update_player_stats()
		
		stat_increased.emit("Endurance")
		show_notification("Endurance increased! Max HP increased!")
		play_level_up_effect("Endurance")
		
		if not player.stats.can_level_up():
			level_up_completed.emit()
			await get_tree().create_timer(0.5).timeout
			close()

func _on_intelligence_button_pressed() -> void:
	if not player or not player.stats:
		print("No player or stats found!")
		return
	
	if not player.stats.can_level_up():
		print("Not enough XP to level up!")
		show_notification("Not enough XP!")
		cannot_level_up.emit()
		return
	
	if player.stats.level_up_intelligence():
		print("Intelligence increased to ", player.stats.intelligence.ability_score)
		update_display()
		update_player_stats()
		stat_increased.emit("Intelligence")
		show_notification("Intelligence increased!")
		play_level_up_effect("Intelligence")
		
		if not player.stats.can_level_up():
			level_up_completed.emit()
			await get_tree().create_timer(0.5).timeout
			close()

func _on_agility_button_pressed() -> void:
	if not player or not player.stats:
		print("No player or stats found!")
		return
	
	if not player.stats.can_level_up():
		print("Not enough XP to level up!")
		show_notification("Not enough XP!")
		cannot_level_up.emit()
		return
	
	if player.stats.level_up_agility():
		print("Agility increased to ", player.stats.agility.ability_score)
		update_display()
		update_player_stats()
		stat_increased.emit("Agility")
		show_notification("Agility increased!")
		play_level_up_effect("Agility")
		
		if not player.stats.can_level_up():
			level_up_completed.emit()
			await get_tree().create_timer(0.5).timeout
			close()

func _on_spirit_button_pressed() -> void:
	if not player or not player.stats:
		print("No player or stats found!")
		return
	
	if not player.stats.can_level_up():
		print("Not enough XP to level up!")
		show_notification("Not enough XP!")
		cannot_level_up.emit()
		return
	
	if player.stats.level_up_spirit():
		print("Spirit increased to ", player.stats.agility.ability_score)
		update_display()
		update_player_stats()
		stat_increased.emit("Spirit")
		show_notification("Spirit increased!")
		play_level_up_effect("Spirit")
		
		if not player.stats.can_level_up():
			level_up_completed.emit()
			await get_tree().create_timer(0.5).timeout
			close()

func _on_close_button_pressed() -> void:
	close()

# ==================== UI UPDATE FUNCTIONS ====================

func update_display() -> void:
	if not player or not player.stats:
		return
	
	var stats = player.stats
	
	if current_level_label:
		current_level_label.text = "Level: %d" % stats.level
	
	if xp_label:
		var xp_needed = stats.get_xp_to_next_level()
		xp_label.text = "XP: %d / %d" % [stats.xp, xp_needed]
	
	if strength_label:
		strength_label.text = str(stats.strength.ability_score)
	
	if endurance_label:
		endurance_label.text = str(stats.endurance.ability_score)
	
	if intelligence_label:
		intelligence_label.text = str(stats.intelligence.ability_score)
	
	if agility_label:
		agility_label.text = str(stats.agility.ability_score)
	
	if max_hp_label:
		max_hp_label.text = "Max HP: %d" % stats.get_max_hp()
	
	if damage_label:
		damage_label.text = "Damage: +%.1f" % stats.get_damage_modifier()
	
	if crit_label:
		crit_label.text = "Crit Chance: %.1f%%" % (stats.get_crit_chance() * 100)
	
	# Update button states
	update_button_states()

func update_button_states() -> void:
	if not player or not player.stats:
		return
	
	var can_level = player.stats.can_level_up()
	
	if strength_button:
		strength_button.disabled = not can_level
	if endurance_button:
		endurance_button.disabled = not can_level
	if intelligence_button:
		intelligence_button.disabled = not can_level
	if agility_button:
		agility_button.disabled = not can_level

func update_player_health() -> void:
	if not player or not player.stats or not player.health_component:
		return
	
	var old_max = player.health_component.max_health
	var new_max = player.stats.get_max_hp()
	var hp_gained = new_max - old_max
	
	player.health_component.max_health = new_max
	
	player.health_component.current_health = min(player.health_component.current_health + hp_gained, new_max)
	
	print("Max HP increased by ", hp_gained, " (", old_max, " → ", new_max, ")")

func update_player_stats() -> void:
	if not player or not player.stats:
		return
	
	if player.health_component:
		player.health_component.max_health = player.stats.get_max_hp()
	
	if player.stats.has_method("update_derived_stats"):
		player.stats.update_derived_stats()

# ==================== OPEN/CLOSE FUNCTIONS ====================

func open(player_ref: Player) -> void:
	player = player_ref
	
	if not player or not player.stats:
		print("Cannot open level-up panel: no player or stats!")
		return
	
	if not player.stats.can_level_up():
		print("Cannot open level-up panel: not enough XP!")
		show_notification("Not enough XP to level up!")
		return
	
	visible = true
	update_display()
	print("Level-up panel opened")

func close() -> void:
	visible = false
	print("Level-up panel closed")

# ==================== FEEDBACK FUNCTIONS ====================

func show_notification(message: String) -> void:
	print("NOTIFICATION: ", message)
	# TODO: Implement actual notification UI
	# Example:
	# notification_label.text = message
	# notification_label.visible = true
	# await get_tree().create_timer(2.0).timeout
	# notification_label.visible = false

func play_level_up_effect(stat_name: String) -> void:
	var label: Label = null
	match stat_name:
		"Strength":
			label = strength_label
		"Endurance":
			label = endurance_label
		"Intelligence":
			label = intelligence_label
		"Agility":
			label = agility_label
	
	if not label:
		return
	
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)
	
	var original_color = label.modulate
	tween.parallel().tween_property(label, "modulate", Color.YELLOW, 0.15)
	tween.tween_property(label, "modulate", original_color, 0.15)
	
	#TODO: Play sound effect if you have one
	# $LevelUpSound.play()

# ==================== UTILITY FUNCTIONS ====================

func get_stats_summary() -> String:
	if not player or not player.stats:
		return "No stats available"
	
	var stats = player.stats
	return """
Level: %d
XP: %d / %d
Strength: %d
Endurance: %d
Intelligence: %d
Agility: %d
Max HP: %d
Damage: +%.1f
Crit: %.1f%%
""" % [
		stats.level,
		stats.xp,
		stats.get_xp_to_next_level(),
		stats.strength.ability_score,
		stats.endurance.ability_score,
		stats.intelligence.ability_score,
		stats.agility.ability_score,
		stats.get_max_hp(),
		stats.get_damage_modifier(),
		stats.get_crit_chance() * 100
	]

## Debug: Print current state
func debug_print_state() -> void:
	print("=== Level Up Panel State ===")
	print(get_stats_summary())
	print("Can level up: ", player.stats.can_level_up() if player and player.stats else "N/A")
	print("Panel visible: ", visible)
