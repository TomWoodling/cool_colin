# cool_colin.gd
# Script for the CharacterBody3D node "CoolColin"

extends CharacterBody3D

# Movement parameters
@export var walk_speed: float = 3.0 # Base speed when no sprint/run modifiers are active
@export var acceleration: float = 10.0
@export var deceleration: float = 5.0 # General deceleration when stopping (not sprint related)
@export var turn_speed: float = 10.0
@export var jump_velocity_value: float = 7.5
@export var gravity_value: float = 20.0
@export var jump_air_deceleration_multiplier: float = 0.1
@export var quick_turn_threshold: float = 120.0 # Degrees for "quick turn" animation
@export var turn_momentum_factor: float = 0.8 # How much speed is maintained during turns
#@export var sniff_slowdown_factor: float = 0.3 # Speed multiplier when sniffing
@export var excitement_speed_boost: float = 1.2 # Speed boost when "excited"
@export var terrain_adaptation_enabled: bool = true

var is_sniffing_while_moving: bool = false
var excitement_level: float = 0.0 # 0.0 to 1.0
var previous_movement_direction: Vector3 = Vector3.ZERO
# Member variable for AnimationTree expressions AND BlendSpace value
var current_horizontal_speed: float = 0.0

# Node references
@export_node_path("Node3D") var camera_gimbal_path
@export_node_path("Node3D") var model_path

@onready var camera_gimbal: Node3D = get_node_or_null(camera_gimbal_path)
@onready var model: Node3D = get_node_or_null(model_path)
@onready var animation_tree_node: AnimationTree = $AnimationStateController
@onready var sprint_handler: SprintHandler = $SprintHandler # Assign in editor or ensure child node is named "SprintHandler"

var _current_target_speed: float = 0.0 # Overall target speed for movement

# For POC Interaction System (to be moved to InteractionHandler later)
var overlapping_discoverables = []

func _ready():
	if GameManager: # Check if GameManager autoload exists
		GameManager.register_player(self)
	else:
		push_error("CoolColin: GameManager not found. Cannot register player.")
	if not camera_gimbal: push_warning("CoolColin: Camera Gimbal node not assigned.")
	if not model: push_warning("CoolColin: Model node not assigned.")
	if not animation_tree_node:
		push_error("CoolColin: CRITICAL - AnimationTree node 'AnimationStateController' not found.")
		set_physics_process(false); set_process_unhandled_input(false); return
	else:
		if not animation_tree_node.anim_player: push_warning("CoolColin: AnimTree '%s' - 'Anim Player' not set." % animation_tree_node.name)
		if not animation_tree_node.active: push_warning("CoolColin: AnimTree '%s' - not 'Active'." % animation_tree_node.name)
		if not animation_tree_node.advance_expression_base_node:
			push_error("CoolColin: CRITICAL - AnimTree '%s' - 'Advance Expression Base Node' not set. Expressions will fail." % animation_tree_node.name)

	if not sprint_handler:
		push_error("CoolColin: CRITICAL - SprintHandler node not found. Sprinting will not work.")
		# Optionally disable sprint input processing if handler is missing
	else:
		# Configure SprintHandler's base speed to match CoolColin's walk_speed
		# This makes walk_speed the single source of truth for the character's base movement.
		sprint_handler.sprint_system_base_speed = walk_speed
		# Other sprint parameters (max_speed, timings) are @export in SprintHandler.gd

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Connect to PlayerInputHandler signals
	var input_handler_node = $PlayerInput
	if input_handler_node:
		input_handler_node.sprint_initiated.connect(_on_sprint_initiated)
		input_handler_node.sprint_released.connect(_on_sprint_released)
		input_handler_node.jump_input_detected.connect(_on_jump_input_detected)
		input_handler_node.intent_sit_requested.connect(_on_intent_sit_requested)
		input_handler_node.intent_lie_down_requested.connect(_on_intent_lie_down_requested)
		input_handler_node.intent_bark_requested.connect(_on_intent_bark_requested)
		input_handler_node.intent_sniff_requested.connect(_on_intent_sniff_requested)
		input_handler_node.intent_dig_requested.connect(_on_intent_dig_requested)
		input_handler_node.intent_interact_requested.connect(_on_intent_interact_requested)
	else:
		push_warning("CoolColin: PlayerInputHandlerNode not found. Input signals will not be connected.")

# Enhanced movement calculation
func calculate_enhanced_movement_speed() -> float:
	var base_speed = _current_target_speed
	
	# Apply sniffing slowdown - need to fix animations first
	#if is_sniffing_while_moving:
	#	base_speed *= sniff_slowdown_factor
	
	# Apply excitement boost (could be triggered by finding treats, seeing other dogs, etc.)
	if excitement_level > 0.5:
		base_speed *= lerp(1.0, excitement_speed_boost, excitement_level)
	
	return base_speed
	
func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y -= gravity_value * delta

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement_direction: Vector3 = calculate_movement_direction(input_vector)
	var movement_input_is_active: bool = (movement_direction != Vector3.ZERO)

	# Determine target speed based on sprint state or walk speed
	if sprint_handler:
		# If Shift is held OR the sprint handler is in a tapering off phase, it dictates the speed.
		if sprint_handler.is_sprint_button_currently_held or \
		   sprint_handler.get_current_phase() == SprintHandler.SprintPhase.TAPERING_OFF:
			_current_target_speed = sprint_handler.get_sprint_target_speed(delta, movement_input_is_active)
		else: # Sprint button not held AND not tapering off from a sprint
			_current_target_speed = walk_speed if movement_input_is_active else 0.0
	else: # Failsafe if sprint_handler is missing
		_current_target_speed = walk_speed if movement_input_is_active else 0.0
	
	# _current_target_speed is now set. SprintHandler's max speed is self-contained.

	current_horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if animation_tree_node:
		animation_tree_node.set_blend_value("MovementState", current_horizontal_speed)

	var is_anim_blocking_movement: bool = false
	var is_currently_jumping_anim: bool = false
	
	if animation_tree_node:
		is_anim_blocking_movement = animation_tree_node.get_character_animation_state("is_any_action_blocking_movement")
		is_currently_jumping_anim = animation_tree_node.get_character_animation_state("is_jump_anim_playing")

	if not is_anim_blocking_movement:
		if movement_input_is_active: # Check if there's movement input
			velocity.x = lerp(velocity.x, movement_direction.x * _current_target_speed, acceleration * delta)
			velocity.z = lerp(velocity.z, movement_direction.z * _current_target_speed, acceleration * delta)
			if model:
				model.rotation.y = lerp_angle(model.rotation.y, atan2(movement_direction.x, movement_direction.z), turn_speed * delta)
		else: # No movement input, apply general deceleration
			velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
			velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
	else: # Animation IS blocking movement
		if is_currently_jumping_anim:
			# Apply specific air deceleration for jumps
			velocity.x = lerp(velocity.x, 0.0, deceleration * jump_air_deceleration_multiplier * delta)
			velocity.z = lerp(velocity.z, 0.0, deceleration * jump_air_deceleration_multiplier * delta)
		else:
			# Original strong deceleration for other blocking animations (sit, bark, etc.)
			velocity.x = lerp(velocity.x, 0.0, deceleration * delta * 2.0) # The "handbrake"
			velocity.z = lerp(velocity.z, 0.0, deceleration * delta * 2.0)

	move_and_slide()

func calculate_movement_direction(input_v: Vector2) -> Vector3:
	var move_dir := Vector3.ZERO
	if camera_gimbal:
		move_dir = (camera_gimbal.global_transform.basis.z * input_v.y + camera_gimbal.global_transform.basis.x * input_v.x).normalized()
	else:
		move_dir = Vector3(input_v.x, 0, input_v.y).normalized()
	return move_dir

func calculate_turn_speed_adjustment(movement_direction: Vector3, delta: float) -> float:
	if previous_movement_direction == Vector3.ZERO:
		previous_movement_direction = movement_direction
		return 1.0
	
	var angle_change = rad_to_deg(previous_movement_direction.angle_to(movement_direction))
	previous_movement_direction = movement_direction
	
	# Reduce speed during sharp turns (dogs need to slow down to change direction)
	if angle_change > quick_turn_threshold:
		return turn_momentum_factor
	
	return 1.0

# --- Signal Callbacks from PlayerInputHandler ---
func _on_sprint_initiated():
	if sprint_handler:
		sprint_handler.initiate_sprint_input()

func _on_sprint_released():
	if sprint_handler:
		sprint_handler.release_sprint_input()

func _on_jump_input_detected():
	var is_anim_blocking: bool = false # Default to not blocking if no anim tree
	if animation_tree_node:
		is_anim_blocking = animation_tree_node.get_character_animation_state("is_any_action_blocking_movement")
	
	if is_on_floor() and not is_anim_blocking:
		velocity.y = jump_velocity_value
		if animation_tree_node:
			animation_tree_node.trigger_character_intent("jump")
	# else: print("Jump blocked")


func _on_intent_sit_requested():
	var is_fully_sitting := false
	var is_fsm_ready := true
	if animation_tree_node:
		is_fully_sitting = animation_tree_node.get_character_animation_state("is_visual_anim_sitting_idle")
		is_fsm_ready = animation_tree_node.get_character_animation_state("is_fsm_ready")

	if is_fully_sitting:
		animation_tree_node.trigger_character_intent("stand_from_sit")
	elif is_fsm_ready and is_on_floor() and (current_horizontal_speed < 0.5): # Condition to allow sitting
		animation_tree_node.trigger_character_intent("sit")

func _on_intent_lie_down_requested():
	var is_fully_lying := false
	var is_fsm_ready := true
	if animation_tree_node:
		is_fully_lying = animation_tree_node.get_character_animation_state("is_visual_anim_lying_idle")
		is_fsm_ready = animation_tree_node.get_character_animation_state("is_fsm_ready")

	if is_fully_lying:
		animation_tree_node.trigger_character_intent("stand_from_lie")
	elif is_fsm_ready and is_on_floor() and (current_horizontal_speed < 0.5): # Condition to allow lying down
		animation_tree_node.trigger_character_intent("lie_down")

# --- POC Interaction Logic (To be moved to InteractionHandler) ---
func _on_intent_bark_requested():
	var is_fsm_ready := true
	if animation_tree_node: is_fsm_ready = animation_tree_node.get_character_animation_state("is_fsm_ready")
	
	if is_fsm_ready and is_on_floor():
		animation_tree_node.trigger_character_intent("bark") # Animation
		# Attempt POC interaction
		for discoverable_area in overlapping_discoverables:
			var discoverable_script = discoverable_area # Assuming script is on the Area3D node itself for Discoverable.tscn
			if discoverable_script and discoverable_script.has_method("attempt_interaction"):
				if discoverable_script.attempt_interaction(GameManager.InteractionType.BARK):
					break 

func _on_intent_sniff_requested():
	var is_fsm_ready := true
	if animation_tree_node: is_fsm_ready = animation_tree_node.get_character_animation_state("is_fsm_ready")

	if is_fsm_ready and is_on_floor():
		animation_tree_node.trigger_character_intent("sniff") # Animation
		# Attempt POC interaction
		for discoverable_area in overlapping_discoverables:
			var discoverable_script = discoverable_area
			if discoverable_script and discoverable_script.has_method("attempt_interaction"):
				if discoverable_script.attempt_interaction(GameManager.InteractionType.SNIFF):
					break

func _on_intent_dig_requested():
	var is_fsm_ready := true
	if animation_tree_node: is_fsm_ready = animation_tree_node.get_character_animation_state("is_fsm_ready")

	if is_fsm_ready and is_on_floor():
		animation_tree_node.trigger_character_intent("dig") # Animation
		# Attempt POC interaction
		for discoverable_area in overlapping_discoverables:
			var discoverable_script = discoverable_area
			if discoverable_script and discoverable_script.has_method("attempt_interaction"):
				if discoverable_script.attempt_interaction(GameManager.InteractionType.DIG):
					break

func _on_intent_interact_requested(): # "E" key for "Give Paw" currently
	var is_visually_sitting_idle := false
	if animation_tree_node:
		is_visually_sitting_idle = animation_tree_node.get_character_animation_state("is_visual_anim_sitting_idle")
	
	if is_visually_sitting_idle: # Condition for give paw
		animation_tree_node.trigger_character_intent("give_paw")
	else:
		print("CoolColin: Interact (E) - conditions for give_paw not met.")


# --- Methods for Discoverable Interaction (To be moved to InteractionHandler) ---
func add_overlapping_discoverable(discoverable_area_node):
	print("triggered add discoverable")
	if not discoverable_area_node in overlapping_discoverables:
		overlapping_discoverables.append(discoverable_area_node)
		#print("Added discoverable: ", discoverable_area_node.get_parent().name if discoverable_area_node.get_parent() else "N/A")


func remove_overlapping_discoverable(discoverable_area_node):
	if discoverable_area_node in overlapping_discoverables:
		overlapping_discoverables.erase(discoverable_area_node)
		# print("Removed discoverable: ", discoverable_area_node.get_parent().name if discoverable_area_node.get_parent() else "N/A")


# --- Public Methods for External Systems (e.g., GameManager) ---
func initiate_sit_externally():
	if animation_tree_node:
		if animation_tree_node.get_character_animation_state("is_visual_anim_sitting_idle"):
			animation_tree_node.trigger_character_intent("stand_from_sit")
		elif animation_tree_node.get_character_animation_state("is_fsm_ready") and \
			is_on_floor() and (current_horizontal_speed < 0.5):
			animation_tree_node.trigger_character_intent("sit")

func initiate_lie_externally():
	if animation_tree_node:
		if animation_tree_node.get_character_animation_state("is_visual_anim_lying_idle"):
			animation_tree_node.trigger_character_intent("stand_from_lie")
		elif animation_tree_node.get_character_animation_state("is_fsm_ready") and \
			 is_on_floor() and (current_horizontal_speed < 0.5):
			animation_tree_node.trigger_character_intent("lie_down")

func initiate_give_paw_externally(): # This will be needed for cutscenes / dialog etc
	if animation_tree_node and animation_tree_node.get_character_animation_state("is_visual_anim_sitting_idle"):
		animation_tree_node.trigger_character_intent("give_paw")

func get_current_sprint_stamina_percentage() -> float:
	if sprint_handler:
		return sprint_handler.get_stamina_percentage()
	return 0.0 # Return 0 if no sprint handler
