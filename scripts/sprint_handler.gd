# sprint_handler.txt
# SprintHandler.gd
class_name SprintHandler extends Node

# Speeds relevant to the sprint system itself
@export var sprint_system_base_speed: float = 3.0  # The speed sprint accelerates from and decelerates/tapers towards. (Effectively CoolColin's walk_speed)
@export var sprint_system_max_speed: float = 9.75 # The peak speed of the sprint

@export var acceleration_time: float = 0.7
@export var peak_duration: float = 5.0
@export var deceleration_while_held_time: float = 1.0 # Time to decelerate from max to base_speed if shift still held
@export var release_taper_time: float = 0.5         # Time to taper off to base_speed when shift is released
@export var stamina_recovery_rate: float = 0.4 # Stamina per second when not sprinting
@export var stamina_depletion_rate: float = 0.5 # Stamina per second during sprint
@export var min_stamina_to_start_sprint: float = 0.6 # Prevents spam-sprinting

var current_stamina: float = 1.0 # 0.0 to 1.0
var stamina_depleted: bool = false
var is_sprint_button_currently_held: bool = false # Renamed for clarity
var current_sprint_factor: float = 0.0 # Normalized factor for current sprint bonus (0 to 1)
var sprint_timer: float = 0.0
var speed_at_release_for_taper: float = 0.0 # Stores the speed when sprint button was released

enum SprintPhase { NONE, ACCELERATING, PEAK, DECELERATING_HELD, TAPERING_OFF }
var current_sprint_phase: SprintPhase = SprintPhase.NONE

func _physics_process(delta: float):
	# Always update stamina each physics frame
	update_stamina(delta)

func initiate_sprint_input():
	is_sprint_button_currently_held = true
	if current_sprint_phase == SprintPhase.NONE or current_sprint_phase == SprintPhase.TAPERING_OFF:
		# Prevent starting sprint if stamina is too low (and not already in a depleted state recovering)
		if current_stamina < min_stamina_to_start_sprint and current_stamina > 0: # Allow if totally empty and recovering
			if stamina_depleted: # If we are marked as depleted, don't try to sprint
				return 
		elif current_stamina <= 0.0:
			stamina_depleted = true # Ensure it's set if somehow missed
			return


		current_sprint_phase = SprintPhase.ACCELERATING
		sprint_timer = 0.0
		# current_sprint_factor will start from 0 if phase was NONE, or from its tapering value if interrupted.
		# For a fresh sprint, ensure factor represents progress from sprint_system_base_speed
		if current_sprint_phase == SprintPhase.TAPERING_OFF: # Interrupted a taper
			# Estimate how far into acceleration we should be based on current_sprint_factor
			# This assumes current_sprint_factor was relative to the (max - base) range
			sprint_timer = current_sprint_factor * acceleration_time
		else: # Fresh sprint
			current_sprint_factor = 0.0

	elif current_sprint_phase == SprintPhase.DECELERATING_HELD:
		# Transition from decelerating_held back to accelerating
		# current_sprint_factor is (1.0 - progress_of_deceleration)
		# So, it directly represents how much "sprint bonus" factor is left.
		var remaining_factor_as_acceleration_progress = current_sprint_factor
		sprint_timer = remaining_factor_as_acceleration_progress * acceleration_time
		current_sprint_phase = SprintPhase.ACCELERATING

func release_sprint_input():
	is_sprint_button_currently_held = false
	if current_sprint_phase != SprintPhase.NONE and current_sprint_phase != SprintPhase.TAPERING_OFF:
		# Store the current actual speed for smooth tapering
		speed_at_release_for_taper = calculate_current_speed_based_on_phase()
		current_sprint_phase = SprintPhase.TAPERING_OFF
		sprint_timer = 0.0

func calculate_current_speed_based_on_phase() -> float:
	# Helper to get the momentary speed before a phase change (for tapering)
	match current_sprint_phase:
		SprintPhase.ACCELERATING, SprintPhase.DECELERATING_HELD:
			return sprint_system_base_speed + (sprint_system_max_speed - sprint_system_base_speed) * current_sprint_factor
		SprintPhase.PEAK:
			return sprint_system_max_speed
		_:
			return sprint_system_base_speed # Default or if in NONE/TAPERING_OFF already

# Helper function to transition to taper phase
func _transition_to_taper():
	speed_at_release_for_taper = calculate_current_speed_based_on_phase()
	current_sprint_phase = SprintPhase.TAPERING_OFF
	sprint_timer = 0.0

# Returns the target speed determined by the sprint system for the current frame
func get_sprint_target_speed(delta: float, movement_input_active: bool) -> float:
	var calculated_speed: float = sprint_system_base_speed # Default

	# Stop sprint if no movement input (except during tapering)
	if not movement_input_active and current_sprint_phase != SprintPhase.TAPERING_OFF:
		# Allow starting a sprint from standstill if button is pressed, then immediately stop if no movement
		var just_initiated_from_standstill = is_sprint_button_currently_held and \
											current_sprint_phase == SprintPhase.ACCELERATING and \
											sprint_timer < delta # Check if it's the very first frame of acceleration
		
		if not just_initiated_from_standstill:
			current_sprint_phase = SprintPhase.NONE
			current_sprint_factor = 0.0
			sprint_timer = 0.0
	
	# Return base speed if not sprinting and no movement
	if not is_sprint_button_currently_held and current_sprint_phase == SprintPhase.NONE:
		return sprint_system_base_speed if movement_input_active else 0.0

	# Prevent sprint re-initiation if stamina depleted and in NONE phase
	if stamina_depleted and current_sprint_phase == SprintPhase.NONE and is_sprint_button_currently_held:
		return sprint_system_base_speed if movement_input_active else 0.0

	match current_sprint_phase:
		SprintPhase.ACCELERATING:
			if not is_sprint_button_currently_held or stamina_depleted: # Also stop if stamina depletes mid-acceleration
				_transition_to_taper()
			else:
				sprint_timer += delta
				current_sprint_factor = min(sprint_timer / acceleration_time, 1.0)
				calculated_speed = sprint_system_base_speed + (sprint_system_max_speed - sprint_system_base_speed) * current_sprint_factor
				if current_sprint_factor >= 1.0:
					current_sprint_phase = SprintPhase.PEAK
					sprint_timer = 0.0
		
		SprintPhase.PEAK:
			if not is_sprint_button_currently_held or stamina_depleted:
				_transition_to_taper()
			else:
				sprint_timer += delta
				current_sprint_factor = 1.0
				calculated_speed = sprint_system_max_speed
				if sprint_timer >= peak_duration:
					current_sprint_phase = SprintPhase.DECELERATING_HELD
					sprint_timer = 0.0

		SprintPhase.DECELERATING_HELD: # Stamina should be recovering here
			if not is_sprint_button_currently_held:
				_transition_to_taper()
			else:
				sprint_timer += delta
				# If stamina recovers enough during this phase, and player is still holding shift, allow re-acceleration
				if not stamina_depleted and is_sprint_button_currently_held:
					# Transition back to accelerating using current factor
					var remaining_factor_as_acceleration_progress = current_sprint_factor
					sprint_timer = remaining_factor_as_acceleration_progress * acceleration_time
					current_sprint_phase = SprintPhase.ACCELERATING
					# Recalculate speed for this frame as accelerating
					current_sprint_factor = min(sprint_timer / acceleration_time, 1.0) # Should be based on the new sprint_timer
					calculated_speed = sprint_system_base_speed + (sprint_system_max_speed - sprint_system_base_speed) * current_sprint_factor
					return calculated_speed # Exit match early as phase changed

				current_sprint_factor = 1.0 - min(sprint_timer / deceleration_while_held_time, 1.0)
				calculated_speed = sprint_system_base_speed + (sprint_system_max_speed - sprint_system_base_speed) * current_sprint_factor
				
				if current_sprint_factor <= 0.0:
					current_sprint_phase = SprintPhase.NONE
					current_sprint_factor = 0.0
					calculated_speed = sprint_system_base_speed
		
		SprintPhase.TAPERING_OFF: # Stamina should be recovering here
			sprint_timer += delta
			var taper_progress = min(sprint_timer / release_taper_time, 1.0)
			calculated_speed = lerp(speed_at_release_for_taper, sprint_system_base_speed, taper_progress)
			current_sprint_factor = (calculated_speed - sprint_system_base_speed) / (sprint_system_max_speed - sprint_system_base_speed) if (sprint_system_max_speed - sprint_system_base_speed) != 0 else 0
			current_sprint_factor = clamp(current_sprint_factor, 0.0, 1.0)

			if taper_progress >= 1.0:
				current_sprint_phase = SprintPhase.NONE
				current_sprint_factor = 0.0
				calculated_speed = sprint_system_base_speed
		
		SprintPhase.NONE: # Stamina should be recovering here
			current_sprint_factor = 0.0
			if is_sprint_button_currently_held and movement_input_active and not stamina_depleted and current_stamina >= min_stamina_to_start_sprint :
				initiate_sprint_input() # This will set phase to ACCELERATING
				# Recalculate speed for this frame as accelerating (first frame of it)
				if current_sprint_phase == SprintPhase.ACCELERATING: # Check if initiate_sprint_input was successful
					current_sprint_factor = min(0.0 / acceleration_time, 1.0) # Starts at 0 factor
					calculated_speed = sprint_system_base_speed + (sprint_system_max_speed - sprint_system_base_speed) * current_sprint_factor
				else: # Sprint initiation failed (e.g. stamina still too low despite check)
					calculated_speed = sprint_system_base_speed

			else:
				calculated_speed = sprint_system_base_speed
				
	if not movement_input_active:
		# If sprint was just initiated from standstill, allow that first frame of speed, then it will be zeroed next frame if still no input
		var just_initiated_from_standstill = is_sprint_button_currently_held and \
											current_sprint_phase == SprintPhase.ACCELERATING and \
											sprint_timer < delta # Check if it's the very first frame
		if not just_initiated_from_standstill:
			calculated_speed = 0.0


	return calculated_speed

# Separate stamina update function - this runs every frame regardless of sprint state
func update_stamina(delta: float):
	# Check if we're actively consuming stamina (only during acceleration and peak phases and button held)
	var is_consuming_stamina = is_sprint_button_currently_held and \
								(current_sprint_phase == SprintPhase.ACCELERATING or \
								 current_sprint_phase == SprintPhase.PEAK)
	
	if is_consuming_stamina:
		# Deplete stamina during active sprinting
		current_stamina -= stamina_depletion_rate * delta
		current_stamina = max(0.0, current_stamina)
		
		# Check if stamina is depleted and force transition if needed
		if current_stamina <= 0.0 and not stamina_depleted:
			stamina_depleted = true
			# If at PEAK or ACCELERATING and stamina runs out, transition to taper or decelerate_held
			if is_sprint_button_currently_held:
				if current_sprint_phase == SprintPhase.PEAK:
					current_sprint_phase = SprintPhase.DECELERATING_HELD # Will start recovering stamina now
					sprint_timer = 0.0
				elif current_sprint_phase == SprintPhase.ACCELERATING:
					_transition_to_taper() # Will start recovering stamina now
			else: # Button was released at the exact moment stamina ran out
				_transition_to_taper()


	else:
		# Recover stamina when not actively consuming it
		# This includes TAPERING_OFF, DECELERATING_HELD (if button held but stamina recovering), and NONE phases,
		# or if ACCELERATING/PEAK but sprint button is released.
		if current_stamina < 1.0: # Only recover if not full
			current_stamina += stamina_recovery_rate * delta
			current_stamina = min(1.0, current_stamina)
		# Remove the spammy print: # print(current_stamina)
		
		# Reset stamina depletion flag when we have enough stamina to sprint again
		if stamina_depleted and current_stamina >= min_stamina_to_start_sprint:
			stamina_depleted = false

func get_current_phase():
	return current_sprint_phase

func is_sprint_active(): # A clear way to know if any sprint mechanic is influencing speed
	return current_sprint_phase != SprintPhase.NONE

# Optional: Get current stamina for UI display
func get_current_stamina() -> float:
	return current_stamina

# Get stamina as percentage for UI
func get_stamina_percentage() -> float:
	return current_stamina * 100.0
