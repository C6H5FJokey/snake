extends InputController
class_name SyncController

@export var id: int

var last_next_move: Vector2i

func _unhandled_input(event: InputEvent) -> void:
	if id == multiplayer.get_unique_id():
		last_next_move = next_move
		super(event)
		if last_next_move != next_move:
			set_next_move.rpc(next_move)
	

@rpc
func set_next_move(v: Vector2):
	next_move = v
