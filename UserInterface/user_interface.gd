extends Control

@onready var health_bar: TextureProgressBar = %HealthBar
@onready var mana_bar: TextureProgressBar = %ManaBar  # NEW
@onready var xp_bar: TextureProgressBar = %XPBar
@onready var health_label: Label = %HealthLabel
@onready var mana_label: Label = %ManaLabel  # NEW (optional)

@onready var spell_hotbar: SpellHotbar = %SpellHotbar  # NEW
@onready var inventory: Control = $Inventory

var player: Player
var cached_stats: Dictionary = {}

func _ready() -> void:
	print("=== UserInterface _ready() CALLED ===")
	player = get_parent() as Player
	
	if not player:
		print("ERROR: Parent is not a Player!")
		return
	
	print("Player found: ", player.name)
	
	await get_tree().process_frame
	
	# Setup Health Bar
	if player.health_component:
		print("Health component found!")
		player.health_component.health_changed.connect(_on_health_changed)
		var current = player.health_component.current_health
		var maximum = player.health_component.max_health
		print("Initial health: ", current, "/", maximum)
		
		if health_bar:
			health_bar.max_value = maximum
			health_bar.value = current
			print("Health bar updated: ", health_bar.value, "/", health_bar.max_value)
		else:
			print("ERROR: health_bar is null!")
		
		if health_label:
			health_label.text = "%d/%d" % [int(current), int(maximum)]
			print("Health label text: ", health_label.text)
		else:
			print("ERROR: health_label is null!")
	else:
		print("ERROR: Health component not found!")
	
	# Setup Mana Bar (NEW)
	if player.stats:
		print("Stats found!")
		player.stats.xp_changed.connect(_on_xp_changed)
		player.stats.level_changed.connect(_on_level_changed)
		player.stats.stat_increased.connect(_on_stat_increased)
		player.stats.mana_changed.connect(_on_mana_changed)  # NEW
		
		# Initialize mana bar
		var current_mana = player.stats.current_mana
		var max_mana = player.stats.get_max_mana()
		print("Initial mana: ", current_mana, "/", max_mana)
		
		if mana_bar:
			mana_bar.max_value = max_mana
			mana_bar.value = current_mana
			print("Mana bar updated: ", mana_bar.value, "/", mana_bar.max_value)
		else:
			print("WARNING: mana_bar not found in scene! Add %ManaBar node.")
		
		if mana_label:
			mana_label.text = "%d/%d" % [int(current_mana), int(max_mana)]
			print("Mana label text: ", mana_label.text)
		else:
			print("INFO: mana_label not found (optional)")
		
		update_stats_display()
		print("Stats connected!")
		if spell_hotbar and player.has_node("MagicSystem"):
			var magic_system = player.get_node("MagicSystem")
			spell_hotbar.magic_system = magic_system
			spell_hotbar.player_stats = player.stats
			print("Spell hotbar connected!")
		
		# Connect to magic system to update current spell highlight
			magic_system.spell_cast.connect(_on_spell_cast)
		else:
			if not spell_hotbar:
				print("WARNING: SpellHotbar not found in UI!")
			if not player.has_node("MagicSystem"):
				print("WARNING: MagicSystem not found on player!")

func _process(_delta: float) -> void:
	# Update current spell highlight
	if spell_hotbar and player and player.has_node("MagicSystem"):
		var magic_system = player.get_node("MagicSystem")
		spell_hotbar.set_current_spell_index(magic_system.current_spell_index)

func _on_xp_changed(current_xp: int, xp_to_next_level: int) -> void:
	var tween = create_tween()
	tween.tween_property(xp_bar, "value", current_xp, 0.2)
	update_stats_display()

func _on_level_changed(new_level: int) -> void:
	print("Level changed to: ", new_level)
	update_stats_display()
	
	# Recalculate max mana when level changes
	if player and player.stats:
		var max_mana = player.stats.get_max_mana()
		if mana_bar:
			mana_bar.max_value = max_mana

func _on_stat_increased(stat_name: String) -> void:
	print("Stat increased: ", stat_name)
	update_stats_display()
	
	# Recalculate max mana if intelligence increased
	if stat_name == "Intelligence" and player and player.stats:
		var current_mana = player.stats.current_mana
		var max_mana = player.stats.get_max_mana()
		if mana_bar:
			mana_bar.max_value = max_mana
			mana_bar.value = current_mana
		if mana_label:
			mana_label.text = "%d/%d" % [int(current_mana), int(max_mana)]

func _on_health_changed(current: float, maximum: float) -> void:
	print("Health changed signal received: ", current, "/", maximum)
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		var tween = create_tween()
		tween.tween_property(health_bar, "value", current, 0.2)
	if health_label:
		health_label.text = "%d/%d" % [int(current), int(maximum)]

func _on_mana_changed(current: float, maximum: float) -> void:
	"""NEW: Called when mana changes (cast spell, regeneration, etc.)"""
	if mana_bar:
		mana_bar.max_value = maximum
		mana_bar.value = current
		var tween = create_tween()
		tween.tween_property(mana_bar, "value", current, 0.2)
	if mana_label:
		mana_label.text = "%d/%d" % [int(current), int(maximum)]
func _on_spell_cast(spell: Spell) -> void:
	"""Called when a spell is cast - for visual feedback"""
	print("Spell cast: ", spell.spell_name)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('open_menu'):
		if inventory and inventory.visible:
			close_menu()
		else:
			open_menu()

func update_stats_display() -> void:
	if not player or not player.stats:
		return
	
	cached_stats = player.stats.get_all_stats()
	
	xp_bar.max_value = cached_stats.xp_to_next_level
	xp_bar.value = cached_stats.xp
	
	# Update mana display when stats refresh
	if mana_bar and cached_stats.has("current_mana") and cached_stats.has("max_mana"):
		mana_bar.max_value = cached_stats.max_mana
		mana_bar.value = cached_stats.current_mana
	if mana_label and cached_stats.has("current_mana") and cached_stats.has("max_mana"):
		mana_label.text = "%d/%d" % [int(cached_stats.current_mana), int(cached_stats.max_mana)]
	
	if inventory and inventory.has_method("update_stats_from_dict"):
		inventory.update_stats_from_dict(cached_stats)
	elif inventory and inventory.has_method("update_stats"):
		inventory.update_stats()

func get_current_stats() -> Dictionary:
	"""Returns the cached stats dictionary for other components to use."""
	return cached_stats

func update_health() -> void:
	if player and player.health_component:
		var current = player.health_component.current_health
		var maximum = player.health_component.max_health
		if health_bar:
			health_bar.max_value = maximum
			health_bar.value = current
		if health_label:
			health_label.text = "%d/%d" % [int(current), int(maximum)]

func update_mana() -> void:
	"""NEW: Force update mana display"""
	if player and player.stats:
		var current = player.stats.current_mana
		var maximum = player.stats.get_max_mana()
		if mana_bar:
			mana_bar.max_value = maximum
			mana_bar.value = current
		if mana_label:
			mana_label.text = "%d/%d" % [int(current), int(maximum)]
	
func open_menu() -> void:
	if inventory:
		inventory.visible = true
		inventory.open_inventory()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		if inventory.has_method("update_gear_stats_from_dict"):
			inventory.update_gear_stats_from_dict(cached_stats)
		elif inventory.has_method("update_gear_stats"):
			inventory.update_gear_stats()
	
func close_menu() -> void:
	if inventory:
		inventory.visible = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
