extends Reference

class_name WorldRect

var width : int
var height : int
var room_type

var x : int
var y : int

var center_x : int
var center_y : int

var center := Vector2()
var rect := Rect2()

func _init(width : int, height : int, room_type) -> void:
	self.width = width
	self.height = height

	self.room_type = room_type

func set_position(center_x : int, center_y : int) -> void:
	self.center_x = center_x
	self.center_y = center_y

	center.x = center_x
	center.y = center_y

	x = center_x - floor(width * 0.5)
	y = center_y - floor(height * 0.5)

	rect.position.x = x
	rect.position.y = y
	rect.end.x = x + width
	rect.end.y = y + height


func get_class():
	return "WorldRect"

