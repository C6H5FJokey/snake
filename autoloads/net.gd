extends Node

signal connection_confirmed
signal player_info_updated
signal updated(path: NodePath, property: String, value: Variant)

const PORT: int = 4433

var player_info: Dictionary = {}
var ready_dict: Dictionary = {}
var map_info: Dictionary = Game.map_info
var game_speed: float = 1.0
var player_name: String = "Player"

func create_client(address: String, port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return false
	multiplayer.multiplayer_peer = peer
	return true


func create_server(port: int, max_client: int = 3) -> bool:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, max_client)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return false
	multiplayer.multiplayer_peer = peer	
	return true

@rpc
func confirm_connection():
	connection_confirmed.emit()
	
@rpc("any_peer")
func set_my_player_info(id: int, name: String, color: Color):
	player_info[id] = {
		"name": name,
		"color": color
	}
	player_info_updated.emit()


func request_update(id: int, path: NodePath, property: String, from_id: int = 1):
	if from_id == 1:
		send_update.rpc_id(get_node(path).get_multiplayer_authority(), id, path, property)
	else:
		send_update.rpc_id(from_id, id, path, property)

@rpc("any_peer")
func send_update(id: int, path: NodePath, property: String):
	if get_node_or_null(path):
		update.rpc_id(id, path, property, get_node(path).get(property), multiplayer.get_unique_id())

@rpc("any_peer")
func update(path: NodePath, property: String, value: Variant, from_id: int):
	updated.emit(path, property, value, from_id)
