class_name SnakeState
extends RefCounted
## Authoritative grid data. It has no scene, input or rendering dependencies.

var id: int
var player_name: String
var color: Color
var body: Array[Vector2i] = []
var direction: Vector2i = Vector2i.RIGHT
var pending_direction: Vector2i = Vector2i.ZERO
var dead: bool = false
var score: int = 0


func to_dict() -> Dictionary:
	return {"id": id, "name": player_name, "color": color,
		"body": PackedVector2Array(body), "direction": direction,
		"dead": dead, "score": score}
