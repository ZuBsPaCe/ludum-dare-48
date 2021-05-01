extends Reference

class_name Tile

var minions := []
var monsters := []

var inner_prison := false
var prisoners := []

var dig_highlight
var rally_highlight

var x : int
var y : int
var coord : Coord
var id : int
var tile_type

var health : int
var rally_time := 0.0
var rally_countdown := 0.0
var rally_end_tiles := []

func _init(id : int, x : int, y : int, tile_type) -> void:
	self.id = id
	self.x = x
	self.y = y
	self.coord = Coord.new(x, y)
	self.tile_type = tile_type
	health = State.dirt_health
