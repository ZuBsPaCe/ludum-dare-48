extends Reference

class_name Map


const TileType = preload("res://scripts/TileType.gd").TileType


var width : int
var height : int
var size : int

var tiles_types := []
var tiles := []

var dig_tiles := []
var rally_tiles := []
var start_tiles := []

var astar : AStar2D
var astar_dirty : AStar2D

var auto_fix_waypoints := false

func _init() -> void:
	pass

func setup(width : int, height : int, default_value) -> void:
	tiles_types.clear()
	tiles.clear()
	dig_tiles.clear()
	rally_tiles.clear()
	start_tiles.clear()

	auto_fix_waypoints = false

	self.width = width
	self.height = height

	size = width * height

	astar = AStar2D.new()
	astar.reserve_space(size)

	astar_dirty = AStar2D.new()
	astar_dirty.reserve_space(size)

	var point_disabled : bool = default_value != TileType.OPEN

	var id := 0
	for y in range(height):
		for x in range(width):
			tiles_types.append(default_value)
			tiles.append(Tile.new(id, x, y, default_value))

			var center_pos := Vector2(x * 32.0 + 16.0, y * 32.0 + 16.0)
			astar.add_point(id, center_pos)
			astar_dirty.add_point(id, center_pos)

			# Handled in finalize_waypoints
			#astar.set_point_disabled(id, point_disabled)

			if y > 0:
				astar.connect_points(id, id - width)
				astar_dirty.connect_points(id, id - width)

			if x > 0:
				astar.connect_points(id, id - 1)
				astar_dirty.connect_points(id, id - 1)

			# See _check_diagonal_connections(). Is necessary for diagonal connections.
#			if y > 0 && x > 0:
#				astar.connect_points(id, id - width - 1)

			id += 1

#	for check_id in range(0, size):
#		_check_diagonal_connections(tiles[check_id])



func is_valid(x : int, y : int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height

func is_tile_type(x : int, y : int, value) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height && tiles_types[y * width + x] == value

func set_tile_type(x : int, y : int, value) -> void:
	var id := y * width + x
	tiles_types[id] = value
	var tile = tiles[id]

	if auto_fix_waypoints:

		assert(tile.tile_type == TileType.DIRT || tile.tile_type == TileType.PRISON)
		assert(value == TileType.OPEN)

		tile.tile_type = value

		# Hint: Don't need to check astar_dirty. It's already connected.

		astar.set_point_disabled(id, false)
		_check_diagonal_connections(astar, tile, TileType.OPEN)

		# Diagonal connections for top tile
		if y > 0 && tiles_types[id - width] == TileType.OPEN:
			_check_diagonal_connections(astar, tiles[id - width], TileType.OPEN)

		# Diagonal connections for left tile
		if x > 0 && tiles_types[id - 1] == TileType.OPEN:
			_check_diagonal_connections(astar, tiles[id - 1], TileType.OPEN)

		# Diagonal connections for bottom tile
		if y < height - 1 && tiles_types[id + width] == TileType.OPEN:
			_check_diagonal_connections(astar, tiles[id + width], TileType.OPEN)

		# Diagonal connections for right tile
		if x < width - 1 && tiles_types[id + 1] == TileType.OPEN:
			_check_diagonal_connections(astar, tiles[id + 1], TileType.OPEN)

	else:
		tile.tile_type = value

func finalize_waypoints() -> void:
	auto_fix_waypoints = true

	for y in range(0, height):
		for x in range(0, width):
			var tile = get_tile(x, y)

			if tile.tile_type == TileType.OPEN:
				astar.set_point_disabled(tile.id, false)
				_check_diagonal_connections(astar, tile, TileType.OPEN)
			else:
				astar.set_point_disabled(tile.id, true)

			if tile.tile_type <= TileType.DIRT:
				astar_dirty.set_point_disabled(tile.id, false)
				_check_diagonal_connections(astar_dirty, tile, TileType.DIRT)
			else:
				astar_dirty.set_point_disabled(tile.id, true)

			assert(
				tile.tile_type == TileType.OPEN ||
				tile.tile_type == TileType.DIRT ||
				tile.tile_type == TileType.ROCK ||
				tile.tile_type == TileType.PRISON ||
				tile.tile_type == TileType.END_PORTAL)



func _check_diagonal_connections(astar : AStar2D, tile : Tile, tile_type) -> void:
	# Top Left
	if tile.x > 0 && tile.y > 0:
		var other_id := tile.id - width - 1
		var left_id := tile.id - 1
		var up_id := tile.id - width
		if (tiles_types[other_id] <= tile_type &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[left_id] <= tile_type &&
			tiles_types[up_id] <= tile_type):
			astar.connect_points(tile.id, other_id)

	# Top Right
	if tile.x < width - 1 && tile.y > 0:
		var other_id := tile.id - width + 1
		var right_id := tile.id + 1
		var up_id := tile.id - width
		if (tiles_types[other_id] <= tile_type &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[right_id] <= tile_type &&
			tiles_types[up_id] <= tile_type):
			astar.connect_points(tile.id, other_id)

	# Bottom Right
	if tile.x < width - 1 && tile.y < height - 1:
		var other_id := tile.id + width + 1
		var right_id := tile.id + 1
		var down_id := tile.id + width
		if (tiles_types[other_id] <= tile_type &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[right_id] <= tile_type &&
			tiles_types[down_id] <= tile_type):
			astar.connect_points(tile.id, other_id)

	# Bottom Left
	if tile.x > 0 && tile.y < height - 1:
		var other_id := tile.id + width - 1
		var left_id := tile.id - 1
		var down_id := tile.id + width
		if (tiles_types[other_id] <= tile_type &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[left_id] <= tile_type &&
			tiles_types[down_id] <= tile_type):
			astar.connect_points(tile.id, other_id)

func get_tile_type(x : int, y : int):
	return tiles_types[y * width + x]

func get_tile(x : int, y : int) -> Tile:
	return tiles[y * width + x]
