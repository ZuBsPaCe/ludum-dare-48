extends Node2D

const GameState = preload("res://scripts/GameState.gd").GameState
const TileType = preload("res://scripts/TileType.gd").TileType

var cursor_dig = preload("res://sprites/CursorDig.png")
var cursor_rally = preload("res://sprites/CursorRally.png")

export(PackedScene) var minion_scene
export(PackedScene) var dig_highlight_scene
export(PackedScene) var rally_highlight_scene
export(PackedScene) var portal_scene

onready var _tilemap32 := $TileMap32
onready var _entity_container := $EntityContainer
onready var _highlight_container := $HighlightContainer
onready var _camera := $GameCamera
onready var _cursor_highlight := $CursorHighlight
onready var _dig_button := $HUD/MarginContainer/HBoxContainer/DigButton
onready var _rally_button := $HUD/MarginContainer/HBoxContainer/RallyButton
onready var _raycast := $RayCast2D


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


enum SpecialType {
	INTRO
}



var _map_type = MapType.CAVES

var _tool_type = ToolType.DIG
var _command_type = CommandType.NONE
var _mouse_on_button := false

var _drag_start_mouse_pos := Vector2()
var _drag_start_camera_pos := Vector2()

var _level_done := false




func _ready() -> void:
	State.map = _map
	Helper.map = _map
	Helper.raycast = _raycast

	State.tilemap32 = _tilemap32

	if OS.get_name() == "HTML5":
		$Screens/Title/ExitButton.visible = false

	$Screens/PostProcess.visible = true

	$Screens/Title/StartButton.text = "START"
	$Screens/Title/NewGameButton.visible = false

	switch_state(GameState.TITLE_SCREEN)


func _process(delta: float) -> void:
	if OS.get_name() != "HTML5":
		if !_fullscreen_cooldown.running && Input.is_key_pressed(KEY_ALT) && Input.is_key_pressed(KEY_ENTER):
			OS.window_fullscreen = !OS.window_fullscreen
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



	if State.game_state == GameState.GAME:
		_fullscreen_cooldown.step(delta)
		_dig_traverse_cooldown.step(delta)
		_start_battle_cooldown.step(delta)
		_level_done_cooldown.step(delta)
		_check_level_done_cooldown.step(delta)
		_spawn_cooldown.step(delta)


		var mouse_pos := get_global_mouse_position()
		var mouse_coord := Coord.new()
		mouse_coord.set_vector(mouse_pos)

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
			new_camera_position = _camera.position + drag_vec * 768.0 * delta

		if new_camera_position != null:
			var screen_size = get_viewport().size
			var screen_half = screen_size * 0.5 * _camera.zoom
			new_camera_position.x = max(new_camera_position.x, screen_half.x)
			new_camera_position.x = min(new_camera_position.x, _camera.limit_right - screen_half.x)
			new_camera_position.y = max(new_camera_position.y, screen_half.y)
			new_camera_position.y = min(new_camera_position.y, _camera.limit_bottom - screen_half.y)
			_camera.position = new_camera_position



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
		game_start_battles()

		if _check_level_done_cooldown.done:
			_check_level_done_cooldown.restart()
			game_check_level_done()

		if _spawn_cooldown.done && !_level_done && State.monsters.size() > 6 && State.monsters.size() < 100:
			_spawn_cooldown.restart()

			for portal in State.end_portals:
				var tiles := Helper.get_tile_circle(portal.tile.coord.x, portal.tile.coord.y, 2, false)

				while tiles.size() > 0:
					var index = randi() % tiles.size()
					var check_tile = tiles[index]
					if check_tile.tile_type == TileType.GROUND:
						var monster : Minion = minion_scene.instance()
						monster.setup(1)
						monster.position = check_tile.coord.to_random_pos()
						_entity_container.add_child(monster)
						break

					tiles.remove(index)


func world_reset() -> void:
	State.world_reset()

func game_reset() -> void:
	_cursor_highlight.visible = false
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
	randomize()

	State.increase_level()
	_spawn_cooldown.restart(State.spawn_cooldown)

	_map_type = MapType.CAVES
	_level_done = false

	map_generate(32, 32)
	map_fill()


func map_generate(width : int, height : int) -> void:
	_camera.limit_right = width * 32
	_camera.limit_bottom = height * 32

	_map.setup(width, height, TileType.DIRT)

	var start_radius := randi() % 4 + 3
	var start_x := randi() % (width - 10) + 5
	var start_y := start_radius + 2
	var start_coord := Coord.new(start_x, start_y)

	#start_radius = 3

	_map.set_tile_type(start_coord.x, start_coord.y, TileType.START_PORTAL)

	var start_tiles := Helper.get_tile_circle(start_x, start_y, start_radius, false)
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

		#start_radius = 3

		_map.set_tile_type(end_coord.x, end_coord.y, TileType.END_PORTAL)

		var end_tiles := Helper.get_tile_circle(end_x, end_y, end_radius, false)
		for tile in end_tiles:
			_map.set_tile_type(tile.x, tile.y, TileType.MONSTER_START)


		var total_cave_count := randi() % (8 + State.level) + (8 + State.level)
		var cave_count := 0

		var monster_tiles := []

		while cave_count < total_cave_count || monster_tiles.size() == 0:
			var radius := randi() % 10 + 1

			var center := Coord.new(randi() % (width - 4) + 2, randi() % (height - 4) + 2)
			if center.distance_to(start_coord) <= radius + start_radius + 3:
				continue

			var cave_tiles := Helper.get_tile_circle(center.x, center.y, radius)
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

			var rock_tiles := Helper.get_tile_circle(center.x, center.y, radius)
			for tile in rock_tiles:
				if tile.tile_type == TileType.DIRT:
					if randi() % 3 == 0:
						_map.set_tile_type(tile.x, tile.y, TileType.ROCK)

			rock_cave_count += 1


func map_fill() -> void:
	var minion_tiles := []
	var monster_tiles := []

	for y in range(_map.height):
		for x in range(_map.width):
			var tile = _map.get_tile_type(x, y)
			var coord := Coord.new(x, y)

			match tile:
				TileType.DIRT:
					_tilemap32.set_cell(x, y, 1)

				TileType.ROCK:
					_tilemap32.set_cell(x, y, 2)

				TileType.START_PORTAL:
					_tilemap32.set_cell(x, y, 0)

					var start_portal = portal_scene.instance()
					start_portal.tile = _map.get_tile(x, y)
					start_portal.position = coord.to_center_pos()
					_entity_container.add_child(start_portal)
					State.start_portals.append(start_portal)

				TileType.END_PORTAL:
					_tilemap32.set_cell(x, y, 0)

					var end_portal = portal_scene.instance()
					end_portal.tile = _map.get_tile(x, y)
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

	if minion_tiles.size() > 0:
		for i in range(State.minion_count):
			var tile : Tile = minion_tiles[randi() % minion_tiles.size()]
			var minion : Minion = minion_scene.instance()
			minion.setup(0)
			minion.position = tile.coord.to_random_pos()
			_entity_container.add_child(minion)

			if i == 0:
				_camera.position = tile.coord.to_center_pos()

	if monster_tiles.size() > 0:
		for i in range(State.level_monster_count):
			var tile : Tile = monster_tiles[randi() % monster_tiles.size()]
			var monster : Minion = minion_scene.instance()
			monster.setup(1)
			monster.position = tile.coord.to_random_pos()
			_entity_container.add_child(monster)


func game_traverse_dig_tiles():
	if _map.dig_tiles.size() == 0:
		return

	var minion_to_path := {}
	var minion_to_dig_tile := {}

	for dig_tile in _map.dig_tiles:
		_map.astar.set_point_disabled(dig_tile.id, false)

		var tiles := Helper.get_tile_circle(dig_tile.x, dig_tile.y, State.minion_view_distance + 4)

		for from_tile in tiles:
			if from_tile.tile_type != TileType.GROUND:
				continue

			for minion in from_tile.minions:
				if minion.can_start_digging():

					var path = _map.astar.get_point_path(minion.tile.id, dig_tile.id)

					if path.size() == 0 || path.size() > State.minion_view_distance:
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
	if attacker.can_interupt():
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
				switch_state(GameState.LEVEL_START)
		return

	if State.minions.size() == 0:
		_level_done = true
		_level_done_cooldown.restart()
		return

	if State.monsters.size() == 0:
		_level_done = true
		_level_done_cooldown.restart()
		State.end_level_info = "LEVEL CLEARED" % State.level
		return

	var fled_minions := []

	for minion in State.minions:
		if !minion.can_end_level():
			continue
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
		set_tool(ToolType.DIG)

func _on_RallyButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_dig_button.pressed = false
		set_tool(ToolType.RALLY)

func _on_MenuButton_pressed() -> void:
	switch_state(GameState.GAME_PAUSED)

func set_tool(tool_type) -> void:
	_tool_type = tool_type

	match tool_type:
		ToolType.DIG:
			Input.set_custom_mouse_cursor(cursor_dig, 0, Vector2(16, 16))
		ToolType.RALLY:
			Input.set_custom_mouse_cursor(cursor_rally, 0, Vector2(16, 16))

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
			$SpecialIntro.visible = true
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			$SpecialIntro.start()
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
			switch_state(GameState.INTRO)
			title_music_target = -80
			track1_target = -80

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
			$LevelStart.visible = true
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			$LevelStart.start()
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



func _on_LevelStart_stop_level_start() -> void:
	switch_state(GameState.GAME)


func _on_GameOver_stop_game_over() -> void:
	switch_state(GameState.TITLE_SCREEN)



func _on_MusicSlider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -80.0 + value / 100.0 * 80.0)


func _on_SoundSlider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sounds"), -80.0 + value / 100.0 * 80.0)



