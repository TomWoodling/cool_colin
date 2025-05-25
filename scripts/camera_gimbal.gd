extends Node3D

# Camera Controller for Cool Colin
# -------------------------------

# This script manages the camera for our dog protagonist
# It should be attached to the CameraGimbal node

@export var distance_from_target: float = 5.0
@export var min_zoom_distance: float = 2.0  # Minimum zoom distance
@export var max_zoom_distance: float = 10.0  # Maximum zoom distance
@export var zoom_speed: float = 0.5  # How fast zooming occurs
@export var height_offset: float = 1.5
@export var rotation_speed: float = 0.005
@export var pitch_limit_min: float = -0.6  # About -35 degrees
@export var pitch_limit_max: float = 0.4   # About 25 degrees
@export var smoothing: float = 10.0
@export var collision_mask: int = 1  # Layer for camera collision

@onready var camera: Camera3D = $SpringArm3D/CameraPitch/Camera3D
@onready var camera_pitch: Node3D = $SpringArm3D/CameraPitch
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var target: Node3D = get_parent()

# Internal variables
var input_enabled: bool = true
var current_rotation: float = 0.0
var current_pitch: float = 0.0

func _ready():
	# Initialize spring arm properties
	spring_arm.spring_length = distance_from_target
	spring_arm.collision_mask = collision_mask
	spring_arm.margin = 0.2
	
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if !input_enabled:
		return
	
	# Handle mouse movement for camera rotation
	if event is InputEventMouseMotion:
		# Rotate around y-axis (left-right)
		current_rotation -= event.relative.x * rotation_speed
		self.rotation.y = current_rotation
		
		# Rotate pitch (up-down)
		current_pitch -= event.relative.y * rotation_speed
		current_pitch = clamp(current_pitch, pitch_limit_min, pitch_limit_max)
		camera_pitch.rotation.x = current_pitch
	
	# Handle mouse wheel for zooming
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length -= zoom_speed
			spring_arm.spring_length = max(spring_arm.spring_length, min_zoom_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length += zoom_speed
			spring_arm.spring_length = min(spring_arm.spring_length, max_zoom_distance)

func _physics_process(delta):
	follow_target(delta)
	
	# Handle input-based zooming
	if Input.is_action_pressed("zoom_in"):
		spring_arm.spring_length -= zoom_speed * delta * 10
		spring_arm.spring_length = max(spring_arm.spring_length, min_zoom_distance)
	elif Input.is_action_pressed("zoom_out"):
		spring_arm.spring_length += zoom_speed * delta * 10
		spring_arm.spring_length = min(spring_arm.spring_length, max_zoom_distance)

func follow_target(delta):
	# Calculate desired position
	var target_pos = target.global_position + Vector3(0, height_offset, 0)
	
	# Smoothly move to target position
	self.global_position = self.global_position.lerp(target_pos, smoothing * delta)
	
	# Make sure gimbal rotation is only on y-axis (for tilt)
	self.rotation.x = 0
	self.rotation.z = 0

func set_input_enabled(enabled: bool):
	input_enabled = enabled
	
	# Toggle mouse mode
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Set camera distance directly (useful for scripted camera movements)
func set_camera_distance(distance: float):
	distance = clamp(distance, min_zoom_distance, max_zoom_distance)
	spring_arm.spring_length = distance
