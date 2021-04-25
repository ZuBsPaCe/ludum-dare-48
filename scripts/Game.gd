extends Node2D

const GameState = preload("res://scripts/GameState.gd").GameState
const TileType = preload("res://scripts/TileType.gd").TileType

var cursor_dig = preload("res://sprites/CursorDig.png")
var cursor_rally = preload("res://sprites/CursorRally.png")

export(PackedScene) var minion_scene
export(PackedScene) var dig_highlight_scene

onready var _navigation := $Navigation2D
onready var _tilemap32 := $Navigation2D/TileMap32
onready var _entity_container := $EntityContainer
onready var _dig_highlight_container := $DigHighlightContainer
onready var _camera := $GameCamera
onready var _cursor_highlight := $CursorHighlight
onready var _dig_button := $HUD/MarginContainer/HBoxContainer/DigButton
onready var _rally_button := $HUD/MarginContainer/HBoxContainer/RallyButton


var _fullscreen_cooldown := Cooldown.new(0.5)
var _dig_traverse_cooldown := Cooldown.new(1.0)

var _map := Map.new()

var _offsets4 := [
	Coord.new(0, -1),
	Coord.new(-1, 0),
	Coord.new(1, 0),
	Coord.new(0, 1)]

var _offsets8 := [
	Coord.new(0, -1),
	Coord.new(-1, 0),
	Coord.new(1, 0),
	Coord.new(0, 1),
	Coord.new(-1, -1),
	Coord.new(1, -1),
	Coord.new(-1, 1),
	Coord.new(1, 1)]

enum ToolType {
	DIG,
	RALLY
}


enum CommandType {
	NONE,
	ADD_DIG,
	REMOVE_DIG
}

enum MapType{
	CAVES
}


var _map_type = MapType.CAVES

var _tool_type = ToolType.DIG
var _command_type = CommandType.NONE
var _mouse_on_button := false


func _ready() -> void:
	State.map = _map
	Helper.map = _map

	State.tilemap32 = _tilemap32

	world_reset()
	game_reset()
	game_start()

func _process(delta: float) -> void:
	_fullscreen_cooldown.step(delta)
	_dig_traverse_cooldown.step(delta)

	if OS.get_name() == "Windows":
		if !_fullscreen_cooldown.running && Input.is_key_pressed(KEY_ALT) && Input.is_key_pressed(KEY_ENTER):
			OS.window_fullscreen = !OS.window_fullscreen
			_fullscreen_cooldown.restart()

	if State.game_state == GameState.GAME_RUNNING:
		var mouse_pos := get_global_mouse_position()
		var mouse_coord := Coord.new()
		mouse_coord.set_vector(mouse_pos)

		_camera.position = mouse_pos

		var mouse_tile = -1

		if _map.is_valid(mouse_coord.x, mouse_coord.y):
			mouse_tile = _map.get_tile_type(mouse_coord.x, mouse_coord.y)



		if _tool_type == ToolType.DIG:
			if mouse_tile == TileType.DIRT:
				if mouse_tile == TileType.DIRT && !_mouse_on_button:
					_cursor_highlight.position = mouse_coord.to_pos()
					_cursor_highlight.visible = true
				else:
					_cursor_highlight.visible = false


				if _command_type == CommandType.NONE:
					if Input.is_action_just_pressed("command") && !_mouse_on_button:
						var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
						if tile.dig_highlight == null:
							_command_type = CommandType.ADD_DIG
						else:
							_command_type = CommandType.REMOVE_DIG
				else:
					if Input.is_action_just_released("command"):
						_command_type = CommandType.NONE

				if !_mouse_on_button:
					if _command_type == CommandType.ADD_DIG:
						var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
						if tile.dig_highlight == null:
							_map.dig_tiles.append(tile)
							var dig_highlight : Node2D = dig_highlight_scene.instance()
							dig_highlight.position = mouse_coord.to_pos()
							_dig_highlight_container.add_child(dig_highlight)
							tile.dig_highlight = dig_highlight
					elif _command_type == CommandType.REMOVE_DIG:
						var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
						if tile.dig_highlight != null:
							_map.dig_tiles.erase(tile)
							tile.dig_highlight.queue_free()
							tile.dig_highlight = null


		if _dig_traverse_cooldown.done:
			_dig_traverse_cooldown.restart()
			game_traverse_dig_tiles()


func world_reset() -> void:
	State.world_reset()

func game_reset() -> void:
	State.game_state = GameState.TITLE_SCREEN
	_cursor_highlight.visible = false
	_dig_button.pressed = true
	_rally_button.pressed = false

	_tool_type = ToolType.DIG
	_command_type = CommandType.NONE
	_mouse_on_button = false

func game_start() -> void:
	randomize()

	_map_type = MapType.CAVES

	map_generate(32, 32)
	map_fill()

	State.game_state = GameState.GAME_RUNNING

func map_generate(width : int, height : int) -> void:
	_map.setup(width, height, TileType.DIRT)

	var start_radius := randi() % 3 + 2
	var start_x := width / 2
	var start_y := start_radius + 2
	var start_coord := Coord.new(start_x, start_y)

	var center_tiles := Helper.get_tile_circle(start_x, start_y, start_radius)
	for tile in center_tiles:
		_map.set_tile_type(tile.x, tile.y, TileType.MINION_START)

	for x in range(0, width):
		_map.set_tile_type(x, 0, TileType.ROCK)
		_map.set_tile_type(x, height - 1, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(x, 1, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(x, height - 2, TileType.ROCK)

	for y in range(0, height):
		_map.set_tile_type(0, y, TileType.ROCK)
		_map.set_tile_type(width - 1, y, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(1, y, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(width - 2, y, TileType.ROCK)

	if _map_type == MapType.CAVES:
		var total_cave_count := randi() % 8 + 8
		var cave_count := 0

		while cave_count < total_cave_count:
			var radius := randi() % 10 + 1

			var center := Coord.new(randi() % (width - 4) + 2, randi() % (height - 4) + 2)
			if center.distance_to(start_coord) <= radius + start_radius + 3:
				continue

			var cave_tiles := Helper.get_tile_circle(center.x, center.y, radius)
			for tile in cave_tiles:
				if tile.tile_type != TileType.DIRT:
					center.distance_to(start_coord)
				_map.set_tile_type(tile.x, tile.y, TileType.GROUND)

			cave_count += 1

func map_fill() -> void:
	var minion_coords := []

	for y in range(_map.height):
		for x in range(_map.width):
			var tile = _map.get_tile_type(x, y)

			match tile:
				TileType.DIRT:
					_tilemap32.set_cell(x, y, 1)

				TileType.ROCK:
					_tilemap32.set_cell(x, y, 2)

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


func game_traverse_dig_tiles():
	if _map.dig_tiles.size() == 0:
		return

	var seen_tiles := {}

	for dig_tile in _map.dig_tiles:
		for offset in _offsets8:
			var x : int = dig_tile.x + offset.x
			var y : int = dig_tile.y + offset.y

			if !_map.is_valid(x, y):
				continue

			var next_tile : Tile = _map.get_tile(x, y)
			if next_tile.tile_type != TileType.GROUND:
				continue

			if offset.x != 0 && offset.y != 0:
				var check_tile1 : Tile = _map.get_tile(x, dig_tile.y)
				var check_tile2 : Tile = _map.get_tile(dig_tile.x, y)
				if check_tile2.tile_type != TileType.GROUND && check_tile2.tile_type != TileType.GROUND:
					continue

			if seen_tiles.has(next_tile):
				continue

			seen_tiles[next_tile] = 1

			for minion in next_tile.minions:
				if minion.can_start_digging():

					var coord := Coord.new(dig_tile.x, dig_tile.y)

					var path = _navigation.get_simple_path(
						minion.position,
						coord.to_random_pos())

					if path.size() > 0:
						minion.dig(path, dig_tile)
					else:
						printerr("No path found...")


func _on_Button_mouse_entered() -> void:
	_mouse_on_button = true

func _on_Button_mouse_exited() -> void:
	_mouse_on_button = false

func _on_DigButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_rally_button.pressed = false
		set_tool(ToolType.DIG)

func _on_RallyButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_dig_button.pressed = false
		set_tool(ToolType.RALLY)

func set_tool(tool_type) -> void:
	_tool_type = tool_type

	match tool_type:
		ToolType.DIG:
			Input.set_custom_mouse_cursor(cursor_dig, 0, Vector2(16, 16))
		ToolType.RALLY:
			Input.set_custom_mouse_cursor(cursor_rally, 0, Vector2(16, 16))
