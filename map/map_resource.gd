@tool
extends Resource
class_name MapResource

enum {EMPTY, WALL, FOOD}

@export var name: String = ""
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
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


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


func to_dict() -> Dictionary:
	return{
		"name": name,
		"size": size,
		"cell_size": cell_size,
		"map": PackedByteArray(map),
		"start_pos": PackedVector2Array(start_pos),
		"move_direction": PackedVector2Array(move_direction)
	}


func from_dict(v: Dictionary):
	name = v.get("name")
	size = v.get("size")
	cell_size = v.get("cell_size")
	if v.has("map"):
		map.resize(v.map.size())
		for i in range(v.map.size()):
			map[i] = v.map[i]
	if v.has("start_pos"):
		start_pos.resize(v.start_pos.size())
		for i in range(v.start_pos.size()):
			start_pos[i] = Vector2i(v.start_pos[i])
	if v.has("move_direction"):
		move_direction.resize(v.move_direction.size())
		for i in range(v.move_direction.size()):
			move_direction[i] = Vector2i(v.move_direction[i])


func save_map(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print_debug(file.get_open_error())
		return
	file.store_var(to_dict())
	file.close()


func load_map(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print_debug(file.get_open_error())
		return
	from_dict(file.get_var())
	file.close()
