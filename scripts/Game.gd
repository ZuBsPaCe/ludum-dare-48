extends Node2D

const GameState = preload("res://scripts/GameState.gd").GameState
const TileType = preload("res://scripts/TileType.gd").TileType
const AudioType = preload("res://scripts/AudioType.gd").AudioType
const NodeType = preload("res://scripts/NodeType.gd").NodeType

const bomb_distance := 160.0
const bomb_distance_sq := bomb_distance * bomb_distance
const bomb_distance_half := bomb_distance * 0.5
const bomb_distance_double_sq := bomb_distance_sq * 2.0

var cursor_dig = preload("res://sprites/CursorDig.png")
var cursor_rally = preload("res://sprites/CursorRally.png")
var cursor_bomb = preload("res://sprites/CursorBomb.png")

export(PackedScene) var minion_scene
export(PackedScene) var dig_highlight_scene
export(PackedScene) var rally_highlight_scene
export(PackedScene) var portal_scene
export(PackedScene) var explosion_scene

onready var _tilemap32 := $TileMap32
onready var _entity_container := $EntityContainer
onready var _explosion_container := $ExplosionContainer
onready var _highlight_container := $HighlightContainer
onready var _camera := $GameCamera
onready var _cursor_highlight := $CursorHighlight
onready var _bomb_indicator := $BombIndicator
onready var _bomb_indicator_part := $BombIndicator/BombIndicatorPartSprite
onready var _dig_button := $HUD/MarginContainer/HBoxContainer/DigButton
onready var _rally_button := $HUD/MarginContainer/HBoxContainer/RallyButton
onready var _bomb_button := $HUD/MarginContainer/HBoxContainer/BombButton
onready var _raycast := $RayCast2D
onready var _bomb_count_label := $HUD/MarginContainer/HBoxContainer/BombButton/BombCount


var title_music_target := -80.0
var track1_target := -80.0


var _fullscreen_cooldown := Cooldown.new(0.5)
var _dig_traverse_cooldown := Cooldown.new(1.0)
var _start_battle_cooldown := Cooldown.new()
var _level_done_cooldown := Cooldown.new(2.0)
var _check_level_done_cooldown := Cooldown.new(2.0)
var _spawn_cooldown := Cooldown.new(5.0)


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
	RALLY,
	BOMB
}


enum CommandType {
	NONE,
	ADD_DIG,
	REMOVE_DIG,
	ADD_RALLY
}

enum MapType{
	CAVES
}



var _map_type = MapType.CAVES

var _tool_type = ToolType.DIG
var _command_type = CommandType.NONE
var _mouse_on_button := false

var _drag_start_mouse_pos := Vector2()
var _drag_start_camera_pos := Vector2()

var _mouse_wheel := 0.0
var _mouse_wheel_direction := 0.0

var _rally_last_mouse_pos := Vector2()
var _rally_last_tiles := []

var _level_done := false

var _loading := true

var _tiles := []

var _world_layers := [
	WorldLayer.new(
		1, 1, [
			WorldConnection.new(0, 0)]),
	WorldLayer.new(
		1, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1)]),
	WorldLayer.new(
		1, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(0, 2)]),
	WorldLayer.new(
		1, 4, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(0, 2),
			WorldConnection.new(0, 3)]),

	WorldLayer.new(
		2, 1, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0)]),
	WorldLayer.new(
		2, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1, "A"),
			WorldConnection.new(1, 0, "A"),
			WorldConnection.new(1, 1)]),
	WorldLayer.new(
		2, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(1, 1),
			WorldConnection.new(1, 2)]),
	WorldLayer.new(
		2, 4, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(0, 2, "A"),
			WorldConnection.new(1, 1, "A"),
			WorldConnection.new(1, 2),
			WorldConnection.new(1, 3)]),

	WorldLayer.new(
		3, 1, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(2, 0)]),
	WorldLayer.new(
		3, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(1, 1),
			WorldConnection.new(2, 1)]),
	WorldLayer.new(
		3, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1, "A"),
			WorldConnection.new(1, 0, "A"),
			WorldConnection.new(1, 1),
			WorldConnection.new(1, 2, "B"),
			WorldConnection.new(2, 1, "B"),
			WorldConnection.new(2, 2)]),
	WorldLayer.new(
		3, 4, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(1, 2),
			WorldConnection.new(1, 2),
			WorldConnection.new(2, 2),
			WorldConnection.new(2, 3)]),

	WorldLayer.new(
		4, 1, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(2, 0),
			WorldConnection.new(3, 0)]),
	WorldLayer.new(
		4, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(1, 1, "A"),
			WorldConnection.new(2, 0, "A"),
			WorldConnection.new(2, 1),
			WorldConnection.new(3, 1)]),
	WorldLayer.new(
		4, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(1, 1),
			WorldConnection.new(2, 1),
			WorldConnection.new(2, 2),
			WorldConnection.new(3, 2)]),
	WorldLayer.new(
		4, 4, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1, "A"),
			WorldConnection.new(1, 0, "A"),
			WorldConnection.new(1, 1),
			WorldConnection.new(1, 2, "B"),
			WorldConnection.new(2, 1, "B"),
			WorldConnection.new(2, 2),
			WorldConnection.new(2, 3, "C"),
			WorldConnection.new(3, 2, "C"),
			WorldConnection.new(3, 3)])
]


func _ready() -> void:
	State.config = ConfigFile.new()
	State.config.load(State.config_path)

	if !State.config.has_section_key("Display", "Fullscreen"):
		State.config.set_value("Display", "Fullscreen", false)

	if !State.config.has_section_key("Audio", "Music"):
		State.config.set_value("Audio", "Music", 0.8)

	if !State.config.has_section_key("Audio", "Sound"):
		State.config.set_value("Audio", "Sound", 0.8)

	$Screens/Title/MusicSlider.value = State.config.get_value("Audio", "Music")
	$Screens/Title/SoundSlider.value = State.config.get_value("Audio", "Sound")

	State.entity_container = $EntityContainer
	State.map = _map
	Helper.map = _map
	Helper.raycast = _raycast

	State.tilemap32 = _tilemap32
	State.game_camera = $GameCamera


	if OS.get_name() == "HTML5":
		$Screens/Title/ExitButton.visible = false
	else:
		OS.window_fullscreen = State.config.get_value("Display", "Fullscreen")

	$Screens/PostProcess.visible = true

	$Screens/Title/StartButton.text = "START"
	$Screens/Title/NewGameButton.visible = false

	_loading = false

	switch_state(GameState.TITLE_SCREEN)

func _input(event: InputEvent) -> void:
	if State.game_state == GameState.WORLD_MAP:
		if event is InputEventMouseButton:
			if event.is_pressed():
				if event.button_index == BUTTON_WHEEL_DOWN:
					_mouse_wheel_direction = 1.0
				elif event.button_index == BUTTON_WHEEL_UP:
					_mouse_wheel_direction = -1.0

func _process(delta: float) -> void:
	if OS.get_name() != "HTML5":
		_fullscreen_cooldown.step(delta)
		if !_fullscreen_cooldown.running && Input.is_key_pressed(KEY_ALT) && Input.is_key_pressed(KEY_ENTER):
			OS.window_fullscreen = !OS.window_fullscreen
			State.config.set_value("Display", "Fullscreen", OS.window_fullscreen)
			State.config.save(State.config_path)
			_fullscreen_cooldown.restart()


	if title_music_target > -80.0:
		if !$TitleMusic.playing && $TitleMusic.volume_db == -80.0:
			$TitleMusic.play()
		if $TitleMusic.volume_db < 0.0:
			$TitleMusic.volume_db = min(0.0, $TitleMusic.volume_db + delta * 20.0)
	else:
		if $TitleMusic.volume_db > -80.0:
			$TitleMusic.volume_db = max(-80.0, $TitleMusic.volume_db - delta * 20.0)
		else:
			$TitleMusic.stop()


	if track1_target > -80.0:
		if !$Track1.playing && $Track1.volume_db == -80.0:
			$Track1.play()
		if $Track1.volume_db < 0.0:
			$Track1.volume_db = min(0.0, $Track1.volume_db + delta * 40.0)
	else:
		if $Track1.volume_db > -80.0:
			$Track1.volume_db = max(-80.0, $Track1.volume_db - delta * 40.0)
		else:
			$Track1.stop()

	var mouse_pos := get_global_mouse_position()

	if State.game_state == GameState.GAME || State.game_state == GameState.WORLD_MAP:
		if Input.is_action_just_pressed("alternate"):
			_drag_start_mouse_pos = get_viewport().get_mouse_position()
			_drag_start_camera_pos = _camera.position


		var new_camera_position = null

		if Input.is_action_pressed("alternate"):
			var drag_vec = (_drag_start_mouse_pos - get_viewport().get_mouse_position()) * _camera.zoom
			new_camera_position = _drag_start_camera_pos + drag_vec
		else:
			var drag_vec := Vector2()
			if Input.is_action_pressed("up"):
				drag_vec.y -= 1
			if Input.is_action_pressed("down"):
				drag_vec.y += 1
			if Input.is_action_pressed("left"):
				drag_vec.x -= 1
			if Input.is_action_pressed("right"):
				drag_vec.x += 1

			if State.game_state == GameState.WORLD_MAP && (_mouse_wheel != 0.0 || _mouse_wheel_direction != 0.0):
				if _mouse_wheel_direction != 0.0:
					if _mouse_wheel_direction < 0.0:
						_mouse_wheel = max(-1.0, _mouse_wheel - delta * 4.0)

					else:
						_mouse_wheel = min(1.0, _mouse_wheel + delta * 4.0)

					if abs(_mouse_wheel) == 1.0:
							_mouse_wheel_direction = 0.0
				else:
					if _mouse_wheel < 0.0:
						_mouse_wheel = min(0.0, _mouse_wheel + delta * 2.0)
					else:
						_mouse_wheel = max(0.0, _mouse_wheel - delta * 2.0)

				drag_vec.y += _mouse_wheel

			new_camera_position = _camera.position + drag_vec * 768.0 * delta

		if new_camera_position != null:
			#var screen_size = get_viewport().size
			var screen_size = get_viewport_rect().size
			var screen_half = screen_size * 0.5 * _camera.zoom
			new_camera_position.x = max(new_camera_position.x, screen_half.x)
			new_camera_position.x = min(new_camera_position.x, _camera.limit_right - screen_half.x)
			new_camera_position.y = max(new_camera_position.y, screen_half.y)
			new_camera_position.y = min(new_camera_position.y, _camera.limit_bottom - screen_half.y)
			_camera.position = new_camera_position


	if State.game_state == GameState.GAME:
		_dig_traverse_cooldown.step(delta)
		_start_battle_cooldown.step(delta)
		_level_done_cooldown.step(delta)
		_check_level_done_cooldown.step(delta)
		_spawn_cooldown.step(delta)

		var mouse_tile = -1
		var mouse_coord := Coord.new()
		mouse_coord.set_vector(mouse_pos)

		if _map.is_valid(mouse_coord.x, mouse_coord.y):
			mouse_tile = _map.get_tile_type(mouse_coord.x, mouse_coord.y)


		match _tool_type:
			ToolType.DIG:
				if (mouse_tile == TileType.DIRT || mouse_tile == TileType.PRISON) && !_mouse_on_button:
					_cursor_highlight.position = mouse_coord.to_pos()
					_cursor_highlight.visible = true
				else:
					_cursor_highlight.visible = false

				if Input.is_action_just_released("command"):
					_command_type = CommandType.NONE

				elif mouse_tile == TileType.DIRT || mouse_tile == TileType.PRISON:
					if _command_type == CommandType.NONE:
						if Input.is_action_just_pressed("command") && !_mouse_on_button:
							var tile : Tile = _map.get_tile(mouse_coord.x, mouse_coord.y)
							if tile.dig_highlight == null:
								_command_type = CommandType.ADD_DIG
							else:
								_command_type = CommandType.REMOVE_DIG

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
				var set_rally := false

				if _command_type == CommandType.NONE:
					if Input.is_action_just_pressed("command") && !_mouse_on_button:
						_command_type = CommandType.ADD_RALLY
						_rally_last_mouse_pos = mouse_pos
						_rally_last_tiles.clear()
						set_rally = true

				if _command_type == CommandType.ADD_RALLY:
					if Input.is_action_pressed("command"):
						var move_dir : Vector2

						if _rally_last_mouse_pos.distance_to(mouse_pos) > 64:
							set_rally = true
							_rally_last_mouse_pos = mouse_pos

					if Input.is_action_just_released("command"):
						set_rally = true

					if set_rally:

						Helper.get_tile_circle(_tiles, mouse_coord.x, mouse_coord.y, State.rally_radius)
						for i in range(_tiles.size() - 1, -1, -1):
							if _tiles[i].tile_type != TileType.GROUND:
								_tiles.remove(i)

						for current_tile in _tiles:
							var distance := mouse_coord.distance_to(current_tile.coord)
							var rally_countdown := (1.0 - distance / (State.rally_radius + 1)) * State.rally_duration

							if current_tile.rally_countdown < rally_countdown:
								current_tile.rally_countdown = rally_countdown

							current_tile.rally_time = 0.0
							current_tile.rally_end_tiles.clear()

							if current_tile.rally_highlight == null:
								_map.rally_tiles.append(current_tile)
								var rally_highlight : Node2D = rally_highlight_scene.instance()
								rally_highlight.position = current_tile.coord.to_pos()
								_highlight_container.add_child(rally_highlight)
								current_tile.rally_highlight = rally_highlight

						if _tiles.size() > 0:
							for last_tile in _rally_last_tiles:
								if last_tile in _tiles:
									continue

								last_tile.rally_end_tiles.append_array(_tiles)
								for minion in last_tile.minions:
									minion.rally_immune = 0

							_rally_last_tiles = _tiles.duplicate()

				if Input.is_action_just_released("command"):
					_command_type = CommandType.NONE

			ToolType.BOMB:
				var valid := false
				var nearest_minion_distance_sq := 0
				var nearest_minion = null
				var nearest_minion_visible = false

				var has_bombs := State.bomb_count > 0

				if has_bombs:
					for minion in State.minions:
						var minion_pos : Vector2 = minion.position + Vector2(0, -8.0)
						var distance_sq = minion_pos.distance_to(mouse_pos)
						if distance_sq <= bomb_distance_double_sq:
							var minion_visible : bool = Helper.raycast_minion_to_pos(minion, mouse_pos)

							if nearest_minion == null || distance_sq < nearest_minion_distance_sq || !nearest_minion_visible && minion_visible:
								nearest_minion = minion
								nearest_minion_distance_sq = distance_sq
								nearest_minion_visible = minion_visible

				var can_bomb : bool = (
					has_bombs &&
					mouse_tile == TileType.GROUND &&
					nearest_minion != null &&
					nearest_minion_visible &&
					nearest_minion_distance_sq <= bomb_distance_sq)

				if has_bombs && nearest_minion != null:
					_bomb_indicator.position = nearest_minion.position + Vector2(0, -8.0)
					_bomb_indicator.rotation = Vector2.DOWN.angle_to(nearest_minion.position - mouse_pos)
					_bomb_indicator_part.visible = nearest_minion_visible
					_bomb_indicator.visible = true
				else:
					_bomb_indicator.visible = false

				if can_bomb:
					if Input.is_action_just_pressed("command") && !_mouse_on_button:
						State.bomb_count -= 1
						_bomb_count_label.text = str(State.bomb_count)

						var entities := []
						Helper.get_tile_circle(_tiles, mouse_coord.x, mouse_coord.y, 8)
						for tile in _tiles:
							for monster in tile.monsters:
								if monster.position.distance_to(mouse_pos) > bomb_distance_half:
									continue
								monster.show_blood_effect(State.entity_container)
								entities.append(monster)
							for minion in tile.minions:
								if minion.position.distance_to(mouse_pos) > bomb_distance_half:
									continue
								minion.show_blood_effect(State.entity_container)
								entities.append(minion)

						var explosion : Node2D = explosion_scene.instance()
						explosion.position = mouse_pos
						explosion.rotation = randf() * 2 * PI
						_explosion_container.add_child(explosion)

						for entity in entities:
							entity.show_blood_drop_effect(_explosion_container)
							entity.die()

		if _dig_traverse_cooldown.done:
			_dig_traverse_cooldown.restart()
			game_traverse_dig_tiles()

		game_traverse_rally_tiles(delta)
		game_start_battles()

		if _check_level_done_cooldown.done:
			_check_level_done_cooldown.restart()
			game_check_level_done()

		if _spawn_cooldown.done && !_level_done && State.monsters.size() > 6 && State.monsters.size() < 100:
			_spawn_cooldown.restart()

			for portal in State.end_portals:
				Helper.get_tile_circle(_tiles, portal.tile.coord.x, portal.tile.coord.y, 2, false)

				while _tiles.size() > 0:
					var index = randi() % _tiles.size()
					var check_tile = _tiles[index]
					if check_tile.tile_type == TileType.GROUND:
						var monster : Minion = minion_scene.instance()
						monster.setup(1, randf() < State.monster_archer_fraction)
						monster.position = check_tile.coord.to_random_pos()
						_entity_container.add_child(monster)
						break

					_tiles.remove(index)

		if Input.is_action_just_pressed("tool1"):
			set_tool(ToolType.DIG)
		elif Input.is_action_just_pressed("tool2"):
			set_tool(ToolType.RALLY)
		elif Input.is_action_just_pressed("tool3"):
			set_tool(ToolType.BOMB)


func world_reset() -> void:
	State.world_reset()

func world_start() -> void:
	randomize()

	var layer_count := 8
	var layer_counts := []

	for i in (layer_count * 4):
		State.world_node_noise.append(Vector2(randf() * 64.0 - 32.0, randf() * 64.0 - 32.0))

	var random_node_count := 0

	var prev1 := 0
	var prev2 := 0

	layer_counts.append(1)

	for i in range(1, layer_count - 1):
		var next_count : int
		while true:
			next_count = randi() % 3 + 2
			if prev1 == prev2 && prev1 == next_count:
				continue
			break

		layer_counts.append(next_count)
		prev2 = prev1
		prev1 = next_count

		random_node_count += next_count

	layer_counts.append(1)


	var valid_node_types := [
		NodeType.PORTAL,
		NodeType.ESCORT,
		NodeType.RESCUE,
		NodeType.DEFEND]

	var random_node_types := []
	var valid_node_types_index = 0
	for i in random_node_count:
		if i <= 2:
			random_node_types.append(NodeType.MERCHANT)
		else:
			random_node_types.append(valid_node_types[valid_node_types_index])
			valid_node_types_index = posmod(valid_node_types_index + 1, valid_node_types.size())


	var layer_connections := []
	var layer_node_types := []

	var node_to_node_types := {}
	node_to_node_types[0] = NodeType.PORTAL
	layer_node_types.append([NodeType.PORTAL])

	for i in range(0, layer_counts.size() - 1):
		var upper_count : int = layer_counts[i]
		var lower_count : int = layer_counts[i + 1]

		var possible_connections := []
		for world_layer in _world_layers:
			if world_layer.upper_count == upper_count && world_layer.lower_count == lower_count:
				possible_connections = world_layer.world_connections
				break

		assert(possible_connections.size() > 0)
		var valid_permutations := []

		var bit_count := possible_connections.size()
		var permutations := pow(2, bit_count)
		for permutation in range(permutations):
			var valid := true
			var connected_upper_indexes := {}
			var connected_lower_indexes := {}
			var groups := {}

			for bit_offset in range(bit_count):
				var bit_set : bool = (permutation & (1 << bit_offset)) > 0
				if bit_set:
					var connection : WorldConnection= possible_connections[bit_offset]
					if connection.group != "":
						if groups.has(connection.group):
							valid = false
							break
						groups[connection.group] = 1

					connected_upper_indexes[connection.from] = 1
					connected_lower_indexes[connection.to] = 1

			if valid:
				if connected_upper_indexes.keys().size() != upper_count:
					valid = false
				elif connected_lower_indexes.keys().size() != lower_count:
					valid = false

			if valid:
				valid_permutations.append(permutation)

		assert(valid_permutations.size() > 0)
		var selected_permutation : int = valid_permutations[randi() % valid_permutations.size()]
		var selected_connections := []
		for bit_offset in range(bit_count):
			var bit_set : bool = (selected_permutation & (1 << bit_offset)) > 0
			if bit_set:
				selected_connections.append(possible_connections[bit_offset])

		layer_connections.append(selected_connections)

		if i < layer_counts.size() - 2:
			var current_node_types := []

			for lower_index in lower_count:
				var upper_node_types := []
				for connection in selected_connections:
					if connection.to == lower_index:
						upper_node_types.append(node_to_node_types[i * 4 + connection.from])

				var node_type = null
				for test in 10:
					var random_index = randi() % random_node_types.size()
					node_type = random_node_types[random_index]
					if !upper_node_types.has(node_type) || test == 9:
						random_node_types.remove(random_index)
						current_node_types.append(node_type)
						node_to_node_types[(i + 1) * 4 + lower_index] = node_type
						break

			layer_node_types.append(current_node_types)

	layer_node_types.append([NodeType.HELL])

	State.world_layer_counts = layer_counts
	State.world_layer_connections = layer_connections
	State.world_layer_node_types = layer_node_types


func game_reset() -> void:
	_cursor_highlight.visible = false
	_bomb_indicator.visible = false

	_dig_button.pressed = true
	_rally_button.pressed = false

	_tool_type = ToolType.DIG
	_command_type = CommandType.NONE
	_mouse_on_button = false

	for child in $EntityContainer.get_children():
		child.queue_free()

	for child in $HighlightContainer.get_children():
		child.queue_free()

	_tilemap32.clear()

	State.game_reset()

func game_start() -> void:
	State.increase_level()
	_spawn_cooldown.restart(State.spawn_cooldown)

	_map_type = MapType.CAVES
	_level_done = false

	map_generate(32, 32)
	map_fill()


func map_generate(width : int, height : int) -> void:
	_camera.limit_right = width * 32
	_camera.limit_bottom = height * 32
	_bomb_count_label.text = str(State.bomb_count)


	_map.setup(width, height, TileType.DIRT)

	var start_radius := randi() % 4 + 3
	var start_x := randi() % (width - 10) + 5
	var start_y := start_radius + 2
	var start_coord := Coord.new(start_x, start_y)

	#start_radius = 5

#	for x in range(2, width-2):
#		for y in range(2, 11):
#			_map.set_tile_type(x, y, TileType.GROUND)

	_map.set_tile_type(start_coord.x, start_coord.y, TileType.START_PORTAL)

	var start_tiles := Helper.get_tile_circle_new(start_x, start_y, start_radius, false)
	for tile in start_tiles:
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
		var end_radius := randi() % 4 + 3
		var end_x := randi() % (width - 10) + 5
		var end_y := height - end_radius - 2
		var end_coord := Coord.new(end_x, end_y)

		_map.set_tile_type(end_coord.x, end_coord.y, TileType.END_PORTAL)

		var end_tiles := Helper.get_tile_circle_new(end_x, end_y, end_radius, false)
		for tile in end_tiles:
			_map.set_tile_type(tile.x, tile.y, TileType.MONSTER_START)


		var total_prison_count := State.level + 1
		var prison_count := 0

		var total_cave_count := randi() % (8 + State.level) + (8 + State.level)
		var cave_count := 0

		var monster_tiles := []

		while cave_count < total_cave_count || monster_tiles.size() == 0:
			var radius := randi() % 10 + 1

			var center := Coord.new(randi() % (width - 4) + 2, randi() % (height - 4) + 2)
			if center.distance_to(start_coord) <= radius + start_radius + 3:
				continue

			var cave_tiles := Helper.get_tile_circle_new(center.x, center.y, radius)

			if prison_count < total_prison_count:
				var prison_center_tile = cave_tiles[randi() % cave_tiles.size()]
				var check_prison_tiles := Helper.get_tile_circle_new(prison_center_tile.x, prison_center_tile.y, 8, true)

				var valid_prison := true
				for check_tile in check_prison_tiles:
					if check_tile.tile_type != TileType.DIRT && check_tile.tile_type != TileType.GROUND && check_tile.tile_type != TileType.ROCK:
						valid_prison = false
						break

				if valid_prison:
					var prison_tiles := Helper.get_tile_circle_new(prison_center_tile.x, prison_center_tile.y, 2, true)
					var inner_tiles := prison_tiles.duplicate()

					var inner_tile_count := 1 + randi() % (prison_tiles.size() - 1)

					while inner_tiles.size() > inner_tile_count:
						inner_tiles.remove(randi() % inner_tiles.size())

					for i in range(inner_tiles.size() - 1, -1, -1):
						var inner_tile = inner_tiles[i]
						if inner_tile.coord.x == 0 || inner_tile.coord.y == 0 || inner_tile.coord.x == _map.width - 1 || inner_tile.coord.y == _map.height - 1:
							inner_tiles.remove(i)

					valid_prison = inner_tiles.size() > 0

					if valid_prison:
						for inner_tile in inner_tiles:
							_map.set_tile_type(inner_tile.x, inner_tile.y, TileType.PRISON_START)
							inner_tile.inner_prison = true

						for inner_tile in inner_tiles:
							for y in range(inner_tile.coord.y - 1, inner_tile.coord.y + 2):
								for x in range(inner_tile.coord.x - 1, inner_tile.coord.x + 2):
									if _map.is_valid(x, y) && _map.get_tile_type(x, y) == TileType.DIRT:
										_map.set_tile_type(x, y, TileType.PRISON)

						var prison := Prison.new()
						prison.inner_tiles = inner_tiles
						State.prisons.append(prison)

						prison_count += 1

			for tile in cave_tiles:
				if tile.tile_type == TileType.DIRT:
					_map.set_tile_type(tile.x, tile.y, TileType.MONSTER_START)
					monster_tiles.append(tile)

			cave_count += 1

		var total_rock_cave_count := 3 + State.level
		var rock_cave_count := 0

		while rock_cave_count < total_rock_cave_count:
			var radius := randi() % 8 + 1

			var center := Coord.new(randi() % (width - 4) + 2, randi() % (height - 4) + 2)
			if center.distance_to(start_coord) <= radius + start_radius + 3:
				continue

			var rock_tiles := Helper.get_tile_circle_new(center.x, center.y, radius)
			for tile in rock_tiles:
				if tile.tile_type == TileType.DIRT:
					if randi() % 3 == 0:
						_map.set_tile_type(tile.x, tile.y, TileType.ROCK)

			rock_cave_count += 1


func map_fill() -> void:
	var minion_tiles := []
	var monster_tiles := []
	var prison_tiles := []


	for y in range(_map.height):
		for x in range(_map.width):
			var tile_type = _map.get_tile_type(x, y)
			var tile = _map.get_tile(x, y)
			var coord := Coord.new(x, y)

			match tile_type:
				TileType.DIRT:
					_tilemap32.set_cell(x, y, 1)

				TileType.ROCK:
					_tilemap32.set_cell(x, y, 2)

				TileType.PRISON:
					_tilemap32.set_cell(x, y, 3)
					# Can't set this to dirt, otherwise monsters
					# will dig into the prison...
					#_map.set_tile_type(x, y, TileType.DIRT)

				TileType.PRISON_START:
					_tilemap32.set_cell(x, y, 0)
					_map.set_tile_type(x, y, TileType.GROUND)

				TileType.START_PORTAL:
					_tilemap32.set_cell(x, y, 4)
					_map.set_tile_type(x, y, TileType.ROCK)

					var start_portal = portal_scene.instance()
					start_portal.tile = tile
					start_portal.position = coord.to_center_pos()
					_entity_container.add_child(start_portal)
					State.start_portals.append(start_portal)

				TileType.END_PORTAL:
					_tilemap32.set_cell(x, y, 4)

					var end_portal = portal_scene.instance()
					end_portal.tile = tile
					end_portal.position = coord.to_center_pos()
					_entity_container.add_child(end_portal)
					end_portal.set_active(true)
					State.end_portals.append(end_portal)

				TileType.GROUND:
					_tilemap32.set_cell(x, y, 0)

				TileType.MINION_START:
					_tilemap32.set_cell(x, y, 0)
					_map.set_tile_type(x, y, TileType.GROUND)
					minion_tiles.append(_map.get_tile(x, y))

				TileType.MONSTER_START:
					_tilemap32.set_cell(x, y, 0)
					_map.set_tile_type(x, y, TileType.GROUND)
					monster_tiles.append(_map.get_tile(x, y))

	_map.finalize_waypoints()


	if minion_tiles.size() > 0:
		for i in range(State.minion_count):
			var tile : Tile = minion_tiles[randi() % minion_tiles.size()]
			var minion : Minion = minion_scene.instance()
			minion.setup(0, i < State.archer_count)
			minion.position = tile.coord.to_random_pos()
			_entity_container.add_child(minion)

			if i == 0:
				_camera.position = tile.coord.to_center_pos()

	if monster_tiles.size() > 0:
		for i in range(State.level_monster_count):
			var tile : Tile = monster_tiles[randi() % monster_tiles.size()]
			var monster : Minion = minion_scene.instance()
			monster.setup(1, randf() < State.monster_archer_fraction)
			monster.position = tile.coord.to_random_pos()
			_entity_container.add_child(monster)

	for prison in State.prisons:
		var amount = max(1.0, randi() % (State.level + 2))
		for i in range(0, amount):
			var tile : Tile = prison.inner_tiles[randi() %  prison.inner_tiles.size()]
			var minion : Minion = minion_scene.instance()
			minion.setup(0, randf() < 0.5, true)
			minion.position = tile.coord.to_random_pos()
			_entity_container.add_child(minion)
			tile.prisoners.append(minion)


func game_traverse_dig_tiles():
	if _map.dig_tiles.size() == 0:
		return

	var minion_to_path := {}
	var minion_to_dig_tile := {}
	var minion_to_distance := {}

	for dig_tile in _map.dig_tiles:
		if (_map.get_tile_type(dig_tile.x + 1, dig_tile.y) == TileType.ROCK &&
			_map.get_tile_type(dig_tile.x - 1, dig_tile.y) == TileType.ROCK &&
			_map.get_tile_type(dig_tile.x, dig_tile.y + 1) == TileType.ROCK &&
			_map.get_tile_type(dig_tile.x, dig_tile.y - 1) == TileType.ROCK):
			continue

		var astar_enabled := false
		Helper.get_tile_circle(State.tile_circle, dig_tile.x, dig_tile.y, State.minion_view_distance, false)

		var tile_count := State.tile_circle.size()

		var tile_index := randi() % tile_count
		for i in range(0, tile_count):
			tile_index = posmod(tile_index + 1, tile_count)

			var from_tile : Tile = State.tile_circle[tile_index]
			if from_tile.tile_type != TileType.GROUND:
				continue

			for minion in from_tile.minions:
				if minion.can_start_digging():
					#var distance : float = minion.coord.distance_to_squared(dig_tile.coord)
					var distance := abs(minion.coord.x - dig_tile.coord.x) + abs(minion.coord.y - dig_tile.coord.y)

					if minion_to_distance.has(minion):
						var best_distance : float= minion_to_distance[minion]
						if randf() >= 0.5:
							if distance > best_distance:
								continue
						else:
							if distance > best_distance - 4:
								continue


					if !astar_enabled:
						_map.astar.set_point_disabled(dig_tile.id, false)

					var path = _map.astar.get_point_path(minion.tile.id, dig_tile.id)

					if path.size() == 0 || path.size() > State.minion_view_distance:
						continue

					minion_to_path[minion] = path
					minion_to_dig_tile[minion] = dig_tile
					minion_to_distance[minion] = distance

		if astar_enabled:
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
		rally_tile.rally_countdown -= delta
		if rally_tile.rally_countdown <= 0:
			rally_tile.rally_countdown = 0
			rally_tile.rally_end_tiles.clear()
			rally_tile.rally_highlight.queue_free()
			rally_tile.rally_highlight = null
			_map.rally_tiles.remove(i)
		else:
			rally_tile.rally_time += delta
			rally_tile.rally_highlight.modulate = Color(1, 1, 1, rally_tile.rally_countdown / State.rally_duration)

func game_start_battles():
	if _start_battle_cooldown.running:
		return

	var entity_count := State.monsters.size() + State.monsters.size()

	if entity_count == 0:
		_start_battle_cooldown.restart(1.0)
		return

	_start_battle_cooldown.restart(1.0 / entity_count)

	if State.monsters.size() > 0:
		State.monster_check_index += 1
		if State.monster_check_index >= State.monsters.size():
			State.monster_check_index = 0

		var monster : Minion = State.monsters[State.monster_check_index]
		game_start_battle(monster, State.minions, State.monster_view_distance)

	if State.minions.size() > 0:
		State.minion_check_index += 1
		if State.minion_check_index >= State.minions.size():
			State.minion_check_index = 0

		var minion : Minion = State.minions[State.minion_check_index]
		game_start_battle(minion, State.monsters, State.minion_view_distance)

func game_start_battle(attacker : Minion, target_list : Array, view_distance : int):
	if attacker.can_start_attack():
		var target_distance := view_distance
		var target = null

		for check_target in target_list:
			var current_distance = attacker.coord.distance_to(check_target.coord)
			if current_distance > target_distance:
				continue

			if Helper.raycast_minion(attacker, check_target):
				target_distance = current_distance
				target = check_target

		if target != null:
			attacker.attack(target)

func game_check_level_done():
	if _level_done:
		if _level_done_cooldown.done:
			if State.minions.size() == 0 && State.minions_fled == 0:
				State.end_level_info = "GAME OVER"
				switch_state(GameState.GAME_OVER)
			else:
				switch_state(GameState.LEVEL_END)
		return

	if State.minions.size() == 0:
		_level_done = true
		_level_done_cooldown.restart()
		return

	if State.monsters.size() == 0:
		_level_done = true
		_level_done_cooldown.restart()
		State.end_level_info = "LEVEL CLEARED"
		return

	var fled_minions := []

	for minion in State.minions:
#		if !minion.can_end_level():
#			continue

		for portal in State.end_portals:
			var distance : float = minion.position.distance_to(portal.position)
			if distance < 55.0:
				fled_minions.append(minion)

	if fled_minions.size() > 0:
		for minion in fled_minions:
			minion.flee()

	if State.minions.size() == 0:
		_level_done = true
		_level_done_cooldown.restart()
		State.end_level_info = "PORTAL REACHED"


func _on_Button_mouse_entered() -> void:
	_mouse_on_button = true

func _on_Button_mouse_exited() -> void:
	_mouse_on_button = false

func _on_DigButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_rally_button.pressed = false
		_bomb_button.pressed = false
		set_tool(ToolType.DIG)

func _on_RallyButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_dig_button.pressed = false
		_bomb_button.pressed = false
		set_tool(ToolType.RALLY)

func _on_BombButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_dig_button.pressed = false
		_rally_button.pressed = false
		set_tool(ToolType.BOMB)


func _on_MenuButton_pressed() -> void:
	switch_state(GameState.GAME_PAUSED)

func set_tool(tool_type) -> void:
	_tool_type = tool_type
	_command_type = CommandType.NONE

	_dig_button.disabled = false
	_rally_button.disabled = false
	_bomb_button.disabled = false

	match tool_type:
		ToolType.DIG:
			Input.set_custom_mouse_cursor(cursor_dig, 0, Vector2(16, 16))
			_dig_button.disabled = true
			_rally_button.pressed = false
			_bomb_button.pressed = false

			_bomb_indicator.visible = false

		ToolType.RALLY:
			Input.set_custom_mouse_cursor(cursor_rally, 0, Vector2(16, 16))
			_rally_button.disabled = true
			_dig_button.pressed = false
			_bomb_button.pressed = false

			_cursor_highlight.visible = false
			_bomb_indicator.visible = false


		ToolType.BOMB:
			Input.set_custom_mouse_cursor(cursor_bomb, 0, Vector2(16, 16))
			_bomb_button.disabled = true
			_dig_button.pressed = false
			_rally_button.pressed = false

			_cursor_highlight.visible = false

func switch_state(new_game_state):
	var old_game_state = State.game_state
	State.game_state  = new_game_state

	match State.game_state:
		GameState.TITLE_SCREEN:
			$Screens/Title.visible = true
			$HUD/MarginContainer.visible = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			title_music_target = 0.0
			track1_target = -80.0
			_camera.zoom = Vector2(0.6, 0.6)

		GameState.INTRO:
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$WorldMap.visible = false
			$SpecialIntro.visible = true
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			$SpecialIntro.start()
			title_music_target = -80
			track1_target = -80.0
			_camera.position = Vector2.ZERO

		GameState.MERCHANT:
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$WorldMap.visible = false
			$Merchant.visible = true
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			$Merchant.start()
			title_music_target = -80
			track1_target = -80.0
			_camera.position = Vector2.ZERO

		GameState.GAME:
			_camera.zoom = Vector2(0.6, 0.6)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			$Screens/Title.visible = false
			game_start()
			$HUD/MarginContainer.visible = true
			title_music_target = -80
			track1_target = 0.0

		GameState.NEW_GAME:
			get_tree().paused = false
			world_reset()
			game_reset()
			world_start()
			switch_state(GameState.WORLD_MAP)
			title_music_target = -80
			track1_target = -80

		GameState.WORLD_MAP:
			_camera.zoom = Vector2(1.0, 1.0)
			_camera.limit_right = get_viewport_rect().size.x
			_camera.limit_bottom = get_viewport_rect().size.y * 2
			_camera.position = Vector2.ZERO

			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$WorldMap.visible = true
			$WorldMap.start()
			title_music_target = -80
			track1_target = -80.0


		GameState.GAME_PAUSED:
			get_tree().paused = true
			$Screens/Title.visible = true
			$HUD/MarginContainer.visible = false
			$Screens/Title/StartButton.text = "CONTINUE"
			$Screens/Title/NewGameButton.visible = true
			title_music_target = -80
			track1_target = -80

		GameState.GAME_CONTINUED:
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = true
			get_tree().paused = false
			State.game_state = GameState.GAME
			title_music_target = -80
			_mouse_on_button = false

		GameState.GAME_OVER:
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$Screens/Title/StartButton.text = "START"
			$Screens/Title/NewGameButton.visible = false
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			$GameOver.start()
			game_reset()
			title_music_target = 0
			track1_target = -80

		GameState.LEVEL_START:
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$WorldMap.visible = false
			$LevelInterlude.visible = true
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			$LevelInterlude.show_level_start()

		GameState.LEVEL_END:
			game_reset()
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$WorldMap.visible = false
			$LevelInterlude.visible = true
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			$LevelInterlude.show_level_end()
			game_reset()
			title_music_target = -80
			track1_target = -80




func _on_StartButton_pressed() -> void:
	if $Screens/Title/StartButton.text == "CONTINUE":
		switch_state(GameState.GAME_CONTINUED)
	else:
		switch_state(GameState.NEW_GAME)


func _on_NewGameButton_pressed() -> void:
	switch_state(GameState.NEW_GAME)


func _on_ExitButton_pressed() -> void:
	get_tree().quit()


func _on_SpecialIntro_stop_intro() -> void:
	switch_state(GameState.GAME)


func _on_LevelInterlude_stop_level_start() -> void:
	switch_state(GameState.GAME)


func _on_LevelInterlude_stop_level_end() -> void:
	switch_state(GameState.WORLD_MAP)


func _on_GameOver_stop_game_over() -> void:
	switch_state(GameState.TITLE_SCREEN)

func _on_WorldMap_world_node_clicked(node_type) -> void:
	if State.world_visited_nodes.size() == 1:
		switch_state(GameState.INTRO)
	else:
		match node_type:
			NodeType.PORTAL:
				switch_state(GameState.LEVEL_START)
			NodeType.TUTORIAL:
				assert(false)
			NodeType.ESCORT:
				switch_state(GameState.LEVEL_START)
			NodeType.RESCUE:
				switch_state(GameState.LEVEL_START)
			NodeType.DEFEND:
				switch_state(GameState.LEVEL_START)
			NodeType.MERCHANT:
				switch_state(GameState.MERCHANT)
			NodeType.HELL:
				switch_state(GameState.LEVEL_START)


func _on_MusicSlider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(value))

	State.config.set_value("Audio", "Music", value)
	State.config.save(State.config_path)

func _on_SoundSlider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sounds"), linear2db(value))

	if !_loading:
		Sounds.play(AudioType.FIGHT)

	State.config.set_value("Audio", "Sound", value)
	State.config.save(State.config_path)

