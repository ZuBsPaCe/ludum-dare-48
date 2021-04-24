extends Reference

class_name Tile

var minions = []
var dig_highlight

var x : int
var y : int
var tile_type

var health := 3

func _init(x : int, y : int, tile_type) -> void:
	self.x = x
	self.y = y
	self.tile_type = tile_type
