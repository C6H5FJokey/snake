extends InputController
class_name SyncController

@export var id: int

func _unhandled_input(event: InputEvent) -> void:
	if id == multiplayer.get_unique_id():
		super(event)
		set_next_move.rpc(next_move)
	

@rpc
func set_next_move(v: Vector2):
	next_move = v
