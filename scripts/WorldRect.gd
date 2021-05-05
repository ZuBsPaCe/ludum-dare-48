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

func set_position(x : int, y : int) -> void:
	self.x = x
	self.y = y

	center.x = x + width * 0.5
	center.y = y + height * 0.5

	center_x = int(center.x)
	center_y = int(center.y)

	rect.position.x = x
	rect.position.y = y
	rect.end.x = x + width
	rect.end.y = y + height


func get_class():
	return "WorldRect"

