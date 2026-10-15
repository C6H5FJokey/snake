class_name InputController
extends Controller

@export var move_left: StringName = &"p1_left"
@export var move_right: StringName = &"p1_right"
@export var move_up: StringName = &"p1_up"
@export var move_down: StringName = &"p1_down"


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed(move_left):
		submit_direction(Vector2i.LEFT)
	elif event.is_action_pressed(move_right):
		submit_direction(Vector2i.RIGHT)
	elif event.is_action_pressed(move_up):
		submit_direction(Vector2i.UP)
	elif event.is_action_pressed(move_down):
		submit_direction(Vector2i.DOWN)
