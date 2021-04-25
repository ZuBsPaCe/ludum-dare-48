extends Node2D

const GameState = preload("res://scripts/GameState.gd").GameState
const TileType = preload("res://scripts/TileType.gd").TileType

var cursor_dig = preload("res://sprites/CursorDig.png")
var cursor_rally = preload("res://sprites/CursorRally.png")

export(PackedScene) var minion_scene
export(PackedScene) var dig_highlight_scene
export(PackedScene) var rally_highlight_scene

onready var _tilemap32 := $TileMap32
onready var _entity_container := $EntityContainer
onready var _highlight_container := $HighlightContainer
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


		match _tool_type:
			ToolType.DIG:
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
								_highlight_container.add_child(dig_highlight)
								tile.dig_highlight = dig_highlight
						elif _command_type == CommandType.REMOVE_DIG:
							var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
							if tile.dig_highlight != null:
								_map.dig_tiles.erase(tile)
								tile.dig_highlight.queue_free()
								tile.dig_highlight = null

			ToolType.RALLY:
				if Input.is_action_pressed("command"):
					var tiles := Helper.get_tile_circle(mouse_coord.x, mouse_coord.y, State.rally_radius)
					for tile in tiles:
						if tile.tile_type != TileType.GROUND:
							continue
						var distance := mouse_coord.distance_to(tile.coord)
						var rally := (1.0 - distance / (State.rally_radius + 1)) * State.rally_duration
						print(distance)
						if rally < tile.rally:
							continue
						tile.rally = rally
						if tile.rally_highlight == null:
							_map.rally_tiles.append(tile)
							var rally_highlight : Node2D = rally_highlight_scene.instance()
							rally_highlight.position = tile.coord.to_pos()
							_highlight_container.add_child(rally_highlight)
							tile.rally_highlight = rally_highlight


		if _dig_traverse_cooldown.done:
			_dig_traverse_cooldown.restart()
			game_traverse_dig_tiles()

		game_traverse_rally_tiles(delta)


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
	_camera.limit_right = width * 32
	_camera.limit_bottom = height * 32

	_map.setup(width, height, TileType.DIRT)

	var start_radius := randi() % 3 + 2
	var start_x := width / 2
	var start_y := start_radius + 2
	var start_coord := Coord.new(start_x, start_y)

	#start_radius = 2

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

	var minion_to_path := {}
	var minion_to_dig_tile := {}

	for dig_tile in _map.dig_tiles:
		_map.astar.set_point_disabled(dig_tile.id, false)

		var tiles := Helper.get_tile_circle(dig_tile.x, dig_tile.y, 5)

		for from_tile in tiles:
			if from_tile.tile_type != TileType.GROUND:
				continue

			for minion in from_tile.minions:
				if minion.can_start_digging():

					var path = _map.astar.get_point_path(minion.tile.id, dig_tile.id)

					if path.size() == 0 || path.size() > 4:
						continue

					if !minion_to_path.has(minion):
						minion_to_path[minion] = path
						minion_to_dig_tile[minion] = dig_tile
					else:
						var other_path = minion_to_path[minion]
						if path.size() < other_path.size():
							minion_to_path[minion] = path
							minion_to_dig_tile[minion] = dig_tile

		_map.astar.set_point_disabled(dig_tile.id, true)

	for minion in minion_to_path:
		var path = minion_to_path[minion]
		var dig_tile = minion_to_dig_tile[minion]
		minion.dig(path, dig_tile)

func game_traverse_rally_tiles(delta : float):
	if _map.rally_tiles.size() == 0:
		return

	for i in range(_map.rally_tiles.size() - 1, -1, -1):
		var rally_tile = _map.rally_tiles[i]
		rally_tile.rally -= delta
		if rally_tile.rally <= 0:
			rally_tile.rally = 0
			rally_tile.rally_highlight.queue_free()
			rally_tile.rally_highlight = null
			_map.rally_tiles.remove(i)
		else:
			rally_tile.rally_highlight.modulate = Color(1, 1, 1, rally_tile.rally / State.rally_duration)



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
