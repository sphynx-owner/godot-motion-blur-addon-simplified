class_name SceneRecord
extends Resource

## Records of all nodes in the scene, in the order they were spawned in.
@export_storage var node_records: Array[NodeRecord]

@export_storage var record_end_frame: int

## Node records by the instance id of the nodes currently being recorded.
var _active_node_records: Dictionary[Node, NodeRecord]


func create_subtree_records_recursive(node: Node, current_frame) -> void:
	create_node_record(node, current_frame)
	
	for child in node.get_children():
		create_subtree_records_recursive(child, current_frame)


func update_all_active_records(current_frame: int) -> void:
	for active_node_id in _active_node_records.keys():
		update_node_record(active_node_id, current_frame)


func close_all_active_records(current_frame: int) -> void:
	for active_node_id in _active_node_records.keys():
		close_node_record(active_node_id, current_frame)
	
	record_end_frame = current_frame


func create_node_record(node: Node, current_frame: int) -> void:
	if !NodeRecord.can_record_node(node):
		return
	
	if _active_node_records.has(node):
		var err_string: String = "node already exists in active node records"
		assert(false, err_string)
		push_error(err_string)
	
	var new_node_record := NodeRecord.new()
	
	new_node_record.capture_node_initial_state(node, current_frame)
	
	_active_node_records[node] = new_node_record
	
	node_records.append(new_node_record)


func update_node_record(node: Node, current_frame: int) -> void:
	if !_active_node_records.has(node):
		var err_string: String = "node does not exist in active node records"
		assert(false, err_string)
		push_error(err_string)
	
	_active_node_records[node].capture_node_frame_info(node, current_frame)


func close_node_record(node: Node, current_frame: int) -> void:
	if !_active_node_records.has(node):
		var err_string: String = "node does not exist in active node records"
		assert(false, err_string)
		push_error(err_string)
	
	_active_node_records[node].close_node_record(current_frame)
	_active_node_records.erase(node)
