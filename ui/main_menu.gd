extends Control

@onready var main_buttons: Control = $MainButtons
@onready var singleplayer_btn: Button = $MainButtons/HBoxContainer/Singleplayer


func _ready() -> void:
	if OS.has_feature("server"):
		Net.player_name = "--server"
		var port = Net.PORT
		var config := ConfigFile.new()
		var err := config.load("server.property")
		if err == OK:
			port = config.get_value("Server", "port", port)
			Net.game_speed = config.get_value("Server", "game_speed", Net.game_speed)
			var map_path: String = config.get_value("Server", "map_path", "")
			if map_path != "":
				var file := FileAccess.open(map_path, FileAccess.READ)
				if file:
					Net.map_info = file.get_var() as Dictionary
				else:
					print(file.get_error())
		if Net.create_server(port, 4):
			get_tree().change_scene_to_file("res://ui/lobby.tscn")
		else:
			print("Can't open server, please restart game and try again!")
		return
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
