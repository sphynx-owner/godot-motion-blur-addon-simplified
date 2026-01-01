class_name Replayer
extends Node

signal stopped_replaying_automatically


var current_frame: int = 0

var current_node_record_index: int = 0

var current_scene_record: SceneRecord

var active_node_replays: Dictionary[Node, NodeRecord]

var replaying := false


func start_replaying() -> void:
	current_frame = 0
	
	current_node_record_index = 0
	
	replaying = true


func stop_replaying() -> void:
	for node in active_node_replays.keys():
		get_tree().root.remove_child(node)
	
	active_node_replays.clear()
	
	replaying = false


func _process(delta: float) -> void:
	if !replaying:
		return
	
	if current_frame > current_scene_record.record_end_frame:
		stop_replaying()
		stopped_replaying_automatically.emit()
	
	if !replaying:
		return
	
	while true:
		if current_node_record_index >=current_scene_record.node_records.size():
			break
		
		var current_node_record: NodeRecord = current_scene_record.node_records[current_node_record_index]
		
		if current_node_record.spawn_frame > current_frame:
			break
		
		current_node_record_index += 1
		
		var recreated_node: Node = current_node_record.recreate_node()
		
		get_tree().root.add_child(recreated_node)
		
		active_node_replays[recreated_node] = current_node_record
	
	
	for node in active_node_replays.keys():
		if active_node_replays[node].despawn_frame <= current_frame:
			active_node_replays.erase(node)
			
			get_tree().root.remove_child(node)
	
	
	for node in active_node_replays.keys():
		active_node_replays[node].recreate_frame(node, current_frame)
	
	
	current_frame += 1
