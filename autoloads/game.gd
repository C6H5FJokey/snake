extends Node

enum{
	SINGLE,
	MULTIPLAYER
}

var play_mode: int = SINGLE

var map_resource_path: String = "res://map/map1.tres"
var map_resource: MapResource = preload("res://map/map1.tres")


@rpc("call_local")
func set_map_resource(v: MapResource):
	map_resource = v


