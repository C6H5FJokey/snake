extends Control

signal back_pressed
signal host_pressed

@onready var player_name: LineEdit = $VBoxContainer/InputForm/PlayerName
@onready var port: LineEdit = $VBoxContainer/InputForm/Port
@onready var echo: Label = $VBoxContainer/Control/Echo

var echo_color: Color : set = _set_echo_color, get = _get_echo_color

func _on_back_pressed() -> void:
	player_name.text = ""
	port.text = ""
	echo.text = ""
	back_pressed.emit()


func _on_host_pressed() -> void:
	if _check_input():
		host_pressed.emit()


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