extends Node2D


signal stop_level_start

func _ready() -> void:
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if $AnimationPlayer.current_animation_position > 0.2:
		if Input.is_action_just_pressed("command"):
			switch_scene()

func start() -> void:
	visible = true
	set_process(true)

	if State.end_level_info.length() > 0:
		$CanvasLayer/LevelLabel.text = State.end_level_info
	else:
		$CanvasLayer/LevelLabel.text = "Well done"

	$AnimationPlayer.play("Default")


func switch_scene() -> void:
	set_process(false)
	$CanvasLayer/LevelLabel.visible = false
	$CanvasLayer/TextureRect.visible = false
	$AnimationPlayer.stop()
	emit_signal("stop_level_start")

func show_level() -> void:
	$CanvasLayer/LevelLabel.text = "Down to Level %d" % State.level
