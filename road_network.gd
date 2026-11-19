extends RefCounted

const TerrainCatalog := preload("res://terrain_catalog.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const TILE_SIZE := 2.0
const BOARD_RADIUS := 4
const FORTRESS := 0

class Tile:
	var lane: int
	var endpoints: Dictionary = {}
	var terrain_id: StringName
	var terrain: Dictionary
	var enemy_entries := 0
	var trap_spent := false

var tiles: Dictionary = {}
var cells_by_space: Dictionary[int, Vector2i] = {}
var positions: Array[Vector3] = [Vector3(0, 0.56, 0)]
var links: Array = [[]]


func opposite(direction: int) -> int:
	return (direction + 2) % 4


func center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x, 0, cell.y) * TILE_SIZE


func port(cell: Vector2i, direction: int) -> Vector3:
	var offset: Vector2i = DIRECTIONS[direction]
	return center(cell) + Vector3(offset.x, 0, offset.y) * TILE_SIZE * 0.5


func open_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in tiles:
		var tile: Tile = tiles[cell]
		for direction: int in tile.endpoints:
			var next: Vector2i = cell + DIRECTIONS[direction]
			if next != Vector2i.ZERO and not tiles.has(next) and not cells.has(next) and maxi(absi(next.x), absi(next.y)) <= BOARD_RADIUS:
				cells.append(next)
	return cells


func expansion_cells(location: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not cells_by_space.has(location):
		return cells
	var cell := cells_by_space[location]
	var tile: Tile = tiles[cell]
	for direction: int in tile.endpoints:
		if tile.endpoints[direction] != location:
			continue
		var next: Vector2i = cell + DIRECTIONS[direction]
		if next != Vector2i.ZERO and not tiles.has(next) and maxi(absi(next.x), absi(next.y)) <= BOARD_RADIUS:
			cells.append(next)
	return cells


func tile_at(location: int) -> Tile:
	if cells_by_space.has(location):
		return tiles[cells_by_space[location]]
	return null


func fitting_lane(cell: Vector2i, ports: Array[int]) -> int:
	if cell == Vector2i.ZERO or tiles.has(cell) or maxi(absi(cell.x), absi(cell.y)) > BOARD_RADIUS:
		return -1
	var lane := -1
	for direction in range(4):
		var next: Vector2i = cell + DIRECTIONS[direction]
		if next == Vector2i.ZERO:
			if not ports.has(direction):
				return -1
			lane = opposite(direction)
		elif tiles.has(next):
			var neighbor: Tile = tiles[next]
			var has_neighbor_road := neighbor.endpoints.has(opposite(direction))
			if ports.has(direction) != has_neighbor_road:
				return -1
			if has_neighbor_road and lane == -1:
				lane = neighbor.lane
	return lane


func road_point(cell: Vector2i, ports: Array[int], progress: float) -> Vector3:
	var start := port(cell, ports[0])
	var end := port(cell, ports[1])
	var midpoint := center(cell)
	return start.lerp(midpoint, progress).lerp(midpoint.lerp(end, progress), progress)


func add_tile(cell: Vector2i, ports: Array[int], count: int, terrain_id: StringName = &"road") -> Array[int]:
	var tile := Tile.new()
	tile.lane = fitting_lane(cell, ports)
	if tile.lane < 0:
		return []
	tile.terrain_id = terrain_id
	tile.terrain = TerrainCatalog.DEFINITIONS[terrain_id]
	tiles[cell] = tile
	var nodes: Array[int] = []
	if ports.size() == 2:
		for index in range(count):
			var node := add_space(road_point(cell, ports, (index + 0.5) / count))
			if not nodes.is_empty():
				connect_spaces(nodes.back(), node)
			nodes.append(node)
		tile.endpoints[ports[0]] = nodes.front()
		tile.endpoints[ports[1]] = nodes.back()
	elif ports.size() == 4:
		var crossing := add_space(center(cell))
		nodes.append(crossing)
		for direction in ports:
			tile.endpoints[direction] = crossing
	elif tile.terrain.effect == &"fork":
		var hub := add_space(center(cell))
		var middle := add_space(center(cell).lerp(port(cell, ports[1]), 0.66))
		var long_start := add_space(center(cell).lerp(port(cell, ports[2]), 0.35))
		var long_end := add_space(center(cell).lerp(port(cell, ports[2]), 0.72))
		nodes.assign([hub, middle, long_start, long_end])
		tile.endpoints[ports[0]] = hub
		tile.endpoints[ports[1]] = middle
		tile.endpoints[ports[2]] = long_end
		connect_spaces(hub, middle)
		connect_spaces(hub, long_start)
		connect_spaces(long_start, long_end)
	else:
		var junction := add_space(center(cell))
		nodes.append(junction)
		for direction in ports:
			var branch := add_space(center(cell).lerp(port(cell, direction), 0.66))
			nodes.append(branch)
			tile.endpoints[direction] = branch
			connect_spaces(junction, branch)
	for node in nodes:
		cells_by_space[node] = cell
	for direction: int in tile.endpoints:
		var next: Vector2i = cell + DIRECTIONS[direction]
		var endpoint: int = tile.endpoints[direction]
		if next == Vector2i.ZERO:
			connect_spaces(FORTRESS, endpoint)
		elif tiles.has(next):
			var neighbor: Tile = tiles[next]
			connect_spaces(endpoint, neighbor.endpoints[opposite(direction)])
	return nodes


func add_space(at: Vector3) -> int:
	var id := positions.size()
	positions.append(at + Vector3.UP * 0.12)
	links.append([])
	return id


func connect_spaces(first: int, second: int) -> void:
	if not links[first].has(second):
		links[first].append(second)
		links[second].append(first)


func distances_to_fortress(blocked: Dictionary = {}) -> Dictionary:
	var queue: Array[int] = [FORTRESS]
	var distance := {FORTRESS: 0}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		var steps: int = distance[current] + 1
		for next: int in links[current]:
			if not blocked.has(next) and not distance.has(next):
				distance[next] = steps
				queue.append(next)
	return distance


func entry_for_lane(lane: int) -> int:
	var distances := distances_to_fortress()
	var entrance := -1
	var fallback := -1
	for cell: Vector2i in tiles:
		var tile: Tile = tiles[cell]
		if tile.lane != lane:
			continue
		for direction: int in tile.endpoints:
			var endpoint: int = tile.endpoints[direction]
			if fallback == -1 or distances[endpoint] > distances[fallback]:
				fallback = endpoint
			var next: Vector2i = cell + DIRECTIONS[direction]
			if next != Vector2i.ZERO and not tiles.has(next):
				if entrance == -1 or distances[endpoint] > distances[entrance]:
					entrance = endpoint
	return entrance if entrance != -1 else fallback


func routes_from(current: int, visited: Dictionary) -> Array[int]:
	var distances := distances_to_fortress(visited)
	var routes: Array[int] = []
	for next: int in links[current]:
		if distances.has(next):
			routes.append(next)
	return routes
