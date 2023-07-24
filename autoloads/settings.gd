extends Node

var master_volume: float = 0.5
var music_volume: float = 1.0
var sound_volume: float = 1.0
var tween_speed: float = 0.5
var show_scores: bool = true


func _ready() -> void:
	load_settings()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_settings()


func save_settings():
	var config := ConfigFile.new()
	config.set_value("Volume", "master", master_volume)
	config.set_value("Volume", "music", music_volume)
	config.set_value("Volume", "sound", sound_volume)
	config.set_value("Game", "tween_speed", tween_speed)
	config.set_value("Game", "show_score", show_scores)
	config.save("user://settings.cfg")


func load_settings():
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	if err != OK:
		return
	var volumes: Array
	volumes = ["Master", "Music", "Sound"]
	for volume in volumes:
		var bus_index := AudioServer.get_bus_index(volume)
		set("%s_volume"%volume.to_lower(), config.get_value("Volume", volume.to_lower(), get("%s_volume"%volume.to_lower())))
		AudioServer.set_bus_volume_db(
			bus_index,
			linear_to_db(get("%s_volume"%volume.to_lower()))
		)
	tween_speed = config.get_value("Game", "tween_speed", tween_speed)
	show_scores = config.get_value("Game", "show_scores", show_scores)
