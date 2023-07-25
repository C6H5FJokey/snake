extends GameScene

@onready var scores_label: Label = $UI/Scores

var scores: int = 0

func _ready() -> void:
	super()
	outcome.reset_btn.hide()
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	Net.updated.connect(_on_net_updated)
	


func _init_snakes():
	var all_id := Array(multiplayer.get_peers())
	all_id.append(multiplayer.get_unique_id())
	if Net.player_info[1].name == "--server":
		all_id.erase(1)
	all_id.sort()
	for id in all_id:
		var snake: SyncSnake = preload("res://snake/sync_snake.tscn").instantiate()
		snake.id = id
		snake.name = Net.player_info.get(id, {}).get("name", "%dP"%(snakes.size()+1))
		snake.color = Net.player_info.get(id, {}).get("color", Color("f2f0e5"))
		snake.map_resource = map_resource
		snake.start_pos = map_resource.start_pos[snakes.size()]
		snake.move_direction = map_resource.move_direction[snakes.size()]
		snake.wait_time = wait_time
		snakes.append(snake)
		add_child(snake, true)
		snake.owner = self
		snake.controller.id = id
		snake.controller.set_multiplayer_authority(id)
		snake.food_eaten.connect(_on_snake_food_eaten.bind(snake))
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
	if is_multiplayer_authority():
		super()
	if Settings.show_scores:
		scores_label.show()


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
		$UI/Outcome/Buttons/Back.grab_focus.call_deferred()
		if is_multiplayer_authority():
			game_over.rpc()
			if Net.player_name == "--server":
				get_tree().change_scene_to_file("res://ui/lobby.tscn")
		return
	if not id == -1:
		if not id == 0:
			outcome.text = "%s Win!"%Net.player_info[id].name
		else:
			outcome.text = "Draw"
		outcome.show()
		$UI/Outcome/Buttons/Back.grab_focus.call_deferred()
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
	$UI/Outcome/Buttons/Back.grab_focus.call_deferred()


func _on_multiplayer_server_disconnected() -> void:
	var dialog := AcceptDialog.new()
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.dialog_text = "Server_was_disconnected"
	get_window().add_child(dialog)
	dialog.popup_centered()
	multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_net_updated(path: NodePath, property: String, value: Variant, _from_id: int):
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


func _on_snake_food_eaten(snake: Snake):
	super(snake)
	_rpc_on_snake_food_eaten.rpc(snake.id)
	if multiplayer.get_unique_id() == snake.id:
		scores += 1
		scores_label.text = str(scores)


@rpc
func _rpc_on_snake_food_eaten(snake_id: int):
	if multiplayer.get_unique_id() == snake_id:
		scores += 1
		scores_label.text = str(scores)
