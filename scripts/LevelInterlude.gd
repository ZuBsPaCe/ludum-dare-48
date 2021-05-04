extends Node2D


signal stop_level_start
signal stop_level_end

var _is_start : bool

func _ready() -> void:
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if $AnimationPlayer.current_animation_position > 0.2:
		if Input.is_action_just_pressed("command"):
			switch_scene()

func show_level_end() -> void:
	_is_start = false

	visible = true
	set_process(true)

	$CanvasLayer/LevelLabel.text = State.end_level_info

	$AnimationPlayer.play("Default")

func show_level_start():
	_is_start = true

	visible = true
	set_process(true)

	$CanvasLayer/LevelLabel.text = "Down to level %d" % State.level
	$AnimationPlayer.play("Default")

func switch_scene() -> void:
	set_process(false)
	$CanvasLayer/LevelLabel.visible = false
	$CanvasLayer/TextureRect.visible = false
	$AnimationPlayer.stop()

	if _is_start:
		emit_signal("stop_level_start")
	else:
		emit_signal("stop_level_end")
