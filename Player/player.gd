extends CharacterBody3D
class_name Player

const SPEED = 5.0
const JUMP_VELOCITY = 10.0  # Increased from 6.0 for higher jumps
const DECAY := 8.0

# Jump feel improvements
const JUMP_HORIZONTAL_BOOST = 2  # Multiplier for horizontal speed during jump
const GRAVITY_SCALE = 1.0  # Makes gravity stronger (less floaty)
const FALL_GRAVITY_MULTIPLIER = 1.5  # Fall faster than we rise
const MAX_FALL_SPEED = 30.0  # Terminal velocity

# Advanced jump mechanics
const COYOTE_TIME = 0.50  # Grace period after leaving ground
const JUMP_BUFFER_TIME = 0.20  # Can press jump slightly before landing
const JUMP_CUT_MULTIPLIER = 0.5  # How much to cut jump when releasing early

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * GRAVITY_SCALE

var _attack_direction := Vector3.ZERO

# Camera variables
var _mouse_delta := Vector2.ZERO

# Jump state tracking
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_jumping: bool = false
var jump_released: bool = true

# Weapon management
var current_weapon: Node3D = null

@export var mouse_sensitivity: float = 0.00075
@export var min_boundary: float = -60
@export var max_boundary: float = 10
@export var animation_decay: float = 15.0
@export var attack_move_speed: float = 3.0
@export_category('RPG Stats')
@export var stats: CharacterStats

@onready var horizontal_pivot: Node3D = $HorizontalPivot
@onready var vertical_pivot: Node3D = $HorizontalPivot/VerticalPivot
@onready var rig_pivot: Node3D = $RigPivot
@onready var rig: Node3D = $RigPivot/Brid
@onready var attack_cast: RayCast3D = %AttackCast
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var area_attack: ShapeCast3D = $RigPivot/AreaAttack
@onready var user_interface: Control = $UserInterface
@onready var magic_system: MagicSystem = $MagicSystem
@onready var cast_origin: Node3D = $RigPivot/CastOrigin
@onready var weapon_slot: Node3D = %WeaponSlot

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_component.body = self
	health_component.initialize(stats.get_max_hp())
	
	# Connect signals
	health_component.damage_taken.connect(_on_damage_taken)
	
	# Setup magic system
	if magic_system:
		magic_system.stats = stats
		magic_system.cast_origin = cast_origin
		magic_system.spell_cast.connect(_on_spell_cast)
		magic_system.spell_failed.connect(_on_spell_failed)
		magic_system.target_locked.connect(_on_target_locked)
		magic_system.target_unlocked.connect(_on_target_unlocked)
	
	# Initialize mana
	if stats:
		stats.current_mana = stats.get_max_mana()
	
	# DEBUG: Check initial scales
	print("=== INITIAL SCALE CHECK ===")
	print("Player scale: ", scale)
	print("RigPivot scale: ", rig_pivot.scale)
	print("Rig scale: ", rig.scale)
	print("HorizontalPivot scale: ", horizontal_pivot.scale)
	print("VerticalPivot scale: ", vertical_pivot.scale)
	print("==========================")

func _input(event: InputEvent):
	# Only process mouse motion when in gameplay mode (mouse captured)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_mouse_delta = event.relative
	
	# Toggle mouse mode with ESC
	if event.is_action_pressed('ui_cancel'):
		toggle_ui_mode(true)

func toggle_ui_mode(show_ui: bool):
	"""Toggle between gameplay mode (mouse captured) and UI mode (mouse visible)"""
	if show_ui:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("UI Mode: Mouse visible for inventory/menus")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("Gameplay Mode: Mouse captured for camera control")

func is_in_gameplay_mode() -> bool:
	"""Returns true if player is in gameplay mode (not in menus/inventory)"""
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# EMERGENCY FIX: Check and fix zero scales every frame
	if rig_pivot.scale.x == 0 or rig_pivot.scale.y == 0 or rig_pivot.scale.z == 0:
		push_warning("⚠️ RigPivot had zero scale! Auto-fixing... Check your animations!")
		rig_pivot.scale = Vector3.ONE
	
	if rig.scale.x == 0 or rig.scale.y == 0 or rig.scale.z == 0:
		push_warning("⚠️ Rig had zero scale! Auto-fixing... Check your animations!")
		rig.scale = Vector3.ONE
	
	if horizontal_pivot.scale.x == 0 or horizontal_pivot.scale.y == 0 or horizontal_pivot.scale.z == 0:
		push_warning("⚠️ HorizontalPivot had zero scale! Auto-fixing... Check your animations!")
		horizontal_pivot.scale = Vector3.ONE
	
	# Handle camera rotation (only in gameplay mode)
	if is_in_gameplay_mode():
		handle_camera_rotation(delta)
	
	# Handle improved jump mechanics
	handle_jump_mechanics(delta)
	
	player_movement(delta)
	handle_slashing_physics_frame(delta)
	handle_overhead_physics_frame()
	handle_rolling_physics_frame(delta)
	move_and_slide()
	
	# Apply gravity with improvements
	apply_improved_gravity(delta)

func _process(delta: float) -> void:
	# Regenerate mana
	if stats:
		stats.regenerate_mana(delta)

func handle_camera_rotation(_delta: float):
	if _mouse_delta != Vector2.ZERO:
		# Apply mouse rotation
		horizontal_pivot.rotate_y(-_mouse_delta.x * mouse_sensitivity)
		vertical_pivot.rotate_x(-_mouse_delta.y * mouse_sensitivity)
		
		# Clamp vertical rotation
		vertical_pivot.rotation.x = clampf(
			vertical_pivot.rotation.x, 
			deg_to_rad(min_boundary),
			deg_to_rad(max_boundary)
		)
		
		# Debug every 60 frames
		if Engine.get_process_frames() % 60 == 0:
			print("Mouse delta: ", _mouse_delta, " | Camera Y: ", horizontal_pivot.rotation_degrees.y, " | Camera X: ", vertical_pivot.rotation_degrees.x)
		
		# Reset mouse delta
		_mouse_delta = Vector2.ZERO

# ==================== IMPROVED JUMP MECHANICS ====================

func handle_jump_mechanics(delta: float) -> void:
	"""Handles coyote time, jump buffering, and jump input detection"""
	var was_on_floor = is_on_floor()
	
	# Update coyote timer (grace period after leaving ground)
	if was_on_floor:
		coyote_timer = COYOTE_TIME
		is_jumping = false
	else:
		coyote_timer -= delta
	
	# Update jump buffer timer (can press jump before landing)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
		jump_released = false
	else:
		jump_buffer_timer -= delta
	
	# Track if jump button was released (for variable jump height)
	if Input.is_action_just_released("jump"):
		jump_released = true
	
	# Can we jump? (either on ground, or within coyote time)
	var can_jump = coyote_timer > 0.0 and not is_jumping
	
	# Should we jump? (jump buffer active and we can jump)
	if jump_buffer_timer > 0.0 and can_jump and is_in_gameplay_mode():
		perform_jump()
		jump_buffer_timer = 0.0  # Consume the buffer
		coyote_timer = 0.0  # Consume coyote time
	
	# Variable jump height - cut jump short if button released early
	if jump_released and velocity.y > 0 and is_jumping:
		velocity.y *= JUMP_CUT_MULTIPLIER
		is_jumping = false  # Stop tracking this jump

func perform_jump() -> void:
	"""Executes the jump with horizontal boost"""
	velocity.y = JUMP_VELOCITY
	is_jumping = true
	jump_released = false
	
	# Add horizontal momentum boost in movement direction
	var movement_direction = get_movement_direction()
	if not movement_direction.is_zero_approx():
		# Boost horizontal velocity during jump
		velocity.x += movement_direction.x * SPEED * (JUMP_HORIZONTAL_BOOST - 1.0)
		velocity.z += movement_direction.z * SPEED * (JUMP_HORIZONTAL_BOOST - 1.0)
	
	# Play jump animation
	jump()
	
	print("JUMP! Velocity: ", velocity, " Boost: ", JUMP_HORIZONTAL_BOOST)

func apply_improved_gravity(delta: float) -> void:
	"""Apply gravity with separate fall speed and terminal velocity"""
	if not is_on_floor():
		var gravity_force = gravity
		
		# Fall faster than we rise (more natural feel)
		if velocity.y < 0:
			gravity_force *= FALL_GRAVITY_MULTIPLIER
		
		velocity.y -= gravity_force * delta
		
		# Clamp to terminal velocity
		velocity.y = maxf(velocity.y, -MAX_FALL_SPEED)

# ==================== MOVEMENT ====================

func player_movement(delta):
	if not rig.is_idle() and not rig.is_dashing():
		return

	# Only handle gameplay input when in gameplay mode
	if is_in_gameplay_mode():
		if rig.is_idle():
			# Melee attacks
			if Input.is_action_just_pressed("light_attack"):
				light_attack()
			if Input.is_action_just_pressed("heavy_attack"):
				heavy_attack()
			if Input.is_action_just_pressed("roll"):
				roll()
			
			# Magic system inputs
			if Input.is_action_just_pressed("spell_attack"):
				cast_spell()
			
			# Cycle spells (Mouse wheel or number keys)
			if Input.is_action_just_pressed("next_spell"):
				magic_system.cycle_spell(1)
			if Input.is_action_just_pressed("previous_spell"):
				magic_system.cycle_spell(-1)
			
			# Toggle lock-on (Tab key)
			if Input.is_action_just_pressed("toggle_lock_on"):
				magic_system.toggle_lock_on()
			
			# Quick cast spells from slots (1-4 keys)
			if Input.is_action_just_pressed("spell_slot_1"):
				cast_spell_from_slot(0)
			if Input.is_action_just_pressed("spell_slot_2"):
				cast_spell_from_slot(1)
			if Input.is_action_just_pressed("spell_slot_3"):
				cast_spell_from_slot(2)
			if Input.is_action_just_pressed("spell_slot_4"):
				cast_spell_from_slot(3)
	
	var direction := get_movement_direction()
	rig.update_animation_tree(direction)
	
	# Better air control - allow some movement adjustment while airborne
	var target_speed = SPEED
	if not is_on_floor():
		target_speed *= 0.8  # Slightly reduced air control
	
	velocity.x = exponential_decay(
		velocity.x, 
		direction.x * target_speed,
		DECAY,
		delta)
	
	velocity.z = exponential_decay(
		velocity.z, 
		direction.z * target_speed,
		DECAY,
		delta)
	
	if direction:
		look_toward_direction(direction, delta)

func _on_damage_taken(amount: float, is_critical: bool) -> void:
	if is_critical:
		print("Critical hit taken!")

func get_movement_direction() -> Vector3:
	var input_dir := Input.get_vector('move_left', 'move_right', 'move_forward', 'move_backward')
	var input_vector := Vector3(input_dir.x, 0, input_dir.y).normalized()
	var direction := horizontal_pivot.global_transform.basis * input_vector
	return direction
	
func look_toward_direction(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	
	var pivot_scale = rig_pivot.scale
	if pivot_scale.x == 0 or pivot_scale.y == 0 or pivot_scale.z == 0:
		push_error("RigPivot has zero scale, cannot look toward direction")
		return
	
	var target_pos = rig_pivot.global_position + direction
	
	if target_pos.distance_squared_to(rig_pivot.global_position) < 0.0001:
		return
	
	var target_transform := rig_pivot.global_transform.looking_at(
		target_pos, Vector3.UP, true
	) 
	
	var t = 1.0 - exp(-animation_decay * delta)
	rig_pivot.global_transform = rig_pivot.global_transform.interpolate_with(
		target_transform, t
	)

func roll() -> void:
	rig.travel('Roll')
	_attack_direction = get_movement_direction()
	
	if _attack_direction.is_zero_approx():
		if rig.scale.x != 0 and rig.scale.y != 0 and rig.scale.z != 0:
			_attack_direction = rig.global_basis * Vector3(0, 0, 1)
		else:
			_attack_direction = -rig_pivot.global_transform.basis.z
	
	if _attack_direction.is_zero_approx():
		_attack_direction = Vector3(0, 0, 1)
	
	attack_cast.reset_damage_tracking()

func light_attack() -> void:
	rig.travel('Light_Attack')
	_attack_direction = get_movement_direction()
	
	if _attack_direction.is_zero_approx():
		if rig.scale.x != 0 and rig.scale.y != 0 and rig.scale.z != 0:
			_attack_direction = rig.global_basis * Vector3(0, 0, 1)
		else:
			_attack_direction = -rig_pivot.global_transform.basis.z
	
	if _attack_direction.is_zero_approx():
		_attack_direction = Vector3(0, 0, 1)
	
	attack_cast.reset_damage_tracking()
	
func heavy_attack() -> void:
	rig.travel('Heavy_Attack')
	_attack_direction = get_movement_direction()
	
	if _attack_direction.is_zero_approx():
		if rig.scale.x != 0 and rig.scale.y != 0 and rig.scale.z != 0:
			_attack_direction = rig.global_basis * Vector3(0, 0, 1)
		else:
			_attack_direction = -rig_pivot.global_transform.basis.z
	
	if _attack_direction.is_zero_approx():
		_attack_direction = Vector3(0, 0, 1)
	
	attack_cast.reset_damage_tracking()
	
func jump() -> void:
	rig.travel('Jump')

# ==================== WEAPON MANAGEMENT ====================

func equip_weapon(weapon_scene_path: String) -> void:
	"""Load and equip a weapon from a packed scene path"""
	# Unequip current weapon first
	unequip_weapon()
	
	# Load the weapon scene
	var weapon_scene = load(weapon_scene_path)
	if not weapon_scene:
		push_error("Failed to load weapon scene: " + weapon_scene_path)
		return
	
	# Instantiate the weapon
	current_weapon = weapon_scene.instantiate()
	if not current_weapon:
		push_error("Failed to instantiate weapon from scene: " + weapon_scene_path)
		return
	
	# Add to weapon slot
	if weapon_slot:
		weapon_slot.add_child(current_weapon)
		print("✅ Weapon equipped: ", weapon_scene_path)
	else:
		push_error("WeaponSlot node not found!")
		current_weapon.queue_free()
		current_weapon = null

func unequip_weapon() -> void:
	"""Remove currently equipped weapon"""
	if current_weapon and is_instance_valid(current_weapon):
		current_weapon.queue_free()
		current_weapon = null
		print("Weapon unequipped")

func get_equipped_weapon() -> Node3D:
	"""Returns the currently equipped weapon, or null if none"""
	return current_weapon

# ==================== MAGIC SYSTEM ====================

func cast_spell() -> void:
	"""Cast currently selected spell"""
	if not magic_system:
		return
	
	# Play spell animation
	rig.travel('Spell_Attack')
	_attack_direction = get_movement_direction()
	
	if _attack_direction.is_zero_approx():
		if rig.scale.x != 0 and rig.scale.y != 0 and rig.scale.z != 0:
			_attack_direction = rig.global_basis * Vector3(0, 0, 1)
		else:
			_attack_direction = -rig_pivot.global_transform.basis.z
	
	if _attack_direction.is_zero_approx():
		_attack_direction = Vector3(0, 0, 1)
	
	# Actually cast the spell
	magic_system.cast_current_spell()

func cast_spell_from_slot(slot: int) -> void:
	"""Cast spell from specific slot"""
	if not magic_system:
		return
	
	var spell = magic_system.get_equipped_spell(slot)
	if spell:
		magic_system.current_spell_index = slot
		cast_spell()

func _on_spell_cast(spell: Spell) -> void:
	"""Called when spell is successfully cast"""
	print("Cast %s! Mana: %.0f/%.0f" % [spell.spell_name, stats.current_mana, stats.get_max_mana()])

func _on_spell_failed(reason: String) -> void:
	"""Called when spell cast fails"""
	print("Spell failed: %s" % reason)
	# TODO: Show UI feedback

func _on_target_locked(target: Node3D) -> void:
	"""Called when target is locked"""
	print("Locked onto: %s" % target.name)
	# TODO: Show lock-on UI indicator

func _on_target_unlocked() -> void:
	"""Called when target is unlocked"""
	print("Target unlocked")
	# TODO: Hide lock-on UI indicator

# ==================== ORIGINAL FUNCTIONS ====================

func handle_slashing_physics_frame(delta: float) -> void:
	if not rig.is_slashing():
		return
	velocity.x = _attack_direction.x * attack_move_speed
	velocity.z = _attack_direction.z * attack_move_speed
	look_toward_direction(_attack_direction, delta)
	attack_cast.deal_damage(10.0 + stats.get_damage_modifier(), stats.get_crit_chance())

func handle_rolling_physics_frame(delta: float) -> void:
	if not rig.is_rolling():
		return
	velocity.x = _attack_direction.x * attack_move_speed
	velocity.z = _attack_direction.z * attack_move_speed
	look_toward_direction(_attack_direction, delta)

func handle_overhead_physics_frame() -> void:
	if not rig.is_overhead():
		return
	velocity.x = 0.0
	velocity.z = 0.0

func _on_health_component_defeat() -> void:
	rig.travel('Defeat')
	VfxManager.spawn_death_text(Color.RED, rig_pivot.global_position)
	collision_shape_3d.disabled = true
	set_physics_process(false)

func _on_rig_heavy_attack() -> void:
	area_attack.deal_damage(15.0 + stats.get_damage_modifier(), stats.get_crit_chance()) 

func exponential_decay(a: float, b: float, decay: float, delta: float) -> float:
	return b + (a - b) * exp(-decay * delta)
