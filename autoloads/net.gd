extends Node

signal connection_confirmed
signal player_info_updated

const PORT: int = 4433

var player_info: Dictionary = {}
var player_name: String

func create_client(address: String, port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return false
	multiplayer.multiplayer_peer = peer
	return true


func create_server(port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 3)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return false
	multiplayer.multiplayer_peer = peer	
	return true

@rpc
func confirm_connection():
	connection_confirmed.emit()
	
@rpc("any_peer")
func set_my_player_name(id: int, player_name: String):
	player_info[id] = player_name
	player_info_updated.emit()

