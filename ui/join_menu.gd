extends Control

signal back_pressed
signal join_pressed(address: String, port: int)

@onready var player_name: LineEdit = $VBoxContainer/InputForm/PlayerName
@onready var address: LineEdit = $VBoxContainer/InputForm/Address
@onready var echo: Label = $VBoxContainer/Control/Echo
@onready var port: LineEdit = $VBoxContainer/InputForm/Port
@onready var join: Button = $VBoxContainer/HBoxContainer/Join

var echo_color: Color : set = _set_echo_color, get = _get_echo_color

func _ready() -> void:
	player_name.grab_focus.call_deferred()
	port.placeholder_text = str(Net.PORT)


func _on_back_pressed() -> void:
	player_name.text = ""
	address.text = ""
	echo.text = ""
	back_pressed.emit()


func _on_join_pressed() -> void:
	if _check_input():
		Net.player_name = player_name.text
		join_pressed.emit(address.text, int(port.text) if port.text else Net.PORT)


func _check_input() -> bool:
	_set_echo_color(Color.RED)
	if player_name.text == "":
		echo.text = "Please input player name!"
		return false
	if address.text == "":
		echo.text = "Please input address!"
		return false
	echo.text = "Waiting..."
	_set_echo_color(Color.WHITE)
	return true


func _set_echo_color(v: Color) -> void:
	echo.label_settings.font_color = v


func _get_echo_color() -> Color:
	return echo.label_settings.font_color
