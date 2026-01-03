@tool
class_name OptionSlider
extends HBoxContainer

signal value_changed

@export var option_name: String:
	set(value):
		option_name = value
		
		$Label.text = option_name

@onready var h_slider: HSlider = $HSlider

var _custom_property_list: Dictionary[String, Dictionary]


func _init() -> void:
	var temp_property_list: Array[Dictionary] = ClassDB.class_get_property_list("Range")
	var control_property_list: Array[Dictionary] = ClassDB.class_get_property_list("Control")
	
	for property in control_property_list:
		temp_property_list.erase(property)
	
	for property in temp_property_list:
		_custom_property_list[property.name] = property


func _ready() -> void:
	h_slider.value_changed.connect(value_changed.emit)
	h_slider.value_changed.connect(func(value: float): $ValueLabel.text = "%10.3f" % value)


func _get_property_list() -> Array[Dictionary]:
	return _custom_property_list.values()


func _set(property: StringName, value: Variant) -> bool:
	if !h_slider:
		return false
	
	h_slider.set(property, value)
	return true


func _get(property: StringName) -> Variant:
	if !h_slider:
		return null
	
	return h_slider.get(property)


func _property_can_revert(property: StringName) -> bool:
	return _custom_property_list.has(property)


func _property_get_revert(property: StringName) -> Variant:
	return ClassDB.class_get_property_default_value("HSlider", property)
