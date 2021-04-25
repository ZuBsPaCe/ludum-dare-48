extends Node

const GameState = preload("res://scripts/GameState.gd").GameState


var game_state = GameState.TITLE_SCREEN
var minion_count : int
var map : Map
var tilemap32 : TileMap

var rally_radius : int
var rally_duration : int

var minion_view_distance : int
var monster_view_distance : int

var dirt_health : int
var minion_health : int
var monster_health : int

var level_monster_count : int

var start_portals := []
var end_portals := []

var monsters := []
var minions := []

var monster_check_index : int
var minion_check_index : int


func _ready() -> void:
	pass


func world_reset() -> void:
	minion_count = 10
	level_monster_count = 10

	rally_radius = 2
	rally_duration = 6
	start_portals.clear()
	end_portals.clear()
	monsters.clear()
	minions.clear()
	monster_check_index = 0
	minion_check_index = 0

	minion_view_distance = 5
	monster_view_distance = 5
	dirt_health = 3
	minion_health = 5
	monster_health = 5

func game_reset():
	pass



