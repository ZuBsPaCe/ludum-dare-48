extends Reference

class_name WorldCircle

var radius : int
var room_type

var center_x : int
var center_y : int

var center := Vector2()


func _init(radius : int, room_type) -> void:
	self.radius = radius
	self.room_type = room_type

func set_position(center_x : int, center_y : int) -> void:
	self.center_x = center_x
	self.center_y = center_y
	center.x = center_x
	center.y = center_y


func get_class():
	return "WorldCircle"
