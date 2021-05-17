extends Node2D

var font := preload("res://art/font/dogica/dogica small.tres")

func _ready() -> void:
	if !visible:
		set_process(false)

func _process(delta: float) -> void:
	update()

func _draw() -> void:
	for monster in State.monsters:
		draw_string(font, monster.position + Vector2(4, -8), "%.1f" % monster.under_attack_cooldown, Color.red)
