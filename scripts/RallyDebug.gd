extends Node2D

const TileType = preload("res://scripts/TileType.gd").TileType

func _ready() -> void:
	if !visible:
		set_process(false)

func _process(delta: float) -> void:
	update()

func _draw() -> void:
	var map := State.map

	for i in range(map.rally_tiles.size() - 1, -1, -1):
		var rally_tile = map.rally_tiles[i]
		if rally_tile.tile_type != TileType.OPEN:
			continue

		if rally_tile.rally_end_tiles != null:
			if rally_tile.rally_end_tiles.size() > 0:
				for end_tile in rally_tile.rally_end_tiles:
					if end_tile.tile_type != TileType.OPEN:
						continue
					draw_line(
						rally_tile.coord.to_pos()+ Vector2(16,16),
						end_tile.coord.to_pos()+ Vector2(16,16),
						Color.red,
						1)
			else:
				draw_circle(
					rally_tile.coord.to_pos()+ Vector2(16,16),
					2.0,
					Color.green)
#
#			if rally_tile.rally_dir != Vector2.ZERO:
#				draw_line(
#					rally_tile.coord.to_pos()+ Vector2(16,16),
#					rally_tile.coord.to_pos()+ Vector2(16,16) + Vector2(1,1) * rally_tile.rally_dir,
#					Color.red,
#					1)
#
#				draw_line(
#					rally_tile.coord.to_pos()+ Vector2(16,16)+ Vector2(3,3) * rally_tile.rally_dir,
#					rally_tile.coord.to_pos()+ Vector2(16,16) + Vector2(8,8) * rally_tile.rally_dir,
#					Color.red,
#					3)
#			else:
#				draw_circle(
#					rally_tile.coord.to_pos()+ Vector2(16,16),
#					2.0,
#					Color.green)
