# Main.gd (script for your main game scene)
extends Node

@export var initial_zone_path: String = "res://scenes/zones/zone_1.tscn"

func _ready():
	if GameManager:
		# CoolColin should have registered himself by now if he's in this scene.
		# If player_node in GameManager is null here, it means CoolColin wasn't ready or didn't register.
		if GameManager.player_node == null:
			# This might happen if CoolColin's _ready() hasn't run yet.
			# A call_deferred can help, or ensure CoolColin is processed first.
			# For simplicity now, we assume registration worked.
			push_warning("Main: GameManager.player_node is null. Zone change might fail if player isn't set.")

		GameManager.change_zone(initial_zone_path)
		# TODO: Show initial intro UI text here
		print("Main scene ready. Initial zone loaded.")
	else:
		push_error("Main: GameManager not found. Cannot start game.")
