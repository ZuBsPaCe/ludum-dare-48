extends Node2D

const GameState = preload("res://scripts/GameState.gd").GameState
const TileType = preload("res://scripts/TileType.gd").TileType
const AudioType = preload("res://scripts/AudioType.gd").AudioType
const NodeType = preload("res://scripts/NodeType.gd").NodeType
const RoomType = preload("res://scripts/RoomType.gd").RoomType
const RegionType = preload("res://scripts/RegionType.gd").RegionType
const TutorialStep = preload("res://scripts/TutorialStep.gd").TutorialStep

const bomb_tile_radius := 2
const bomb_radius := bomb_tile_radius * 32.0
const bomb_radius_sq := bomb_radius * bomb_radius

const bomb_view_tile_radius := 4
const bomb_view_radius := bomb_view_tile_radius * 32.0
const bomb_view_radius_sq := bomb_view_radius * bomb_view_radius

const yellow_modulate := Color(1, 1, 0, 0.25)
const dark_modulate := Color(0.1, 0.1, 0.1, 0.25)

var cursor_dig = preload("res://sprites/CursorDig.png")
var cursor_rally = preload("res://sprites/CursorRally.png")
var cursor_bomb = preload("res://sprites/CursorBomb.png")

export(PackedScene) var minion_scene
export(PackedScene) var dig_highlight_scene
export(PackedScene) var rally_highlight_scene
export(PackedScene) var portal_scene
export(PackedScene) var explosion_scene

onready var _tilemap32 := $TileMap32
onready var _decal_container := $DecalContainer
onready var _debris_container := $DebrisContainer
onready var _entity_container := $EntityContainer
onready var _explosion_container := $ExplosionContainer
onready var _highlight_container := $HighlightContainer
onready var _camera := $GameCamera
onready var _cursor_highlight := $CursorHighlight
onready var _bomb_view_indicator := $BombViewIndicator
onready var _bomb_blast_indicator := $BombBlastIndicator
onready var _dig_button := $HUD/MarginContainer/VBoxContainer/GridContainer/HBoxContainerCenter/DigButton
onready var _rally_button :=  $HUD/MarginContainer/VBoxContainer/GridContainer/HBoxContainerCenter/RallyButton
onready var _bomb_button :=  $HUD/MarginContainer/VBoxContainer/GridContainer/HBoxContainerCenter/BombButton
onready var _menu_button := $HUD/MarginContainer/VBoxContainer/GridContainer/HBoxContainerRight/MenuButton
onready var _raycast := $RayCast2D
onready var _bomb_count_label := $HUD/MarginContainer/VBoxContainer/GridContainer/HBoxContainerCenter/BombButton/BombCount


var title_music_target := -80.0
var track1_target := -80.0


var _fullscreen_cooldown := Cooldown.new(0.5)
var _dig_traverse_cooldown := Cooldown.new(1.0)
var _start_battle_cooldown := Cooldown.new()
var _level_done_cooldown := Cooldown.new(2.0)
var _check_level_done_cooldown := Cooldown.new(2.0)
var _spawn_cooldown := Cooldown.new()
var _swarm_cooldown := Cooldown.new()
var _tutorial_cooldown := Cooldown.new()

var _restart_cooldown := Cooldown.new(0.2)
var _restarted := false

var _map := Map.new()

var _region_sampler := RegionSampler.new()

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
	NONE,
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


enum SizeType {
	SINGLE,
	TINY,
	SMALL,
	MEDIUM,
	LARGE
}


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
var _regenerate_map := false

var _tiles := []

var _story_queue := []
var _story_queue_keep_open := []
var _story_queue_kept_open := false
var _story_done := true

var _tutorial_dig_last_tile : Tile

var _world_layer_templates := [
	WorldLayerTemplate.new(
		1, 1, [
			WorldConnection.new(0, 0)]),
	WorldLayerTemplate.new(
		1, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1)]),
	WorldLayerTemplate.new(
		1, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(0, 2)]),
	WorldLayerTemplate.new(
		1, 4, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(0, 2),
			WorldConnection.new(0, 3)]),

	WorldLayerTemplate.new(
		2, 1, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0)]),
	WorldLayerTemplate.new(
		2, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1, "A"),
			WorldConnection.new(1, 0, "A"),
			WorldConnection.new(1, 1)]),
	WorldLayerTemplate.new(
		2, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(1, 1),
			WorldConnection.new(1, 2)]),
	WorldLayerTemplate.new(
		2, 4, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(0, 2, "A"),
			WorldConnection.new(1, 1, "A"),
			WorldConnection.new(1, 2),
			WorldConnection.new(1, 3)]),

	WorldLayerTemplate.new(
		3, 1, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(2, 0)]),
	WorldLayerTemplate.new(
		3, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(1, 1),
			WorldConnection.new(2, 1)]),
	WorldLayerTemplate.new(
		3, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1, "A"),
			WorldConnection.new(1, 0, "A"),
			WorldConnection.new(1, 1),
			WorldConnection.new(1, 2, "B"),
			WorldConnection.new(2, 1, "B"),
			WorldConnection.new(2, 2)]),
	WorldLayerTemplate.new(
		3, 4, [
			WorldConnection.new(0, 0),
			WorldConnection.new(0, 1),
			WorldConnection.new(1, 2),
			WorldConnection.new(1, 2),
			WorldConnection.new(2, 2),
			WorldConnection.new(2, 3)]),

	WorldLayerTemplate.new(
		4, 1, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(2, 0),
			WorldConnection.new(3, 0)]),
	WorldLayerTemplate.new(
		4, 2, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(1, 1, "A"),
			WorldConnection.new(2, 0, "A"),
			WorldConnection.new(2, 1),
			WorldConnection.new(3, 1)]),
	WorldLayerTemplate.new(
		4, 3, [
			WorldConnection.new(0, 0),
			WorldConnection.new(1, 0),
			WorldConnection.new(1, 1),
			WorldConnection.new(2, 1),
			WorldConnection.new(2, 2),
			WorldConnection.new(3, 2)]),
	WorldLayerTemplate.new(
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

	if !State.config.has_section_key("Game", "Tutorial"):
		State.config.set_value("Game", "Tutorial", true)

	$Screens/Title/MusicSlider.value = State.config.get_value("Audio", "Music")
	$Screens/Title/SoundSlider.value = State.config.get_value("Audio", "Sound")

	State.decal_container = _decal_container
	State.debris_container = _debris_container
	State.entity_container = _entity_container

	State.map = _map
	Helper.map = _map
	Helper.raycast = _raycast

	State.tilemap32 = _tilemap32
	State.game_camera = $GameCamera
	State.sounds = $GameCamera/Sounds


	if OS.get_name() == "HTML5":
		$Screens/Title/ExitButton.visible = false
	else:
		OS.window_fullscreen = State.config.get_value("Display", "Fullscreen")

	$Screens/PostProcess.visible = true

	$Screens/Title/StartButton.text = "START"

	if State.config.get_value("Game", "Tutorial") == false:
		$Screens/Title/NewGameButton.text = "Tutorial"
		$Screens/Title/NewGameButton.visible = true
	else:
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
			$TitleMusic.volume_db = min(0.0, $TitleMusic.volume_db + delta * 60.0)
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

	if State.game_state == GameState.GAME || State.game_state == GameState.WORLD_MAP || State.game_state == GameState.TUTORIAL:
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


	if State.game_state == GameState.GAME || State.game_state == GameState.TUTORIAL:
		_dig_traverse_cooldown.step(delta)
		_start_battle_cooldown.step(delta)
		_level_done_cooldown.step(delta)
		_check_level_done_cooldown.step(delta)
		_spawn_cooldown.step(delta)
		_swarm_cooldown.step(delta)

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

						if _rally_last_mouse_pos.distance_to(mouse_pos) >= 32:
							set_rally = true
							_rally_last_mouse_pos = mouse_pos

					if Input.is_action_just_released("command"):
						set_rally = true

					if set_rally:

						Helper.get_tile_circle(_tiles, mouse_coord.x, mouse_coord.y, State.rally_radius)
						for current_tile in _tiles:
							var distance := mouse_coord.distance_to(current_tile.coord)
							var rally_countdown : float = (1.0 - distance / (State.rally_radius + 1)) * State.rally_duration

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

				var has_bombs : bool = State.bomb_count > 0

				if has_bombs:
					for minion in State.minions:
						var minion_pos : Vector2 = minion.position + Vector2(0, -8.0)
						var distance_sq = minion_pos.distance_squared_to(mouse_pos)
						if distance_sq <= bomb_view_radius_sq * 2.0:
							var minion_visible : bool = Helper.raycast_minion_to_pos(minion, mouse_pos)

							if nearest_minion == null || distance_sq < nearest_minion_distance_sq || !nearest_minion_visible && minion_visible:
								nearest_minion = minion
								nearest_minion_distance_sq = distance_sq
								nearest_minion_visible = minion_visible

				var indicator_alpha = 0.0
				if nearest_minion != null:
					indicator_alpha = 1.0 - (nearest_minion_distance_sq - bomb_view_radius_sq) / bomb_view_radius_sq

				var can_bomb : bool = (
					has_bombs &&
					mouse_tile == TileType.OPEN &&
					nearest_minion != null &&
					nearest_minion_visible &&
					nearest_minion_distance_sq <= bomb_view_radius_sq)

				if has_bombs:
					_bomb_blast_indicator.position = mouse_pos
					_bomb_view_indicator.visible = true
				else:
					_bomb_view_indicator.visible = false

				if has_bombs && nearest_minion != null:
					_bomb_view_indicator.position = nearest_minion.position + Vector2(0, -8.0)
					_bomb_view_indicator.rotation = Vector2.DOWN.angle_to(nearest_minion.position - mouse_pos)
					if can_bomb:
						_bomb_view_indicator.modulate = yellow_modulate
					else:
						_bomb_view_indicator.modulate = dark_modulate
						_bomb_view_indicator.modulate.a = indicator_alpha * 0.25

					_bomb_blast_indicator.visible = true
				else:
					_bomb_view_indicator.visible = false

				if can_bomb:
					if Input.is_action_just_pressed("command") && !_mouse_on_button:
						State.bomb_count -= 1
						_bomb_count_label.text = str(State.bomb_count)

						var entities := []
						Helper.get_tile_circle(_tiles, mouse_coord.x, mouse_coord.y, bomb_tile_radius + 1)
						for tile in _tiles:
							for monster in tile.monsters:
								if monster.position.distance_squared_to(mouse_pos) > bomb_radius_sq:
									continue
								monster.show_blood_effect()
								entities.append(monster)
							for minion in tile.minions:
								if minion.position.distance_squared_to(mouse_pos) > bomb_radius_sq:
									continue
								minion.show_blood_effect()
								entities.append(minion)

							var tile_distance : float = tile.coord.distance_squared_to(mouse_coord)
							if tile_distance <= 2:
								tile.hurt(3)
							elif tile_distance <= 4:
								tile.hurt(1 + randi() % 3)
							else:
								tile.hurt(randi() % 3)

						for arrow in State.arrows:
							if mouse_pos.distance_squared_to(arrow.position) <= bomb_radius_sq:
								arrow.die()

						var explosion : Node2D = explosion_scene.instance()
						explosion.position = mouse_pos
						explosion.rotation = randf() * 2 * PI
						_explosion_container.add_child(explosion)

						State.sounds.play(AudioType.BOMB, mouse_pos)

						for entity in entities:
							entity.show_blood_drop_effect(_explosion_container)
							entity.die()


		game_traverse_dig_tiles()
		game_traverse_rally_tiles(delta)
		game_start_battles()
		game_check_level_done()
		game_spawn_monsters()
		game_command_swarms()

		if Input.is_action_just_pressed("tool1"):
			set_tool(ToolType.DIG)
		elif Input.is_action_just_pressed("tool2"):
			set_tool(ToolType.RALLY)
		elif Input.is_action_just_pressed("tool3"):
			set_tool(ToolType.BOMB)

		if State.world_node_type == NodeType.TUTORIAL:
			_tutorial_cooldown.step(delta)

			if State.tutorial_step == TutorialStep.START:
				_tutorial_cooldown.restart(3)
				State.tutorial_step = TutorialStep.INTRO

			elif State.tutorial_step == TutorialStep.INTRO && _tutorial_cooldown.done:
				show_story("Finally! You reached the dungeon!", true)
				State.tutorial_step = TutorialStep.START_DIGGING

			elif State.tutorial_step == TutorialStep.START_DIGGING && _story_done:
				_dig_button.visible = true
				show_story("Select the pickaxe and click on the dirt near you.", true)
				State.tutorial_step = TutorialStep.HIDE_START_DIGGING

			elif State.tutorial_step == TutorialStep.HIDE_START_DIGGING:
				if _map.dig_tiles.size() > 0:
					hide_story()
					State.tutorial_step = TutorialStep.CAMERA

			elif State.tutorial_step == TutorialStep.CAMERA && _story_done:
				show_story("Move your view with arrow keys, WASD or right mouse button.", true)
				_tutorial_cooldown.restart(30)
				State.tutorial_step = TutorialStep.GOTO_PRISON

			elif State.tutorial_step == TutorialStep.GOTO_PRISON:
				if State.minions[0].tile == _tutorial_dig_last_tile || _tutorial_cooldown.done:
					show_story("You hear desperate cries for help...")
					show_story("Keep digging! You can select multiple tiles by dragging.", true)
					State.tutorial_step = TutorialStep.HIDE_GOTO_PRISON

			elif State.tutorial_step == TutorialStep.HIDE_GOTO_PRISON:
				if State.minions[0].is_digging():
					hide_story()
					State.tutorial_step = TutorialStep.FREE_PRISONERS
					_tutorial_cooldown.restart(5)

			elif State.tutorial_step == TutorialStep.FREE_PRISONERS && _tutorial_cooldown.done:
				var min_distance := 10.0
				for tile in State.prisons[0].inner_tiles:
					var distance : float = tile.coord.distance_to(State.minions[0].coord)
					if distance < min_distance:
						min_distance = distance

				if min_distance < 4.0:
					show_story("Poor prisoners. Free them!", true)
					State.tutorial_step = TutorialStep.PRISONERS_FREED

			elif State.tutorial_step == TutorialStep.PRISONERS_FREED && _story_done:
				var has_prisoners := false
				for prison in State.prisons:
					for tile in prison.inner_tiles:
						if tile.prisoners.size() > 0:
							has_prisoners = true
							break

				if !has_prisoners:
					show_story("Well done! They are grateful to you!")
					show_story("One of them tells you about a secret chest near the entrance.", true)
					State.tutorial_step = TutorialStep.START_RALLY

			elif State.tutorial_step == TutorialStep.START_RALLY && _story_done:
				_rally_button.visible = true
				show_story("Select the rally tool and paint the way to the portal you came in.", true)
				State.tutorial_step = TutorialStep.GO_BACK_TO_START_PORTAL

			elif State.tutorial_step == TutorialStep.GO_BACK_TO_START_PORTAL:
				var near_start_portal_count := 0
				for minion in State.minions:
					if minion.coord.distance_to(State.start_portals[0].tile.coord) <= 4:
						near_start_portal_count += 1
						if near_start_portal_count == 2:
							break

				if near_start_portal_count == 2:
					show_story("Your companion reveals a chest full of bombs!")
					show_story("He tells you about a secret portal down to the south.", true)
					State.tutorial_step = TutorialStep.START_BOMBING

			elif State.tutorial_step == TutorialStep.START_BOMBING && _story_done:
				_bomb_button.visible = true
				show_story("Select the bomb tool and make way to the southern portal.", true)
				State.tutorial_step = TutorialStep.BOMBING

			elif State.tutorial_step == TutorialStep.BOMBING && $ExplosionContainer.get_child_count() > 0:
				show_story("Watch out! Bombs are dangerous!")
				State.tutorial_step = TutorialStep.REACH_PORTAL
				_tutorial_cooldown.restart(10)

			elif State.tutorial_step == TutorialStep.REACH_PORTAL:
				show_story("Enter the southern portal.", true)
				_tutorial_cooldown.restart(10)
				State.tutorial_step = TutorialStep.ALL_REACH_PORTAL

			elif State.tutorial_step == TutorialStep.ALL_REACH_PORTAL && _tutorial_cooldown.done:
				if State.minions_fled > 0:
					if State.minions.size() > 0:
						show_story("Good job! Take all your friends with you.", true)
					State.tutorial_step = TutorialStep.PERFECT

			elif State.tutorial_step == TutorialStep.PERFECT:
				if State.minions_fled > 0 && State.minions.size() == 0:
					show_story("Perfect!", true)
					State.tutorial_step = TutorialStep.DONE



		if _story_queue.size() > 0:
			if !$HUD/AnimationPlayer.is_playing():
				if _story_queue_kept_open:
					$HUD/AnimationPlayer.play("HideStoryLabel")
					_story_queue_kept_open = false
				else:
					var text : String = _story_queue.pop_front()
					var keep_open : bool = _story_queue_keep_open.pop_front()
					if text != "":
						$HUD/MarginContainer/VBoxContainer/StoryLabel.text = text
						if keep_open:
							$HUD/AnimationPlayer.play("ShowStoryLabel")
							_story_queue_kept_open = true
						else:
							$HUD/AnimationPlayer.play("ShowAndHideStoryLabel")
							_story_queue_kept_open = false

		_story_done = _story_queue.size() == 0 && !$HUD/AnimationPlayer.is_playing()

		if _restart_cooldown.running:
			_restart_cooldown.step(delta)
		elif Input.is_action_just_pressed("restart"):
			_restart_cooldown.restart()

			_restarted = true

			if State.game_state == GameState.TUTORIAL:
				switch_state(GameState.TUTORIAL)
			else:
				game_reset()
				switch_state(GameState.GAME)




func world_reset() -> void:
	State.world_reset()

func world_start() -> void:
	var random_seed : int
	if State.random_seed == 0:
		randomize()
		random_seed = randi()
	else:
		random_seed = State.random_seed
	seed(random_seed)

	print("Current world seed: %d" % random_seed)

	# Create world layers and initialize layer seeds. First thing we need to
	# to after initializing the world seed above.

	var layer_count := 8
	var world_layers := []

	for layer_index in layer_count:
		world_layers.append(WorldLayer.new(layer_index, randi()))


	var random_node_count := 0

	var prev1 := 0
	var prev2 := 0

	# Set random number of nodes per layer (except first and last layer with one node each)
	world_layers[0].nodes.append(WorldNode.new(0, 0))

	for layer_index in range(1, layer_count - 1):
		var world_layer : WorldLayer = world_layers[layer_index]

		var next_count : int
		while true:
			next_count = randi() % 3 + 2
			if prev1 == prev2 && prev1 == next_count:
				continue
			break

		for node_index in next_count:
			world_layer.nodes.append(WorldNode.new(layer_index, node_index))

		prev2 = prev1
		prev1 = next_count

		random_node_count += next_count

	var last_node : WorldNode = WorldNode.new(layer_count - 1, 0)
	world_layers[layer_count - 1].nodes.append(last_node)


	# Assign random noise to each node. Used for offsetting the node in the world map

	for world_layer in world_layers:
		for node in world_layer.nodes:
			node.noise = Vector2(randf() * 64.0 - 32.0, randf() * 64.0 - 32.0)


	# Create a list of random but evenly distributed node types, which will
	# be randomly assigned to the nodes.

	var valid_node_types := [
		NodeType.PORTAL,
		NodeType.DEFEND,
		NodeType.PRISON,
		NodeType.RESCUE,
		NodeType.ESCORT]

	var random_node_types := []

	var valid_node_types_index = 0
	for i in random_node_count:
		if i <= 2:
			random_node_types.append(NodeType.MERCHANT)
		else:
			random_node_types.append(valid_node_types[valid_node_types_index])
			valid_node_types_index = posmod(valid_node_types_index + 1, valid_node_types.size())


	# Assign connections to each layer and connect nodes

	for layer_index in range(0, world_layers.size() - 1):
		var upper_world_layer : WorldLayer = world_layers[layer_index]
		var lower_world_layer : WorldLayer = world_layers[layer_index + 1]

		var upper_count : int = upper_world_layer.nodes.size()
		var lower_count : int = lower_world_layer.nodes.size()

		var possible_connections := []
		for world_layer_template in _world_layer_templates:
			if world_layer_template.upper_count == upper_count && world_layer_template.lower_count == lower_count:
				possible_connections = world_layer_template.world_connections
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
					var connection : WorldConnection = possible_connections[bit_offset]
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
		for bit_offset in range(bit_count):
			var bit_set : bool = (selected_permutation & (1 << bit_offset)) > 0
			if bit_set:
				var selected_connection : WorldConnection = possible_connections[bit_offset]
				var upper_from_node : WorldNode = upper_world_layer.nodes[selected_connection.from]
				var lower_to_node : WorldNode = lower_world_layer.nodes[selected_connection.to]

				upper_from_node.next_nodes.append(lower_to_node)
				lower_to_node.prev_nodes.append(upper_from_node)

	for node in world_layers[world_layers.size() - 2].nodes:
		node.next_nodes.append(last_node)
		last_node.prev_nodes.append(node)


	# Assign a node type to each node

	var first_node_type = NodeType.PORTAL
	#var first_node_type = NodeType.RESCUE
	#var first_node_type = NodeType.DEFEND

	world_layers[0].nodes[0].node_type = first_node_type

	for layer_index in range(0, world_layers.size() - 2):
		var upper_world_layer : WorldLayer = world_layers[layer_index]
		var lower_world_layer : WorldLayer = world_layers[layer_index + 1]

		for lower_node in lower_world_layer.nodes:
			var upper_node_types := []
			var check_nodes := []

			for upper_node in lower_node.prev_nodes:
				upper_node_types.append(upper_node.node_type)
				check_nodes.append(upper_node)

			var all_prev_nodes := []

			while check_nodes.size() > 0:
				var current_count := check_nodes.size()
				for check_index in current_count:
					var check_node : WorldNode = check_nodes.pop_front()
					if all_prev_nodes.has(check_node):
						continue

					all_prev_nodes.append(check_node)
					check_nodes.append_array(check_node.prev_nodes)


			var rescue_in_path := false
			for check_node in all_prev_nodes:
				if check_node.node_type == NodeType.RESCUE:
					rescue_in_path = true
					break

			var node_type = null
			for test in 3:
				var random_index = randi() % random_node_types.size()
				node_type = random_node_types[random_index]

				if (!upper_node_types.has(node_type) && (node_type != NodeType.RESCUE || !rescue_in_path) ||
					test == 2):
					random_node_types.remove(random_index)
					lower_node.node_type = node_type
					break

	world_layers[world_layers.size() - 1].nodes[0].node_type = NodeType.HELL

	State.world_layers = world_layers


func game_reset() -> void:
	_cursor_highlight.visible = false
	_bomb_view_indicator.visible = false
	_bomb_blast_indicator.visible = false
	_bomb_blast_indicator.modulate = dark_modulate

	for child in _decal_container.get_children():
		child.queue_free()

	for child in _debris_container.get_children():
		child.queue_free()

	for child in _entity_container.get_children():
		child.queue_free()

	for child in _highlight_container.get_children():
		child.queue_free()

	_tilemap32.clear()

	State.game_reset()

func game_start() -> void:
	var layer_seed : int
	if State.random_seed != 0:
		layer_seed = State.world_layers[State.world_layer_index].layer_seed
	else:
		randomize()
		layer_seed = randi()

	print("Current layer seed: %d" % layer_seed)
	seed(layer_seed)

	if !_restarted:
		State.increase_level()
	else:
		_restarted = false

	if State.spawns_per_minute > 0:
		_spawn_cooldown.restart(60.0 / State.spawns_per_minute)
	else:
		_spawn_cooldown.reset()

	_swarm_cooldown.restart(State.swarm_cooldown_init)
	_dig_traverse_cooldown.restart()

	_level_done = false

	while true:
		_regenerate_map = false
		map_generate()
		if !_regenerate_map:
			break
		else:
			print("Regenerating...")

	map_fill()

	_dig_button.focus_mode = Control.FOCUS_CLICK
	_rally_button.focus_mode = Control.FOCUS_CLICK
	_bomb_button.focus_mode = Control.FOCUS_CLICK
	_menu_button.focus_mode = Control.FOCUS_CLICK

	if State.world_node_type == NodeType.TUTORIAL:
		_dig_button.visible = false
		_rally_button.visible = false
		_bomb_button.visible = false

		set_tool(ToolType.NONE)

		State.bomb_count = 100

	else:
		_dig_button.visible = true
		_rally_button.visible = true
		_bomb_button.visible = true

		set_tool(ToolType.DIG)

	_mouse_on_button = false

	reset_story()


	_camera.limit_right = _map.width * 32
	_camera.limit_bottom = _map.height * 32
	_bomb_count_label.text = str(State.bomb_count)


func map_generate() -> void:
	var areas := []

	if State.world_node_type == NodeType.TUTORIAL:
		_map.setup(20, 20, TileType.ROCK)

		var start_cave = add_circle_area(RoomType.START, SizeType.MEDIUM, RegionType.SINGLE_TOP_LEFT, true, areas, [])
		var center_cave = add_circle_area(RoomType.CAVE, SizeType.SMALL, RegionType.SINGLE_CENTER, true, areas, [])

		var prison_cave = add_circle_area(RoomType.CAVE, SizeType.MEDIUM, RegionType.SINGLE_TOP_RIGHT, true, areas, [])
		add_rect_area(RoomType.PRISON, SizeType.SMALL, SizeType.SMALL, RegionType.SINGLE_TOP_RIGHT, true, areas, [RoomType.CAVE], [prison_cave])

		var portal_cave = add_circle_area(RoomType.PORTAL, SizeType.MEDIUM, RegionType.SINGLE_BOTTOM, false, areas, [])
		if portal_cave == null:
			add_circle_area(RoomType.PORTAL, SizeType.MEDIUM, RegionType.HOR_BOTTOM, true, areas, [])

		fill_areas(areas)


		var start_cave_tiles := get_area_tiles(start_cave)
		var center_cave_tiles := get_area_tiles(center_cave)
		var prison_cave_tiles := get_area_tiles(prison_cave)

		var first_passage_tiles = connect_rand_tiles(start_cave_tiles, center_cave_tiles, 1)
		connect_rand_tiles(center_cave_tiles, prison_cave_tiles, 1)

		_tutorial_dig_last_tile = null

		for tile in first_passage_tiles:
			if tile.tile_type == TileType.DIRT:
				_tutorial_dig_last_tile = tile
			if tile.tile_type == TileType.OPEN:
				if _tutorial_dig_last_tile != null:
					break

		add_rock_borders()


	elif State.world_node_type == NodeType.DEFEND:
		_map.setup(32, 32, TileType.DIRT)

		apply_cave_randomization_2(null, TileType.DIRT, TileType.ROCK, true, 0.3, 1)

		for i in 2:
			add_circle_area(RoomType.CAVE, SizeType.MEDIUM, RegionType.SINGLE_CENTER, false, areas, [RoomType.CAVE])

		for i in 2:
			add_circle_area(RoomType.CAVE, SizeType.SMALL, RegionType.SINGLE_CENTER, false, areas, [RoomType.CAVE])

		var start_area := add_rect_area(RoomType.START, SizeType.LARGE, SizeType.LARGE, RegionType.SINGLE_CENTER, true, areas, [RoomType.CAVE])

		var portal_areas := [
			RegionType.SINGLE_TOP_LEFT, RegionType.SINGLE_TOP, RegionType.SINGLE_TOP_RIGHT,
			RegionType.SINGLE_RIGHT, RegionType.SINGLE_BOTTOM_RIGHT, RegionType.SINGLE_BOTTOM,
			RegionType.SINGLE_BOTTOM_LEFT, RegionType.SINGLE_LEFT]

		add_rect_area(RoomType.PORTAL, SizeType.SMALL, SizeType.SMALL, Helper.rand_pop(portal_areas), true, areas, [])
		add_rect_area(RoomType.PORTAL, SizeType.SMALL, SizeType.SMALL, Helper.rand_pop(portal_areas), true, areas, [])
		add_rect_area(RoomType.PORTAL, SizeType.SMALL, SizeType.SMALL, Helper.rand_pop(portal_areas), true, areas, [])

		fill_areas(areas)

		var open1 := start_area.x + 1 + randi() % (start_area.width - 3)
		var open2 := start_area.x + 1 + randi() % (start_area.width - 3)
		for x in range(start_area.x, start_area.x + start_area.width):
			if x != open1 && x - 1 != open1:
				_map.set_tile_type(x, start_area.y, TileType.ROCK)
			else:
				_map.set_tile_type(x, start_area.y, TileType.DIRT)
			if x != open2 && x - 1 != open2:
				_map.set_tile_type(x, start_area.y + start_area.height - 1, TileType.ROCK)
			else:
				_map.set_tile_type(x, start_area.y + start_area.height - 1, TileType.DIRT)

		open1 = start_area.y + 1 + randi() % (start_area.height - 3)
		open2 = start_area.y + 1 + randi() % (start_area.height - 3)
		for y in range(start_area.y, start_area.y + start_area.height):
			if y != open1 && y - 1 != open1:
				_map.set_tile_type(start_area.x, y, TileType.ROCK)
			else:
				_map.set_tile_type(start_area.x, y, TileType.DIRT)
			if y != open2 && y - 1 != open2:
				_map.set_tile_type(start_area.x + start_area.width - 1, y, TileType.ROCK)
			else:
				_map.set_tile_type(start_area.x + start_area.width - 1, y, TileType.DIRT)

		add_rock_borders()
		fix_closed_areas()
	elif true || State.world_node_type == NodeType.PORTAL:

		#State.level = 10
		var layout := (State.level - 1) % 10

		if true:

			if State.level == 1:
				_map.setup(20, 20, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_circle_area(RoomType.PORTAL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 2:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < 2:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				fill_areas(areas)

				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.1, 0)

				add_rock_borders()
				fix_closed_areas()

			elif State.level == 2:
				_map.setup(20, 20, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_circle_area(RoomType.PORTAL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 4:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.SMALL, RegionType.ALL, false, areas, [])
					if cave != null && i < 2:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				fill_areas(areas)

				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()
			elif State.level == 3:
				_map.setup(24, 24, TileType.ROCK)

				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_circle_area(RoomType.PORTAL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 4:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < 3:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				fill_areas(areas)

				apply_cave_randomization_2(null, TileType.ROCK, TileType.DIRT, true, 0.3, 2)

				add_rock_borders()
				fix_closed_areas()

				add_swarm_waypoints(areas)

#			elif State.level == 3:
#				_map.setup(24, 24, TileType.ROCK)
#
#				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
#				add_circle_area(RoomType.PORTAL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])
#
#				for i in 4:
#					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
#					if cave != null && i < 3:
#						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])
#
#				fill_areas(areas)
#
#				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.1, 0)
#
#				add_rock_borders()
#				fix_closed_areas()

			elif State.level == 4:
				_map.setup(26, 26, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_circle_area(RoomType.PORTAL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 3:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < 3:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				for i in 2:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.SMALL, RegionType.ALL, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE])

				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 1)

				fill_areas(areas)

				apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()

				add_swarm_waypoints(areas)


			elif State.level == 5:
				_map.setup(32, 32, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 3:
					var cave := add_rect_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, SizeType.SMALL, RegionType.ALL, false, areas, [])
					if cave != null && i < 3:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				for i in 4:
					var cave := add_rect_area(RoomType.MONSTER_CAVE, SizeType.SMALL, SizeType.SMALL, RegionType.ALL, false, areas, [RoomType.CAVE])

				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.25, 3)

				fill_areas(areas)

				#apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()

				add_swarm_waypoints(areas)

			elif State.level == 6:
				_map.setup(32, 32, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.MEDIUM, RegionType.HOR_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 5:
					var cave := add_rect_area(RoomType.MONSTER_CAVE, SizeType.LARGE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < 4:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				for i in 7:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.LARGE, RegionType.ALL, false, areas, [RoomType.CAVE, RoomType.MONSTER_CAVE])


				fill_areas(areas)

				#apply_cave_randomization_2(TileType.OPEN, TileType.OPEN, TileType.ROCK, true, 0.1, 0)
				apply_cave_randomization_2(TileType.MONSTER_START, TileType.MONSTER_START, TileType.ROCK, true, 0.2, 0)
				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 0)

				#apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()

				add_swarm_waypoints(areas)

			elif State.level == 7:
				_map.setup(32, 32, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.MEDIUM, RegionType.HOR_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.LARGE, SizeType.MEDIUM, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 20:
					var cave := add_rect_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < 5:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				apply_cave_randomization_2(null, TileType.DIRT, TileType.ROCK, true, 0.4, 4)

				fill_areas(areas)

				#apply_cave_randomization_2(TileType.OPEN, TileType.OPEN, TileType.ROCK, true, 0.1, 0)

#				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 0)

				#apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()

				add_swarm_waypoints(areas)


			elif State.level == 8:
				_map.setup(32, 32, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.MEDIUM, RegionType.HOR_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.LARGE, SizeType.MEDIUM, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 20:
					var cave := add_rect_area(RoomType.CAVE, SizeType.LARGE, SizeType.TINY, RegionType.ALL, false, areas, [])

				for i in 8:
					var cave := add_rect_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, SizeType.SMALL, RegionType.ALL, false, areas, [])
					if cave != null && i < 5:
						add_rect_area(RoomType.PRISON, SizeType.SMALL, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				apply_cave_randomization_2(null, TileType.DIRT, TileType.ROCK, true, 0.3, 4)

				fill_areas(areas)

				#apply_cave_randomization_2(TileType.OPEN, TileType.OPEN, TileType.ROCK, true, 0.1, 0)

#				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 0)

				#apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()

				add_swarm_waypoints(areas)

			elif State.level == 9:
				_map.setup(32, 32, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.MEDIUM, RegionType.SINGLE_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.LARGE, SizeType.MEDIUM, RegionType.SINGLE_BOTTOM, true, areas, [])

				for i in 20:
					add_circle_area(RoomType.ROCK, SizeType.SMALL, RegionType.SINGLE_CENTER, true, areas, [RoomType.ROCK])

				for i in 20:
					add_rect_area(RoomType.MONSTER_CAVE, SizeType.SMALL, SizeType.MEDIUM, RegionType.VER_LEFT, false, areas, [RoomType.MONSTER_CAVE])
					add_rect_area(RoomType.MONSTER_CAVE, SizeType.SMALL, SizeType.MEDIUM, RegionType.VER_RIGHT, false, areas, [RoomType.MONSTER_CAVE])

				add_rect_area(RoomType.PRISON, SizeType.SMALL, SizeType.SMALL, RegionType.SINGLE_BOTTOM_LEFT, true, areas, [RoomType.MONSTER_CAVE])
				add_rect_area(RoomType.PRISON, SizeType.SMALL, SizeType.SMALL, RegionType.SINGLE_BOTTOM_RIGHT, true, areas, [RoomType.MONSTER_CAVE])

				apply_cave_randomization_2(null, TileType.MONSTER_START, TileType.OPEN, true, 0.3, 2)

				fill_areas(areas)

				#apply_cave_randomization_2(TileType.OPEN, TileType.OPEN, TileType.ROCK, true, 0.1, 0)

#				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 0)

				#apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()

				add_swarm_waypoints(areas)

			elif State.level == 10:
				_map.setup(32, 32, TileType.DIRT)

				add_circle_area(RoomType.START, SizeType.MEDIUM, RegionType.SINGLE_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.SINGLE_BOTTOM_LEFT, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.SINGLE_BOTTOM_RIGHT, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.SINGLE_BOTTOM, true, areas, [])

				for i in 10:
					add_circle_area(RoomType.ROCK, SizeType.SMALL, RegionType.HOR_CENTER, false, areas, [])

				for i in 20:
					add_rect_area(RoomType.MONSTER_CAVE, SizeType.LARGE, SizeType.LARGE, RegionType.HOR_BOTTOM, false, areas, [RoomType.MONSTER_CAVE])
					add_rect_area(RoomType.MONSTER_CAVE, SizeType.SMALL, SizeType.LARGE, RegionType.HOR_BOTTOM, false, areas, [RoomType.MONSTER_CAVE])

					add_rect_area(RoomType.CAVE, SizeType.LARGE, SizeType.LARGE, RegionType.HOR_TOP, false, areas, [RoomType.CAVE])
					add_rect_area(RoomType.CAVE, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_TOP, false, areas, [RoomType.CAVE])

				add_rect_area(RoomType.PRISON, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_BOTTOM, false, areas, [RoomType.MONSTER_CAVE])

				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.OPEN, true, 0.3, 2)
				apply_cave_randomization_2(null, TileType.MONSTER_START, TileType.OPEN, true, 0.3, 2)
				apply_cave_randomization_2(null, TileType.OPEN, TileType.OPEN, true, 0.3, 2)

				fill_areas(areas)

				#apply_cave_randomization_2(TileType.OPEN, TileType.OPEN, TileType.ROCK, true, 0.1, 0)

#				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 0)

				#apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2)

				add_rock_borders()
				fix_closed_areas()

				#add_swarm_waypoints(areas)

				State.swarm_waypoints.append(Coord.new(8, 8))
				State.swarm_waypoints.append(Coord.new(16, 8))
				State.swarm_waypoints.append(Coord.new(24, 8))

				State.swarm_waypoints.append(Coord.new(8, 24))
				State.swarm_waypoints.append(Coord.new(16, 24))
				State.swarm_waypoints.append(Coord.new(24, 24))

		if false:
			if State.level < 3:
				_map.setup(32, 32, TileType.DIRT)
				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_circle_area(RoomType.PORTAL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 3:
					var cave := add_circle_area(RoomType.CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])

				for i in 3:
					var cave := add_circle_area(RoomType.CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [RoomType.CAVE])

				for i in 5:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < State.level * 2:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				fill_areas(areas)

				apply_cave_randomization_2(null, TileType.OPEN, TileType.DIRT, true, 0.3, 2, 3, 2)
				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 1, 3, 2)

				add_rock_borders()
				fix_closed_areas()

			elif State.level < 5:
				_map.setup(32, 32, TileType.DIRT)
				add_circle_area(RoomType.START, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_circle_area(RoomType.PORTAL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 10:
					var cave := add_circle_area(RoomType.CAVE, SizeType.SMALL, RegionType.ALL, false, areas, [RoomType.CAVE])

				for i in 3:
					var cave := add_circle_area(RoomType.CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [RoomType.CAVE])

				for i in 5:
					var cave := add_circle_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < State.level * 2:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.MONSTER_CAVE, RoomType.CAVE], [cave])

				fill_areas(areas)

				apply_cave_randomization_2(null, TileType.DIRT, TileType.OPEN, true, 0.1, 2, 3, 2)
				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 3, 3, 2)

				add_rock_borders()
				fix_closed_areas()

			elif true:
				_map.setup(32, 32, TileType.DIRT)
				add_rect_area(RoomType.START, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 5:
					var cave := add_rect_area(RoomType.CAVE, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.ALL, false, areas, [])

				for i in 5:
					var cave := add_rect_area(RoomType.MONSTER_CAVE, SizeType.MEDIUM, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null && i < State.level:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.CAVE, RoomType.MONSTER_CAVE], [cave])

				fill_areas(areas)

				apply_cave_randomization_2(null, TileType.OPEN, TileType.DIRT, true, 0.3, 3, 3, 2)
				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 3, 3, 2)

				add_rock_borders()
				fix_closed_areas()

			elif false:
				_map.setup(32, 32, TileType.OPEN)
				add_rect_area(RoomType.START, SizeType.SMALL, SizeType.SMALL, RegionType.SINGLE_CENTER, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.SMALL, SizeType.SMALL, RegionType.SINGLE_BOTTOM, true, areas, [])
				fill_areas(areas)
				add_rock_borders()

			elif false:
				_map.setup(32, 32, TileType.OPEN)
				if true:
					add_rect_area(RoomType.START, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
					add_rect_area(RoomType.PORTAL, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

					for i in 10:
						var cave := add_circle_area(RoomType.CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
						if cave != null:
							add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.CAVE], [cave])

				for i in 50:
					add_rect_area(RoomType.PRISON, SizeType.SMALL, SizeType.SMALL, RegionType.ALL, false, areas, [RoomType.PRISON])

				for i in 5:
					add_circle_area(RoomType.CAVE, SizeType.TINY, RegionType.ALL, false, areas, [RoomType.CAVE])
					add_circle_area(RoomType.CAVE, SizeType.SMALL, RegionType.ALL, false, areas, [RoomType.CAVE])


				fill_areas(areas)


				add_rock_borders()
				#apply_cave_randomization(0.3, 3, 3, 2)
				apply_cave_randomization_2(null, TileType.OPEN, TileType.DIRT, true, 0.3, 3, 3, 2)
				apply_cave_randomization_2(TileType.DIRT, TileType.DIRT, TileType.ROCK, true, 0.2, 3, 3, 2)

				fix_closed_areas()
			else:
				_map.setup(32, 32, TileType.DIRT)
				apply_cave_randomization_2(null, TileType.DIRT, TileType.ROCK, true, 0.3, 3, 3, 2)

				add_rect_area(RoomType.START, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_TOP, true, areas, [])
				add_rect_area(RoomType.PORTAL, SizeType.SMALL, SizeType.SMALL, RegionType.HOR_BOTTOM, true, areas, [])

				for i in 10:
					var cave := add_circle_area(RoomType.CAVE, SizeType.MEDIUM, RegionType.ALL, false, areas, [])
					if cave != null:
						add_rect_area(RoomType.PRISON, SizeType.MEDIUM, SizeType.SMALL, RegionType.SPECIFIC_AREAS, false, areas, [RoomType.CAVE], [cave])

				fill_areas(areas)
				add_rock_borders()

				fix_closed_areas()

			#_camera.zoom = Vector2(2, 2)

func add_swarm_waypoints(areas : Array) -> void:
	for area in areas:
		if area.room_type == RoomType.MONSTER_CAVE || area.room_type == RoomType.PORTAL:
			State.swarm_waypoints.append(Coord.new(area.center_x, area.center_y))


func fix_closed_areas() -> void:
	var tiles := []

	for tile in _map.tiles:
		if tile.tile_type != TileType.ROCK:
			tile.checked = false
			tiles.append(tile)
		else:
			tile.checked = true

	var regions := []

	while true:
		var queue := []
		var tile : Tile = null

		while tiles.size() > 0:
			tile = tiles.pop_back()
			if !tile.checked:
				break

		if tiles.size() == 0:
			break

		tile.checked = true
		queue.append(tile)

		var region := []
		regions.append(region)

		while queue.size() > 0:
			tile = queue.pop_back()
			region.append(tile)

			Helper.get_tile_neighbours_4(State.tile_circle, tile.x, tile.y)
			for neighbour in State.tile_circle:
				if neighbour.checked:
					continue
				neighbour.checked = true
				queue.append(neighbour)

	if regions.size() <= 1:
		return

	var astar := AStar2D.new()
	astar.reserve_space(_map.size)
	var id := 0
	for y in _map.height:
		for x in _map.width:
			var tile : Tile = _map.get_tile(x, y)
			if tile.tile_type == TileType.ROCK:
				astar.add_point(id, Vector2(x, y), 2)
			else:
				astar.add_point(id, Vector2(x, y), 1)

			if y > 0:
				astar.connect_points(id, id - _map.width)

			if x > 0:
				astar.connect_points(id, id - 1)

			id += 1

	regions.sort_custom(self, "sort_regions")

	for from_index in range(0, regions.size() - 1):
		var path_set := false
		var smallest_id_path : Array

		for to_index in range(from_index + 1, regions.size()):
			var from_region : Array = regions[from_index]
			var to_region : Array = regions[to_index]

			var id_path := astar.get_id_path(
				from_region[randi() % from_region.size()].id,
				to_region[randi() % to_region.size()].id)

			assert(id_path.size() > 0)

			if !path_set || id_path.size() < smallest_id_path.size():
				path_set = true
				smallest_id_path = id_path

		for path_id in smallest_id_path:
			var tile : Tile = _map.tiles[path_id]
			if tile.tile_type == TileType.ROCK:
				_map.set_tile_type(tile.x, tile.y, TileType.DIRT)

func register_prisons() -> void:
	var tiles := []

	# TODO: Nearly same code like in fix_closed_areas...

	for tile in _map.tiles:
		if tile.tile_type == TileType.PRISON:
			tile.checked = false
			tiles.append(tile)
		else:
			tile.checked = true

	var regions := []

	while true:
		var queue := []
		var tile : Tile = null

		while tiles.size() > 0:
			tile = tiles.pop_back()
			if !tile.checked:
				break

		if tiles.size() == 0:
			break

		tile.checked = true
		queue.append(tile)

		var region := []
		regions.append(region)

		while queue.size() > 0:
			tile = queue.pop_back()
			region.append(tile)

			Helper.get_tile_neighbours_4(State.tile_circle, tile.x, tile.y)
			for neighbour in State.tile_circle:
				if neighbour.checked:
					continue
				neighbour.checked = true
				queue.append(neighbour)

	for region in regions:
		var inner_tiles := []
		for prison_tile in region:
			if (prison_tile.x <= 1 ||
				prison_tile.y <= 1 ||
				prison_tile.x >= _map.width - 2 ||
				prison_tile.y >= _map.height - 2):
				continue

			Helper.get_tile_neighbours_4(State.tile_circle, prison_tile.x, prison_tile.y)
			var is_prison_start := true
			for tile in State.tile_circle:
				if tile.tile_type != TileType.PRISON && tile.tile_type != TileType.ROCK:
					is_prison_start = false
					break
			if is_prison_start:
				inner_tiles.append(prison_tile)

		if inner_tiles.size() == 0:
			continue

		for prison_tile in inner_tiles:
			_map.set_tile_type(prison_tile.x, prison_tile.y, TileType.PRISON_START)
			prison_tile.inner_prison = true

		var prison := Prison.new()
		prison.inner_tiles = inner_tiles
		State.prisons.append(prison)

func connect_rand_tiles(from_tiles : Array, to_tiles : Array, passage_size : int = 1) -> Array:
	if from_tiles.size() == 0 || to_tiles.size() == 0:
		return []

	return connect_tiles(Helper.rand_item(from_tiles), Helper.rand_item(to_tiles), passage_size)


func connect_tiles(from_tile : Tile, to_tile: Tile, passage_size : int = 1) -> Array:
	var astar := AStar2D.new()
	astar.reserve_space(_map.size)
	var id := 0
	for y in _map.height:
		for x in _map.width:
			var tile : Tile = _map.get_tile(x, y)
			astar.add_point(id, Vector2(x, y), 1)

			if y > 0:
				astar.connect_points(id, id - _map.width)

			if x > 0:
				astar.connect_points(id, id - 1)

			id += 1

	var offset := 0
	var from_coord := Coord.new()
	var to_coord := Coord.new()
	var tiles := []

	for i in passage_size:
		from_coord.set_coord(from_tile.coord)
		to_coord.set_coord(to_tile.coord)

		if offset > 0:
			if abs(to_coord.x - from_coord.x) >= abs(to_coord.y - from_coord.y):
				from_coord.y += offset
				to_coord.y += offset
			else:
				from_coord.x += offset
				to_coord.x += offset

		var final_from_tile := _map.get_tile(from_coord.x, from_coord.y)
		var final_to_tile := _map.get_tile(to_coord.x, to_coord.y)

		var id_path := astar.get_id_path(
			final_from_tile.id,
			final_to_tile.id)

		assert(id_path.size() > 0)

		for path_id in id_path:
			var tile : Tile = _map.tiles[path_id]
			if tile.tile_type == TileType.ROCK:
				_map.set_tile_type(tile.x, tile.y, TileType.DIRT)
			tiles.append(tile)

		if offset <= 0:
			offset = abs(offset) + 1
		else:
			offset = -offset

	return tiles



func sort_regions(a : Array, b : Array) -> bool:
	if a.size() < b.size():
		return true
	elif a.size() > b.size():
		return false
	return a[0].id < b[0].id

func add_rock_borders() -> void:
	var width := _map.width
	var height := _map.height

	for x in range(0, width):
		assert(can_change_tile_type(x, 0))
		assert(can_change_tile_type(x, 1))
		assert(can_change_tile_type(x, height - 1))
		assert(can_change_tile_type(x, height - 2))

		_map.set_tile_type(x, 0, TileType.ROCK)
		_map.set_tile_type(x, height - 1, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(x, 1, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(x, height - 2, TileType.ROCK)

	for y in range(0, height):
		assert(can_change_tile_type(0, y))
		assert(can_change_tile_type(1, y))
		assert(can_change_tile_type(width - 1, y))
		assert(can_change_tile_type(width - 2, y))


		_map.set_tile_type(0, y, TileType.ROCK)
		_map.set_tile_type(width - 1, y, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(1, y, TileType.ROCK)

		if randi() % 2 == 0:
			_map.set_tile_type(width - 2, y, TileType.ROCK)

func can_change_tile_type(x : int, y : int) -> bool:
	var tile_type = _map.get_tile_type(x, y)
	return (
		tile_type == TileType.DIRT ||
		tile_type == TileType.OPEN ||
		tile_type == TileType.ROCK ||
		tile_type == TileType.MONSTER_START ||
		tile_type == TileType.MINION_START ||
		tile_type == TileType.PRISON)

func fill_areas(areas : Array) -> void:
	for area in areas:
		match area.room_type:
			RoomType.START:
				fill_area(TileType.MINION_START, area)
				_map.set_tile_type(area.center_x, area.center_y, TileType.START_PORTAL)

			RoomType.PORTAL:
				fill_area(TileType.MONSTER_START, area)
				_map.set_tile_type(area.center_x, area.center_y, TileType.END_PORTAL)

			RoomType.CAVE:
				fill_area(TileType.OPEN, area)

			RoomType.MONSTER_CAVE:
				fill_area(TileType.MONSTER_START, area)

			RoomType.ROCK:
				fill_area(TileType.ROCK, area)

			RoomType.PRISON:
				fill_area(TileType.PRISON, area)
#				var prison_tiles = fill_area(TileType.PRISON, area)
#				var prison_start_tiles := []
#				for prison_tile in prison_tiles:
#					if (prison_tile.x <= 1 ||
#						prison_tile.y <= 1 ||
#						prison_tile.x >= _map.width - 2 ||
#						prison_tile.y >= _map.height - 2):
#						continue
#
#					Helper.get_tile_neighbours_4(State.tile_circle, prison_tile.x, prison_tile.y)
#					var is_prison_start := true
#					for tile in State.tile_circle:
#						if tile.tile_type != TileType.PRISON:
#							is_prison_start = false
#							break
#					if is_prison_start:
#						prison_start_tiles.append(prison_tile)
#				assert(prison_start_tiles.size() > 0)
#				for prison_tile in prison_start_tiles:
#					_map.set_tile_type(prison_tile.x, prison_tile.y, TileType.PRISON_START)
#					prison_tile.inner_prison = true
#
#				var prison := Prison.new()
#				prison.inner_tiles = prison_start_tiles
#				State.prisons.append(prison)


func fill_area(tile_type, area) -> Array:
	if area == null:
		return []

	var tiles := get_area_tiles(area)
	for tile in tiles:
		_map.set_tile_type(tile.x, tile.y, tile_type)
	return tiles

func get_area_tiles(area) -> Array:
	if area == null:
		return []

	var tiles := []
	if area.get_class() == "WorldCircle":
		Helper.get_tile_circle(State.tile_circle, area.center_x, area.center_y, area.radius - 1)
		for tile in State.tile_circle:
			tiles.append(tile)
	else:
		for y in range(area.y, area.y + area.height):
			for x in range(area.x, area.x + area.width):
				if _map.is_valid(x, y):
					tiles.append(_map.get_tile(x, y))
	return tiles


func apply_cave_randomization(set_dirt_factor : float, iterations : int, dirt_birth_limit : int = 3, dirt_death_limit : int = 2) -> void:
	var make_open_tiles := []
	var make_dirt_tiles := []

	if set_dirt_factor > 0:
		for y in _map.height:
			for x in _map.width:
				var center_tile := _map.get_tile(x, y)
				if center_tile.tile_type != TileType.OPEN:
					continue

				if randf() < set_dirt_factor:
					make_dirt_tiles.append(center_tile)

	for tile in make_dirt_tiles:
		_map.set_tile_type(tile.x, tile.y, TileType.DIRT)

	for tile in make_open_tiles:
		_map.set_tile_type(tile.x, tile.y, TileType.OPEN)

	make_dirt_tiles.clear()
	make_open_tiles.clear()


	var dirt_stay_alive_limit := 8 - dirt_death_limit

	for i in iterations:
		for y in _map.height:
			for x in _map.width:
				var center_tile := _map.get_tile(x, y)
				if center_tile.tile_type == TileType.OPEN:
					var dirt_count := 0
					Helper.get_tile_neighbours_8(State.tile_circle, x, y)
					for tile in State.tile_circle:
						if tile.tile_type != TileType.OPEN:
							dirt_count += 1
							if dirt_count > dirt_birth_limit:
								make_dirt_tiles.append(center_tile)
								break
				elif center_tile.tile_type == TileType.DIRT:
					var dirt_count := 0
					Helper.get_tile_neighbours_8(State.tile_circle, x, y)
					for tile in State.tile_circle:
						if tile.tile_type != TileType.OPEN:
							dirt_count += 1
					if dirt_count < dirt_death_limit:
						make_open_tiles.append(center_tile)

		for tile in make_dirt_tiles:
			_map.set_tile_type(tile.x, tile.y, TileType.DIRT)

		for tile in make_open_tiles:
			_map.set_tile_type(tile.x, tile.y, TileType.OPEN)

		make_dirt_tiles.clear()
		make_open_tiles.clear()

func apply_cave_randomization_2(filter_type, from_type, to_type, eager : bool, set_factor : float, iterations : int, birth_limit : int = 3, death_limit : int = 2) -> void:
	var filtered_tiles := []

	if filter_type == null:
		filtered_tiles = _map.tiles
	else:
		for tile in _map.tiles:
			if tile.tile_type == filter_type:
				filtered_tiles.append(tile)

	var birth_tiles := []
	var death_tiles := []

	if set_factor > 0:
		for tile in filtered_tiles:
			if tile.tile_type != from_type:
				continue

			if randf() < set_factor:
				birth_tiles.append(tile)

	for tile in birth_tiles:
		_map.set_tile_type(tile.x, tile.y, to_type)

	birth_tiles.clear()


	#var dirt_stay_alive_limit := 8 - dirt_death_limit

	for i in iterations:
		for tile in filtered_tiles:
			if tile.tile_type == from_type:
				var happy_count := 0
				Helper.get_tile_neighbours_8(State.tile_circle, tile.x, tile.y)

				if eager:
					happy_count += 8 - State.tile_circle.size()

				for neighbour in State.tile_circle:
					if eager:
						if neighbour.tile_type != from_type:
							happy_count += 1
						else:
							continue
					else:
						if neighbour.tile_type == to_type:
							happy_count += 1
						else:
							continue

					if happy_count > birth_limit:
						birth_tiles.append(tile)
						break

			elif tile.tile_type == to_type:
				var happy_count := 0
				Helper.get_tile_neighbours_8(State.tile_circle, tile.x, tile.y)

				if eager:
					happy_count += 8 - State.tile_circle.size()

				for neighbour in State.tile_circle:
					if eager:
						if neighbour.tile_type != from_type:
							happy_count += 1
						else:
							continue
					else:
						if neighbour.tile_type == to_type:
							happy_count += 1
						else:
							continue
				if happy_count < death_limit:
					death_tiles.append(tile)

		for tile in birth_tiles:
			_map.set_tile_type(tile.x, tile.y, to_type)

		for tile in death_tiles:
			_map.set_tile_type(tile.x, tile.y, from_type)

		birth_tiles.clear()
		death_tiles.clear()





func get_random_circle_radius(size_type) -> int:
	match size_type:
		SizeType.SINGLE:
			return 1
		SizeType.TINY:
			return 2
		SizeType.SMALL:
			return 3
		SizeType.MEDIUM:
			return 3 + (randi() % 2)
		SizeType.LARGE:
			return 4 + (randi() % 2)
	assert(false)
	return 0

func get_random_rect_size(size_type) -> int:
	match size_type:
		SizeType.SINGLE:
			return 1
		SizeType.TINY:
			return 2 + (randi() % 2)
		SizeType.SMALL:
			return 3 + (randi() % 2)
		SizeType.MEDIUM:
			return 4 + (randi() % 3)
		SizeType.LARGE:
			return 6 + (randi() % 4)
	assert(false)
	return 0

func add_circle_area(room_type, size_type, region_type, important : bool, areas : Array, allowed_room_type_overlaps, specific_areas = []) -> WorldCircle:
	while true:
		_region_sampler.setup(region_type, specific_areas)

		var circle := WorldCircle.new(get_random_circle_radius(size_type), room_type)

		for i in 1000:
			_region_sampler.set_random_position(circle)

			var valid := true
			for other_area in areas:
				if allowed_room_type_overlaps.has(other_area.room_type):
					continue
				if areas_overlap(circle, other_area):
					valid = false
					break

			if valid:
				areas.append(circle)
				return circle

		if important && size_type > 1:
			size_type -= 1
		else:
			break

	if important:
		_regenerate_map = true

	assert(!important)
	return null

func add_rect_area(room_type, size_type1, size_type2, region_type, important : bool, areas : Array, allowed_room_type_overlaps, specific_areas = []) -> WorldRect:
	if specific_areas == null:
		specific_areas = []

	while true:
		_region_sampler.setup(region_type, specific_areas)

		var width : int
		var height : int
		if size_type1 == size_type2 || randi() % 2 == 0:
			width = get_random_rect_size(size_type1)
			height = get_random_rect_size(size_type2)
		else:
			width = get_random_rect_size(size_type2)
			height = get_random_rect_size(size_type1)

		var rect := WorldRect.new(width, height, room_type)

		for i in 1000:
			_region_sampler.set_random_position(rect)

			var valid := true
			for other_area in areas:
				if allowed_room_type_overlaps.has(other_area.room_type):
					continue
				if areas_overlap(rect, other_area):
					valid = false
					break

			if valid:
				areas.append(rect)
				return rect

		if important && (size_type1 > 1 || size_type2 > 1):
			if size_type1 > 1:
				size_type1 -= 1
			if size_type2 > 1:
				size_type2 -= 1
		else:
			break

	if important:
		_regenerate_map = true

	assert(!important)
	return null

func areas_overlap(area1, area2) -> bool:
	var class1 = area1.get_class()
	if area1.get_class() == "WorldCircle" && area2.get_class() == "WorldCircle":
		return area1.center.distance_to(area2.center) <= area1.radius + area2.radius

	if area1.get_class() == "WorldRect" && area2.get_class() == "WorldRect":
		return area1.rect.intersects(area2.rect, true)

	var circle : WorldCircle
	var rect : Rect2

	if area1.get_class() == "WorldRect":
		rect = area1.rect
		circle = area2
	else:
		rect = area2.rect
		circle = area1

	var closest_point_in_rect = Vector2(
		clamp(circle.center_x, rect.position.x, rect.end.x),
		clamp(circle.center_y, rect.position.y, rect.end.y))

	return circle.center.distance_to(closest_point_in_rect) <= circle.radius

func map_fill() -> void:

	register_prisons()

	var minion_tiles := []
	var monster_tiles := []
	var prison_tiles := []


	for y in range(_map.height):
		for x in range(_map.width):
			var tile_type = _map.get_tile_type(x, y)
			var tile = _map.get_tile(x, y)
			var coord := Coord.new(x, y)

			if x == 0 || x == _map.width - 1 || y == 0 || y == _map.height - 1:
				tile.immune = true

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
					_map.set_tile_type(x, y, TileType.OPEN)

				TileType.START_PORTAL:
					_tilemap32.set_cell(x, y, 4)
					tile.immune = true

					var start_portal = portal_scene.instance()
					start_portal.tile = tile
					start_portal.position = coord.to_center_pos()
					_entity_container.add_child(start_portal)
					State.start_portals.append(start_portal)

				TileType.END_PORTAL:
					_tilemap32.set_cell(x, y, 4)
					tile.immune = true

					var end_portal = portal_scene.instance()
					end_portal.tile = tile
					end_portal.position = coord.to_center_pos()
					_entity_container.add_child(end_portal)
					end_portal.set_active(true)
					State.end_portals.append(end_portal)

				TileType.OPEN:
					_tilemap32.set_cell(x, y, 0)

				TileType.MINION_START:
					_tilemap32.set_cell(x, y, 0)
					_map.set_tile_type(x, y, TileType.OPEN)
					minion_tiles.append(_map.get_tile(x, y))

				TileType.MONSTER_START:
					_tilemap32.set_cell(x, y, 0)
					_map.set_tile_type(x, y, TileType.OPEN)
					monster_tiles.append(_map.get_tile(x, y))

	_map.finalize_waypoints()

	_map.start_tiles = minion_tiles
	if minion_tiles.size() > 0:
		var kings_added := 0
		var archers_added := 0
		for i in range(State.minion_count):
			var tile : Tile = minion_tiles[randi() % minion_tiles.size()]
			var minion : Minion = minion_scene.instance()
			if kings_added < State.minion_king_count:
				kings_added += 1
				minion.setup_minion(false, false, true)
			elif archers_added < State.archer_count:
				archers_added += 1
				minion.setup_minion(true)
			else:
				minion.setup_minion()
			minion.position = tile.coord.to_random_pos()
			_entity_container.add_child(minion)

			if i == 0:
				_camera.position = tile.coord.to_center_pos()

	if monster_tiles.size() > 0:
		if State.world_node_type != NodeType.DEFEND:
			var monster_count := State.level_monster_count

			for i in range(State.level_monster_count):
				var tile : Tile = monster_tiles[randi() % monster_tiles.size()]
				var monster : Minion = minion_scene.instance()

				monster.setup_monster(randf() < State.monster_archer_fraction, randf() < 0.33)

				monster.position = tile.coord.to_random_pos()
				_entity_container.add_child(monster)
		else:
			var monsters_per_portal := State.level_monster_count

			for portal in State.end_portals:
				for monster in spawn_monsters_from_portal(portal, monsters_per_portal):
					monster.setup_monster(randf() < State.monster_archer_fraction, false, false, true)
					_entity_container.add_child(monster)
					portal.waiting_monsters.append(monster)


	# We want to put the prison king far away.
	State.prisons.sort_custom(self, "sort_prisons_far_to_near")

	var king_prison_index := -1
	if State.world_node_type == NodeType.RESCUE:
		if State.prisons.size() <= 3:
			king_prison_index = 0
		else:
			king_prison_index = randi() % (State.prisons.size() / 2 + 1)

	for prison_index in State.prisons.size():
		var prison : Prison = State.prisons[prison_index]

		var amount = int(rand_range(State.prisoners_per_prison_min_count, State.prisoners_per_prison_max_count))
		for i in range(0, amount):
			var tile : Tile = prison.inner_tiles[randi() %  prison.inner_tiles.size()]
			assert(tile.tile_type == TileType.OPEN)

			var minion : Minion = minion_scene.instance()
			if prison_index == king_prison_index:
				minion.setup_minion(randf() < 0.5, true, true)
				prison_index = -1
			else:
				minion.setup_minion(randf() < 0.5, true)
			minion.position = tile.coord.to_random_pos()
			_entity_container.add_child(minion)

func sort_prisons_far_to_near(prison1 : Prison, prison2 : Prison) -> bool:
	var start_portal_pos : Vector2 = State.start_portals[0].position
	var dist1 : float = prison1.inner_tiles[0].coord.to_pos().distance_squared_to(start_portal_pos)
	var dist2 : float = prison2.inner_tiles[0].coord.to_pos().distance_squared_to(start_portal_pos)

	if dist1 > dist2:
		return true
	if dist1 < dist2:
		return false
	return hash(prison1) < hash(prison2)

func game_traverse_dig_tiles():
	if _dig_traverse_cooldown.running:
		return

	_dig_traverse_cooldown.restart()

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
			if from_tile.tile_type != TileType.OPEN:
				continue

			for minion in from_tile.minions:
				if minion.can_start_digging():
					#var distance : float = minion.coord.distance_squared_to(dig_tile.coord)
					var distance : float = minion.coord.manhattan_distance_to(dig_tile.coord)

					if minion_to_distance.has(minion):
						var best_distance : float = minion_to_distance[minion]
						if randf() >= 0.5:
							if distance > best_distance:
								continue
						else:
							if distance > best_distance - 4:
								continue


					if !astar_enabled:
						astar_enabled = true
						_map.astar.set_point_disabled(dig_tile.id, false)

					var path = _map.astar.get_id_path(minion.tile.id, dig_tile.id)

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
		game_start_battle(monster, State.minions)

	if State.minions.size() > 0:
		State.minion_check_index += 1
		if State.minion_check_index >= State.minions.size():
			State.minion_check_index = 0

		var minion : Minion = State.minions[State.minion_check_index]
		game_start_battle(minion, State.monsters)

func game_start_battle(attacker : Minion, target_list : Array):
	if attacker.can_start_attack():
		var target_distance := attacker.view_distance
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
			if attacker.task != Minion.MinionTask.ATTACK:
				State.sounds.play(AudioType.TALK, attacker.position)

func game_check_level_done():
	if _check_level_done_cooldown.running && _story_done:
		return

	_check_level_done_cooldown.restart()

	var fled_minions := []

	for minion in State.minions:
#		if !minion.can_end_level():
#			continue

		for portal in State.end_portals:
			if !portal.active:
				continue
			var distance : float = minion.position.distance_to(portal.position)
			if distance < 64.0:
				fled_minions.append(minion)

	if fled_minions.size() > 0:
		for minion in fled_minions:
			minion.flee()


	var all_minions_dead := false
	var all_minion_kings_dead := false
	var minion_kings_in_prison := false
	var all_minions_fled := false
	var all_monsters_dead := false

	if State.minions.size() == 0:
		if State.minions_fled == 0:
			all_minions_dead = true
		else:
			all_minions_fled = true

	if State.monsters.size() == 0:
		all_monsters_dead = true

	for minion_king in State.minion_kings:
		if minion_king.prisoner:
			minion_kings_in_prison = true

	if State.minion_kings_created_count > 0 && State.minion_kings_died_count >= State.minion_kings_created_count:
		all_minion_kings_dead = true

	var done := false
	var failed := false

	if all_minions_dead:
		State.end_level_info = "GAME OVER"
		done = true
		failed = true
	elif all_minion_kings_dead:
		State.end_level_info = "YOUR KING DIED"
		done = true
		failed = true
	elif State.world_node_type == NodeType.RESCUE:
		if all_minions_fled:
			if minion_kings_in_prison:
				State.end_level_info = "KING LEFT BEHIND"
				done = true
				failed = true
			else:
				State.end_level_info = "KING RESCUED"
				done = true
	elif State.world_node_type == NodeType.DEFEND:
		if all_monsters_dead:
			State.end_level_info = "BASE DEFENDED"
			done = true
	elif all_minions_fled:
		State.end_level_info = "PORTAL REACHED"
		done = true


	if done:
		if !_level_done:
			_level_done = true
			_level_done_cooldown.restart()
		elif _level_done_cooldown.done:
			if failed:
				switch_state(GameState.GAME_OVER)
			else:
				switch_state(GameState.LEVEL_END)

func game_spawn_monsters() -> void:
	if !_spawn_cooldown.started || _spawn_cooldown.running || _level_done || State.monsters.size() <= 6 || State.monsters.size() > 100:
		return

	_spawn_cooldown.restart()

	for portal in State.end_portals:
		for monster in spawn_monsters_from_portal(portal, 1):
			if State.swarm_waypoints.size() == 0:
				monster.setup_monster(randf() < State.monster_archer_fraction, randf() < 0.33)
			else:
				monster.setup_monster(randf() < State.monster_archer_fraction, false)
				portal.waiting_monsters.append(monster)
			_entity_container.add_child(monster)

# WARNING: Caller must call setup_monster and add monster to _entity_container!
func spawn_monsters_from_portal(portal, monster_count : int) -> Array:
	Helper.get_tile_circle(State.tile_circle, portal.tile.coord.x, portal.tile.coord.y, 2, false)

	for i in range(State.tile_circle.size() - 1, -1, -1):
		if State.tile_circle[i].tile_type != TileType.OPEN:
			State.tile_circle.remove(i)

	var monsters := []
	if State.tile_circle.size() == 0:
		return monsters

	for i in monster_count:
		var tile : Tile = Helper.rand_item(State.tile_circle)

		var monster : Minion = minion_scene.instance()
		monster.position = tile.coord.to_random_pos()
		monsters.append(monster)

	return monsters

func game_command_swarms() -> void:
	if _swarm_cooldown.running:
		return

	_swarm_cooldown.restart(State.swarm_cooldown_min + randi() % (State.swarm_cooldown_max - State.swarm_cooldown_min))

	if State.world_node_type == NodeType.PORTAL:
		if State.swarm_waypoints.size() > 0:
			for i in State.end_portals.size():
				for portal in State.end_portals:
					for j in range(portal.waiting_monsters.size() - 1, -1, -1):
						var monster = portal.waiting_monsters[j]
						if !is_instance_valid(monster) || monster.dead:
							portal.waiting_monsters.remove(j)

					if portal.waiting_monsters.size() == 0:
						continue

					var possible_monsters := []
					for monster in portal.waiting_monsters:
						if monster.can_start_swarm():
							possible_monsters.append(monster)

					if possible_monsters.size() == 0:
						continue

					while true:
						var swarm_size := 3 + randi() % 4
						if possible_monsters.size() < swarm_size:
							break

						var swarm := []
						for swarm_index in swarm_size:
							var swarm_monster = possible_monsters.pop_back()
							swarm.append(swarm_monster)
							portal.waiting_monsters.erase(swarm_monster)

						State.monster_swarms.append(swarm)

			for swarm in State.monster_swarms:
				for i in range(swarm.size() - 1, -1, -1):
					var monster = swarm[i]
					if !is_instance_valid(monster) || monster.dead:
						swarm.remove(i)

				if swarm.size() == 0:
					continue

				var can_start := true

				for monster in swarm:
					if !monster.can_start_swarm():
						can_start = false

				if !can_start:
					continue

				var target : Coord = Helper.rand_item(State.swarm_waypoints)
				Helper.get_tile_circle(State.tile_circle, target.x, target.y, 4)
				var possible_tiles := []
				for tile in State.tile_circle:
					if tile.tile_type == TileType.OPEN:
						possible_tiles.append(tile)

				if possible_tiles.size() > 0:
					for monster in swarm:
						monster.swarm(Helper.rand_item(possible_tiles))

	elif State.world_node_type == NodeType.DEFEND:
		var portal_index := randi() % State.end_portals.size()

		for i in State.end_portals.size():
			portal_index = posmod(portal_index + 1, State.end_portals.size())
			var portal = State.end_portals[portal_index]
			if portal.waiting_monsters.size() == 0:
				continue

			var possible_monsters := []
			for monster in portal.waiting_monsters:
				if monster.can_start_swarm():
					possible_monsters.append(monster)

			if possible_monsters.size() == 0:
				continue

			var swarm_size := min(5 + randi() % 6, possible_monsters.size())

			if possible_monsters.size() - swarm_size < 5:
				swarm_size = possible_monsters.size()

			var swarm := []
			for swarm_index in swarm_size:
				var swar_monster = possible_monsters.pop_back()
				swarm.append(swar_monster)
				portal.waiting_monsters.erase(swar_monster)

			State.monster_swarms.append(swarm)

			for monster in swarm:
				monster.swarm(Helper.rand_item(_map.start_tiles))

			break


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
		ToolType.NONE:
			Input.set_custom_mouse_cursor(null)

		ToolType.DIG:
			Input.set_custom_mouse_cursor(cursor_dig, 0, Vector2(16, 16))
			_dig_button.disabled = true
			_rally_button.pressed = false
			_bomb_button.pressed = false

			_bomb_view_indicator.visible = false
			_bomb_blast_indicator.visible = false

		ToolType.RALLY:
			Input.set_custom_mouse_cursor(cursor_rally, 0, Vector2(16, 16))
			_rally_button.disabled = true
			_dig_button.pressed = false
			_bomb_button.pressed = false

			_cursor_highlight.visible = false
			_bomb_view_indicator.visible = false
			_bomb_blast_indicator.visible = false


		ToolType.BOMB:
			Input.set_custom_mouse_cursor(cursor_bomb, 0, Vector2(16, 16))
			_bomb_button.disabled = true
			_dig_button.pressed = false
			_rally_button.pressed = false

			_cursor_highlight.visible = false

func switch_state(new_game_state):
	var old_game_state = State.game_state
	State.game_state  = new_game_state

	Input.set_custom_mouse_cursor(null)

	match State.game_state:
		GameState.TITLE_SCREEN:
			$Screens/Title.visible = true
			$HUD/MarginContainer.visible = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			title_music_target = 0.0
			track1_target = -80.0
			_camera.zoom = Vector2(0.6, 0.6)
			_camera.position = get_viewport_rect().size / 2

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
			_camera.limit_right = 999999
			_camera.limit_bottom = 999999
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
			_camera.limit_right = 999999
			_camera.limit_bottom = 999999
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
			switch_state(GameState.INTRO)
			title_music_target = -80
			track1_target = -80

		GameState.TUTORIAL:
			get_tree().paused = false
			world_reset()
			game_reset()
			world_start()

			State.world_node_type = NodeType.TUTORIAL

			_camera.zoom = Vector2(0.6, 0.6)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			$Screens/Title.visible = false
			game_start()
			$HUD/MarginContainer.visible = true
			title_music_target = -80

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

			if State.world_node_type == NodeType.TUTORIAL:
				$Screens/Title/NewGameButton.text = "SKIP TUTORIAL"
			else:
				$Screens/Title/NewGameButton.text = "NEW GAME"

			$Screens/Title/NewGameButton.visible = true

			title_music_target = -80
			track1_target = -80

		GameState.GAME_CONTINUED:
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = true
			get_tree().paused = false
			State.game_state = GameState.GAME
			title_music_target = -80
			track1_target = 0
			_mouse_on_button = false

		GameState.GAME_OVER:
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$Screens/Title/StartButton.text = "START"

			if State.config.get_value("Game", "Tutorial") == false:
				$Screens/Title/NewGameButton.text = "Tutorial"
				$Screens/Title/NewGameButton.visible = true
			else:
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
			title_music_target = 0

		GameState.LEVEL_END:
			game_reset()
			$Screens/Title.visible = false
			$HUD/MarginContainer.visible = false
			$WorldMap.visible = false
			$LevelInterlude.visible = true
			_camera.zoom = Vector2(1.0, 1.0)
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			$LevelInterlude.show_level_end()
			title_music_target = -80
			track1_target = -80
			$Success.play()


func show_story(message : String, keep_open = false) -> void:
	_story_queue.append(message)
	_story_queue_keep_open.append(keep_open)

func hide_story() -> void:
	_story_queue.append("")
	_story_queue_keep_open.append(false)

func reset_story() -> void:
	$HUD/MarginContainer/VBoxContainer/StoryLabel.text = ""
	$HUD/AnimationPlayer.stop(true)


func _on_StartButton_pressed() -> void:
	if $Screens/Title/StartButton.text == "CONTINUE":
		switch_state(GameState.GAME_CONTINUED)
	elif State.config.get_value("Game", "Tutorial"):
		switch_state(GameState.TUTORIAL)
	else:
		switch_state(GameState.NEW_GAME)


func _on_NewGameButton_pressed() -> void:
	if $Screens/Title/NewGameButton.text == "Tutorial":
		switch_state(GameState.TUTORIAL)
	else:
		if State.world_node_type == NodeType.TUTORIAL:
			State.config.set_value("Game", "Tutorial", false)
			State.config.save(State.config_path)

		switch_state(GameState.NEW_GAME)


func _on_ExitButton_pressed() -> void:
	get_tree().quit()


func _on_SpecialIntro_stop_intro() -> void:
	switch_state(GameState.LEVEL_START)


func _on_LevelInterlude_stop_level_start() -> void:
	switch_state(GameState.GAME)


func _on_LevelInterlude_stop_level_end() -> void:
	if State.world_node_type == NodeType.TUTORIAL:
		State.config.set_value("Game", "Tutorial", false)
		State.config.save(State.config_path)
		switch_state(GameState.NEW_GAME)
	elif State.level == 10:
		switch_state(GameState.TITLE_SCREEN)
	else:
		switch_state(GameState.MERCHANT)


func _on_GameOver_stop_game_over() -> void:
	switch_state(GameState.TITLE_SCREEN)

func _on_WorldMap_world_node_clicked(node_type) -> void:
	if State.world_layer_index == 0:
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
		State.sounds.play(AudioType.TEST, null)

	State.config.set_value("Audio", "Sound", value)
	State.config.save(State.config_path)

