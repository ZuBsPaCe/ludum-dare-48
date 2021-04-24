extends Reference

class_name Coord

var x : int
var y : int

func _init(x = 0, y = 0) -> void:
	self.x = x
	self.y = y

func to_random_pos() -> Vector2:
	return Vector2(
		x * 32.0 + randf() * 32.0,
		y * 32.0 + randf() * 32.0)
