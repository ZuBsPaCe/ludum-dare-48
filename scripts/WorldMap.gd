extends Node2D

const NodeType = preload("res://scripts/NodeType.gd").NodeType

export(PackedScene) var button_scene
export(Texture) var line_texture

export(Texture) var king_icon
export(Texture) var portal_icon
export(Texture) var flag_icon
export(Texture) var prison_icon
export(Texture) var dollar_icon


signal world_node_clicked

func _ready() -> void:
	set_process(false)

func start() -> void:
	set_process(true)

	visible = true


	var viewport_rect := get_viewport_rect()
	var layer_count : int = State.world_layer_counts.size()
	var visited_nodes := State.world_visited_nodes

#	visited_nodes.append(0)
#	visited_nodes.append(0)
#	visited_nodes.append(0)
#	visited_nodes.append(0)
#	visited_nodes.append(0)


	if State.world_layer_index > 0:
		State.game_camera.position.y = 128.0 + get_node_pos(State.world_layer_index, 0, 1, viewport_rect).y



	for layer_index in (layer_count - 1):
		var node_count : int = State.world_layer_counts[layer_index]
		var connections : Array = State.world_layer_connections[layer_index]

		for node_index in range(node_count):

			for connection in connections:
				if connection.from != node_index:
					continue

				var next_node_count : int = State.world_layer_counts[layer_index + 1]

				var from_pos := get_node_pos(layer_index, node_index, node_count, viewport_rect)
				var to_pos := get_node_pos(layer_index + 1, connection.to, next_node_count, viewport_rect)

				var texture_rect := TextureRect.new()
				texture_rect.texture = line_texture
				texture_rect.rect_pivot_offset = Vector2(8.0, 0.0)
				texture_rect.rect_position = from_pos + Vector2(32.0, 32.0) + Vector2(-8.0, 0.0)
				texture_rect.rect_scale = Vector2(1.0, from_pos.distance_to(to_pos) / 16.0)
				texture_rect.rect_rotation = rad2deg(Vector2.DOWN.angle_to(to_pos - from_pos))

				$CanvasLayer.add_child(texture_rect)


	for layer_index in layer_count:

		var node_count : int = State.world_layer_counts[layer_index]
		var node_types : Array = State.world_layer_node_types[layer_index]
		assert(node_count == node_types.size())

		for node_index in range(node_count):
			var button : Control = button_scene.instance()
			button.rect_position = get_node_pos(layer_index, node_index, node_count, viewport_rect)
			$CanvasLayer.add_child(button)

			var node_type = node_types[node_index]
			match node_type:
				NodeType.PORTAL:
					button.set_icon(portal_icon)
				NodeType.TUTORIAL:
					pass
				NodeType.ESCORT:
					button.set_icon(king_icon)
				NodeType.RESCUE:
					button.set_icon(prison_icon)
				NodeType.DEFEND:
					button.set_icon(flag_icon)
				NodeType.MERCHANT:
					button.set_icon(dollar_icon)
				NodeType.HELL:
					pass

			button.set_disabled(true)

			if layer_index < State.world_layer_index:
				if visited_nodes[layer_index] == node_index:
					button.set_highlight(true)
					var button_disabled : TextureRect = button.get_node("ButtonDisabled")
					button_disabled.modulate.r8 = 44
					button_disabled.modulate.g8 = 255

			elif layer_index == State.world_layer_index:
				var reachable := false

				if layer_index == 0:
					reachable = true
				else:
					var connections : Array = State.world_layer_connections[layer_index - 1]
					for connection in connections:
						if connection.to == node_index && visited_nodes[layer_index - 1] == connection.from:
							reachable = true
							break

				if reachable:
					#button.set_highlight(true)
					button.set_disabled(false)
					button.tag = node_type
					button.index = node_index
					button.connect("pressed", self, "on_button_pressed", [button])


func _process(delta: float) -> void:
	# CanvasLayer FollowViewport does not work correctly with input events (wrong coords).
	# We shift the layer ourselves
	$CanvasLayer.transform.origin.y = -State.game_camera.position.y + get_viewport_rect().size.y / 2


func get_node_pos(layer_index : int, node_index : int, node_count : int, viewport_rect : Rect2) -> Vector2:
	return Vector2(
		(node_index + 1) * (viewport_rect.size.x / (node_count + 1)) - 32.0,
		(layer_index + 1) * 128.0) + State.world_node_noise[layer_index * 4 + node_index]

func on_button_pressed(button) -> void:
	set_process(false)
	for child in $CanvasLayer.get_children():
		child.queue_free()

	visible = false


	State.world_node_type = button.tag
	State.world_visited_nodes.append(button.index)

	emit_signal("world_node_clicked", button.tag)
