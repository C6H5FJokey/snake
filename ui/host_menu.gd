extends Control

signal back_pressed
signal host_pressed(port: int)

@onready var player_name_edit: LineEdit = $VBoxContainer/InputForm/PlayerName
@onready var port: LineEdit = $VBoxContainer/InputForm/Port
@onready var echo: Label = $VBoxContainer/Control/Echo

var echo_color: Color : set = _set_echo_color, get = _get_echo_color
var player_name: String: set = _set_player_name, get = _get_player_name

func _ready() -> void:
	player_name_edit.grab_focus.call_deferred()
	port.placeholder_text = str(Net.PORT)

func _on_back_pressed() -> void:
	player_name_edit.text = ""
	port.text = ""
	echo.text = ""
	back_pressed.emit()


func _on_host_pressed() -> void:
	if _check_input():
		host_pressed.emit(int(port.text) if port.text else Net.PORT)


func _check_input() -> bool:
	_set_echo_color(Color.RED)
	if player_name_edit.text == "":
		echo.text = "Please input player name!"
		return false
	echo.text = "Waiting..."
	_set_echo_color(Color.WHITE)
	return true


func _set_echo_color(v: Color) -> void:
	echo.label_settings.font_color = v


func _get_echo_color() -> Color:
	return echo.label_settings.font_color


func _set_player_name(v: String) -> void:
	Net.player_name = v
	player_name_edit.text = v


func _get_player_name() -> String:
	return player_name_edit.text


