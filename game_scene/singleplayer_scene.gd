extends GameScene

@onready var scores_label: Label = $UI/Scores

var scores: int = 0

func _init_snakes():
	super()
	snakes[0].color = Game.player_1_color


func _on_snake_food_eaten(snake: Snake):
	super(snake)
	scores += 1
	scores_label.text = str(scores)


func start_game():
	super()
	if Settings.show_scores:
		scores_label.show()
