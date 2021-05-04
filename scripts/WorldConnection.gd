extends Reference

class_name WorldConnection

var from : int
var to : int
var group : String

func _init(from : int, to : int, group = "") -> void:
	self.from = from
	self.to = to
	self.group = group
