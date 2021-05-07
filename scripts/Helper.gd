extends Node

const TileType = preload("res://scripts/TileType.gd").TileType

var map : Map

var raycast : RayCast2D


func _ready() -> void:
	pass

func get_tile_neighbours_4(result : Array, center_x : int, center_y : int, return_self = false) -> void:
	result.clear()
	if return_self:
		result.append(map.get_tile(center_x, center_y))

	if center_y < map.height - 1:
		result.append(map.get_tile(center_x, center_y + 1))
	if center_x > 0:
		result.append(map.get_tile(center_x - 1, center_y))
	if center_x < map.width - 1:
		result.append(map.get_tile(center_x + 1, center_y))
	if center_y > 0:
		result.append(map.get_tile(center_x, center_y - 1))

func get_tile_neighbours_8(result : Array, center_x : int, center_y : int, return_self = false) -> void:
	get_tile_neighbours_4(result, center_x, center_y, return_self)

	if center_x < map.width - 1 && center_y < map.height - 1:
		result.append(map.get_tile(center_x + 1, center_y + 1))
	if center_x > 0 && center_y < map.height - 1:
		result.append(map.get_tile(center_x - 1, center_y + 1))
	if center_x < map.width - 1 && center_y > 0:
		result.append(map.get_tile(center_x + 1, center_y - 1))
	if center_x > 0 && center_y > 0:
		result.append(map.get_tile(center_x - 1, center_y - 1))

func get_tile_circle_new(center_x : int, center_y : int, radius : int, return_self = true) -> Array:
	var result := []
	get_tile_circle(result, center_x, center_y, radius, return_self)
	return result

func get_tile_circle(result : Array, center_x : int, center_y : int, radius : int, return_self = true) -> void:
	result.clear()
	var radius_sq := radius * radius
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if !map.is_valid(x, y):
				continue

			if !return_self && y == center_y && x == center_x:
				continue

			var diff_x := center_x - x
			var diff_y := center_y - y
			if diff_x * diff_x + diff_y * diff_y <= radius_sq:
				result.append(map.get_tile(x, y))

func get_neighbour_tiles_ordered(center_x : int, center_y : int) -> Array:
	var tiles := []

	tiles.append(map.get_tile(center_x, center_y - 1))
	tiles.append(map.get_tile(center_x + 1, center_y - 1))
	tiles.append(map.get_tile(center_x + 1, center_y))
	tiles.append(map.get_tile(center_x + 1, center_y + 1))
	tiles.append(map.get_tile(center_x, center_y + 1))
	tiles.append(map.get_tile(center_x - 1, center_y + 1))
	tiles.append(map.get_tile(center_x - 1, center_y))
	tiles.append(map.get_tile(center_x - 1, center_y - 1))

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
				if map.is_tile_type(coord.x - 1, coord.y, TileType.OPEN):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						coord.y * 32.0 + randf() * 32.0)

			2:
				if map.is_tile_type(coord.x + 1, coord.y, TileType.OPEN):
					return Vector2(
						(coord.x + 1) * 32.0 + randf() * 32.0,
						coord.y * 32.0 + randf() * 32.0)

			3:
				if map.is_tile_type(coord.x, coord.y - 1, TileType.OPEN):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						(coord.y - 1) * 32.0 + randf() * 32.0)

			4:
				if map.is_tile_type(coord.x, coord.y + 1, TileType.OPEN):
					return Vector2(
						coord.x * 32.0 + randf() * 32.0,
						(coord.y + 1) * 32.0 + randf() * 32.0)

			5:
				if map.is_tile_type(coord.x - 1, coord.y - 1, TileType.OPEN):
					if map.is_tile_type(coord.x - 1, coord.y, TileType.OPEN) && map.is_tile_type(coord.x, coord.y - 1, TileType.OPEN):
						return Vector2(
							(coord.x - 1) * 32.0 + randf() * 32.0,
							(coord.y - 1) * 32.0 + randf() * 32.0)

			6:
				if map.is_tile_type(coord.x + 1, coord.y - 1, TileType.OPEN):
					if map.is_tile_type(coord.x + 1, coord.y, TileType.OPEN) && map.is_tile_type(coord.x, coord.y - 1, TileType.OPEN):
						return Vector2(
							(coord.x + 1) * 32.0 + randf() * 32.0,
							(coord.y - 1) * 32.0 + randf() * 32.0)

			7:
				if map.is_tile_type(coord.x + 1, coord.y + 1, TileType.OPEN):
					if map.is_tile_type(coord.x + 1, coord.y, TileType.OPEN) && map.is_tile_type(coord.x, coord.y + 1, TileType.OPEN):
						return Vector2(
							(coord.x + 1) * 32.0 + randf() * 32.0,
							(coord.y + 1) * 32.0 + randf() * 32.0)

			8:
				if map.is_tile_type(coord.x - 1, coord.y + 1, TileType.OPEN):
					if map.is_tile_type(coord.x - 1, coord.y, TileType.OPEN) && map.is_tile_type(coord.x, coord.y + 1, TileType.OPEN):
						return Vector2(
							(coord.x - 1) * 32.0 + randf() * 32.0,
							(coord.y + 1) * 32.0 + randf() * 32.0)

	return coord.to_random_pos()

func raycast_minion(from_minion : Minion, to_minion : Minion) -> bool:
	var diff_vec := to_minion.position - from_minion.position
#	raycast.clear_exceptions()
#	raycast.add_exception(from_minion)
	raycast.position = from_minion.position
	raycast.cast_to = diff_vec
	raycast.collision_mask = from_minion.collision_mask

	raycast.force_raycast_update()

	var collider := raycast.get_collider()
	if collider == null:
		return false

	return collider == to_minion

func raycast_minion_to_pos(from_minion : Minion, to_pos : Vector2) -> bool:
	var diff_vec := to_pos - from_minion.position
#	raycast.clear_exceptions()
#	raycast.add_exception(from_minion)
	raycast.position = from_minion.position
	raycast.cast_to = diff_vec
	raycast.collision_mask = 1

	raycast.force_raycast_update()

	var collider := raycast.get_collider()
	return collider == null

func rand_item(array : Array) -> Object:
	return array[randi() % array.size()]

func rand_pop(array : Array) -> Object:
	var index := randi() % array.size()
	var object = array[index]
	array.remove(index)
	return object
