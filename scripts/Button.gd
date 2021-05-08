extends Control


export(Texture) var icon : Texture
export var show_count := false

onready var _button_normal := $ButtonNormal
onready var _button_hover := $ButtonHover
onready var _button_disabled := $ButtonDisabled
onready var _button_highlight := $ButtonHighlight
onready var _icon := $Icon
onready var _count_label := $Count

signal pressed
signal toggled

var tag

func _ready() -> void:
	_icon.texture = icon
	_count_label.visible = show_count

func set_icon(texture : Texture) -> void:
	_icon.texture = texture

func set_count(count : int) -> void:
	_count_label.text = str(count)
	_count_label.visible = true

func set_disabled(disabled : bool) -> void:
	_button_normal.disabled = disabled
	_button_disabled.visible = disabled

func set_highlight(highlight : bool) -> void:
	_button_highlight.visible = highlight

func _on_ButtonNormal_mouse_entered() -> void:
	if !_button_normal.disabled:
		_button_hover.visible = true


func _on_ButtonNormal_mouse_exited() -> void:
	if !_button_normal.disabled:
		_button_hover.visible = false


func _on_ButtonNormal_pressed() -> void:
	emit_signal("pressed")


func _on_ButtonNormal_toggled(button_pressed: bool) -> void:
	emit_signal("toggled", button_pressed)
