extends Node

const TileType = preload("res://scripts/TileType.gd").TileType

var map : Map

func _ready() -> void:
	pass

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
				if map.is_tile(coord.x - 1, coord.y, TileType.GROUND):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						coord.y * 32.0 + randf() * 32.0)

			2:
				if map.is_tile(coord.x + 1, coord.y, TileType.GROUND):
					return Vector2(
						(coord.x + 1) * 32.0 + randf() * 32.0,
						coord.y * 32.0 + randf() * 32.0)

			3:
				if map.is_tile(coord.x, coord.y - 1, TileType.GROUND):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						(coord.y - 1) * 32.0 + randf() * 32.0)

			4:
				if map.is_tile(coord.x, coord.y + 1, TileType.GROUND):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						(coord.y + 1) * 32.0 + randf() * 32.0)

			5:
				if map.is_tile(coord.x - 1, coord.y - 1, TileType.GROUND):
					if map.is_tile(coord.x - 1, coord.y, TileType.GROUND) && map.is_tile(coord.x, coord.y - 1, TileType.GROUND):
						return Vector2(
							(coord.x - 1) * 32.0 + randf() * 32.0,
							(coord.y - 1) * 32.0 + randf() * 32.0)

			6:
				if map.is_tile(coord.x + 1, coord.y - 1, TileType.GROUND):
					if map.is_tile(coord.x + 1, coord.y, TileType.GROUND) && map.is_tile(coord.x, coord.y - 1, TileType.GROUND):
						return Vector2(
							(coord.x + 1) * 32.0 + randf() * 32.0,
							(coord.y - 1) * 32.0 + randf() * 32.0)

			7:
				if map.is_tile(coord.x + 1, coord.y + 1, TileType.GROUND):
					if map.is_tile(coord.x + 1, coord.y, TileType.GROUND) && map.is_tile(coord.x, coord.y + 1, TileType.GROUND):
						return Vector2(
							(coord.x + 1) * 32.0 + randf() * 32.0,
							(coord.y + 1) * 32.0 + randf() * 32.0)

			8:
				if map.is_tile(coord.x - 1, coord.y + 1, TileType.GROUND):
					if map.is_tile(coord.x - 1, coord.y, TileType.GROUND) && map.is_tile(coord.x, coord.y + 1, TileType.GROUND):
						return Vector2(
							(coord.x - 1) * 32.0 + randf() * 32.0,
							(coord.y + 1) * 32.0 + randf() * 32.0)

	return coord.to_random_pos()


