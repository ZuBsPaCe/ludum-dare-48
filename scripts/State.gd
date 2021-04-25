extends Node

const GameState = preload("res://scripts/GameState.gd").GameState


var game_state = GameState.TITLE_SCREEN
var minion_count : int
var map : Map
var tilemap32 : TileMap

var rally_radius : int
var rally_duration : int

var level_monster_count : int

var start_portals := []
var end_portals := []


func _ready() -> void:
	pass


func world_reset() -> void:
	minion_count = 10
	rally_radius = 2
	rally_duration = 6
	level_monster_count = 10
	start_portals.clear()
	end_portals.clear()

func game_reset():
	pass



