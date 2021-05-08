extends Reference

class_name WorldLayer

var index : int
var layer_seed : int
var nodes := []

func _init(index : int, layer_seed : int) -> void:
	self.index = index
	self.layer_seed = layer_seed
