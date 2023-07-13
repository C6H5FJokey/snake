extends Controller
class_name InputController

@export var move_left: StringName = "ui_left"
@export var move_right: StringName = "ui_right"
@export var move_up: StringName = "ui_up"
@export var move_down: StringName = "ui_down"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(move_left):
		next_move = Vector2i.LEFT
	if event.is_action_pressed(move_right):
		next_move = Vector2i.RIGHT
	if event.is_action_pressed(move_up):
		next_move = Vector2i.UP
	if event.is_action_pressed(move_down):
		next_move = Vector2i.DOWN
