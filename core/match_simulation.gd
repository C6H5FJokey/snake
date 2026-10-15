class_name MatchSimulation
extends RefCounted
## All modes use this fixed-step grid simulation; only the host advances it online.
## A fatal move is committed (including growth), then the body becomes an obstacle.

var layout: MapResource
var snakes: Array[SnakeState] = []
var tick: int = 0
var food: Vector2i = Vector2i(-1, -1)
var phase: String = "waiting"
var winner_id: int = 0
var _random := RandomNumberGenerator.new()
var _occupied: Dictionary[Vector2i, bool] = {}


func configure(map_layout: MapResource, players: Array, seed_value: int = 0) -> void:
	layout = map_layout.duplicate(true)
	_random.seed = seed_value
	snakes.clear()
	tick = 0
	phase = "waiting"
	food = Vector2i(-1, -1)
	winner_id = 0
	for i: int in players.size():
		var player: Dictionary = players[i]
		var snake := SnakeState.new()
		snake.id = player.id
		snake.player_name = player.get("name", "Player")
		snake.color = player.get("color", Color.WHITE)
		snake.direction = layout.move_direction[i]
		for segment: int in 4:
			snake.body.append(layout.wrap(layout.start_pos[i] - snake.direction * segment))
		snakes.append(snake)
	_rebuild_occupied()


func start() -> void:
	if phase != "waiting":
		return
	phase = "running"
	_spawn_food()


func submit_direction(player_id: int, direction: Vector2i) -> void:
	if not is_direction(direction) or phase == "finished":
		return
	for snake: SnakeState in snakes:
		if snake.id == player_id and not snake.dead:
			# Last intent wins. Reverse validation happens against the executed direction.
			snake.pending_direction = direction
			return


func step() -> void:
	if phase != "running":
		return
	var next_bodies: Array = []
	var growing: Array[bool] = []
	for snake: SnakeState in snakes:
		var next_body: Array[Vector2i] = snake.body.duplicate()
		var grows: bool = false
		if not snake.dead:
			if is_direction(snake.pending_direction) and snake.pending_direction != -snake.direction:
				snake.direction = snake.pending_direction
			snake.pending_direction = Vector2i.ZERO
			var head: Vector2i = layout.wrap(snake.body[0] + snake.direction)
			grows = head == food
			next_body.push_front(head)
			if not grows:
				next_body.pop_back()
		next_bodies.append(next_body)
		growing.append(grows)

	# Resolve against one complete proposed board, never against partially moved snakes.
	var body_occupancy: Dictionary[Vector2i, bool] = {}
	var head_counts: Dictionary[Vector2i, int] = {}
	for i: int in snakes.size():
		var body: Array = next_bodies[i]
		if not snakes[i].dead:
			head_counts[body[0]] = head_counts.get(body[0], 0) + 1
		for j: int in range(0 if snakes[i].dead else 1, body.size()):
			body_occupancy[body[j]] = true
	var eaten: bool = false
	var deaths: Array[bool] = []
	for i: int in snakes.size():
		var snake: SnakeState = snakes[i]
		if snake.dead:
			deaths.append(true)
			continue
		var head: Vector2i = next_bodies[i][0]
		var hit: bool = layout.map[layout.as_index(head)] == MapResource.WALL
		hit = hit or body_occupancy.has(head) or head_counts.get(head, 0) > 1
		for j: int in snakes.size():
			if i != j and not snakes[j].dead:
				if head == snakes[j].body[0] and next_bodies[j][0] == snake.body[0]:
					hit = true
		deaths.append(hit)
	# Commit only after every collision has read the same old and proposed boards.
	for i: int in snakes.size():
		snakes[i].body.assign(next_bodies[i])
		snakes[i].dead = deaths[i]
		if growing[i]:
			snakes[i].score += 1
			eaten = true
	tick += 1
	_rebuild_occupied()
	if eaten:
		_spawn_food()
	var alive: Array[SnakeState] = snakes.filter(func(snake: SnakeState) -> bool: return not snake.dead)
	if alive.is_empty() or (snakes.size() > 1 and alive.size() == 1):
		phase = "finished"
		winner_id = _find_winner(alive)


func mark_disconnected(player_id: int) -> void:
	for snake: SnakeState in snakes:
		if snake.id == player_id:
			snake.dead = true
			snake.pending_direction = Vector2i.ZERO
	_rebuild_occupied()


func snapshot() -> Dictionary:
	var states: Array = []
	for snake: SnakeState in snakes:
		states.append(snake.to_dict())
	return {"tick": tick, "phase": phase, "food": food,
		"snakes": states, "winner_id": winner_id}


func _rebuild_occupied() -> void:
	_occupied.clear()
	for snake: SnakeState in snakes:
		for cell: Vector2i in snake.body:
			_occupied[cell] = true


func _spawn_food() -> void:
	var free: Array[Vector2i] = []
	for i: int in layout.map.size():
		var cell: Vector2i = layout.from_index(i)
		if layout.map[i] != MapResource.WALL and not _occupied.has(cell):
			free.append(cell)
	food = free[_random.randi_range(0, free.size() - 1)] if not free.is_empty() else Vector2i(-1, -1)


func _find_winner(alive: Array[SnakeState]) -> int:
	if alive.size() == 1:
		return alive[0].id
	var longest: int = -1
	var result: int = 0
	for snake: SnakeState in snakes:
		if snake.body.size() > longest:
			longest = snake.body.size()
			result = snake.id
		elif snake.body.size() == longest:
			result = 0
	return result


static func is_direction(value: Vector2i) -> bool:
	return absi(value.x) + absi(value.y) == 1
