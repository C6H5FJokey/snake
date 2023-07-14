extends Control

@onready var main_buttons: Control = $ColorRect/MainButtons
@onready var host_menu: Control = $ColorRect/HostMenu
@onready var join_menu: Control = $ColorRect/JoinMenu



func _on_singleplayer_pressed() -> void:
	Game.play_mode = Game.SINGLE
	get_tree().change_scene_to_file("res://game_scene/singleplayer_scene.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_local_multiplayer_pressed() -> void:
	Game.play_mode = Game.MULTIPLAYER
	get_tree().change_scene_to_file("res://game_scene/multiplayer_scene.tscn")


func _on_host_game_pressed() -> void:
	main_buttons.hide()
	host_menu.show()


func _on_join_game_pressed() -> void:
	main_buttons.hide()
	join_menu.show()


func _on_host_menu_back_pressed() -> void:
	host_menu.hide()
	main_buttons.show()


func _on_join_menu_back_pressed() -> void:
	join_menu.hide()
	main_buttons.show()
