class_name SceneRecord
extends Resource

## Records of all nodes in the scene, in the order they were spawned in.
@export_storage var _node_records: Array[NodeRecord]

## Node records by the instance id of the nodes currently being recorded.
var _active_node_records: Dictionary[Node, NodeRecord]


func create_subtree_records_recursive(node: Node, current_frame) -> void:
	if NodeRecord.can_record_node(node):
		_create_node_record(node, current_frame)
	
	for child in node.get_children():
		create_subtree_records_recursive(child, current_frame)


func update_all_active_records(current_frame: int) -> void:
	for active_node_id in _active_node_records.keys():
		_update_node_record(active_node_id, current_frame)


func close_all_active_records(current_frame: int) -> void:
	for active_node_id in _active_node_records.keys():
		_close_node_record(active_node_id, current_frame)


func _create_node_record(node: Node, current_frame: int) -> void:
	var new_node_record := NodeRecord.new()
	
	new_node_record.capture_node_initial_state(node, current_frame)
	
	_active_node_records[node] = new_node_record


func _update_node_record(node: Node, current_frame: int) -> void:
	_active_node_records[node].capture_node_frame_info(node, current_frame)


func _close_node_record(node: Node, current_frame: int) -> void:
	_active_node_records[node].close_node_record(current_frame)
	_active_node_records.erase(node)
