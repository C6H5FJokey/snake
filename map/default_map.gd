extends Node

@export var map_resource: MapResource

func _ready() -> void:
	for i in range(21):
		for j in range(21):
			if i == 0 or i == 20:
				map_resource.map[i*21+j] = MapResource.WALL
			elif j == 0 or j == 20:
				map_resource.map[i*21+j] = MapResource.WALL
			else:
				map_resource.map[i*21+j] = MapResource.EMPTY
			ResourceSaver.save(map_resource)
