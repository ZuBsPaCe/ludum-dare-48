extends Reference

class_name Map


var width : int
var height : int
var size : int

var tiles_types := []
var tiles := []

var dig_tiles := []

func _init() -> void:
	pass

func setup(width : int, height : int, default_value) -> void:
	tiles_types.clear()
	tiles.clear()

	self.width = width
	self.height = height

	size = width * height

	for y in range(height):
		for x in range(width):
			tiles_types.append(default_value)
			tiles.append(Tile.new(x, y, default_value))

func is_valid(x : int, y : int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height

func is_tile_type(x : int, y : int, value) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height && tiles_types[y * width + x] == value

func set_tile_type(x : int, y : int, value) -> void:
	tiles_types[y * width + x] = value
	tiles[y * width + x].tile_type = value

func get_tile_type(x : int, y : int):
	return tiles_types[y * width + x]

func get_tile(x : int, y : int) -> Tile:
	return tiles[y * width + x]
