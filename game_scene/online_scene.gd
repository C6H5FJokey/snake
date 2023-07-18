extends GameScene

func _ready() -> void:
	super()
	outcome.reset_btn.hide()
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	Net.updated.connect(_on_net_updated)
	


func _init_snakes():
	var all_id := Array(multiplayer.get_peers())
	all_id.append(multiplayer.get_unique_id())
	if Net.player_info[1] == "--server":
		all_id.erase(1)
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


func game_update():
	if not is_multiplayer_authority():
		return
	super()


func start_game():
	if not is_multiplayer_authority():
		return
	spawn_food()
	timer.start()


#@rpc
#func _sync_food(_food_index: int, _spawn_food_num: int) -> void:
#	food_index = _food_index
#	map_resource.map[food_index] = MapResource.FOOD
#	if not food_node:
#		food_node = preload("res://map/piece/food.tscn").instantiate()
#		add_child(food_node)
#		food_node.owner = self
#	food_node.global_position = map_resource.calculate_map_position(map_resource.from_index(food_index))
#	spawn_food_num = _spawn_food_num
#
#
#@rpc
#func _sync_game_update(_food_index: int, _spawn_food_num: int) -> void:
#	move_requested.emit()
#	if test_game_over():
#		return
#	if is_food_eated:
#		map_resource.map[food_index] = MapResource.EMPTY
#		_sync_food(_food_index, _spawn_food_num)
#		is_food_eated = false


func spawn_food() -> void:
	super()
	Net.send_update(0, get_path(), "food_index")


func test_game_over() -> bool:
	if snakes.size() <= 1:
		return super()
	if snakes.reduce(
		func(accum: int ,snake: Snake): 
			return accum + (0 if snake.is_dead else 1)
			, 0) <= 1:
		return true
	return false


func _on_outcome_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/lobby.tscn")


@rpc
func game_over(id: int = -1) -> void:
	if snakes.size() <= 1:
		super()
		return
	if not id == -1:
		if not id == 0:
			outcome.text = "%s Win!"%Net.player_info[id]
		else:
			outcome.text = "Draw"
		outcome.show()
		return
	var win_snake: Snake
	for snake in snakes:
		if snake is Snake:
			if win_snake :
				if snake.snake_body_length > win_snake.snake_body_length:
					win_snake = snake
				elif snake.snake_body_length == win_snake.snake_body_length:
					win_snake = null
			else:
				win_snake = snake
			if not snake.is_dead:
				win_snake = snake
				break
	if win_snake:
		outcome.text = "%s Win!"%win_snake.name
		game_over.rpc(win_snake.id)
	else:
		outcome.text = "Draw"
		game_over.rpc(0)
	outcome.show()
	timer.stop()


func _on_multiplayer_server_disconnected() -> void:
	var dialog := AcceptDialog.new()
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.dialog_text = "Server_was_disconnected"
	get_window().add_child(dialog)
	dialog.popup_centered()
	multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_net_updated(path: NodePath, property: String, value: Variant, from_id: int):
	if not path == get_path():
		return
	match property:
		"food_index":
			food_index = value
			if not food_node:
				food_node = preload("res://map/piece/food.tscn").instantiate()
				add_child(food_node)
				food_node.owner = self
			food_node.global_position = map_resource.calculate_map_position(map_resource.from_index(food_index))
