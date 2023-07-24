extends Control

@onready var main_buttons: Control = $MainButtons
@onready var singleplayer_btn: Button = $MainButtons/HBoxContainer/Singleplayer


func _ready() -> void:
	singleplayer_btn.grab_focus.call_deferred()


func _on_singleplayer_pressed() -> void:
	Game.play_mode = Game.SINGLE
	get_tree().change_scene_to_file("res://ui/sub_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_local_multiplayer_pressed() -> void:
	Game.play_mode = Game.MULTIPLAYER
	get_tree().change_scene_to_file("res://ui/sub_menu.tscn")


func _on_host_game_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/host_menu.tscn")


func _on_join_game_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/join_menu.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/settings.tscn")
