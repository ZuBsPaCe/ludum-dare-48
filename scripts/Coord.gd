extends Reference

class_name Coord

var x : int
var y : int

func _init(x = 0, y = 0) -> void:
	self.x = x
	self.y = y

func set_coord(other : Coord):
	x = other.x
	y = other.y

func set_vector(pos : Vector2) -> void:
	x = int(pos.x / 32.0)
	y = int(pos.y / 32.0)

func to_pos() -> Vector2:
	return Vector2(
		x * 32.0,
		y * 32.0)

func to_random_pos() -> Vector2:
	return Vector2(
		x * 32.0 + randf() * 32.0,
		y * 32.0 + randf() * 32.0)

func to_center_pos() -> Vector2:
	return Vector2(
		x * 32.0 + 16.0,
		y * 32.0 + 16.0)

func distance_to(other : Coord) -> float:
	var diff_x := other.x - x
	var diff_y := other.y - y
	return sqrt(diff_x * diff_x + diff_y * diff_y)

func distance_squared_to(other : Coord) -> float:
	var diff_x := other.x - x
	var diff_y := other.y - y
	return float(diff_x * diff_x + diff_y * diff_y)

func manhattan_distance_to(other : Coord) -> float:
	return abs(x - other.x) + abs(y - other.y)

func _to_string() -> String:
	return "%d/%d" % [x, y]
