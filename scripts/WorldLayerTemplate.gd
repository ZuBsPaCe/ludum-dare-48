extends Reference

class_name WorldLayerTemplate


var upper_count : int
var lower_count : int
var world_connections := []

var visited := false


func _init(
	upper_count : int,
	lower_count : int,
	world_connections : Array) -> void:
	self.upper_count = upper_count
	self.lower_count = lower_count
	self.world_connections = world_connections
