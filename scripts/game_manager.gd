# GameManager.gd
# Updated sections for POC completion with zone transition

extends Node

# --- Enums for Discoveries ---
enum DiscoveryCategory { ARTIFACTS, MEMORY, LANDSCAPES, NATURAL_PHENOMENA }
enum InteractionType { SNIFF, DIG, BARK }

# --- Pause handling ---
var game_paused: bool = false
@onready var pause_ui: CanvasLayer = $Pause

# --- Signals ---
signal discovery_made(discovery_id, discovery_data)
signal category_completed(category_enum_value, category_name_string)
signal all_poc_discoveries_complete
signal final_outcome_triggered(outcome_type_string)
signal countdown_started(seconds_remaining)
signal countdown_tick(seconds_remaining)
signal poc_completed(outcome_type)

# --- Discovery Definitions ---
var all_discoveries = [
	# Zone 1 (Example: 4 discoveries)
	{"id": "disc_z1_art1", "name": "Worn Leather Collar", "category": DiscoveryCategory.ARTIFACTS, "zone_num": 1, "interaction": InteractionType.SNIFF, "description": "A tattered leather collar, smells faintly of the sea and an unknown dog."},
	{"id": "disc_z1_mem1", "name": "Echo of a Playful Yap", "category": DiscoveryCategory.MEMORY, "zone_num": 1, "interaction": InteractionType.BARK, "description": "Barking here stirs a fleeting memory of puppyhood games."},
	{"id": "disc_z1_lnd1", "name": "Unusual Sand Dune Formation", "category": DiscoveryCategory.LANDSCAPES, "zone_num": 1, "interaction": InteractionType.DIG, "description": "The wind has sculpted this dune in a peculiar way."},
	{"id": "disc_z1_nat1", "name": "Strange Salty Crystals", "category": DiscoveryCategory.NATURAL_PHENOMENA, "zone_num": 1, "interaction": InteractionType.SNIFF, "description": "These crystals hum with a faint, salty energy."},
	# Zone 2 (Example: 4 discoveries)
	{"id": "disc_z2_art1", "name": "Rusty Metal Tag", "category": DiscoveryCategory.ARTIFACTS, "zone_num": 2, "interaction": InteractionType.DIG, "description": "A small, corroded metal tag. The markings are illegible."},
	{"id": "disc_z2_mem1", "name": "Sense of Being Watched", "category": DiscoveryCategory.MEMORY, "zone_num": 2, "interaction": InteractionType.BARK, "description": "An uneasy feeling, like unseen eyes are following."},
	{"id": "disc_z2_lnd1", "name": "Moss-Covered Pathway", "category": DiscoveryCategory.LANDSCAPES, "zone_num": 2, "interaction": InteractionType.SNIFF, "description": "An old path, barely visible under the moss, leading somewhere forgotten."},
	{"id": "disc_z2_nat1", "name": "Whispering Reeds", "category": DiscoveryCategory.NATURAL_PHENOMENA, "zone_num": 2, "interaction": InteractionType.BARK, "description": "The wind through these reeds sounds almost like hushed voices."},
	# Zone 3 (Example: 4 discoveries)
	{"id": "disc_z3_art1", "name": "Carved Wooden Figurine", "category": DiscoveryCategory.ARTIFACTS, "zone_num": 3, "interaction": InteractionType.SNIFF, "description": "A small, weathered wooden animal, crudely carved but with care."},
	{"id": "disc_z3_mem1", "name": "Familiar Comforting Warmth", "category": DiscoveryCategory.MEMORY, "zone_num": 3, "interaction": InteractionType.DIG, "description": "Digging here unearths a spot that feels safe and warm, like a den."},
	{"id": "disc_z3_lnd1", "name": "Circle of Fallen Trees", "category": DiscoveryCategory.LANDSCAPES, "zone_num": 3, "interaction": InteractionType.BARK, "description": "These trees fell inwards, forming a natural clearing."},
	{"id": "disc_z3_nat1", "name": "Glowing Fungi Patch", "category": DiscoveryCategory.NATURAL_PHENOMENA, "zone_num": 3, "interaction": InteractionType.SNIFF, "description": "A patch of mushrooms that emit a soft, pulsating light."},
	# Zone 4 (Example: 4 discoveries)
	{"id": "disc_z4_art1", "name": "Smooth, Cool Stone", "category": DiscoveryCategory.ARTIFACTS, "zone_num": 4, "interaction": InteractionType.DIG, "description": "A perfectly smooth stone, cool to the touch, unlike others nearby."},
	{"id": "disc_z4_mem1", "name": "A Howl on the Wind", "category": DiscoveryCategory.MEMORY, "zone_num": 4, "interaction": InteractionType.BARK, "description": "A distant, mournful howl seems to echo from the past when barking here."},
	{"id": "disc_z4_lnd1", "name": "The Causeway Viewpoint", "category": DiscoveryCategory.LANDSCAPES, "zone_num": 4, "interaction": InteractionType.SNIFF, "description": "From here, the entire causeway to the mainland is visible."},
	{"id": "disc_z4_nat1", "name": "Sudden Chill in the Air", "category": DiscoveryCategory.NATURAL_PHENOMENA, "zone_num": 4, "interaction": InteractionType.SNIFF, "description": "Even on a warm day, this spot holds a distinct, unnatural chill."}
]
var total_discoveries_possible: int = 16

# --- Player Knowledge State ---
var player_discovered_ids = {}
var category_counts = {
	DiscoveryCategory.ARTIFACTS: 0,
	DiscoveryCategory.MEMORY: 0,
	DiscoveryCategory.LANDSCAPES: 0,
	DiscoveryCategory.NATURAL_PHENOMENA: 0
}
var completed_categories_in_order = []
var total_discoveries_made: int = 0

# --- Scene Management ---
var current_zone_node: Node = null
var current_zone_scene_path: String = ""
var player_node: CharacterBody3D = null

# --- POC Game State ---
enum POCState { INTRO, EXPLORING, ALL_DISCOVERIES_MADE, COUNTDOWN_ACTIVE, FINAL_ZONE, GAME_END }
var current_poc_state: POCState = POCState.INTRO

# --- Countdown Timer ---
var countdown_timer: Timer
var countdown_seconds_remaining: int = 5

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	pause_ui.visible = false
	setup_countdown_timer()
	print("GameManager Initialized.")

func setup_countdown_timer():
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(countdown_timer)

func _unhandled_input(_event: InputEvent):
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
		
func toggle_pause():
	if game_paused == true:
		pause_ui.visible = false
		get_tree().paused = false
		game_paused = false
	else:
		pause_ui.visible = true
		get_tree().paused = true
		game_paused = true
	get_viewport().set_input_as_handled()

# --- Player Registration ---
func register_player(player: CharacterBody3D):
	if player:
		player_node = player
		print("Player (CoolColin) registered with GameManager.")
	else:
		push_error("GameManager: Attempted to register a null player.")

# --- Zone Management ---
func change_zone(target_zone_scene_path: String, entry_point_name: String = "PlayerSpawnPoint"):
	print("GameManager: Changing to zone: " + target_zone_scene_path)
	if not player_node:
		push_error("GameManager: Player node not registered. Cannot change zone.")
		return

	if current_zone_node:
		current_zone_node.queue_free()
		current_zone_node = null
		print("GameManager: Freed previous zone: " + current_zone_scene_path)

	var zone_packed_scene = load(target_zone_scene_path)
	if zone_packed_scene:
		current_zone_node = zone_packed_scene.instantiate()
		get_tree().root.add_child.call_deferred(current_zone_node) 
		current_zone_scene_path = target_zone_scene_path
		print("GameManager: Loaded zone: " + target_zone_scene_path)
		
		# Use call_deferred to ensure the zone is fully loaded before moving player
		call_deferred("_move_player_to_spawn", entry_point_name)
	else:
		push_error("GameManager: Failed to load zone: " + target_zone_scene_path)

func _move_player_to_spawn(entry_point_name: String):
	var spawn_point = current_zone_node.get_node_or_null(entry_point_name) as Marker3D
	if spawn_point:
		player_node.global_transform.origin = spawn_point.global_transform.origin
		player_node.velocity = Vector3.ZERO
		print("GameManager: Player moved to spawn point: " + entry_point_name)
	else:
		push_warning("GameManager: Spawn point '" + entry_point_name + "' not found. Player not moved.")

# --- Discovery Logic ---
func get_discovery_data_by_id(id_to_find: String):
	for discovery in all_discoveries:
		if discovery.id == id_to_find:
			return discovery
	return null

func is_discovery_made(id_of_discovery: String) -> bool:
	return id_of_discovery in player_discovered_ids

func make_discovery(id_of_discovery: String) -> bool:
	if is_discovery_made(id_of_discovery):
		print("GameManager: Discovery '" + id_of_discovery + "' already made.")
		return false

	var discovery_data = get_discovery_data_by_id(id_of_discovery)
	if not discovery_data:
		push_error("GameManager: Attempted to make unknown discovery: " + id_of_discovery)
		return false

	player_discovered_ids[id_of_discovery] = true
	total_discoveries_made += 1
	var category_enum = discovery_data.category
	category_counts[category_enum] += 1
	
	emit_signal("discovery_made", id_of_discovery, discovery_data)
	print("GameManager: " + str(discovery_data.name) + " discovered! (" + str(total_discoveries_made) + "/" + str(total_discoveries_possible) + ")")
	print("   Category '" + DiscoveryCategory.keys()[category_enum] + "' count: " + str(category_counts[category_enum]))

	if category_counts[category_enum] == 4:
		if not category_enum in completed_categories_in_order:
			completed_categories_in_order.append(category_enum)
			emit_signal("category_completed", category_enum, DiscoveryCategory.keys()[category_enum])
			print("GameManager: Category completed: " + DiscoveryCategory.keys()[category_enum])

	if total_discoveries_made >= total_discoveries_possible:
		print("GameManager: All POC discoveries complete!")
		current_poc_state = POCState.ALL_DISCOVERIES_MADE
		emit_signal("all_poc_discoveries_complete")
		start_final_sequence()
	
	return true

# --- Final Sequence Logic ---
func start_final_sequence():
	print("GameManager: Starting final sequence - 5 second countdown to Zone 5")
	current_poc_state = POCState.COUNTDOWN_ACTIVE
	countdown_seconds_remaining = 5
	countdown_timer.start()
	emit_signal("countdown_started", countdown_seconds_remaining)
	print("GameManager: Countdown started - " + str(countdown_seconds_remaining) + " seconds remaining")

func _on_countdown_tick():
	countdown_seconds_remaining -= 1
	emit_signal("countdown_tick", countdown_seconds_remaining)
	print("GameManager: Countdown - " + str(countdown_seconds_remaining) + " seconds remaining")
	
	if countdown_seconds_remaining <= 0:
		countdown_timer.stop()
		load_final_zone()

func load_final_zone():
	print("GameManager: Loading Zone 5 for final dig")
	current_poc_state = POCState.FINAL_ZONE
	# Assuming your zone 5 scene is at this path - adjust as needed
	change_zone("res://scenes/zones/zone_5.tscn", "PlayerSpawnPoint")

# --- POC Final Outcome (Called by FinalDigSpot) ---
func trigger_final_poc_outcome():
	if total_discoveries_made < total_discoveries_possible:
		print("GameManager: Not all discoveries made yet. Cannot trigger final outcome.")
		return
	
	if completed_categories_in_order.is_empty():
		push_error("GameManager: Cannot determine outcome, no categories completed in order.")
		return

	if not player_node:
		push_error("GameManager: Player node not available for final outcome.")
		return

	var last_category_completed = completed_categories_in_order.back()
	var outcome_description = ""

	if last_category_completed == DiscoveryCategory.ARTIFACTS or last_category_completed == DiscoveryCategory.MEMORY:
		outcome_description = "SIT_THINK"
		print("GameManager Outcome A (Plot/Character): Player finds tennis ball - Colin will SIT and THINK.")
		if player_node.has_method("initiate_sit_externally"):
			player_node.initiate_sit_externally()
		else: 
			push_error("Player node missing 'initiate_sit_externally'")
			
	elif last_category_completed == DiscoveryCategory.LANDSCAPES or last_category_completed == DiscoveryCategory.NATURAL_PHENOMENA:
		outcome_description = "LIE_DREAM"
		print("GameManager Outcome B (Magical Realism/Mystery): Player finds big bone - Colin will LIE and DREAM.")
		if player_node.has_method("initiate_lie_externally"):
			player_node.initiate_lie_externally()
		else: 
			push_error("Player node missing 'initiate_lie_externally'")
	else:
		push_error("GameManager: Unknown last category for final outcome: " + str(last_category_completed))
		return
		
	current_poc_state = POCState.GAME_END
	emit_signal("final_outcome_triggered", outcome_description)
	
	# Show POC completion after a short delay
	await get_tree().create_timer(2.0).timeout
	show_poc_completion(outcome_description)

func show_poc_completion(outcome_type: String):
	print("=== POC COMPLETED ===")
	print("Final Category: " + DiscoveryCategory.keys()[completed_categories_in_order.back()])
	print("Outcome: " + outcome_type)
	print("Total Discoveries: " + str(total_discoveries_made) + "/" + str(total_discoveries_possible))
#	print("Categories completed in order: " + str([DiscoveryCategory.keys()[cat] for cat in completed_categories_in_order]))
	print("=== END POC ===")
	
	emit_signal("poc_completed", outcome_type)

# --- Utility Functions ---
func get_discoveries_for_zone(zone_number: int) -> Array:
	var zone_discoveries = []
	for discovery in all_discoveries:
		if discovery.zone_num == zone_number:
			zone_discoveries.append(discovery.id)
	return zone_discoveries
