class_name ReplayManager
extends Node

@export var record_button: Button

@export var replay_button: Button

@export var save_button: Button

@export var load_button: Button

@export var recorder: Recorder

@export var replayer: Replayer


func _ready() -> void:
	record_button.toggled.connect(_on_record_button_toggled)
	replay_button.toggled.connect(_on_replay_button_toggled)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	replayer.stopped_replaying_automatically.connect(func(): replay_button.button_pressed = false)


func _on_record_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_start_recording()
		replay_button.disabled = true
		save_button.disabled = true
		load_button.disabled = true
		
	else:
		_stop_recording()
		replay_button.disabled = false
		save_button.disabled = false
		load_button.disabled = false


func _on_replay_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_start_replay()
		record_button.disabled = true
		
	else:
		_stop_replay()
		record_button.disabled = false


func _start_recording() -> void:
	recorder.start_recording()


func _stop_recording() -> void:
	recorder.stop_recording()


func _start_replay() -> void:
	replayer.current_scene_record = recorder.current_scene_record
	replayer.start_replaying()


func _stop_replay() -> void:
	replayer.stop_replaying()


func _on_save_button_pressed() -> void:
	ResourceSaver.save(
		recorder.current_scene_record, 
		"res://addons/sphynx_replay_tool/temp/temp_scene_record.tres", 
		ResourceSaver.SaverFlags.FLAG_REPLACE_SUBRESOURCE_PATHS)


func _on_load_button_pressed() -> void:
	recorder.current_scene_record = ResourceLoader.load("res://addons/sphynx_replay_tool/temp/temp_scene_record.tres")
