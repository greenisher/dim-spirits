extends Control
class_name SpellHotbar


@export var magic_system: MagicSystem
@export var player_stats: CharacterStats
@export var slot_size: Vector2 = Vector2(64, 64)
@export var slot_spacing: float = 8.0
@export var show_keybinds: bool = true
@export var show_mana_cost: bool = true

var spell_slots: Array[SpellSlot] = []

func _ready() -> void:
	if not magic_system:
		push_error("SpellHotbar: No MagicSystem assigned!")
		return
	
	if not player_stats:
		push_error("SpellHotbar: No CharacterStats assigned!")
		return
	
	# Connect to magic system signals
	magic_system.equipped_spell_changed.connect(_on_equipped_spell_changed)
	magic_system.spell_cast.connect(_on_spell_cast)
	magic_system.spell_failed.connect(_on_spell_failed)
	
	# Connect to stats signals
	if player_stats:
		player_stats.mana_changed.connect(_on_mana_changed)
	
	# Initialize spell slots
	_create_spell_slots()
	
	# Update all slots with current spells
	for i in range(magic_system.max_equipped_spells):
		var spell = magic_system.get_equipped_spell(i)
		_update_slot(i, spell)

func _process(_delta: float) -> void:
	# Update cooldowns every frame
	_update_cooldowns()
	
	# Update mana availability
	_update_mana_states()

func _create_spell_slots() -> void:
	"""Create spell slot UI elements"""
	var slot_count = magic_system.max_equipped_spells
	
	for i in range(slot_count):
		var slot = SpellSlot.new()
		add_child(slot)
		
		# Configure slot
		slot.custom_minimum_size = slot_size
		slot.slot_index = i
		slot.keybind_number = i + 1  # 1, 2, 3, 4
		slot.show_keybind = show_keybinds
		slot.show_mana_cost = show_mana_cost
		
		# Position slot horizontally
		slot.position = Vector2(i * (slot_size.x + slot_spacing), 0)
		
		spell_slots.append(slot)
		
		# Connect slot signals
		slot.slot_clicked.connect(_on_slot_clicked)

func _update_slot(slot_index: int, spell: Spell) -> void:
	"""Update a slot with spell data"""
	if slot_index >= spell_slots.size():
		return
	
	var slot = spell_slots[slot_index]
	slot.set_spell(spell, player_stats)

func _update_cooldowns() -> void:
	"""Update cooldown displays for all slots"""
	for i in range(spell_slots.size()):
		var slot = spell_slots[i]
		var spell = magic_system.get_equipped_spell(i)
		
		if spell and magic_system.is_on_cooldown(spell):
			var remaining = magic_system.get_cooldown_remaining(spell)
			var percentage = (remaining / spell.cooldown) * 100.0
			slot.set_cooldown(remaining, percentage)
		else:
			slot.clear_cooldown()

func _update_mana_states() -> void:
	"""Update which slots are usable based on mana"""
	if not player_stats:
		return
	
	var current_mana = player_stats.current_mana
	
	for i in range(spell_slots.size()):
		var slot = spell_slots[i]
		var spell = magic_system.get_equipped_spell(i)
		
		if spell:
			var can_afford = current_mana >= spell.mana_cost
			slot.set_affordable(can_afford)

func _on_equipped_spell_changed(slot_index: int, spell: Spell) -> void:
	"""Called when a spell is equipped/unequipped"""
	_update_slot(slot_index, spell)

func _on_spell_cast(spell: Spell) -> void:
	"""Called when a spell is cast"""
	# Visual feedback could go here (flash, animation, etc.)
	pass

func _on_spell_failed(reason: String) -> void:
	"""Called when spell cast fails"""
	# Could show error message or visual feedback
	print("Spell failed: ", reason)

func _on_mana_changed(_current: float, _maximum: float) -> void:
	"""Called when player mana changes"""
	_update_mana_states()

func _on_slot_clicked(slot_index: int) -> void:
	"""Called when player clicks a spell slot"""
	# Cast the spell in that slot
	var spell = magic_system.get_equipped_spell(slot_index)
	if spell:
		magic_system.current_spell_index = slot_index
		magic_system.cast_current_spell()

func highlight_slot(slot_index: int, highlight: bool) -> void:
	"""Highlight a specific slot (for current selection)"""
	if slot_index >= 0 and slot_index < spell_slots.size():
		spell_slots[slot_index].set_highlighted(highlight)

func set_current_spell_index(index: int) -> void:
	"""Update visual indicator for current spell"""
	# Clear all highlights
	for i in range(spell_slots.size()):
		spell_slots[i].set_highlighted(false)
	
	# Highlight current
	if index >= 0 and index < spell_slots.size():
		spell_slots[index].set_highlighted(true)
