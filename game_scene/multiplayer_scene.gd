extends GameScene

@export var sub_viewports_path: Array[NodePath]
@export var scores_labels_path: Array[NodePath]

var sub_viewports: Array[SubViewport]
var scores_labels: Dictionary
var scores: Dictionary

func _init_snakes():
	super()
	snakes[0].color = Game.player_1_color
	snakes[1].color = Game.player_2_color



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
	for path in sub_viewports_path:
		sub_viewports.append(get_node(path))
	for sub_viewport in sub_viewports:
		sub_viewport.world_2d = get_viewport().world_2d
	for i in snakes.size():
		scores[snakes[i]] = 0
		scores_labels[snakes[i]] = get_node(scores_labels_path[i])
		


func _on_snake_food_eaten(snake: Snake) -> void:
	super(snake)
	scores[snake] += 1
	scores_labels[snake].text = str(scores[snake])


func start_game():
	super()
	if Settings.show_scores:
		scores_labels.values().map(func(label: Label):label.show())
