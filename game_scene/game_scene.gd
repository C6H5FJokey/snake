extends Node
class_name  GameScene

signal game_finished
signal move_requested

@onready var playground: Polygon2D = %Playground
@onready var timer: Timer = $Timer
@onready var to_start: Control = %ToStart
@onready var outcome: Control = %Outcome
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport

@export_group("Component")
@export var map_resource: MapResource

var food_index: int
var food_node: Node2D
var snakes: Array

var walls_pos: Array[Vector2i]

var is_food_eated: bool = false
var spawn_food_num: int = 0

func _ready() -> void:
	if map_resource:
		var right = map_resource.cell_size.x * map_resource.size.x
		var down = map_resource.cell_size.y * map_resource.size.y
		playground.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(right, 0),
			Vector2(right, down),
			Vector2(0, down)
			])
	snakes = get_tree().get_nodes_in_group("Snake")
	
	for snake in snakes:
		snake.map_resource = map_resource
		snake.food_eaten.connect(_on_snake_food_eaten)
		move_requested.connect(snake._on_move_requested)
	
	for i in range(map_resource.map.size()):
		if map_resource.map[i] == MapResource.WALL:
			walls_pos.append(map_resource.from_index(i))
			put_wall(map_resource.from_index(i))
	
	_init_game()
	
	to_start._on_to_start()

func _on_timer_timeout() -> void:
	game_update()


func game_update() -> void:
	move_requested.emit()
	for snake in snakes:
		for other in snakes:
			if snake == other:
				continue
			if other.snake_body.has(snake.snake_body[0]):
				snake.become_dead()
	if test_game_over():
		game_over()
		return
	if is_food_eated:
		if food_node:
			food_node.queue_free()
		map_resource.map[food_index] = MapResource.EMPTY
		spawn_food()
		is_food_eated = false
		

func _on_snake_food_eaten() -> void:
	is_food_eated = true


func put_wall(cell_pos: Vector2i) -> void:
	var wall = preload("res://map/piece/wall.tscn").instantiate()
	sub_viewport.add_child(wall)
	wall.owner = self
	wall.global_position = map_resource.calculate_map_position(cell_pos)


func spawn_food():
	var snake_bodys: Array
	for snake in snakes:
		snake_bodys.append_array(snake.snake_body)
	food_index = _spawn_food_index(snake_bodys + walls_pos)
	map_resource.map[food_index] = MapResource.FOOD
	food_node = preload("res://map/piece/food.tscn").instantiate()
	sub_viewport.add_child(food_node)
	food_node.owner = self
	food_node.global_position = map_resource.calculate_map_position(map_resource.from_index(food_index))
	spawn_food_num += 1


func _spawn_food_index(filter_pos: Array) -> int:
	var filter_index := filter_pos.map(func(x):return map_resource.as_index(x))
	var food_index := range(map_resource.map.size()).filter(
		func(x): return not filter_index.has(x)
		)
	return food_index.pick_random()
	

func test_game_over() -> bool:
	if snakes.all(func(snake: Snake): return snake.is_dead):
		return true
	return false


func game_over() -> void:
	outcome.show()
	timer.stop()


func start_game() -> void:
	spawn_food()
	timer.start()


func _on_to_start_to_started() -> void:
	start_game()


func _init_game():
	pass
