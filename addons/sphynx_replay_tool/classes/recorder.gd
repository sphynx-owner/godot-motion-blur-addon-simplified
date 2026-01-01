class_name Recorder
extends Node

var current_frame: int = 0

var current_scene_record: SceneRecord


func start_recording() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	
	current_frame = 0
	
	current_scene_record = SceneRecord.new()
	
	current_scene_record.create_subtree_records_recursive(get_tree().root, current_frame)


func stop_recording() -> void:
	get_tree().node_added.disconnect(_on_node_added)
	get_tree().node_removed.disconnect(_on_node_removed)
	
	RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)
	
	current_scene_record.close_all_active_records(current_frame)


func _on_node_added(node: Node) -> void:
	current_scene_record.create_node_record(node, current_frame)


func _on_node_removed(node: Node) -> void:
	current_scene_record.close_node_record(node, current_frame)


func _on_frame_post_draw() -> void:
	current_scene_record.update_all_active_records(current_frame)
	
	current_frame += 1
