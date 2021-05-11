extends Reference

class_name Tile

const AudioType = preload("res://scripts/AudioType.gd").AudioType
const TileType = preload("res://scripts/TileType.gd").TileType

var minions := []
var monsters := []

var inner_prison := false
var prisoners := []

var dig_highlight
var rally_highlight

var x : int
var y : int
var coord : Coord
var id : int
var tile_type

var health : int
var rally_time := 0.0
var rally_countdown := 0.0
var rally_end_tiles := []

# Tiles like START_PORTAL, END_PORTAL or border tiles are immune.
var immune := false

var checked := false

func _init(id : int, x : int, y : int, tile_type) -> void:
	self.id = id
	self.x = x
	self.y = y
	self.coord = Coord.new(x, y)
	self.tile_type = tile_type
	health = State.dirt_health

func _to_string() -> String:
	return "%d / %d: %d" % [x, y, tile_type]

func hurt(amount : int = 1) -> void:
	if health <= 0 || tile_type == TileType.OPEN || immune:
		return

	assert(minions.size() == 0)

	health -= amount

	if health <= 0:
		if dig_highlight != null:
			dig_highlight.queue_free()
			dig_highlight = null
		State.map.set_tile_type(x, y, TileType.OPEN)
		State.tilemap32.set_cell(x, y, 0)
		State.map.dig_tiles.erase(self)

		var prisoner_tiles := []
		var check_tiles = [self]

		while check_tiles.size() > 0:
			var check_count : int = check_tiles.size()
			for i in range(check_count):
				var check_tile : Tile = check_tiles[0]
				check_tiles.remove(0)

				Helper.get_tile_neighbours_4(State.tile_circle, check_tile.x, check_tile.y)
				for next_tile in State.tile_circle:
					if next_tile.inner_prison && !prisoner_tiles.has(next_tile):
						check_tiles.append(next_tile)
						prisoner_tiles.append(next_tile)

		for prisoner_tile in prisoner_tiles:
			if prisoner_tile.prisoners.size() > 0:
				for freed_prisoner in prisoner_tile.prisoners:
					if !is_instance_valid(freed_prisoner):
						# Could have died due to a bomg :(
						continue
					freed_prisoner.prisoner = false
					freed_prisoner.pickaxe.visible = true

					if freed_prisoner.king:
						State.minion_king_count += 1

					State.minions.append(freed_prisoner)
				prisoner_tile.prisoners.clear()

