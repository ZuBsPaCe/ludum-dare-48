extends Node

const GameState = preload("res://scripts/GameState.gd").GameState


var game_state = GameState.TITLE_SCREEN
var minion_count : int
var map : Map
var tilemap32 : TileMap


func _ready() -> void:
	pass


func world_reset() -> void:
	minion_count = 10

func game_reset():
	pass



