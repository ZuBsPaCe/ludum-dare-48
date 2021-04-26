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

	$CanvasLayer/LevelLabel.text = State.end_level_info

	$AnimationPlayer.play("Default")

func show_level():
	$CanvasLayer/LevelLabel.text = "Down to level %d" % State.level

func switch_scene() -> void:
	set_process(false)
	$CanvasLayer/LevelLabel.visible = false
	$CanvasLayer/TextureRect.visible = false
	$AnimationPlayer.stop()
	emit_signal("stop_level_start")
