extends Node
class_name Controller

@export var next_move: Vector2i = Vector2i.RIGHT

func get_next_move() -> Vector2i:
	return next_move
