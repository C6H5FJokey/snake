extends Control

@onready var player_name: LineEdit = $VBoxContainer/InputForm/PlayerName
@onready var port: LineEdit = $VBoxContainer/InputForm/Port
@onready var echo: Label = $VBoxContainer/Control/Echo

var echo_color: Color : set = _set_echo_color, get = _get_echo_color

func _ready() -> void:
	player_name.grab_focus.call_deferred()
	port.placeholder_text = str(Net.PORT)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_host_pressed() -> void:
	if not _check_input():
		return
	var max_clients: int = 3 if not player_name.text == "--server" else 4
	if not Net.create_server(int(port.text) if port.text else Net.PORT, max_clients):
		echo.text = "Can't host game!"
		echo_color = Color.RED
	else:
		Net.player_name = player_name.text
		get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _check_input() -> bool:
	_set_echo_color(Color.RED)
	if player_name.text == "":
		echo.text = "Please input player name!"
		return false
	echo.text = "Waiting..."
	_set_echo_color(Color.WHITE)
	return true


func _set_echo_color(v: Color) -> void:
	echo.label_settings.font_color = v


func _get_echo_color() -> Color:
	return echo.label_settings.font_color

