extends Controller
class_name InputController

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		next_move = Vector2i.LEFT
	if event.is_action_pressed("ui_right"):
		next_move = Vector2i.RIGHT
	if event.is_action_pressed("ui_up"):
		next_move = Vector2i.UP
	if event.is_action_pressed("ui_down"):
		next_move = Vector2i.DOWN
