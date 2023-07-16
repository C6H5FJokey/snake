@tool
extends Resource
class_name MapResource

enum {EMPTY, WALL, FOOD}

@export var size := Vector2i(20, 20) :set = _set_size
@export var cell_size := Vector2i(64, 64)
@export var map: Array[int]
@export var start_pos: Array[Vector2i] = []
@export var move_direction: Array[Vector2i] = []

var half_cell_size := cell_size / 2

func _set_size(v: Vector2i) -> void:
	size = v
	map.clear()
	map.resize(v.x * v.y)
	notify_property_list_changed()


func calculate_map_position(grid_position: Vector2i) -> Vector2:
	return grid_position * cell_size + half_cell_size


func calculate_grid_position(map_position: Vector2) -> Vector2i:
	return Vector2i(map_position) / cell_size


func is_within_bounds(cell: Vector2i) -> bool:
	return cell >= Vector2i(0, 0) and cell < size


@warning_ignore("shadowed_global_identifier")
func clamp(grid_position: Vector2i) -> Vector2i:
	return grid_position.clamp(Vector2i(0, 0), size)


@warning_ignore("shadowed_global_identifier")
func wrap(grid_position: Vector2i) -> Vector2i:
	return Vector2i(wrapi(grid_position.x, 0, size.x), wrapi(grid_position.y, 0, size.y))


func as_index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func from_index(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % size.x, index / size.x)
