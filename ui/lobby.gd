extends Control

const player_panel_res = preload("res://ui/player_panel.tscn")

@onready var player_container: VBoxContainer = $PlayerContainer
@onready var ready_btn: Button = $Ready

var player_id: Array
var ready_dict: Dictionary = {}

func _ready() -> void:
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_on_multiplayer_server_disconnected()
		return
	if multiplayer.get_unique_id() == 1 and Net.player_name == "--server":
		ready_btn.hide()
	multiplayer.multiplayer_peer.refuse_new_connections = false
	Net.set_my_player_name(multiplayer.get_unique_id(), Net.player_name)
	player_id = Array(multiplayer.get_peers())
	player_id.append(multiplayer.get_unique_id())
	player_id.sort()
	_update_player_container()
	ready_btn.grab_focus.call_deferred()
	
	Net.set_my_player_name.rpc(multiplayer.get_unique_id(), Net.player_name)
	Net.player_info_updated.connect(_update_player_container)
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	

func _on_multiplayer_peer_connected(id: int):
	player_id.insert(player_id.bsearch(id), id)
	if is_multiplayer_authority():
		Net.confirm_connection.rpc_id(id)
	Net.set_my_player_name.rpc_id(id, multiplayer.get_unique_id() ,Net.player_name)


func _on_multiplayer_peer_disconnected(id: int):
	Net.player_info.erase(id)
	player_id.erase(id)
	_update_player_container()


func _on_multiplayer_server_disconnected() -> void:
	var dialog := AcceptDialog.new()
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.dialog_text = "Server_was_disconnected"
	get_window().add_child(dialog)
	dialog.popup_centered()
	multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _update_player_container() -> void:
	for player_panel in player_container.get_children():
		if not player_id.has(player_panel.name.to_int()): # or player_panel.name == "1" and Net.player_info.get(player_panel.name.to_int()) == "--server"
			player_container.remove_child(player_panel)
			player_panel.queue_free()
	var index: int = 0
	for id in player_id:
		if id == 1 and Net.player_info.get(id) == "--server":
			continue
		var player_planel: PlayerPanel = player_container.get_node_or_null(str(id))
		if not player_planel:
			player_planel = create_player_panel(id)
			player_container.add_child(player_planel)
			player_container.move_child(player_planel, index)
			player_planel.player_name.text = Net.player_info.get(id, "Player")
			player_planel.owner = self
		player_planel.no.text = "%dP"%(index+1)
		index += 1
		if is_multiplayer_authority() and id != multiplayer.get_unique_id():
			player_planel.remove_btn.show()


func _on_back_pressed() -> void:
	multiplayer.server_disconnected.disconnect(_on_multiplayer_server_disconnected)
	multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_player_panel_player_removed(id: int) -> void:
	if is_multiplayer_authority():
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _on_ready_toggled(button_pressed: bool) -> void:
	_ready_toggled.rpc(multiplayer.get_unique_id(), button_pressed)


@rpc("any_peer", "call_local")
func _ready_toggled(id: int, pressd: bool) -> void:
	ready_dict[id] = pressd
	var player_panel: PlayerPanel = player_container.get_node(str(id))
	player_panel.ready_label.visible = pressd
	if is_multiplayer_authority():
		if player_id.all(func(id: int): return ready_dict.get(id, false)):
			start_game.rpc()


@rpc("call_local")
func start_game():
	multiplayer.multiplayer_peer.refuse_new_connections = true
	get_tree().change_scene_to_file("res://game_scene/online_scene.tscn")


func create_player_panel(id: int) -> PlayerPanel:
	var player_panel: PlayerPanel = player_panel_res.instantiate()
	player_panel.name = str(id)
	player_panel.player_removed.connect(_on_player_panel_player_removed.bind(id))
	return player_panel
