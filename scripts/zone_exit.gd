	  
# ZoneExit.gd
extends Area3D

@export var target_zone_scene_path: String = "" 
# In the editor, for an exit in zone_1 leading to zone_2, set this to "res://zone_2.tscn"
# @export var target_entry_point_name: String = "PlayerSpawnPoint" # If different entry points are needed

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Player"): # Add "Player" to CoolColin's group in his scene
		if target_zone_scene_path.is_empty():
			push_warning("Target zone scene path not set for " + name)
			return
		
		# Call the GameManager to handle the zone change
		GameManager.change_zone(target_zone_scene_path) # Pass target_entry_point_name if needed

	
