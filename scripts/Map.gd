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

func _init() -> void:
	pass

func setup(width : int, height : int, default_value) -> void:
	tiles_types.clear()
	tiles.clear()
	dig_tiles.clear()
	rally_tiles.clear()

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

			if default_value != TileType.GROUND:
				astar.set_point_disabled(id, true)

			if y > 0:
				astar.connect_points(id, id - width)

			if x > 0:
				astar.connect_points(id, id - 1)

			# See _check_nav_connections(). Is necessary for diagonal connections.
#			if y > 0 && x > 0:
#				astar.connect_points(id, id - width - 1)

			id += 1

	for check_id in range(0, size):
		_check_nav_connections(tiles[check_id])



func is_valid(x : int, y : int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height

func is_tile_type(x : int, y : int, value) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height && tiles_types[y * width + x] == value

func set_tile_type(x : int, y : int, value) -> void:
	var id := y * width + x
	tiles_types[id] = value
	var tile = tiles[id]
	tile.tile_type = value

	if value == TileType.GROUND:
		astar.set_point_disabled(id, false)
		_check_nav_connections(tile)


func _check_nav_connections(tile : Tile) -> void:
	if tile.x > 0 && tile.y > 0:
		var other_id := tile.id - width - 1
		if tiles_types[other_id] == TileType.GROUND && !astar.are_points_connected(tile.id, other_id):
			astar.connect_points(tile.id, other_id)

	if tile.x < width - 1 && tile.y > 0:
		var other_id := tile.id - width + 1
		if tiles_types[other_id] == TileType.GROUND && !astar.are_points_connected(tile.id, other_id):
			astar.connect_points(tile.id, other_id)

	if tile.x < width - 1 && tile.y < height - 1:
		var other_id := tile.id + width + 1
		if tiles_types[other_id] == TileType.GROUND && !astar.are_points_connected(tile.id, other_id):
			astar.connect_points(tile.id, other_id)

	if tile.x > 0 && tile.y < height - 1:
		var other_id := tile.id + width - 1
		if tiles_types[other_id] == TileType.GROUND && !astar.are_points_connected(tile.id, other_id):
			astar.connect_points(tile.id, other_id)


func get_tile_type(x : int, y : int):
	return tiles_types[y * width + x]

func get_tile(x : int, y : int) -> Tile:
	return tiles[y * width + x]
