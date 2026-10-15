extends GameScene


func is_online() -> bool:
	return true


func _init_snakes() -> void:
	for player: Dictionary in Net.round_config.players:
		var snake: Snake = preload("res://snake/snake.tscn").instantiate()
		snake.name = "Snake_%d" % player.id
		snake.player_id = player.id
		snake.color = player.color
		if player.id == multiplayer.get_unique_id():
			var input := InputController.new()
			input.name = "InputController"
			snake.add_child(input)
			snake.controller = input
		add_child(snake)
		snakes.append(snake)
		if snake.controller:
			var camera := Camera2D.new()
			camera.position_smoothing_enabled = true
			snake.snake_head.add_child(camera)
	if Net.player_info.get(1, {}).get("dedicated", false) and multiplayer.is_server():
		var camera := Camera2D.new()
		camera.position = Vector2(map_resource.size * map_resource.cell_size) / 2.0
		add_child(camera)
