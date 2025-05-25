# PlayerInputHandler.gd
# Child node of CoolColin. Its purpose is to detect raw player input
# and emit signals for CoolColin or other systems to interpret.

extends Node

# --- Signals for Movement Intents ---
signal sprint_initiated
signal sprint_released
signal jump_input_detected # For physics application by CoolColin

# --- Signals for Discrete Action Intents ---
# CoolColin will connect to these, check conditions, and then call the AnimationTree script.
signal intent_sit_requested
signal intent_lie_down_requested
signal intent_bark_requested
signal intent_sniff_requested
signal intent_dig_requested
signal intent_interact_requested # For "E" key, context decided by CoolColin/FSM

var last_sprint_press_time: float = 0.0
# The 'event' parameter is useful if you need to check specific event properties,
# but for action checks, Input singleton is often used directly.
# We'll use _unhandled_input for actions that should be "handled" and potentially block UI.
# Movement modifiers like sprint are often fine in _input or _physics_process if polled.
# For simplicity and consistency with action handling, let's keep most here.

func _unhandled_input(event: InputEvent):
	# Add input buffering for better responsiveness
	if Input.is_action_just_pressed("jump"):
		emit_signal("jump_input_detected")
		# Buffer jump input for short period if not on floor
		if not get_parent().is_on_floor():
			get_tree().create_timer(0.1).timeout.connect(func(): 
				if get_parent().is_on_floor():
					emit_signal("jump_input_detected")
			)
		get_viewport().set_input_as_handled()
	
	# Double-tap sprint for burst of speed (like a dog getting excited)
	if Input.is_action_just_pressed("sprint"):
		check_double_tap_sprint()
		emit_signal("sprint_initiated")
		# Typically, sprint modifier itself doesn't get "handled" by get_viewport().set_input_as_handled()
		# as it modifies other actions (movement).

	elif Input.is_action_just_released("sprint"):
		emit_signal("sprint_released")

	# --- Jump Input ---
	# The AnimationTree expression `Input.is_action_just_pressed("jump") and is_on_floor()`
	# is the primary driver for the animation state change.
	# CoolColin's script needs to know when to apply the jump velocity.
	if Input.is_action_just_pressed("jump"):
		emit_signal("jump_input_detected")
		get_viewport().set_input_as_handled() # NOW WE HANDLE IT, as AnimTree won't use expression

	# --- Discrete Action Intents ---
	# These actions typically "consume" the input.
	elif Input.is_action_just_pressed("sit"):
		emit_signal("intent_sit_requested")
		get_viewport().set_input_as_handled()

	elif Input.is_action_just_pressed("lie_down"):
		emit_signal("intent_lie_down_requested")
		get_viewport().set_input_as_handled()

	elif Input.is_action_just_pressed("bark"):
		emit_signal("intent_bark_requested")
		get_viewport().set_input_as_handled()

	elif Input.is_action_just_pressed("sniff"):
		emit_signal("intent_sniff_requested")
		get_viewport().set_input_as_handled()

	elif Input.is_action_just_pressed("dig"):
		emit_signal("intent_dig_requested")
		get_viewport().set_input_as_handled()

	elif Input.is_action_just_pressed("interact"): # "E" key
		emit_signal("intent_interact_requested") # CoolColin will decide what "interact" means
		get_viewport().set_input_as_handled()

	# --- Pause Logic ---
	# Pause logic will be handled by a GameManager singleton or a similar global entity
	# that has its process_mode set to "always" to allow unpausing.
	# For now, we assume Input.is_action_just_pressed("pause") is checked elsewhere.

	# --- Mouse Mode Toggle (Debug/Convenience) ---
	# This can stay here or move to a debug overlay script if preferred.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Optionally, handle this event too if it's purely for this debug toggle.
		# get_viewport().set_input_as_handled()
		
func check_double_tap_sprint():
	var current_time = Time.get_time_dict_from_system()["second"]
	if current_time - last_sprint_press_time < 0.3: # 300ms window
		# Trigger excitement boost
		if get_parent().has_method("trigger_excitement"):
			get_parent().trigger_excitement()
	last_sprint_press_time = current_time
