extends Node
## Run: godot --headless --path . res://tests/run_tests.tscn

var checks: int = 0
var failures: int = 0
var _scenes_complete: bool = false
var root: Window:
	get:
		return get_tree().root


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _fixture(bodies: Array, directions: Array, dimensions: Vector2i = Vector2i(12, 12)) -> MatchSimulation:
	var layout := MapResource.new()
	layout.size = dimensions
	layout.map.fill(MapResource.EMPTY)
	var players: Array = []
	for i: int in bodies.size():
		layout.start_pos.append(Vector2i(6, 6))
		layout.move_direction.append(directions[i])
		players.append({"id": i + 1, "name": "Same", "color": Color.WHITE})
	var sim := MatchSimulation.new()
	sim.configure(layout, players, 1234)
	for i: int in bodies.size():
		sim.snakes[i].body.assign(bodies[i])
	sim.start()
	sim.food = Vector2i(-1, -1)
	return sim


func _run() -> void:
	root.get_node("Bgm").stop()
	_test_rules()
	_test_maps()
	_test_snapshot_order()
	_test_settings()
	await _test_touch()
	await _test_view()
	await _test_scenes()
	await _test_connection_failure()
	check(_scenes_complete, "scene suite reached its end without a script error")
	print("TEST_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _test_settings() -> void:
	var settings: Node = root.get_node("Settings")
	var original: bool = settings.show_scores
	settings.show_scores = false
	check(settings.save_settings("res://.godot/test-settings.cfg") == OK, "settings save to isolated fixture")
	settings.show_scores = true
	settings.load_settings("res://.godot/test-settings.cfg")
	check(not settings.show_scores, "score visibility survives settings reload")
	var legacy := ConfigFile.new()
	legacy.set_value("Game", "show_score", false)
	legacy.save("res://.godot/test-settings-legacy.cfg")
	settings.show_scores = true
	settings.load_settings("res://.godot/test-settings-legacy.cfg")
	check(not settings.show_scores, "old score key migrates on load")
	settings.show_scores = original


func _test_connection_failure() -> void:
	var net: Node = root.get_node("Net")
	net.auto_change_scene = false
	var started: bool = net.create_client("127.0.0.1", 25439)
	check(started, "ENet starts a connection to a closed local port")
	if started:
		net.multiplayer.multiplayer_peer.get_peer(1).set_timeout(4, 100, 500)
		var deadline: int = Time.get_ticks_msec() + 5000
		while net.phase != "offline" and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		check(net.phase == "offline" and net.player_info.is_empty(), "connection failure clears the session")
	net.leave_session()
	net.auto_change_scene = true


func _test_rules() -> void:
	var sim: MatchSimulation = _fixture([[Vector2i(2, 2), Vector2i(1, 2)]], [Vector2i.RIGHT])
	sim.layout.map[sim.layout.as_index(Vector2i(3, 2))] = MapResource.WALL
	sim.step()
	check(sim.snakes[0].dead and sim.phase == "finished", "wall collision finishes single-player")
	sim = _fixture([[Vector2i(0, 2), Vector2i(1, 2)]], [Vector2i.LEFT])
	sim.step()
	check(sim.snakes[0].body[0] == Vector2i(11, 2) and not sim.snakes[0].dead, "wrap")
	sim = _fixture([[Vector2i(2, 2), Vector2i(1, 2)]], [Vector2i.RIGHT])
	sim.food = Vector2i(3, 2)
	sim.step()
	check(sim.snakes[0].body.size() == 3 and sim.snakes[0].score == 1, "food grows and scores once")
	check(not sim.snakes[0].body.has(sim.food), "food respawns outside body")
	sim = _fixture([[Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 2)]], [Vector2i.UP])
	sim.submit_direction(1, Vector2i.RIGHT)
	sim.step()
	check(sim.snakes[0].dead, "self collision")
	sim = _fixture([[Vector2i(2, 2), Vector2i(2, 3), Vector2i(1, 3), Vector2i(1, 2)]], [Vector2i.UP])
	sim.submit_direction(1, Vector2i.LEFT)
	sim.step()
	check(not sim.snakes[0].dead, "own vacated tail is traversable")
	sim = _fixture([[Vector2i(2, 2)], [Vector2i(4, 2), Vector2i(3, 2)]], [Vector2i.RIGHT, Vector2i.RIGHT])
	sim.step()
	check(not sim.snakes[0].dead, "other vacated tail is traversable")
	sim = _fixture([[Vector2i(2, 2)], [Vector2i(4, 2), Vector2i(3, 2)]], [Vector2i.RIGHT, Vector2i.RIGHT])
	sim.food = Vector2i(5, 2)
	sim.step()
	check(sim.snakes[0].dead and not sim.snakes[1].dead, "growing tail remains occupied")
	sim = _fixture([[Vector2i(2, 2)], [Vector2i(4, 2), Vector2i(3, 2)]], [Vector2i.RIGHT, Vector2i.RIGHT])
	sim.mark_disconnected(2)
	sim.step()
	check(sim.snakes[0].dead, "dead bodies remain obstacles")
	sim = _fixture([[Vector2i(2, 2)], [Vector2i(4, 2)]], [Vector2i.RIGHT, Vector2i.LEFT])
	sim.step()
	check(sim.snakes.all(func(s: SnakeState) -> bool: return s.dead), "same-cell heads both die")
	check(sim.winner_id == 0, "equal lengths draw")
	sim = _fixture([[Vector2i(2, 2)], [Vector2i(3, 2)]], [Vector2i.RIGHT, Vector2i.LEFT])
	sim.step()
	check(sim.snakes.all(func(s: SnakeState) -> bool: return s.dead), "head exchange kills both")
	var reversed: MatchSimulation = _fixture([[Vector2i(3, 2)], [Vector2i(2, 2)]], [Vector2i.LEFT, Vector2i.RIGHT])
	reversed.step()
	check(reversed.snakes.all(func(s: SnakeState) -> bool: return s.dead), "head exchange is independent of iteration order")
	sim = _fixture([[Vector2i(2, 2)]], [Vector2i.RIGHT])
	sim.submit_direction(1, Vector2i.UP)
	sim.submit_direction(1, Vector2i.LEFT)
	sim.step()
	check(sim.snakes[0].direction == Vector2i.RIGHT, "last intent wins, invalid reversal is ignored")
	sim.submit_direction(1, Vector2i.DOWN)
	sim.step()
	check(sim.snakes[0].direction == Vector2i.DOWN, "valid turn is consumed")
	sim = _fixture([[Vector2i(0, 0), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0)]], [Vector2i.RIGHT], Vector2i(4, 1))
	sim.step()
	check(sim.food == Vector2i(-1, -1) and sim.phase == "running", "full board keeps moving without food")
	var full := MatchSimulation.new()
	var full_map := MapResource.new()
	full_map.size = Vector2i(4, 1)
	full_map.map.fill(0)
	full_map.start_pos = [Vector2i(0, 0)]
	full_map.move_direction = [Vector2i.RIGHT]
	full.configure(full_map, [{"id": 1}], 42)
	full.start()
	check(full.food == Vector2i(-1, -1), "initial full board food generation has an explicit empty result")
	sim = _fixture([[Vector2i(1, 1), Vector2i(0, 1)], [Vector2i(1, 3), Vector2i(0, 3)], [Vector2i(1, 5)]], [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT])
	for snake: SnakeState in sim.snakes:
		snake.dead = true
	sim.step()
	check(sim.winner_id == 0, "two longest snakes remain a draw even with a shorter third snake")
	sim = _fixture([[Vector2i(1, 1), Vector2i(0, 1)], [Vector2i(1, 3)]], [Vector2i.RIGHT, Vector2i.RIGHT])
	sim.mark_disconnected(1)
	sim.step()
	check(sim.winner_id == 2, "survivor wins regardless of length")
	var a: MatchSimulation = _fixture([[Vector2i(4, 4)]], [Vector2i.RIGHT])
	var b: MatchSimulation = _fixture([[Vector2i(4, 4)]], [Vector2i.RIGHT])
	a.food = Vector2i(5, 4)
	b.food = a.food
	for i: int in 300:
		var direction: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][(i / 5) % 4]
		a.submit_direction(1, direction)
		b.submit_direction(1, direction)
		a.step()
		b.step()
	check(a.snapshot() == b.snapshot(), "seeded simulation is deterministic for the same input sequence")
	var copy: Dictionary = a.snapshot()
	copy.snakes[0]["score"] = 999
	check(a.snakes[0].score != 999, "snapshot does not alias live state")


func _test_maps() -> void:
	var layout: MapResource = load("res://map/default.tres")
	check(layout.validate(4).is_empty(), "default map supports four players")
	for path: String in ["res://default.map", "res://focus_star.map"]:
		var imported := MapResource.new()
		check(imported.load_map(path), "legacy map loads: " + path)
	var copied := MapResource.new()
	check(copied.from_dict(layout.to_dict()), "map dictionary round-trip")
	var before: Dictionary = copied.to_dict()
	var invalid: Dictionary = before.duplicate(true)
	invalid["size"] = Vector2i(-1, 2)
	check(not copied.from_dict(invalid) and copied.to_dict() == before, "invalid import is transactional")
	invalid = before.duplicate(true)
	invalid["start_pos"] = PackedVector2Array([Vector2(4.5, 2)])
	check(not copied.from_dict(invalid), "fractional spawn rejected")
	copied.cell_size = Vector2i(33, 65)
	check(copied.half_cell_size == Vector2(16.5, 32.5), "half-cell follows changed cell size")
	check(copied.clamp(Vector2i(999, 999)) == copied.size - Vector2i.ONE, "clamp stays inside board")
	check(not copied.validate(5).is_empty(), "insufficient spawns rejected")


func _test_snapshot_order() -> void:
	var net: Node = root.get_node("Net")
	net.auto_change_scene = false
	net.phase = "running"
	net.round_id = 7
	net.latest_snapshot = {"tick": 3, "phase": "running"}
	var state: Dictionary = {"round_id": 7, "tick": 5, "phase": "running", "snakes": [], "food": Vector2i(-1, -1)}
	check(net.accept_snapshot(state), "next full snapshot repairs a missed tick")
	state = state.duplicate(true)
	state.tick = 4
	check(not net.accept_snapshot(state), "out of order snapshot rejected")
	state.tick = 6
	state.round_id = 6
	check(not net.accept_snapshot(state), "previous round rejected")
	state.round_id = 7
	state.phase = "finished"
	check(net.accept_snapshot(state), "final reliable checkpoint accepted")
	state.phase = "running"
	state.tick = 7
	check(not net.accept_snapshot(state), "late live state cannot undo final result")
	net.leave_session()
	net.auto_change_scene = true


func _touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	return event


func _drag(index: int, point: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	return event


func _test_touch() -> void:
	var pad: TouchPad = load("res://misc/touch_button.tscn").instantiate()
	root.add_child(pad)
	pad.position = Vector2(40, 80)
	pad.scale = Vector2(1.5, 1.5)
	pad.show()
	var intents: Array[Vector2i] = []
	pad.direction_requested.connect(func(direction: Vector2i) -> void: intents.append(direction))
	var transform: Transform2D = pad.get_global_transform_with_canvas()
	check(pad.handle_touch(_touch(3, transform * Vector2(220, 120), true)), "scaled pad captures press")
	check(intents == [Vector2i.RIGHT], "press immediately submits right")
	pad.handle_touch(_drag(4, transform * Vector2(120, 20)))
	check(intents.size() == 1, "unowned finger ignored")
	pad.handle_touch(_drag(3, transform * Vector2(120, 20)))
	check(intents.back() == Vector2i.UP, "owned finger can slide to another direction")
	var count: int = intents.size()
	pad.handle_touch(_drag(3, transform * Vector2(120, 10)))
	pad.handle_touch(_drag(3, transform * Vector2(121, 119)))
	check(intents.size() == count, "stationary sector and center generate no repeated turns")
	pad.handle_touch(_drag(3, transform * Vector2(300, 120)))
	check(pad.finger_index == 3, "dragging outside retains ownership until release")
	pad.handle_touch(_drag(3, transform * Vector2(20, 120)))
	check(intents.back() == Vector2i.LEFT, "captured finger can reenter with a new direction")
	count = intents.size()
	pad.handle_touch(_touch(3, transform * Vector2(20, 120), false))
	check(intents.size() == count and pad.finger_index == -1, "release does not submit a turn")
	pad.handle_touch(_touch(5, transform * Vector2(220, 120), false))
	check(pad.finger_index == -1, "unowned release cannot activate pad")
	pad.handle_touch(_touch(5, transform * Vector2(-20, 120), true))
	pad.handle_touch(_drag(5, transform * Vector2(20, 120)))
	check(pad.finger_index == -1, "press outside cannot slide into activation")
	pad.handle_touch(_touch(6, transform * Vector2(220, 120), true))
	pad.handle_touch(_touch(6, transform * Vector2(120, 20), false, true))
	check(pad.finger_index == -1, "cancel clears captured finger")
	pad.handle_touch(_touch(7, transform * Vector2(220, 120), true))
	count = intents.size()
	pad.handle_touch(_drag(7, transform * Vector2(200, 40)))
	check(intents.size() == count, "hysteresis prevents boundary jitter")
	pad.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(pad.finger_index == -1, "focus loss clears capture")
	var second: TouchPad = load("res://misc/touch_button.tscn").instantiate()
	root.add_child(second)
	second.position = Vector2(600, 80)
	second.show()
	pad.handle_touch(_touch(8, transform * Vector2(220, 120), true))
	second.handle_touch(_touch(9, second.get_global_transform_with_canvas() * Vector2(20, 120), true))
	check(pad.finger_index == 8 and second.finger_index == 9, "two pads capture different fingers")
	pad.queue_free()
	second.queue_free()
	await get_tree().process_frame


func _test_scenes() -> void:
	var game: Node = root.get_node("Game")
	game.map_resource = load("res://map/default.tres").duplicate(true)
	for path: String in ["res://ui/main_menu.tscn", "res://ui/sub_menu.tscn", "res://ui/settings.tscn",
			"res://ui/host_menu.tscn", "res://ui/join_menu.tscn",
			"res://game_scene/singleplayer_scene.tscn", "res://game_scene/multiplayer_scene.tscn"]:
		var scene: Node = load(path).instantiate()
		root.add_child(scene)
		await get_tree().process_frame
		if scene is GameScene:
			var controller: Controller = scene.snakes[0].controller
			controller.submit_direction(Vector2i.DOWN)
			check(scene.simulation.snakes[0].pending_direction == Vector2i.DOWN, "controller uses shared intent entry: " + path)
			scene._on_to_start_to_started()
			for i: int in 20:
				scene._physics_process(0.1)
			check(scene.simulation.tick > 0, "scene advances shared core: " + path)
			var before: Dictionary = scene.simulation.snapshot()
			scene.snakes[0]._process(0.5)
			check(before == scene.simulation.snapshot(), "rendering cannot modify grid rules: " + path)
		else:
			check(scene.is_inside_tree(), "menu scene instantiates: " + path)
		scene.queue_free()
		await get_tree().process_frame
	_scenes_complete = true


func _test_view() -> void:
	var settings: Node = root.get_node("Settings")
	var original_speed: float = settings.tween_speed
	settings.tween_speed = 0.5
	var layout: MapResource = load("res://map/default.tres").duplicate(true)
	var sim := MatchSimulation.new()
	sim.configure(layout, [{"id": 1, "color": Color.WHITE}], 42)
	var view: Snake = load("res://snake/snake.tscn").instantiate()
	root.add_child(view)
	view.apply_snapshot(sim.snapshot().snakes[0], layout, 0, 0.5)
	var old_tail: Vector2 = layout.calculate_map_position(sim.snakes[0].body.back())
	sim.start()
	sim.food = layout.wrap(sim.snakes[0].body[0] + Vector2i.RIGHT)
	sim.step()
	view.apply_snapshot(sim.snapshot().snakes[0], layout, sim.tick, 0.5)
	var segments: Array[Node] = view.get_children().filter(func(node: Node) -> bool: return node is SnakeBody)
	check(segments.back().position == old_tail, "new growth segment starts at the old tail, not the origin")
	sim.step()
	sim.step()
	view.apply_snapshot(sim.snapshot().snakes[0], layout, sim.tick, 0.5)
	check(segments[0].position == layout.calculate_map_position(sim.snakes[0].body[0]), "missed view ticks correct immediately instead of interpolating across unknown steps")
	settings.tween_speed = 0.0
	sim.step()
	view.apply_snapshot(sim.snapshot().snakes[0], layout, sim.tick, 0.5)
	check(segments[0].position == layout.calculate_map_position(sim.snakes[0].body[0]), "zero interpolation setting applies the next grid pose immediately")
	settings.tween_speed = original_speed
	view.queue_free()
	await get_tree().process_frame
