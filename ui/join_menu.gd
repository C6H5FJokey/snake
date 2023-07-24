extends Control

@onready var player_name: LineEdit = $VBoxContainer/InputForm/PlayerName
@onready var address: LineEdit = $VBoxContainer/InputForm/Address
@onready var echo: Label = $VBoxContainer/Control/Echo
@onready var port: LineEdit = $VBoxContainer/InputForm/Port
@onready var join: Button = $VBoxContainer/HBoxContainer/Join
@onready var connect_timer: Timer = $ConnectTimer

var echo_color: Color : set = _set_echo_color, get = _get_echo_color

func _ready() -> void:
	player_name.grab_focus.call_deferred()
	port.placeholder_text = str(Net.PORT)
	Net.connection_confirmed.connect(
		func():
			connect_timer.stop()
			get_tree().change_scene_to_file("res://ui/lobby.tscn")	
	)


func _on_back_pressed() -> void:
	connect_timer.stop()
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		multiplayer.multiplayer_peer.close()
		join.disabled = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_join_pressed() -> void:
	if not _check_input():
		return
	Net.player_name = player_name.text
	if not Net.create_client(address.text, int(port.text) if port.text else Net.PORT):
		echo.text = "Can't join game!"
		echo_color = Color.RED
	else:
		join.disabled = true
		connect_timer.start()


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


func _on_connect_timer_timeout() -> void:
	join.disabled = false
	multiplayer.multiplayer_peer.close()
	echo.text = "Join game timeout!"
	echo_color = Color.RED
