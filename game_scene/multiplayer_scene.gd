extends GameScene


@onready var sub_viewport_2: SubViewport = $SubViewportContainer2/SubViewport


func test_game_over() -> bool:
	if snakes.reduce(
		func(accum: int ,snake: Snake): 
			return accum + (0 if snake.is_dead else 1)
			, 0) <= 1:
		return true
	return false


func game_over() -> void:
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
	else:
		outcome.text = "Draw"
	super()


func _init_game() -> void:
	super()
	sub_viewport_2.world_2d = sub_viewport.world_2d


func _process(delta: float) -> void:
	$SubViewportContainer2/SubViewport/Camera2D.global_position = snakes[1].snake_head.global_position
