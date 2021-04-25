extends Node

const TileType = preload("res://scripts/TileType.gd").TileType

var map : Map

func _ready() -> void:
	pass

func get_tile_circle(center_x : int, center_y : int, radius : int, return_self = true) -> Array:
	var tiles := []
	var radius_sq := radius * radius
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if !map.is_valid(x, y):
				continue

			if !return_self && y == center_y && x == center_x:
				continue

			var diff_x := center_x - x
			var diff_y := center_y - y
			if diff_x * diff_x + diff_y * diff_y <= radius:
				tiles.append(map.get_tile(x, y))
	return tiles

func get_walkable_pos(coord : Coord, include_current = true) -> Vector2:
	var rand = randi() % 9

	for i in range(9):
		rand = posmod(rand + 1, 9)

		match rand:
			0:
				if !include_current:
					continue
				return coord.to_random_pos()

			1:
				if map.is_tile_type(coord.x - 1, coord.y, TileType.GROUND):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						coord.y * 32.0 + randf() * 32.0)

			2:
				if map.is_tile_type(coord.x + 1, coord.y, TileType.GROUND):
					return Vector2(
						(coord.x + 1) * 32.0 + randf() * 32.0,
						coord.y * 32.0 + randf() * 32.0)

			3:
				if map.is_tile_type(coord.x, coord.y - 1, TileType.GROUND):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						(coord.y - 1) * 32.0 + randf() * 32.0)

			4:
				if map.is_tile_type(coord.x, coord.y + 1, TileType.GROUND):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						(coord.y + 1) * 32.0 + randf() * 32.0)

			5:
				if map.is_tile_type(coord.x - 1, coord.y - 1, TileType.GROUND):
					if map.is_tile_type(coord.x - 1, coord.y, TileType.GROUND) && map.is_tile_type(coord.x, coord.y - 1, TileType.GROUND):
						return Vector2(
							(coord.x - 1) * 32.0 + randf() * 32.0,
							(coord.y - 1) * 32.0 + randf() * 32.0)

			6:
				if map.is_tile_type(coord.x + 1, coord.y - 1, TileType.GROUND):
					if map.is_tile_type(coord.x + 1, coord.y, TileType.GROUND) && map.is_tile_type(coord.x, coord.y - 1, TileType.GROUND):
						return Vector2(
							(coord.x + 1) * 32.0 + randf() * 32.0,
							(coord.y - 1) * 32.0 + randf() * 32.0)

			7:
				if map.is_tile_type(coord.x + 1, coord.y + 1, TileType.GROUND):
					if map.is_tile_type(coord.x + 1, coord.y, TileType.GROUND) && map.is_tile_type(coord.x, coord.y + 1, TileType.GROUND):
						return Vector2(
							(coord.x + 1) * 32.0 + randf() * 32.0,
							(coord.y + 1) * 32.0 + randf() * 32.0)

			8:
				if map.is_tile_type(coord.x - 1, coord.y + 1, TileType.GROUND):
					if map.is_tile_type(coord.x - 1, coord.y, TileType.GROUND) && map.is_tile_type(coord.x, coord.y + 1, TileType.GROUND):
						return Vector2(
							(coord.x - 1) * 32.0 + randf() * 32.0,
							(coord.y + 1) * 32.0 + randf() * 32.0)

	return coord.to_random_pos()


