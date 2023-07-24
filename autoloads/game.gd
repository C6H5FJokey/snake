extends Node

enum{
	SINGLE,
	MULTIPLAYER
}

var play_mode: int = SINGLE

var map_info: Dictionary = preload("res://map/default.tres").to_dict()
var map_resource: MapResource = MapResource.new()
var game_speed: float = 1.0
var player_1_color: Color = Color("d3a068")
var player_2_color: Color = Color("567b79")

func _ready() -> void:
	load_settings()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_settings()


func save_settings():
	var config := ConfigFile.new()
	config.set_value("Game", "player_1_color", player_1_color)
	config.set_value("Game", "player_2_color", player_2_color)
	config.save("user://game.cfg")


func load_settings():
	var config := ConfigFile.new()
	var err := config.load("user://game.cfg")
	if err != OK:
		return
	player_1_color = config.get_value("Game", "player_1_color", player_1_color)
	player_2_color = config.get_value("Game", "player_2_color", player_2_color)
