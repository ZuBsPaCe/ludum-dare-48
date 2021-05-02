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
