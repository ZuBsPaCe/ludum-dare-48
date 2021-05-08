extends Reference

class_name WorldNode

var layer_index : int
var index_in_layer : int

var prev_nodes := []
var next_nodes := []

var node_type

var noise : Vector2

var visited := false

func _init(layer_index : int, index_in_layer : int) -> void:
	self.layer_index = layer_index
	self.index_in_layer = index_in_layer
