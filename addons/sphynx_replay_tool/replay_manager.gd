class_name ReplayManager
extends Node

# Records of all nodes in the scene, in the order they were spawned in.
var _node_records: Array[NodeRecord]


func _ready() -> void:
	gather_initial_visual_nodes()


func gather_initial_visual_nodes() -> void:
	pass
