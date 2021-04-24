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


func set_tiles(value) -> void:
	for x in range(height):
		for y in range(width):
			tiles[y * width + x] = value

func set_tile(x : int, y : int, value) -> void:
	tiles[y * width + x] = value

func get_tile(x : int, y : int):
	return tiles[y * width + x]
