class_name ReplayManager
extends Node

@export var record_button: Button

@export var replay_button: Button


func _on_record_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_start_recording()
		replay_button.disabled = true
		
	else:
		_stop_recording()
		replay_button.disabled = false


func _on_replay_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_start_replay()
		record_button.disabled = true
		
	else:
		_stop_replay()
		record_button.disabled = false


func _start_recording() -> void:
	pass


func _stop_recording() -> void:
	pass


func _start_replay() -> void:
	pass


func _stop_replay() -> void:
	pass
