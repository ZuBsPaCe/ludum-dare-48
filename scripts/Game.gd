extends Node2D

const GameState = preload("res://scripts/GameState.gd").GameState
const TileType = preload("res://scripts/TileType.gd").TileType

export(PackedScene) var minion_scene
export(PackedScene) var tile_highlight_scene

onready var _tilemap32 := $TileMap32
onready var _entity_container := $EntityContainer
onready var _tile_highlight_container := $TileHighlightContainer
onready var _camera := $GameCamera
onready var _cursor_highlight := $CursorHighlight


var _fullscreen_cooldown := Cooldown.new(0.5)


var _map := Map.new()


enum CommandType {
	NONE,
	ADD_BUILD,
	REMOVE_BUILD
}

var _command_type = CommandType.NONE


func _ready() -> void:
	State.map = _map
	Helper.map = _map

	world_reset()
	game_reset()
	game_start()

func _process(delta: float) -> void:
	_fullscreen_cooldown.step(delta)

	if OS.get_name() == "Windows":
		if !_fullscreen_cooldown.running && Input.is_key_pressed(KEY_ALT) && Input.is_key_pressed(KEY_ENTER):
			OS.window_fullscreen = !OS.window_fullscreen
			_fullscreen_cooldown.restart()

	if State.game_state == GameState.GAME_RUNNING:
		var mouse_pos := get_global_mouse_position()
		var mouse_coord := Coord.new()
		mouse_coord.set_vector(mouse_pos)

		var mouse_tile = -1

		if _map.is_valid(mouse_coord.x, mouse_coord.y):
			mouse_tile = _map.get_tile_type(mouse_coord.x, mouse_coord.y)

		if mouse_tile == TileType.ROCK:
			_cursor_highlight.position = mouse_coord.to_pos()
			_cursor_highlight.visible = true

			if _command_type == CommandType.NONE:
				if Input.is_action_just_pressed("command"):
					var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
					if tile.tile_highlight == null:
						_command_type = CommandType.ADD_BUILD
					else:
						_command_type = CommandType.REMOVE_BUILD
			else:
				if Input.is_action_just_released("command"):
					_command_type = CommandType.NONE

			if _command_type == CommandType.ADD_BUILD:
				var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
				if tile.tile_highlight == null:
					_map.build_tiles.append(tile)
					var tile_highlight : Node2D = tile_highlight_scene.instance()
					tile_highlight.position = mouse_coord.to_pos()
					_tile_highlight_container.add_child(tile_highlight)
					tile.tile_highlight = tile_highlight
			elif _command_type == CommandType.REMOVE_BUILD:
				var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
				if tile.tile_highlight != null:
					_map.build_tiles.erase(tile)
					tile.tile_highlight.queue_free()
					tile.tile_highlight = null

		else:
			_cursor_highlight.visible = false

func world_reset() -> void:
	State.world_reset()

func game_reset() -> void:
	State.game_state = GameState.TITLE_SCREEN
	_cursor_highlight.visible = false

func game_start() -> void:
	randomize()
	map_generate(32, 32)
	map_fill()

	State.game_state = GameState.GAME_RUNNING

func map_generate(width : int, height : int) -> void:
	_map.setup(width, height, TileType.ROCK)

	var half_width = width / 2
	for y in range(8, 11):
		for x in range(half_width - 1, half_width + 2):
			_map.set_tile_type(x, y, TileType.MINION_START)

func map_fill() -> void:
	var minion_coords := []

	for y in range(_map.height):
		for x in range(_map.width):
			var tile = _map.get_tile_type(x, y)

			match tile:
				TileType.ROCK:
					_tilemap32.set_cell(x, y, 1)

				TileType.GROUND:
					_tilemap32.set_cell(x, y, 0)

				TileType.MINION_START:
					_tilemap32.set_cell(x, y, 0)
					minion_coords.append(Coord.new(x, y))

					_map.set_tile_type(x, y, TileType.GROUND)

	for i in range(State.minion_count):
		var coord : Coord = minion_coords[randi() % minion_coords.size()]
		var minion : Minion = minion_scene.instance()
		minion.position = coord.to_random_pos()
		_entity_container.add_child(minion)

		if i == 0:
			_camera.position = coord.to_random_pos()



