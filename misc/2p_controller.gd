extends Controller


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("2p_left"):
		next_move = Vector2i.LEFT
	if event.is_action_pressed("2p_right"):
		next_move = Vector2i.RIGHT
	if event.is_action_pressed("2p_up"):
		next_move = Vector2i.UP
	if event.is_action_pressed("2p_down"):
		next_move = Vector2i.DOWN
