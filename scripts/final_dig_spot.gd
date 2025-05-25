# FinalDigSpot.gd
class_name FinalDigSpot extends Area3D

@export var tennis_ball_prefab: PackedScene
@export var big_bone_prefab: PackedScene

@onready var dig_particles: GPUParticles3D = $DigParticles

var player_in_range: bool = false
var cool_colin_node = null
var already_dug: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if dig_particles: 
		dig_particles.emitting = true
		print("FinalDigSpot: Dig particles active - ready for player interaction")

func _on_body_entered(body):
	if already_dug: return
	if body.is_in_group("Player"):
		player_in_range = true
		cool_colin_node = body
		if body.has_method("add_overlapping_discoverable"):
			body.add_overlapping_discoverable(self)
		print("FinalDigSpot: Player entered range. DIG to reveal the final reward!")

func _on_body_exited(body):
	if already_dug: return
	if body.is_in_group("Player"):
		player_in_range = false
		if body.has_method("remove_overlapping_discoverable"):
			body.remove_overlapping_discoverable(self)
		cool_colin_node = null
		print("FinalDigSpot: Player exited range.")

func attempt_interaction(interaction_type: GameManager.InteractionType) -> bool:
	if already_dug or not player_in_range:
		return false

	# This spot ONLY responds to DIG
	if interaction_type != GameManager.InteractionType.DIG:
		print("FinalDigSpot: Only digging works here! Try digging instead.")
		return false

	if not GameManager:
		push_error("FinalDigSpot: GameManager not found!")
		return false
		
	# Check if all discoveries are actually complete
	if GameManager.total_discoveries_made < GameManager.total_discoveries_possible:
		print("FinalDigSpot: You haven't found everything yet! Keep exploring.")
		return false
		
	if not tennis_ball_prefab or not big_bone_prefab:
		push_error("FinalDigSpot: Final item prefabs not set!")
		return false
		
	print("FinalDigSpot: Player is digging for the final reward!")
	already_dug = true
	if dig_particles: dig_particles.emitting = false

	# Determine which item to spawn based on GameManager state
	var last_category = GameManager.completed_categories_in_order.back() if !GameManager.completed_categories_in_order.is_empty() else null
	var item_to_spawn_instance: Node3D = null
	var reward_name = ""

	if last_category == GameManager.DiscoveryCategory.ARTIFACTS or last_category == GameManager.DiscoveryCategory.MEMORY:
		item_to_spawn_instance = tennis_ball_prefab.instantiate()
		reward_name = "Tennis Ball"
		print("FinalDigSpot: Spawning Tennis Ball (Plot/Character ending).")
	elif last_category == GameManager.DiscoveryCategory.LANDSCAPES or last_category == GameManager.DiscoveryCategory.NATURAL_PHENOMENA:
		item_to_spawn_instance = big_bone_prefab.instantiate()
		reward_name = "Big Bone"
		print("FinalDigSpot: Spawning Big Bone (Magical/Mystery ending).")
	else:
		push_warning("FinalDigSpot: Could not determine final item. Last category: " + str(last_category))
		return false

	if item_to_spawn_instance:
		# Spawn the item slightly above the dig spot
		add_child(item_to_spawn_instance)
		item_to_spawn_instance.transform.origin = Vector3.UP * 0.5
		print("FinalDigSpot: " + reward_name + " revealed! Colin's journey is complete.")

	# Remove from player's interaction list
	if cool_colin_node and cool_colin_node.has_method("remove_overlapping_discoverable"):
		cool_colin_node.remove_overlapping_discoverable(self)

	# Tell GameManager to trigger Colin's final animation and complete the POC
	GameManager.trigger_final_poc_outcome()
	
	return true
