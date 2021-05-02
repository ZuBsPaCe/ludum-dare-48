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

var astar : AStar2D

var auto_fix_waypoints := false

func _init() -> void:
	pass

func setup(width : int, height : int, default_value) -> void:
	tiles_types.clear()
	tiles.clear()
	dig_tiles.clear()
	rally_tiles.clear()

	auto_fix_waypoints = false

	self.width = width
	self.height = height

	size = width * height

	astar = AStar2D.new()
	astar.reserve_space(size)

	var id := 0
	for y in range(height):
		for x in range(width):
			tiles_types.append(default_value)
			tiles.append(Tile.new(id, x, y, default_value))

			astar.add_point(id, Vector2(x * 32.0 + 16.0, y * 32.0 + 16.0))

			assert(default_value != TileType.GROUND)
			astar.set_point_disabled(id, true)

			if y > 0:
				astar.connect_points(id, id - width)

			if x > 0:
				astar.connect_points(id, id - 1)

			# See _check_nav_connections(). Is necessary for diagonal connections.
#			if y > 0 && x > 0:
#				astar.connect_points(id, id - width - 1)

			id += 1

#	for check_id in range(0, size):
#		_check_nav_connections(tiles[check_id])



func is_valid(x : int, y : int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height

func is_tile_type(x : int, y : int, value) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height && tiles_types[y * width + x] == value

func set_tile_type(x : int, y : int, value) -> void:
	var id := y * width + x
	tiles_types[id] = value
	var tile = tiles[id]
	tile.tile_type = value

	if auto_fix_waypoints:
		if value == TileType.GROUND:
			astar.set_point_disabled(id, false)
			_check_nav_connections(tile)

			if y > 0 && tiles_types[id - width] == TileType.GROUND:
				_check_nav_connections(tiles[id - width])

			if x > 0 && tiles_types[id - 1] == TileType.GROUND:
				_check_nav_connections(tiles[id - 1])

			if y < height - 1 && tiles_types[id + width] == TileType.GROUND:
				_check_nav_connections(tiles[id + width])

			if x < width - 1 && tiles_types[id + 1] == TileType.GROUND:
				_check_nav_connections(tiles[id + 1])

		else:
			assert(false)
#			astar.set_point_disabled(id, true)
#			_check_nav_connections(tile, true)

func finalize_waypoints() -> void:
	auto_fix_waypoints = true

	for y in range(0, height):
		for x in range(0, width):
			var tile = get_tile(x, y)
			if tile.tile_type == TileType.GROUND:
				astar.set_point_disabled(tile.id, false)
				_check_nav_connections(tile)
			else:
				assert(tile.tile_type == TileType.DIRT || tile.tile_type == TileType.ROCK || tile.tile_type == TileType.PRISON || tile.tile_type == TileType.END_PORTAL)



func _check_nav_connections(tile : Tile) -> void:
	# Top Left
	if tile.x > 0 && tile.y > 0:
		var other_id := tile.id - width - 1
		var left_id := tile.id - 1
		var up_id := tile.id - width
		if (tiles_types[other_id] == TileType.GROUND &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[left_id] == TileType.GROUND &&
			tiles_types[up_id] == TileType.GROUND):
			astar.connect_points(tile.id, other_id)

	# Top Right
	if tile.x < width - 1 && tile.y > 0:
		var other_id := tile.id - width + 1
		var right_id := tile.id + 1
		var up_id := tile.id - width
		if (tiles_types[other_id] == TileType.GROUND &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[right_id] == TileType.GROUND &&
			tiles_types[up_id] == TileType.GROUND):
			astar.connect_points(tile.id, other_id)

	# Bottom Right
	if tile.x < width - 1 && tile.y < height - 1:
		var other_id := tile.id + width + 1
		var right_id := tile.id + 1
		var down_id := tile.id + width
		if (tiles_types[other_id] == TileType.GROUND &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[right_id] == TileType.GROUND &&
			tiles_types[down_id] == TileType.GROUND):
			astar.connect_points(tile.id, other_id)

	# Bottom Left
	if tile.x > 0 && tile.y < height - 1:
		var other_id := tile.id + width - 1
		var left_id := tile.id - 1
		var down_id := tile.id + width
		if (tiles_types[other_id] == TileType.GROUND &&
			!astar.are_points_connected(tile.id, other_id) &&
			tiles_types[left_id] == TileType.GROUND &&
			tiles_types[down_id] == TileType.GROUND):
			astar.connect_points(tile.id, other_id)

#	else:
#		if tile.x > 0 && tile.y > 0:
#			var other_id := tile.id - width - 1
#			if tiles_types[other_id] == TileType.GROUND && astar.are_points_connected(tile.id, other_id):
#				astar.disconnect_points(tile.id, other_id)
#
#		if tile.x < width - 1 && tile.y > 0:
#			var other_id := tile.id - width + 1
#			if tiles_types[other_id] == TileType.GROUND && astar.are_points_connected(tile.id, other_id):
#				astar.disconnect_points(tile.id, other_id)
#
#		if tile.x < width - 1 && tile.y < height - 1:
#			var other_id := tile.id + width + 1
#			if tiles_types[other_id] == TileType.GROUND && astar.are_points_connected(tile.id, other_id):
#				astar.disconnect_points(tile.id, other_id)
#
#		if tile.x > 0 && tile.y < height - 1:
#			var other_id := tile.id + width - 1
#			if tiles_types[other_id] == TileType.GROUND && astar.are_points_connected(tile.id, other_id):
#				astar.disconnect_points(tile.id, other_id)


func get_tile_type(x : int, y : int):
	return tiles_types[y * width + x]

func get_tile(x : int, y : int) -> Tile:
	return tiles[y * width + x]
