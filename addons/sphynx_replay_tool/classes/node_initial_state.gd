@abstract 
class_name NodeInitialState
extends Resource

@export_storage var state: Dictionary[String, Variant]


func _init(node: MeshInstance3D = null) -> void:
	if !node:
		return
	
	_capture_node_initial_state(node)


@abstract func recreate_node() -> Node

@abstract func _capture_node_initial_state(node: Node) -> void
