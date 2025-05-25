# animation_state_controller.gd
extends AnimationTree

@onready var main_sm_playback: AnimationNodeStateMachinePlayback = get("parameters/playback")
@onready var character_body: CharacterBody3D = get_parent() as CharacterBody3D

enum FsmState { READY, PROCESSING_SIT_CYCLE, PROCESSING_LIE_CYCLE, PROCESSING_GENERAL_ACTION }
var current_fsm_state: FsmState = FsmState.READY

enum ActionType { NONE = 0, BARK = 1, SNIFF = 2, DIG = 3 }
var _current_action_choice: ActionType = ActionType.NONE

var _wants_to_sit: bool = false
var _wants_to_stand_from_sit: bool = false
var _wants_to_lie: bool = false
var _wants_to_stand_from_lie: bool = false
var _wants_to_give_paw: bool = false
var _wants_to_jump: bool = false
var _trigger_actions_sub_sm: bool = false # For main SM to enter "Actions" node

var _is_anim_fully_sitting_idle: bool = false
var _is_anim_fully_lying_idle: bool = false
var _is_anim_playing_full_jump: bool = false
var _is_anim_in_main_sit_cycle_node: bool = false
var _is_anim_in_main_lie_cycle_node: bool = false
var _is_anim_in_main_actions_node: bool = false

var _fsm_state_just_set_by_intent: bool = false

func _ready():
	if not (tree_root is AnimationNodeStateMachine): push_error_and_disable("Tree Root not SM"); return
	if not main_sm_playback: push_error_and_disable("No main_sm_playback"); return
	if not character_body: push_error_and_disable("Parent not CharacterBody3D"); return
	if not advance_expression_base_node: push_error("CRITICAL: Advance Expression Base Node NOT SET.")
	elif get_node(advance_expression_base_node) != character_body: push_warning("Advance Expression Base Node not parent.")
	
	current_fsm_state = FsmState.READY
	_current_action_choice = ActionType.NONE
	_fsm_state_just_set_by_intent = false

	# Initialize AnimationTree parameters (this makes them known to the AT)
	set("parameters/conditions/_wants_to_sit", false)
	set("parameters/SitCycle/conditions/_wants_to_stand_from_sit", false)
	set("parameters/conditions/_wants_to_lie", false)
	set("parameters/LieCycle/conditions/_wants_to_stand_from_lie", false)
	set("parameters/SitCycle/conditions/_wants_to_give_paw", false)
	set("parameters/conditions/_wants_to_jump", false)
	set("parameters/conditions/_trigger_actions_sub_state_machine", false)

	# Integer choice parameter (can be useful for debugging or other complex logic if needed)
	set("parameters/Actions/action_choice", ActionType.NONE) # Ensure this path exists or is desired

	# Boolean parameters for specific actions, derived from the integer choice
	set("parameters/Actions/conditions/trigger_bark", false) # CRITICAL: Path example
	set("parameters/Actions/conditions/trigger_sniff", false)
	set("parameters/Actions/conditions/trigger_dig", false)

func push_error_and_disable(msg: String):
	push_error("AnimTree Script (%s): %s" % [name, msg])
	set_physics_process(false)

func _physics_process(delta: float):
	if not main_sm_playback or not is_active(): return

	var main_anim_state_node_name: String = main_sm_playback.get_current_node()

	_is_anim_in_main_sit_cycle_node = (main_anim_state_node_name == "SitCycle")
	if _is_anim_in_main_sit_cycle_node:
		var sit_sm_playback = get("parameters/SitCycle/playback") as AnimationNodeStateMachinePlayback
		_is_anim_fully_sitting_idle = sit_sm_playback and (sit_sm_playback.get_current_node() == "sitting_idle")
	else: _is_anim_fully_sitting_idle = false
			
	_is_anim_in_main_lie_cycle_node = (main_anim_state_node_name == "LieCycle")
	if _is_anim_in_main_lie_cycle_node:
		var lie_sm_playback = get("parameters/LieCycle/playback") as AnimationNodeStateMachinePlayback
		_is_anim_fully_lying_idle = lie_sm_playback and (lie_sm_playback.get_current_node() == "lying_idle")
	else: _is_anim_fully_lying_idle = false
			
	_is_anim_playing_full_jump = (main_anim_state_node_name == "PlayFullJumpAnim")
	_is_anim_in_main_actions_node = (main_anim_state_node_name == "Actions")

	if _fsm_state_just_set_by_intent:
		_fsm_state_just_set_by_intent = false
	else:
		match current_fsm_state:
			FsmState.PROCESSING_SIT_CYCLE:
				if main_anim_state_node_name == "IdleState" and not get("parameters/conditions/_wants_to_sit"):
					current_fsm_state = FsmState.READY
			FsmState.PROCESSING_LIE_CYCLE:
				if main_anim_state_node_name == "IdleState" and not get("parameters/conditions/_wants_to_lie"):
					current_fsm_state = FsmState.READY
			FsmState.PROCESSING_GENERAL_ACTION:
				if not _is_anim_in_main_actions_node and main_anim_state_node_name == "IdleState":
					current_fsm_state = FsmState.READY
					_current_action_choice = ActionType.NONE # Reset script choice
					# Parameters below will be set to false due to _current_action_choice being NONE
			FsmState.READY: pass

	_trigger_actions_sub_sm = (current_fsm_state == FsmState.PROCESSING_GENERAL_ACTION and _current_action_choice != ActionType.NONE)

	# Set general boolean parameters
	set("parameters/conditions/_wants_to_sit", _wants_to_sit)
	set("parameters/SitCycle/conditions/_wants_to_stand_from_sit", _wants_to_stand_from_sit)
	set("parameters/conditions/_wants_to_lie", _wants_to_lie)
	set("parameters/LieCycle/conditions/_wants_to_stand_from_lie", _wants_to_stand_from_lie)
	set("parameters/SitCycle/conditions/_wants_to_give_paw", _wants_to_give_paw)
	set("parameters/conditions/_wants_to_jump", _wants_to_jump)
	set("parameters/conditions/_trigger_actions_sub_state_machine", _trigger_actions_sub_sm)

	# Set integer action choice (still useful for debugging or if other systems might read it)
	set("parameters/Actions/action_choice", _current_action_choice) # Verify path

	# Set DERIVED boolean parameters for Actions sub-state machine conditions
	set("parameters/Actions/conditions/trigger_bark", _current_action_choice == ActionType.BARK) # Verify path
	set("parameters/Actions/conditions/trigger_sniff", _current_action_choice == ActionType.SNIFF) # Verify path
	set("parameters/Actions/conditions/trigger_dig", _current_action_choice == ActionType.DIG) # Verify path

	# Reset one-shot script flags for main intents
	if _wants_to_sit: _wants_to_sit = false
	if _wants_to_stand_from_sit: _wants_to_stand_from_sit = false
	if _wants_to_lie: _wants_to_lie = false
	if _wants_to_stand_from_lie: _wants_to_stand_from_lie = false
	if _wants_to_give_paw: _wants_to_give_paw = false
	if _wants_to_jump: _wants_to_jump = false

func trigger_character_intent(intent_name: String):
	var previous_fsm_state = current_fsm_state
	var action_choice_was_modified = false # Renamed for clarity

	if intent_name == "stand_from_sit":
		if current_fsm_state == FsmState.PROCESSING_SIT_CYCLE and _is_anim_fully_sitting_idle:
			_wants_to_stand_from_sit = true; return
	if intent_name == "stand_from_lie":
		if current_fsm_state == FsmState.PROCESSING_LIE_CYCLE and _is_anim_fully_lying_idle:
			_wants_to_stand_from_lie = true; return
	if intent_name == "give_paw":
		if current_fsm_state == FsmState.PROCESSING_SIT_CYCLE and _is_anim_fully_sitting_idle:
			_wants_to_give_paw = true; return

	if current_fsm_state != FsmState.READY:
		if intent_name == "jump": pass
		else: return

	var previous_action_choice = _current_action_choice # Store previous action choice
	match intent_name:
		"sit": current_fsm_state = FsmState.PROCESSING_SIT_CYCLE; _wants_to_sit = true
		"lie_down": current_fsm_state = FsmState.PROCESSING_LIE_CYCLE; _wants_to_lie = true
		"bark": current_fsm_state = FsmState.PROCESSING_GENERAL_ACTION; _current_action_choice = ActionType.BARK
		"sniff": current_fsm_state = FsmState.PROCESSING_GENERAL_ACTION; _current_action_choice = ActionType.SNIFF
		"dig": current_fsm_state = FsmState.PROCESSING_GENERAL_ACTION; _current_action_choice = ActionType.DIG
		"jump": _wants_to_jump = true
		_:
			if not (intent_name in ["stand_from_sit", "stand_from_lie", "give_paw"]): # Avoid re-warning
				push_warning("AnimTree Script: Unknown intent '%s' or FSM not ready." % intent_name)

	if _current_action_choice != previous_action_choice: # Check if action choice actually changed
		action_choice_was_modified = true

	if current_fsm_state != previous_fsm_state or action_choice_was_modified:
		_fsm_state_just_set_by_intent = true

# get_character_animation_state and set_blend_value remain the same
func get_character_animation_state(state_name: String):
	match state_name:
		"is_any_action_blocking_movement": return current_fsm_state != FsmState.READY or _is_anim_playing_full_jump
		"is_visual_anim_sitting_idle": return _is_anim_fully_sitting_idle
		"is_visual_anim_lying_idle": return _is_anim_fully_lying_idle
		"is_fsm_ready": return current_fsm_state == FsmState.READY
		"is_jump_anim_playing": return _is_anim_playing_full_jump
		_: push_warning("AnimTree Script: Unknown get_character_animation_state query: '%s'" % state_name); return false
func set_blend_value(blend_node_name: String, value: float): set("parameters/" + blend_node_name + "/blend_position", value)
