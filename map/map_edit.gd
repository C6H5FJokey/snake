@tool
extends TileMap

@export_file("*.map") var map_path: String = ""
@export_group("map_property")
@export var map_name: String = ""
@export var cell_size := Vector2i(64, 64)
@export var start_pos: Array[Vector2i] = []
@export var move_direction: Array[Vector2i] = []
var map_resource := MapResource.new()

func _ready() -> void:
	if map_path == "":
		map_path = "default.map"
	map_resource.name = map_name
	map_resource.size = get_used_rect().size
	map_resource.start_pos = start_pos
	map_resource.move_direction = move_direction
	for cell in get_used_cells(0):
		map_resource.map[map_resource.as_index(cell)] = MapResource.WALL
	notify_property_list_changed()
	map_resource.save_map(map_path)
