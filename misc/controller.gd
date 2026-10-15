class_name Controller
extends Node

signal direction_requested(direction: Vector2i)

var next_move: Vector2i = Vector2i.ZERO
var enabled: bool = true


func submit_direction(direction: Vector2i) -> void:
	if enabled and MatchSimulation.is_direction(direction):
		next_move = direction
		direction_requested.emit(direction)


func get_next_move() -> Vector2i:
	return next_move
