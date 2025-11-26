extends Control
class_name SpellSlot

## Individual spell slot in the hotbar - shows icon, cooldown, mana cost, keybind

signal slot_clicked(slot_index: int)

var slot_index: int = 0
var keybind_number: int = 1
var show_keybind: bool = true
var show_mana_cost: bool = true

var current_spell: Spell = null
var player_stats: CharacterStats = null

# UI elements (created programmatically)
var background: Panel
var icon: TextureRect
var cooldown_overlay: ColorRect
var cooldown_label: Label
var mana_label: Label
var keybind_label: Label
var highlight_border: Panel
var unusable_overlay: ColorRect

func _init() -> void:
	custom_minimum_size = Vector2(64, 64)
	
	# Create UI elements
	_create_ui_elements()

func _create_ui_elements() -> void:
	"""Create all UI elements for the spell slot"""
	
	# Background panel
	background = Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Create theme for background
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style_bg.corner_radius_top_left = 4
	style_bg.corner_radius_top_right = 4
	style_bg.corner_radius_bottom_left = 4
	style_bg.corner_radius_bottom_right = 4
	background.add_theme_stylebox_override("panel", style_bg)
	
	# Icon
	icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	
	# Cooldown overlay (dark semi-transparent)
	cooldown_overlay = ColorRect.new()
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.color = Color(0, 0, 0, 0.7)
	cooldown_overlay.visible = false
	add_child(cooldown_overlay)
	
	# Cooldown timer label
	cooldown_label = Label.new()
	cooldown_label.set_anchors_preset(Control.PRESET_CENTER)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 20)
	cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	cooldown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cooldown_label.add_theme_constant_override("outline_size", 2)
	cooldown_label.visible = false
	add_child(cooldown_label)
	
	# Mana cost label (bottom right)
	mana_label = Label.new()
	mana_label.set_anchor(SIDE_RIGHT, 1.0)
	mana_label.set_anchor(SIDE_BOTTOM, 1.0)
	mana_label.offset_left = -40
	mana_label.offset_top = -20
	mana_label.offset_right = -4
	mana_label.offset_bottom = -4
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mana_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	mana_label.add_theme_font_size_override("font_size", 14)
	mana_label.add_theme_color_override("font_color", Color.CYAN)
	mana_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mana_label.add_theme_constant_override("outline_size", 2)
	add_child(mana_label)
	
	# Keybind label (bottom left)
	keybind_label = Label.new()
	keybind_label.set_anchor(SIDE_BOTTOM, 1.0)
	keybind_label.offset_left = 4
	keybind_label.offset_top = -20
	keybind_label.offset_right = 24
	keybind_label.offset_bottom = -4
	keybind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	keybind_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	keybind_label.add_theme_font_size_override("font_size", 14)
	keybind_label.add_theme_color_override("font_color", Color.WHITE)
	keybind_label.add_theme_color_override("font_outline_color", Color.BLACK)
	keybind_label.add_theme_constant_override("outline_size", 2)
	add_child(keybind_label)
	
	# Unusable overlay (when not enough mana)
	unusable_overlay = ColorRect.new()
	unusable_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	unusable_overlay.color = Color(0, 0, 0, 0.5)
	unusable_overlay.visible = false
	add_child(unusable_overlay)
	
	# Highlight border (when selected)
	highlight_border = Panel.new()
	highlight_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_highlight = StyleBoxFlat.new()
	style_highlight.bg_color = Color(0, 0, 0, 0)  # Transparent background
	style_highlight.border_width_left = 3
	style_highlight.border_width_right = 3
	style_highlight.border_width_top = 3
	style_highlight.border_width_bottom = 3
	style_highlight.border_color = Color(1, 1, 0, 1)  # Yellow border
	style_highlight.corner_radius_top_left = 4
	style_highlight.corner_radius_top_right = 4
	style_highlight.corner_radius_bottom_left = 4
	style_highlight.corner_radius_bottom_right = 4
	highlight_border.add_theme_stylebox_override("panel", style_highlight)
	highlight_border.visible = false
	add_child(highlight_border)

func _ready() -> void:
	# Make clickable
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Update keybind display
	if show_keybind:
		keybind_label.text = str(keybind_number)
	else:
		keybind_label.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(slot_index)
			accept_event()

func set_spell(spell: Spell, stats: CharacterStats) -> void:
	"""Set the spell displayed in this slot"""
	current_spell = spell
	player_stats = stats
	
	if spell:
		# Show icon
		if spell.icon:
			icon.texture = spell.icon
			icon.visible = true
		else:
			icon.visible = false
		
		# Show mana cost
		if show_mana_cost:
			mana_label.text = str(int(spell.mana_cost))
			mana_label.visible = true
		else:
			mana_label.visible = false
		
		# Make visible
		background.visible = true
	else:
		# Empty slot
		icon.visible = false
		mana_label.visible = false
		background.modulate = Color(0.5, 0.5, 0.5, 0.5)  # Dim empty slots

func set_cooldown(remaining_time: float, percentage: float) -> void:
	"""Show cooldown overlay"""
	if remaining_time > 0:
		cooldown_overlay.visible = true
		cooldown_label.visible = true
		cooldown_label.text = "%.1f" % remaining_time
		
		# Animate cooldown overlay (shrink from bottom to top)
		var height = size.y * (percentage / 100.0)
		cooldown_overlay.size.y = height
	else:
		clear_cooldown()

func clear_cooldown() -> void:
	"""Clear cooldown display"""
	cooldown_overlay.visible = false
	cooldown_label.visible = false

func set_affordable(can_afford: bool) -> void:
	"""Show/hide unusable overlay based on mana"""
	unusable_overlay.visible = not can_afford
	
	# Also desaturate icon
	if not can_afford:
		icon.modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		icon.modulate = Color(1, 1, 1, 1)

func set_highlighted(highlighted: bool) -> void:
	"""Show/hide highlight border"""
	highlight_border.visible = highlighted

func flash_error() -> void:
	"""Flash red when cast fails"""
	var tween = create_tween()
	tween.tween_property(background, "modulate", Color.RED, 0.1)
	tween.tween_property(background, "modulate", Color.WHITE, 0.1)
