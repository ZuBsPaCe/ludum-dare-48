extends Node2D

const NodeType = preload("res://scripts/NodeType.gd").NodeType

export(PackedScene) var button_scene
export(Texture) var line_texture

export(Texture) var king_icon
export(Texture) var portal_icon
export(Texture) var flag_icon
export(Texture) var prison_icon
export(Texture) var dollar_icon
export(Texture) var shield_icon


signal world_node_clicked

func _ready() -> void:
	set_process(false)

func start() -> void:
	set_process(true)

	visible = true


	var viewport_rect := get_viewport_rect()
	var layer_count : int = State.world_layers.size()

	if State.world_layer_index > 0:
		var current_world_layer : WorldLayer = State.world_layers[State.world_layer_index]
		State.game_camera.position.y = 128.0 + get_node_pos(current_world_layer, current_world_layer.nodes[0], viewport_rect).y

	for current_layer_index in (layer_count - 1):
		var current_world_layer : WorldLayer = State.world_layers[current_layer_index]
		var next_world_layer : WorldLayer = State.world_layers[current_layer_index + 1]

		var current_node_count := current_world_layer.nodes.size()
		var next_node_count := next_world_layer.nodes.size()

		for current_node in current_world_layer.nodes:
			var from_pos := get_node_pos(current_world_layer, current_node, viewport_rect)

			for next_node in current_node.next_nodes:
				var to_pos := get_node_pos(next_world_layer, next_node, viewport_rect)

				var texture_rect := TextureRect.new()
				texture_rect.texture = line_texture
				texture_rect.rect_pivot_offset = Vector2(8.0, 0.0)
				texture_rect.rect_position = from_pos + Vector2(32.0, 32.0) + Vector2(-8.0, 0.0)
				texture_rect.rect_scale = Vector2(1.0, from_pos.distance_to(to_pos) / 16.0)
				texture_rect.rect_rotation = rad2deg(Vector2.DOWN.angle_to(to_pos - from_pos))

				$CanvasLayer.add_child(texture_rect)


	for layer_index in layer_count:
		var world_layer : WorldLayer = State.world_layers[layer_index]

		for node in world_layer.nodes:
			var button : Control = button_scene.instance()
			button.rect_position = get_node_pos(world_layer, node, viewport_rect)
			$CanvasLayer.add_child(button)

			match node.node_type:
				NodeType.PORTAL:
					button.set_icon(portal_icon)
				NodeType.TUTORIAL:
					pass
				NodeType.ESCORT:
					button.set_icon(shield_icon)
				NodeType.RESCUE:
					button.set_icon(king_icon)
				NodeType.PRISON:
					button.set_icon(prison_icon)
				NodeType.DEFEND:
					button.set_icon(flag_icon)
				NodeType.MERCHANT:
					button.set_icon(dollar_icon)
				NodeType.HELL:
					pass

			button.set_disabled(true)

			if layer_index < State.world_layer_index:
				if node.visited:
					button.set_highlight(true)
					var button_disabled : TextureRect = button.get_node("ButtonDisabled")
					button_disabled.modulate.r8 = 44
					button_disabled.modulate.g8 = 255

			elif layer_index == State.world_layer_index:
				var reachable := false

				if layer_index == 0:
					reachable = true
				else:
					for prev_node in node.prev_nodes:
						if prev_node.visited:
							reachable = true
							break

				if reachable:
					#button.set_highlight(true)
					button.set_disabled(false)
					button.tag = node
					button.connect("pressed", self, "on_button_pressed", [button])


func _process(delta: float) -> void:
	# CanvasLayer FollowViewport does not work correctly with input events (wrong coords).
	# We shift the layer ourselves
	$CanvasLayer.transform.origin.y = -State.game_camera.position.y + get_viewport_rect().size.y / 2


func get_node_pos(layer : WorldLayer, node : WorldNode, viewport_rect : Rect2) -> Vector2:
	return Vector2(
		(node.index_in_layer + 1) * (viewport_rect.size.x / (layer.nodes.size() + 1)) - 32.0,
		(layer.index + 1) * 128.0) + node.noise

func on_button_pressed(button) -> void:
	set_process(false)
	for child in $CanvasLayer.get_children():
		child.queue_free()

	visible = false

	var world_node : WorldNode = button.tag
	world_node.visited = true

	State.world_node_type = world_node.node_type

	emit_signal("world_node_clicked", button.tag)
