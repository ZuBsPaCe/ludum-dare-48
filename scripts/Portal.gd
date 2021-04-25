extends Node2D

var active := false

onready var _portal_animation := $PortalAnimation

func _ready() -> void:
	pass

func set_active(new_active : bool) -> void:
	if new_active:
		if !active:
			active = true
			_portal_animation.play("Start")
	else:
		if active:
			active = false
			_portal_animation.play("Stop")
