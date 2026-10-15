extends Node
## Multi-process participant using real menus, match scenes and Net RPCs.

var role: String = "host"
var scenario: String = "clean"
var cycles: int = 20
var port: int = 25433
var _completed: int = 0
var _sent_round: int = -1
var _finished_at: int = 0
var _started_at: int = 0
var _last_ready: int = -1000
var _loading_round: int = -1
var _load_at: int = 0
var _timeout_seen: bool = false
var _input_seen: bool = false
var _disconnect_sent: bool = false


func _ready() -> void:
	get_tree().root.get_node("Bgm").stop()
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.split("=", true, 1)
		if pair.size() != 2:
			continue
		match pair[0]:
			"--role": role = pair[1]
			"--scenario": scenario = pair[1]
			"--cycles": cycles = int(pair[1])
			"--port": port = int(pair[1])
	Net.player_name = "--server" if scenario == "dedicated" and role == "host" else "Same"
	Net.countdown_step_seconds = 0.03
	Net.load_timeout_seconds = 0.3 if scenario == "timeout" else 10.0
	Net.snapshot_received.connect(_on_snapshot)
	Net.returned_to_lobby.connect(_on_return)
	Net.match_prepared.connect(_on_prepared)
	Net.session_closed.connect(_on_session_closed)
	_started_at = Time.get_ticks_msec()
	if role == "host":
		if not Net.create_server(port, 4 if scenario == "dedicated" else 3):
			_fail("bind failed")
			return
		Net.set_game_settings(Net.map_info, 5.0)
		get_tree().change_scene_to_file.call_deferred("res://ui/lobby.tscn")
	else:
		Net.auto_change_scene = false
		if not Net.create_client("127.0.0.1", port):
			_fail("client creation failed")


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _started_at > 90000:
		_fail("timeout phase=%s completed=%d" % [Net.phase, _completed])
		return
	if role != "host" and _loading_round == Net.round_id and Net.phase == "loading" and now >= _load_at:
		_loading_round = -1
		get_tree().change_scene_to_file("res://game_scene/online_scene.tscn")
	if Net.phase == "lobby":
		if _completed >= cycles:
			if role != "host" or multiplayer.get_peers().is_empty():
				if scenario == "timeout" and not _timeout_seen:
					_fail("loading timeout was not exercised")
					return
				if role != "host" and not _input_seen:
					_fail("reliable input was not observed in authoritative state")
					return
				print("NETWORK_OK role=%s scenario=%s cycles=%d" % [role, scenario, _completed])
				Net.leave_session()
				get_tree().quit()
			return
		if Net.player_info.size() == 3 and now - _last_ready > 200:
			var id: int = multiplayer.get_unique_id()
			if not Net.ready_dict.get(id, false) and not Net.player_info.get(id, {}).get("dedicated", false):
				_last_ready = now
				Net.set_ready(true)
	if Net.phase == "countdown" and _sent_round != Net.round_id and role != "host":
		_sent_round = Net.round_id
		var players: Array = Net.round_config.players
		for i: int in players.size():
			if players[i].id == multiplayer.get_unique_id():
				var initial: Vector2i = Net.latest_snapshot.snakes[i].direction
				Net.submit_direction(_test_direction(initial))
	if role == "host" and Net.phase == "finished" and now - _finished_at > 300:
		Net.request_return_to_lobby()
	if role == "host" and Net.phase == "running" and Net.simulation.tick >= 1 and not _disconnect_sent:
		if scenario == "disconnect":
			_disconnect_sent = true
			multiplayer.multiplayer_peer.disconnect_peer(multiplayer.get_peers()[0])
		elif scenario == "server_loss":
			Net.leave_session()
			print("SERVER_CLOSED_OK")
			get_tree().quit()


func _on_prepared() -> void:
	if role != "host":
		_loading_round = Net.round_id
		_load_at = Time.get_ticks_msec() + (1000 if scenario == "timeout" and Net.round_id == 1 and role == "client2" else 150)


func _on_return(reason: String) -> void:
	if reason == "Loading timed out.":
		_timeout_seen = true
		print("TIMEOUT_RECOVERED role=" + role)
		Net.load_timeout_seconds = 10.0
	if role != "host":
		get_tree().change_scene_to_file.call_deferred("res://ui/lobby.tscn")


func _on_snapshot(state: Dictionary) -> void:
	if role != "host" and state.tick > 0:
		for i: int in state.snakes.size():
			var snake: Dictionary = state.snakes[i]
			if snake.id == multiplayer.get_unique_id():
				var layout := MapResource.new()
				layout.from_dict(Net.round_config.map)
				var initial: Vector2i = layout.move_direction[i]
				if snake.direction == _test_direction(initial):
					_input_seen = true
	if state.phase == "running":
		print("STATE round=%d tick=%d hash=%s" % [state.round_id, state.tick, var_to_str(state).sha256_text()])
	if state.phase == "finished":
		_completed += 1
		_finished_at = Time.get_ticks_msec()
		print("RESULT round=%d tick=%d hash=%s" % [state.round_id, state.tick, var_to_str(state).sha256_text()])


func _fail(message: String) -> void:
	push_error("NETWORK_FAIL %s %s" % [role, message])
	Net.leave_session()
	get_tree().quit(1)


func _test_direction(initial: Vector2i) -> Vector2i:
	return Vector2i(-initial.y, initial.x) if scenario == "fault" else Vector2i(initial.y, -initial.x)


func _on_session_closed(_reason: String) -> void:
	if Net.phase != "offline" or not Net.player_info.is_empty() or not Net.latest_snapshot.is_empty():
		_fail("disconnect did not clear cached session")
	elif scenario == "disconnect":
		print("NETWORK_DISCONNECTED_OK role=" + role)
		get_tree().quit()
	elif scenario == "server_loss":
		print("SERVER_LOSS_OK role=" + role)
		get_tree().quit()
