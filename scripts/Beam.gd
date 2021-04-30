extends Node2D

onready var sprite := $Sprite

func _ready() -> void:
	sprite.rotation = randf() * 2 * PI
