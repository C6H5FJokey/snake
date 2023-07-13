@tool
extends TileMap

@export var map_resource: MapResource

func _ready() -> void:
	if not map_resource:
		map_resource = MapResource.new()
		map_resource.resource_path = "res://map/new_map.tres"
	map_resource.size = get_used_rect().size
	for cell in get_used_cells(0):
		map_resource.map[map_resource.as_index(cell)] = MapResource.WALL
	ResourceSaver.save(map_resource, map_resource.resource_path)
