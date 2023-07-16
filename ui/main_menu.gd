extends Control

@onready var main_buttons: Control = $ColorRect/MainButtons
@onready var host_menu: Control = $ColorRect/HostMenu
@onready var join_menu: Control = $ColorRect/JoinMenu
@onready var connect_timer: Timer = $ConnectTimer
@onready var singleplayer_btn: Button = $ColorRect/MainButtons/HBoxContainer/Singleplayer


func _ready() -> void:
	singleplayer_btn.grab_focus.call_deferred()
	Net.connection_confirmed.connect(
		func():
			connect_timer.stop()
			get_tree().change_scene_to_file("res://ui/lobby.tscn")	
	)


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
	connect_timer.stop()
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		multiplayer.multiplayer_peer.close()
		(join_menu.join as Button).disabled = false
	main_buttons.show()


func _on_host_menu_host_pressed(port: int) -> void:
	if not Net.create_server(port):
		host_menu.echo.text = "Can't host game!"
		host_menu.echo_color = Color.RED
	else:
		get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _on_join_menu_join_pressed(address, port) -> void:
	if not Net.create_client(address, port):
		join_menu.echo.text = "Can't join game!"
		join_menu.echo_color = Color.RED
	else:
		(join_menu.join as Button).disabled = true
		connect_timer.start()


func _on_connect_timer_timeout() -> void:
	(join_menu.join as Button).disabled = false
	multiplayer.multiplayer_peer.close()
	join_menu.echo.text = "Join game timeout!"
	join_menu.echo_color = Color.RED
