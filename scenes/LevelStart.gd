extends Node2D


signal stop_game_over

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

	$AnimationPlayer.play("Default")


func switch_scene() -> void:
	set_process(false)
	$CanvasLayer/GameOverLabel.visible = false
	$CanvasLayer/TextureRect.visible = false
	$AnimationPlayer.stop()
	emit_signal("stop_game_over")
