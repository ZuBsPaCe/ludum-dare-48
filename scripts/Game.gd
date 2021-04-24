extends Node2D

export(PackedScene) var minion_scene
export(PackedScene) var ground_tile

onready var _tilemap32 := $TileMap32
onready var _entity_container := $EntityContainer

var _map : Map


var _state_minion_count : int


enum TileType {
	GROUND,
	MINION_START
}

func _ready() -> void:
	world_reset()
	game_reset()
	game_start()

func world_reset() -> void:
	_state_minion_count = 10

func game_reset() -> void:
	pass

func game_start() -> void:
	randomize()

	map_generate(32, 32)
	map_fill()

func map_generate(width : int, height : int) -> void:
	_map = Map.new(width, height, TileType.GROUND)

	var half_width = width / 2
	for y in range(8, 11):
		for x in range(half_width - 1, half_width + 2):
			_map.set_tile(x, y, TileType.MINION_START)

func map_fill() -> void:
	var minion_coords := []

	for y in range(_map.height):
		for x in range(_map.width):
			var tile = _map.get_tile(x, y)

			match tile:
				TileType.GROUND:
					_tilemap32.set_cell(x, y, tile)

				TileType.MINION_START:
					_tilemap32.set_cell(x, y, tile)
					minion_coords.append(Coord.new(x, y))

	for i in range(_state_minion_count):
		var coord : Coord = minion_coords[randi() % minion_coords.size()]
		var minion : Minion = minion_scene.instance()
		minion.position = coord.to_random_pos()
		_entity_container.add_child(minion)



