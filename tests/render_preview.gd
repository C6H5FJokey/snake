extends Node
## Optional desktop GPU smoke test; writes a preview into the ignored cache.


func _ready() -> void:
	get_tree().root.get_node("Bgm").stop()
	_run.call_deferred()


func _run() -> void:
	Game.map_resource = load("res://map/default.tres").duplicate(true)
	var scene: GameScene = load("res://game_scene/multiplayer_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	scene.to_start.hide()
	scene.simulation.start()
	scene.simulation.food = Vector2i(5, 2)
	scene.simulation.step()
	scene._apply_snapshot(scene.simulation.snapshot())
	# Let the original smooth cameras settle after skipping the normal four-second countdown.
	for i: int in 60:
		await get_tree().process_frame
	for pad: TouchPad in scene._pads:
		pad.show()
	for i: int in 6:
		await RenderingServer.frame_post_draw
	var result: Error = get_viewport().get_texture().get_image().save_png("res://.godot/preview.png")
	print("RENDER_PREVIEW result=%d" % result)
	get_tree().quit(0 if result == OK else 1)
