@tool
class_name MapResource
extends Resource

enum {EMPTY, WALL, FOOD}

@export var name: String = ""
@export var size: Vector2i = Vector2i(20, 20):
	set(value):
		size = value
		map.clear()
		map.resize(maxi(0, value.x * value.y))
@export var cell_size: Vector2i = Vector2i(64, 64)
@export var map: Array[int] = []
@export var start_pos: Array[Vector2i] = []
@export var move_direction: Array[Vector2i] = []

var half_cell_size: Vector2:
	get:
		return Vector2(cell_size) / 2.0


func calculate_map_position(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position * cell_size) + half_cell_size


func calculate_grid_position(map_position: Vector2) -> Vector2i:
	return Vector2i((map_position / Vector2(cell_size)).floor())


func is_within_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


@warning_ignore("shadowed_global_identifier")
func clamp(grid_position: Vector2i) -> Vector2i:
	return grid_position.clamp(Vector2i.ZERO, size - Vector2i.ONE)


@warning_ignore("shadowed_global_identifier")
func wrap(grid_position: Vector2i) -> Vector2i:
	return Vector2i(wrapi(grid_position.x, 0, size.x), wrapi(grid_position.y, 0, size.y))


func as_index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func from_index(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % size.x, index / size.x)


func validate(player_count: int = 0) -> String:
	if size.x <= 0 or size.y <= 0 or cell_size.x <= 0 or cell_size.y <= 0:
		return "Map and cell dimensions must be positive."
	if map.size() != size.x * size.y:
		return "Map cell count does not match its dimensions."
	for value: int in map:
		if value < EMPTY or value > FOOD:
			return "Unknown map cell value."
	if start_pos.size() != move_direction.size() or start_pos.size() < maxi(1, player_count):
		return "Not enough matching spawn positions and directions."
	var occupied: Dictionary[Vector2i, bool] = {}
	for i: int in (player_count if player_count > 0 else start_pos.size()):
		var direction: Vector2i = move_direction[i]
		if absi(direction.x) + absi(direction.y) != 1 or not is_within_bounds(start_pos[i]):
			return "Invalid spawn position or direction."
		for j: int in 4:
			var cell: Vector2i = self.wrap(start_pos[i] - direction * j)
			if map[as_index(cell)] == WALL or occupied.has(cell):
				return "Starting snake bodies overlap a wall or another snake."
			occupied[cell] = true
	return ""


func to_dict() -> Dictionary:
	return {"name": name, "size": size, "cell_size": cell_size,
		"map": PackedByteArray(map), "start_pos": PackedVector2Array(start_pos),
		"move_direction": PackedVector2Array(move_direction)}


func from_dict(value: Dictionary) -> bool:
	# Validate a candidate so failed imports leave the current layout intact.
	if not value.get("size") is Vector2i or not value.get("cell_size") is Vector2i:
		return false
	var cells: Variant = value.get("map")
	var starts: Variant = value.get("start_pos")
	var directions: Variant = value.get("move_direction")
	if not (cells is Array or cells is PackedByteArray or cells is PackedInt32Array):
		return false
	if not (starts is Array or starts is PackedVector2Array):
		return false
	if not (directions is Array or directions is PackedVector2Array):
		return false
	var dimensions: Vector2i = value.size
	if dimensions.x <= 0 or dimensions.y <= 0 or int(dimensions.x) * int(dimensions.y) != cells.size():
		return false
	var candidate := MapResource.new()
	candidate.name = str(value.get("name", ""))
	candidate.size = value.size
	candidate.cell_size = value.cell_size
	for cell: Variant in cells:
		if not cell is int:
			return false
	candidate.map.assign(cells)
	for cell: Variant in starts:
		if not (cell is Vector2 or cell is Vector2i) or Vector2(cell) != Vector2(Vector2i(cell)):
			return false
		candidate.start_pos.append(Vector2i(cell))
	for direction: Variant in directions:
		if not (direction is Vector2 or direction is Vector2i) or Vector2(direction) != Vector2(Vector2i(direction)):
			return false
		candidate.move_direction.append(Vector2i(direction))
	if not candidate.validate().is_empty():
		return false
	name = candidate.name
	size = candidate.size
	cell_size = candidate.cell_size
	map = candidate.map
	start_pos = candidate.start_pos
	move_direction = candidate.move_direction
	return true


func save_map(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(to_dict())


func load_map(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var value: Variant = file.get_var(false)
	return value is Dictionary and from_dict(value)
