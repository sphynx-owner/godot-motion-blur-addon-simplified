class_name Recorder
extends Node

var current_frame: int = 0

var _current_scene_record: SceneRecord


func start_recording() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	
	current_frame = 0
	
	_current_scene_record = SceneRecord.new()


func stop_recording() -> void:
	get_tree().node_added.disconnect(_on_node_added)
	get_tree().node_removed.disconnect(_on_node_removed)
	
	RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)


func _on_node_added(node: Node) -> void:
	pass


func _on_node_removed(node: Node) -> void:
	pass


func _on_frame_post_draw() -> void:
	current_frame += 1
