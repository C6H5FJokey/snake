extends Node
## Persistent ENet session. All RPCs target /root/Net, never a replaceable scene.

signal lobby_updated
signal connection_confirmed
signal connection_error(message: String)
signal match_prepared
signal snapshot_received(state: Dictionary)
signal countdown_updated(value: int)
signal returned_to_lobby(reason: String)
signal session_closed(reason: String)

const PORT: int = 4433
const MAX_PLAYERS: int = 4

var player_info: Dictionary = {}
var ready_dict: Dictionary = {}
var map_info: Dictionary = Game.map_info.duplicate(true)
var game_speed: float = 1.0
var player_name: String = "Player"
var status_message: String = ""
var phase: String = "offline"
var round_id: int = 0
var round_config: Dictionary = {}
var latest_snapshot: Dictionary = {}
var countdown_value: int = 3
var auto_change_scene: bool = true
var load_timeout_seconds: float = 30.0
var countdown_step_seconds: float = 1.0
var simulation: MatchSimulation
var _waiting_for: Dictionary = {}
var _loading_elapsed: float = 0.0
var _countdown_elapsed: float = 0.0
var _step_elapsed: float = 0.0


func _ready() -> void:
	# Clients talk only to the host; the roster is our reliable lobby state.
	# Disabling peer relay also avoids engine-generated disconnect notifications
	# being sent to another connection closing in the same ENet poll.
	var scene_multiplayer := multiplayer as SceneMultiplayer
	scene_multiplayer.server_relay = false
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func create_client(address: String, port: int) -> bool:
	leave_session()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port, 3) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	phase = "connecting"
	return true


func create_server(port: int, max_client: int = 3) -> bool:
	leave_session()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, max_client, 3) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	phase = "lobby"
	player_info[1] = {"name": player_name, "color": Game.player_1_color,
		"dedicated": player_name == "--server"}
	_publish_lobby()
	return true


func leave_session() -> void:
	phase = "offline"
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	player_info.clear()
	ready_dict.clear()
	round_config.clear()
	latest_snapshot.clear()
	_waiting_for.clear()
	simulation = null
	round_id = 0
	_step_elapsed = 0.0


func set_profile(new_name: String, color: Color) -> void:
	player_name = new_name
	if multiplayer.is_server():
		_update_profile(1, new_name, color)
	else:
		_register_player.rpc_id(1, new_name, color)


@rpc("any_peer", "call_remote", "reliable", 0)
func _register_player(new_name: String, color: Color) -> void:
	if multiplayer.is_server():
		_update_profile(multiplayer.get_remote_sender_id(), new_name, color)


func _update_profile(id: int, new_name: String, color: Color) -> void:
	if phase != "lobby" or id <= 0 or (id != 1 and not multiplayer.get_peers().has(id)):
		return
	if new_name.strip_edges().is_empty():
		return
	player_info[id] = {"name": new_name.left(64), "color": color,
		"dedicated": id == 1 and new_name == "--server"}
	ready_dict.clear()
	_publish_lobby()


func set_ready(value: bool) -> void:
	if multiplayer.is_server():
		_update_ready(1, value)
	else:
		_submit_ready.rpc_id(1, value)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_ready(value: bool) -> void:
	if multiplayer.is_server():
		_update_ready(multiplayer.get_remote_sender_id(), value)


func _update_ready(id: int, value: bool) -> void:
	if phase != "lobby" or not player_info.has(id) or player_info[id].dedicated:
		return
	ready_dict[id] = value
	_publish_lobby()
	var players: Array = match_players()
	var all_registered: bool = player_info.size() == multiplayer.get_peers().size() + 1
	if all_registered and not players.is_empty() and players.all(func(player: Dictionary) -> bool: return ready_dict.get(player.id, false)):
		_prepare_round()


func set_game_settings(new_map: Dictionary, speed: float) -> bool:
	if not multiplayer.is_server() or phase != "lobby" or not is_finite(speed) or speed < 0.5 or speed > 5.0:
		return false
	var layout := MapResource.new()
	if not layout.from_dict(new_map):
		return false
	map_info = layout.to_dict()
	game_speed = speed
	ready_dict.clear()
	_publish_lobby()
	return true


func match_players() -> Array:
	var players: Array = []
	var ids: Array = player_info.keys()
	ids.sort()
	for id: int in ids:
		if not player_info[id].dedicated:
			var player: Dictionary = player_info[id].duplicate(true)
			player["id"] = id
			players.append(player)
	return players


func _publish_lobby() -> void:
	var state: Dictionary = {"players": player_info.duplicate(true), "ready": ready_dict.duplicate(),
		"map": map_info.duplicate(true), "speed": game_speed}
	_receive_lobby.rpc(state)


@rpc("authority", "call_local", "reliable", 0)
func _receive_lobby(state: Dictionary) -> void:
	player_info = state.players
	ready_dict = state.ready
	map_info = state.map
	game_speed = state.speed
	if phase == "connecting" and player_info.has(multiplayer.get_unique_id()):
		phase = "lobby"
		connection_confirmed.emit()
	lobby_updated.emit()


func _prepare_round() -> void:
	var players: Array = match_players()
	var layout := MapResource.new()
	if not layout.from_dict(map_info) or not layout.validate(players.size()).is_empty() or players.size() > MAX_PLAYERS:
		ready_dict.clear()
		_publish_lobby()
		connection_error.emit("Map does not have valid spawns for these players.")
		return
	simulation = MatchSimulation.new()
	simulation.configure(layout, players, randi())
	_waiting_for.clear()
	for id: int in player_info:
		_waiting_for[id] = true
	_loading_elapsed = 0.0
	multiplayer.multiplayer_peer.refuse_new_connections = true
	var config: Dictionary = {"map": layout.to_dict(), "players": players,
		"step_seconds": 0.5 / game_speed, "initial": simulation.snapshot()}
	_load_round.rpc(round_id + 1, config)


@rpc("authority", "call_local", "reliable", 0)
func _load_round(id: int, config: Dictionary) -> void:
	if id <= round_id:
		return
	round_id = id
	round_config = config
	latest_snapshot = config.initial.duplicate(true)
	latest_snapshot["round_id"] = id
	latest_snapshot["step_seconds"] = config.step_seconds
	phase = "loading"
	match_prepared.emit()
	_navigate("res://game_scene/online_scene.tscn")


func notify_scene_ready() -> void:
	if phase != "loading":
		return
	if multiplayer.is_server():
		_accept_scene_ready(1, round_id)
	else:
		_scene_ready.rpc_id(1, round_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func _scene_ready(id: int) -> void:
	if multiplayer.is_server():
		_accept_scene_ready(multiplayer.get_remote_sender_id(), id)


func _accept_scene_ready(peer_id: int, id: int) -> void:
	if phase != "loading" or id != round_id or not _waiting_for.has(peer_id):
		return
	_waiting_for.erase(peer_id)
	if _waiting_for.is_empty():
		_countdown_elapsed = 0.0
		_receive_countdown.rpc(round_id, 3)


@rpc("authority", "call_local", "reliable", 0)
func _receive_countdown(id: int, value: int) -> void:
	if id != round_id or phase not in ["loading", "countdown"]:
		return
	phase = "countdown"
	countdown_value = value
	countdown_updated.emit(value)


func submit_direction(direction: Vector2i) -> void:
	if phase not in ["countdown", "running"]:
		return
	if multiplayer.is_server():
		_accept_direction(1, round_id, direction)
	else:
		_submit_direction.rpc_id(1, round_id, direction)


@rpc("any_peer", "call_remote", "reliable", 1)
func _submit_direction(id: int, direction: Vector2i) -> void:
	if multiplayer.is_server():
		_accept_direction(multiplayer.get_remote_sender_id(), id, direction)


func _accept_direction(peer_id: int, id: int, direction: Vector2i) -> void:
	if id == round_id and phase in ["countdown", "running"] and simulation != null:
		simulation.submit_direction(peer_id, direction)


func _physics_process(delta: float) -> void:
	if phase == "offline" or not multiplayer.is_server():
		return
	match phase:
		"loading":
			_loading_elapsed += delta
			if _loading_elapsed >= load_timeout_seconds:
				_return_to_lobby.rpc("Loading timed out.")
				_publish_lobby()
		"countdown":
			_countdown_elapsed += delta
			if _countdown_elapsed >= countdown_step_seconds:
				_countdown_elapsed -= countdown_step_seconds
				if countdown_value > 0:
					_receive_countdown.rpc(round_id, countdown_value - 1)
				else:
					simulation.start()
					_step_elapsed = 0.0
					_receive_checkpoint.rpc(_make_snapshot())
		"running":
			_step_elapsed += delta
			var interval: float = round_config.step_seconds
			while _step_elapsed >= interval and phase == "running":
				_step_elapsed -= interval
				simulation.step()
				var state: Dictionary = _make_snapshot()
				if state.phase == "finished":
					_receive_checkpoint.rpc(state)
				else:
					_receive_snapshot.rpc(state)


func _make_snapshot() -> Dictionary:
	var state: Dictionary = simulation.snapshot()
	state["round_id"] = round_id
	state["step_seconds"] = round_config.step_seconds
	return state


@rpc("authority", "call_local", "unreliable", 2)
func _receive_snapshot(state: Dictionary) -> void:
	accept_snapshot(state)


@rpc("authority", "call_local", "reliable", 0)
func _receive_checkpoint(state: Dictionary) -> void:
	accept_snapshot(state)


func accept_snapshot(state: Dictionary) -> bool:
	if phase not in ["loading", "countdown", "running", "finished"] or state.get("round_id", -1) != round_id:
		return false
	if state.tick < latest_snapshot.get("tick", -1):
		return false
	if latest_snapshot.get("phase") == "finished" and state.phase != "finished":
		return false
	if state.tick == latest_snapshot.get("tick", -1) and state.phase == latest_snapshot.get("phase"):
		return false
	latest_snapshot = state.duplicate(true)
	phase = state.phase
	snapshot_received.emit(latest_snapshot)
	return true


func request_return_to_lobby() -> void:
	if multiplayer.is_server():
		_accept_return()
	else:
		_request_return.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_return() -> void:
	if multiplayer.is_server() and player_info.has(multiplayer.get_remote_sender_id()):
		_accept_return()


func _accept_return() -> void:
	if phase == "finished":
		_return_to_lobby.rpc("")
		_publish_lobby()


@rpc("authority", "call_local", "reliable", 0)
func _return_to_lobby(reason: String) -> void:
	status_message = reason
	phase = "lobby"
	ready_dict.clear()
	latest_snapshot.clear()
	round_config.clear()
	_waiting_for.clear()
	simulation = null
	if multiplayer.is_server():
		multiplayer.multiplayer_peer.refuse_new_connections = false
	returned_to_lobby.emit(reason)
	_navigate("res://ui/lobby.tscn")


func _on_connected() -> void:
	_register_player.rpc_id(1, player_name, Game.player_1_color)


func _on_connection_failed() -> void:
	leave_session()
	connection_error.emit("Connection failed.")


func _on_server_disconnected() -> void:
	if phase == "offline":
		return
	leave_session()
	status_message = "Server disconnected."
	session_closed.emit("Server disconnected.")
	_navigate("res://ui/main_menu.tscn")


func _on_peer_disconnected(id: int) -> void:
	if phase == "offline" or not multiplayer.is_server():
		return
	player_info.erase(id)
	ready_dict.erase(id)
	if phase == "running" and simulation != null:
		simulation.mark_disconnected(id)
	# ENet can report several disconnects in one poll. Broadcasting inside that
	# callback can still visit another peer whose channel storage was already freed.
	_finish_peer_disconnect.call_deferred()


func _finish_peer_disconnect() -> void:
	if phase == "offline" or not multiplayer.is_server():
		return
	if phase == "loading" or phase == "countdown":
		_return_to_lobby.rpc("A player disconnected while loading.")
	_publish_lobby()


func _navigate(path: String) -> void:
	if auto_change_scene:
		get_tree().change_scene_to_file.call_deferred(path)
