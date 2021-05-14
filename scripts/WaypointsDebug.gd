extends Node2D

func _ready() -> void:
	if !visible:
		set_process(false)

func _process(delta: float) -> void:
	update()

func _draw() -> void:
	var map := State.map

	var width = map.width
	var height = map.height

	for y in range(0, height):
		for x in range(0, width):
			var tile = map.get_tile(x, y)
			if map.astar.is_point_disabled(tile.id):
				continue

			# Top
			if tile.y > 0:
				var other_tile = map.get_tile(x, y - 1)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

			# Bottom
			if tile.y < height - 1:
				var other_tile = map.get_tile(x, y + 1)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

			# Left
			if tile.x > 0:
				var other_tile = map.get_tile(x - 1, y)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

			# Right
			if tile.x < width - 1:
				var other_tile = map.get_tile(x + 1, y)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

			# Top Left
			if tile.x > 0 && tile.y > 0:
				var other_tile = map.get_tile(x - 1, y - 1)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

			# Top Right
			if tile.x < width - 1 && tile.y > 0:
				var other_tile = map.get_tile(x + 1, y - 1)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

			# Bottom Left
			if tile.x > 0 && tile.y < height - 1:
				var other_tile = map.get_tile(x - 1, y + 1)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

			# Bottom Right
			if tile.x < width - 1 && tile.y < height - 1:
				var other_tile = map.get_tile(x + 1, y + 1)
				if !map.astar.is_point_disabled(other_tile.id) && map.astar.are_points_connected(tile.id, other_tile.id):
					draw_line(tile.coord.to_center_pos(), other_tile.coord.to_center_pos(), Color.green)

	for minion in State.minions:
		if (minion.task == Minion.MinionTask.RALLY ||
			minion.task == Minion.MinionTask.GO_DIG ||
			minion.task == Minion.MinionTask.MOVE ||
			minion.task == Minion.MinionTask.SWARM):
			var index = minion.path_index
			while index < minion.path.size() - 1:
				var current_id = minion.path[index]
				var next_id = minion.path[index + 1]
				draw_line(map.tiles[current_id].coord.to_center_pos(), map.tiles[next_id].coord.to_center_pos(), Color.blue, 3)
				index += 1

			if minion.task == Minion.MinionTask.RALLY:
				minion.modulate.b = 0.0
		else:
			minion.modulate.b = 1.0


