extends Reference

class_name Tile

var minions = []
var dig_highlight
var rally_highlight

var x : int
var y : int
var coord : Coord
var id : int
var tile_type

var health := 3
var rally := 0.0

func _init(id : int, x : int, y : int, tile_type) -> void:
	self.id = id
	self.x = x
	self.y = y
	self.coord = Coord.new(x, y)
	self.tile_type = tile_type
