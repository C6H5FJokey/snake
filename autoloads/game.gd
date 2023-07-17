extends Node

enum{
	SINGLE,
	MULTIPLAYER
}

var play_mode: int = SINGLE

var map_resource: MapResource = preload("res://map/new_map.tres")


@rpc("call_local")
func set_map_resource(v: MapResource):
	map_resource = v


