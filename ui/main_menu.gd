extends Control



func _on_singleplayer_pressed() -> void:
	Game.play_mode = Game.SINGLE
	get_tree().change_scene_to_file("res://game_scene/singleplayer_scene.tscn")


func _on_multiplayer_pressed() -> void:
	Game.play_mode = Game.MULTIPLAYER
	get_tree().change_scene_to_file("res://game_scene/multiplayer_scene.tscn")
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().quit()
