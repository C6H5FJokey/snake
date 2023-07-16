extends GameScene


func _init_snakes():
	var all_id := Array(multiplayer.get_peers())
	all_id.append(multiplayer.get_unique_id())
	all_id.sort()
	for id in all_id:
		var snake: SyncSnake = preload("res://snake/sync_snake.tscn").instantiate()
		snake.id = id
		snake.name = Net.player_info.get(id, "%dP"%(snakes.size()+1))
		snake.map_resource = map_resource
		snake.start_pos = map_resource.start_pos[snakes.size()]
		snake.move_direction = map_resource.move_direction[snakes.size()]
		snakes.append(snake)
		add_child(snake, true)
		snake.owner = self
		snake.controller.id = id
		snake.controller.set_multiplayer_authority(id)
		snake.food_eaten.connect(_on_snake_food_eaten)
		move_requested.connect(snake._on_move_requested)
		if id == multiplayer.get_unique_id():
			var camera := Camera2D.new()
			camera.position_smoothing_enabled = true
			snake.snake_head.add_child(camera)
			camera.owner = snake


@rpc
func game_update():
	super()


func start_game():
	if not is_multiplayer_authority():
		return
	spawn_food()
	_sync_food.rpc(food_index, spawn_food_num)
	timer.start()


func _on_timer_timeout():
	super()
	_sync_game_update.rpc(food_index, spawn_food_num)


@rpc
func _sync_food(_food_index: int, _spawn_food_num: int) -> void:
	food_index = _food_index
	map_resource.map[food_index] = MapResource.FOOD
	food_node = preload("res://map/piece/food.tscn").instantiate()
	add_child(food_node)
	food_node.owner = self
	food_node.global_position = map_resource.calculate_map_position(map_resource.from_index(food_index))
	spawn_food_num = _spawn_food_num


@rpc
func _sync_game_update(_food_index: int, _spawn_food_num: int) -> void:
	move_requested.emit()
	if test_game_over():
		return
	if is_food_eated:
		if food_node:
			food_node.queue_free()
		map_resource.map[food_index] = MapResource.EMPTY
		_sync_food(_food_index, _spawn_food_num)
		is_food_eated = false


func test_game_over() -> bool :
	return super()
