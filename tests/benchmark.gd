extends Node
## CPU-only deterministic long-snake benchmark. Headless cannot measure GPU/draw time.


func _ready() -> void:
	get_tree().root.get_node("Bgm").stop()
	_run.call_deferred()


func _run() -> void:
	var layout := MapResource.new()
	layout.size = Vector2i(1024, 4)
	layout.map.fill(MapResource.EMPTY)
	layout.start_pos = [Vector2i(700, 1), Vector2i(700, 3)]
	layout.move_direction = [Vector2i.RIGHT, Vector2i.RIGHT]
	var players: Array = [{"id": 1, "name": "1P", "color": Color.WHITE},
		{"id": 2, "name": "2P", "color": Color.WHITE}]
	var sim := MatchSimulation.new()
	sim.configure(layout, players, 42)
	for snake: SnakeState in sim.snakes:
		snake.body.clear()
		for i: int in 512:
			snake.body.append(layout.wrap(layout.start_pos[snake.id - 1] - Vector2i(i, 0)))
	sim.start()
	var started: int = Time.get_ticks_usec()
	for i: int in 1000:
		sim.step()
	var step_us: float = (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var state: Dictionary
	for i: int in 1000:
		state = sim.snapshot()
	var snapshot_us: float = (Time.get_ticks_usec() - started) / 1000.0
	Game.map_resource = layout
	var scene: GameScene = load("res://game_scene/multiplayer_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	scene._apply_snapshot(state)
	state.tick += 1
	scene._apply_snapshot(state)
	started = Time.get_ticks_usec()
	for i: int in 300:
		for snake: Snake in scene.snakes:
			snake._process(1.0 / 60.0)
	var visual_us: float = (Time.get_ticks_usec() - started) / 300.0
	var result: Dictionary = {"segments": 1024, "split_viewports": 2,
		"cpu_us_per_step": step_us, "cpu_us_per_snapshot": snapshot_us,
		"cpu_us_per_visual_update": visual_us, "snapshot_bytes": var_to_bytes(state).size(),
		"display_driver": DisplayServer.get_name(), "gpu_measured": false}
	print("BENCHMARK " + JSON.stringify(result))
	var file := FileAccess.open("res://.godot/benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()
