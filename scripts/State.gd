extends Node

const GameState = preload("res://scripts/GameState.gd").GameState
const NodeType = preload("res://scripts/NodeType.gd").NodeType

const random_seed := 0

var game_state = GameState.TITLE_SCREEN

var world_layers := []
var world_layer_index : int

var world_node_type

var minion_count : int
var archer_count : int
var minion_king_count : int
var bomb_count : int
var map : Map
var tilemap32 : TileMap

var increase_minion_count : int
var increase_archer_count : int
var increase_bomb_count : int

var rally_radius : int
var rally_duration : int
var rally_immune : int

var minion_view_distance : int
var monster_view_distance : int

var monster_archer_fraction := 0.25

var dirt_health : int
var minion_health : int
var monster_health : int
var king_health : int

var level_monster_count : int

var start_portals := []
var end_portals := []

var monsters := []

# does not contain monsters and fled minions
var minions := []
var minions_fled : int
var archers_fled : int

var minion_kings_created_count : int
var minion_kings_died_count : int
var minion_kings := []

var monster_check_index : int
var minion_check_index : int

var level : int
var end_level_info := ""

var spawn_cooldown := 20

var swarm_cooldown_init := 30
var swarm_cooldown_min := 15
var swarm_cooldown_max := 45

const config_path = "res://settings.ini"
var config : ConfigFile

var game_camera : Camera2D

var prisons := []
var monster_swarms := []

var entity_container : Node2D


var tile_circle := []
var area_limits := [0, 0, 0, 0]

func _ready() -> void:
	pass


func world_reset() -> void:
	world_layers.clear()
	world_layer_index = 0

	world_node_type = NodeType.PORTAL

	minion_count = 7

	level_monster_count = 10
	bomb_count = 10

	# Part of minion_count
	archer_count = 2
	minion_king_count = 0


	increase_minion_count = 0
	increase_archer_count = 0
	increase_bomb_count = 0


	rally_radius = 2
	rally_duration = 15
	rally_immune = 15

	monster_check_index = 0
	minion_check_index = 0

	minion_view_distance = 8
	monster_view_distance = 8
	dirt_health = 3
	minion_health = 5
	monster_health = 5
	king_health = 20

	level = 0
	end_level_info = ""

	spawn_cooldown = 20

	minions_fled = 0
	archers_fled = 0


	minion_kings.clear()
	minion_kings_created_count = 0
	minion_kings_died_count = 0

func increase_level():
	State.level += 1
	State.world_layer_index += 1

	if State.level > 1:
		var free_minion_count := 0
		for minion in minions:
			if !minion.prisoner:
				free_minion_count += 1

		var current_count := free_minion_count + minions_fled + archers_fled
		minions_fled = 0
		archers_fled = 0

		minion_count = current_count + increase_minion_count + increase_archer_count
		archer_count = archers_fled + increase_archer_count

		for minion in minions:
			if minion.archer:
				archer_count += 1

		level_monster_count *= 1.5


		bomb_count += increase_bomb_count

		increase_minion_count = 0
		increase_archer_count = 0
		increase_bomb_count = 0


	spawn_cooldown = max(10, 45 - State.level * 6)

func game_reset():
	start_portals.clear()
	end_portals.clear()
	monsters.clear()
	minions.clear()
	prisons.clear()
	minion_kings.clear()

	monster_swarms.clear()

	minion_kings_created_count = 0
	minion_kings_died_count = 0
