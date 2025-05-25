# Discoverable.gd
class_name Discoverable extends Area3D # Root node is Area3D for player proximity detection

@export var discovery_id: String = "" : set = set_discovery_id # Unique ID from GameManager.all_discoveries
@export var initially_hidden: bool = false # If true, mesh is hidden until discovered via particles

# Node References (Assign in Editor or via @onready if names are consistent)
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer # For rotation or reveal animation
@onready var interaction_particles: GPUParticles3D = $InteractionParticles # Particles to show *before* discovery if hidden
# @onready var discovery_reveal_particles: GPUParticles3D = $DiscoveryRevealParticles # Optional: Particles for the reveal moment

var player_in_range: bool = false
var cool_colin_node = null # Stores reference to CoolColin when he's in range
var is_discovered: bool = false

var discovery_data: Dictionary # Store data for this specific discoverable

# Predefined colors for categories (can be customized)
const CATEGORY_COLORS = {
	GameManager.DiscoveryCategory.ARTIFACTS: Color.SADDLE_BROWN, # Brownish
	GameManager.DiscoveryCategory.MEMORY: Color.DEEP_SKY_BLUE,     # Bluish
	GameManager.DiscoveryCategory.LANDSCAPES: Color.FOREST_GREEN,  # Greenish
	GameManager.DiscoveryCategory.NATURAL_PHENOMENA: Color.MEDIUM_PURPLE # Purplish
}

func _ready():
	if discovery_id.is_empty():
		push_warning(str(name) + ": Discovery ID not set. This discoverable will not function correctly.")
		set_physics_process(false) # Disable if no ID
		return

	if not GameManager:
		push_error(str(name) + ": GameManager not found. Discoverable cannot function.")
		set_physics_process(false)
		return
		
	discovery_data = GameManager.get_discovery_data_by_id(discovery_id)
	if not discovery_data:
		push_error(str(name) + ": No data found in GameManager for discovery_id: " + discovery_id)
		set_physics_process(false)
		return

	is_discovered = GameManager.is_discovery_made(discovery_id) # Check initial discovered state

	# Setup connections
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Initial visual setup
	if is_discovered:
		reveal_as_discovered(false) # Reveal instantly if already found, no animation/particles
	else:
		if initially_hidden:
			if mesh_instance: mesh_instance.visible = false
			if animation_player: animation_player.stop() # Stop rotation if hidden
			if interaction_particles: interaction_particles.emitting = true # Show "dig here" particles
		else: # Not hidden initially, but not yet discovered
			if mesh_instance: mesh_instance.visible = true
			if animation_player and animation_player.has_animation("rotate"): animation_player.play("rotate") # Autoplay rotation
			if interaction_particles: interaction_particles.emitting = false # Hide if mesh is visible
			# Apply a default "undiscovered" material or tint if desired
			# Example: if mesh_instance: mesh_instance.material_override = StandardMaterial3D.new()
			# mesh_instance.material_override.albedo_color = Color.GRAY 


	# Apply category color if mesh is visible and not overridden by an "undiscovered" look
	if mesh_instance and mesh_instance.visible and not initially_hidden and is_discovered:
		apply_category_color()
	elif mesh_instance and not initially_hidden and not is_discovered:
		# Could apply a generic "unknown" color or rely on its base material
		pass


func set_discovery_id(new_id: String):
	discovery_id = new_id
	if Engine.is_editor_hint() or not is_inside_tree(): # Don't run full logic in editor or before ready
		return
	# If called at runtime after _ready, re-initialize
	if is_inside_tree() and get_tree() != null:
		_ready()


func apply_category_color():
	if not mesh_instance or not discovery_data: return

	var category = discovery_data.category
	if category in CATEGORY_COLORS:
		var new_material = mesh_instance.get_active_material(0).duplicate() if mesh_instance.get_active_material(0) else StandardMaterial3D.new()
		new_material.albedo_color = CATEGORY_COLORS[category]
		mesh_instance.material_override = new_material
	else: # Default color if category not in our map
		var new_material = mesh_instance.get_active_material(0).duplicate() if mesh_instance.get_active_material(0) else StandardMaterial3D.new()
		new_material.albedo_color = Color.WHITE 
		mesh_instance.material_override = new_material


func _on_body_entered(body):
	if is_discovered: return # Don't interact if already found

	if body.is_in_group("Player"):
		player_in_range = true
		cool_colin_node = body
		if body.has_method("add_overlapping_discoverable"):
			body.add_overlapping_discoverable(self)
		
		# TODO: Show UI prompt based on discovery_data.interaction type
		# e.g., UIManager.show_interaction_prompt(discovery_data.interaction)
		print(str(name) + ": Player entered range. Required interaction: " + GameManager.InteractionType.keys()[discovery_data.interaction])


func _on_body_exited(body):
	if is_discovered: return

	if body.is_in_group("Player"):
		player_in_range = false
		if body.has_method("remove_overlapping_discoverable"):
			body.remove_overlapping_discoverable(self)
		cool_colin_node = null
		
		# TODO: Hide UI prompt
		# UIManager.hide_interaction_prompt()
		print(str(name) + ": Player exited range.")


func attempt_interaction(interaction_type: GameManager.InteractionType) -> bool:
	if is_discovered or not player_in_range or not discovery_data:
		return false

	if discovery_data.interaction == interaction_type:
		if GameManager.make_discovery(discovery_id): # This handles all backend logic
			print(str(name) + ": Successfully discovered with " + GameManager.InteractionType.keys()[interaction_type])
			reveal_as_discovered(true) # Reveal with animation/particles
			return true
		else:
			# Should not happen if is_discovered check is working, but as a failsafe:
			print(str(name) + ": GameManager reported discovery failed (was already made?).")
			reveal_as_discovered(false) # Ensure it's visually discovered
			return false 
	else:
		print(str(name) + ": Failed interaction. Required: " + GameManager.InteractionType.keys()[discovery_data.interaction] + ", Tried: " + GameManager.InteractionType.keys()[interaction_type])
		# Optional: Play a "failed interaction" sound/effect
		return false


func reveal_as_discovered(play_effects: bool):
	is_discovered = true # Mark as discovered internally

	if interaction_particles:
		interaction_particles.emitting = false # Hide "dig here" particles

	if mesh_instance:
		mesh_instance.visible = true # Ensure mesh is visible
		apply_category_color()     # Apply color based on category

	if animation_player:
		if animation_player.has_animation("rotate"): # Your existing rotation
			animation_player.play("rotate")
		if play_effects and animation_player.has_animation("reveal_effect"): # Optional reveal animation
			animation_player.play("reveal_effect")
		# else if not playing reveal effect, ensure rotate is playing
		elif not (play_effects and animation_player.has_animation("reveal_effect")) and animation_player.has_animation("rotate"):
			animation_player.play("rotate")


	# Optional: Play reveal particles
	# if play_effects and discovery_reveal_particles:
	#    discovery_reveal_particles.restart() # Emits once

	# Disable further interaction checks by removing from CoolColin's list explicitly
	# (though is_discovered flag should prevent re-discovery)
	if cool_colin_node and cool_colin_node.has_method("remove_overlapping_discoverable"):
		cool_colin_node.remove_overlapping_discoverable(self)
	
	# You might want to disable the Area3D's collision/monitoring after discovery
	# monitoring = false
	# monitorable = false 
	# Or set_deferred("monitoring", false)
