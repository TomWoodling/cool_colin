# POC_UI_Manager.txt
# POC_UI_Manager.gd
# Attach this to a CanvasLayer node with UI elements as children
# Simple UI to handle countdown, POC completion display, and stamina

extends CanvasLayer

@onready var countdown_label: Label = $CountdownLabel
@onready var completion_panel: Panel = $CompletionPanel
@onready var completion_title: Label = $CompletionPanel/VBoxContainer/TitleLabel
@onready var completion_details: Label = $CompletionPanel/VBoxContainer/DetailsLabel
@onready var discovery_counter: Label = $DiscoveryCounter
@onready var stamina_bar: ProgressBar = $StaminaBar # Assign this in the editor or ensure path is correct

var discoveries_made: int = 0
var total_discoveries: int = 16 # Should ideally get this from GameManager if it can change

func _ready():
	# Connect to GameManager signals
	if GameManager:
		GameManager.discovery_made.connect(_on_discovery_made)
		GameManager.countdown_started.connect(_on_countdown_started)
		GameManager.countdown_tick.connect(_on_countdown_tick)
		GameManager.poc_completed.connect(_on_poc_completed)
		GameManager.all_poc_discoveries_complete.connect(_on_all_discoveries_complete)
		total_discoveries = GameManager.total_discoveries_possible # Get actual total
	else:
		push_error("POC_UI_Manager: GameManager not found!")

	# Initialize UI visibility
	if countdown_label: countdown_label.visible = false
	if completion_panel: completion_panel.visible = false
	if discovery_counter: discovery_counter.visible = true # Discovery counter should be visible
	if stamina_bar: 
		stamina_bar.visible = true # Stamina bar should be visible
		stamina_bar.max_value = 100
		stamina_bar.value = 100 # Start full
	
	update_discovery_counter()

func _process(delta: float):
	# Update Stamina Bar
	if stamina_bar and stamina_bar.visible:
		if GameManager and GameManager.player_node and GameManager.player_node.has_method("get_current_sprint_stamina_percentage"):
			stamina_bar.value = GameManager.player_node.get_current_sprint_stamina_percentage()
		elif stamina_bar: # Failsafe if player node is temporarily unavailable
			stamina_bar.value = 0


func _on_discovery_made(discovery_id: String, discovery_data: Dictionary):
	discoveries_made += 1
	update_discovery_counter()
	# print("UI: Discovery made - " + discovery_data.name) # Console log already covers this

func update_discovery_counter():
	if discovery_counter:
		discovery_counter.text = "Discoveries: " + str(discoveries_made) + "/" + str(total_discoveries)

func _on_all_discoveries_complete():
	# print("UI: All discoveries complete! Preparing for final sequence...") # Console log covers this
	if discovery_counter:
		discovery_counter.text = "All Discoveries Found!" # Or similar celebratory message

func _on_countdown_started(seconds_remaining: int):
	if countdown_label:
		countdown_label.visible = true
		countdown_label.text = "Loading Final Zone...\n" + str(seconds_remaining)
		# print("UI: Countdown started - " + str(seconds_remaining) + " seconds") # Console log
	if stamina_bar: stamina_bar.visible = false # Hide stamina bar during transition
	if discovery_counter: discovery_counter.visible = false # Hide counter during transition


func _on_countdown_tick(seconds_remaining: int):
	if countdown_label and countdown_label.visible:
		if seconds_remaining > 0:
			countdown_label.text = "Loading Final Zone...\n" + str(seconds_remaining)
		else:
			countdown_label.text = "Entering Final Zone..."
			# Hide countdown after a brief moment (or GameManager can signal when zone load is complete)
			# For now, let it be visible until next state
			
func _on_poc_completed(outcome_type: String):
	# This signal implies the final zone is loaded and the final interaction happened.
	if countdown_label: countdown_label.visible = false
	if stamina_bar: stamina_bar.visible = false
	if discovery_counter: discovery_counter.visible = false
	
	show_completion_screen(outcome_type)

func show_completion_screen(outcome_type: String):
	if not completion_panel: 
		push_error("POC_UI_Manager: Completion Panel node not found!")
		return
	
	completion_panel.visible = true
	
	if completion_title:
		completion_title.text = "POC COMPLETED!"
	
	if completion_details:
		var details_text = ""
		details_text += "Colin's Journey Complete!\n\n"
		
		var final_outcome_string = "Unknown Outcome"
		if outcome_type == "SIT_THINK":
			final_outcome_string = "Colin sits thoughtfully with his tennis ball,\nreflecting on memories and artifacts found."
		elif outcome_type == "LIE_DREAM":
			final_outcome_string = "Colin lies peacefully with his big bone,\ndreaming of magical landscapes and phenomena."
		
		details_text += "Final Outcome: " + outcome_type + "\n"
		details_text += final_outcome_string + "\n\n"

		details_text += "Discoveries Found: " + str(discoveries_made) + "/" + str(total_discoveries) + "\n\n"
		
		if GameManager and GameManager.completed_categories_in_order.size() > 0:
			details_text += "Categories Completed (in order):\n"
			for category_enum_int_value in GameManager.completed_categories_in_order: # This will be an integer
				var category_name = "Unknown Category"
				# GameManager.DiscoveryCategory.has(value) checks if the int value is valid for the enum
				if GameManager.DiscoveryCategory.has(category_enum_int_value):
					# GameManager.DiscoveryCategory.keys()[value] gets the string name from the int value
					category_name = GameManager.DiscoveryCategory.keys()[category_enum_int_value]
				else:
					# This should not happen if GameManager is working correctly
					push_warning("POC_UI_Manager: Encountered an invalid category enum integer value: " + str(category_enum_int_value))

				details_text += "• " + category_name + "\n"
		
		completion_details.text = details_text
	
	# print("UI: POC completion screen displayed") # Console log
