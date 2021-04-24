extends Reference

class_name Map


var width : int
var height : int
var size : int

var tiles := []


func _init(width : int, height : int, default_value) -> void:
	self.width = width
	self.height = height

	size = width * height

	for x in range(height):
		for y in range(width):
			tiles.append(default_value)

func is_valid(x : int, y : int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height

func is_tile(x : int, y : int, value) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height && tiles[y * width + x] == value

func set_tiles(value) -> void:
	for x in range(height):
		for y in range(width):
			tiles[y * width + x] = value

func set_tile(x : int, y : int, value) -> void:
	tiles[y * width + x] = value

func get_tile(x : int, y : int):
	return tiles[y * width + x]

func get_index(x : int, y : int) -> int:
	return y * width + x

func get_tile_indexed(index : int):
	return tiles[index]

func set_tile_indexed(index : int, value) -> void:
	tiles[index] = value
