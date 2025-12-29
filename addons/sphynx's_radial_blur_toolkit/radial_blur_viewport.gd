@tool
extends SubViewport

func _ready() -> void:
	get_parent().get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()


func _on_viewport_size_changed():
	size = get_parent().get_viewport().size
	pass
