@tool
class_name OptionSlider
extends HBoxContainer

signal value_changed

@export var option_name: String:
	set(value):
		option_name = value
		
		$Label.text = option_name

var _custom_property_list: Dictionary[String, Dictionary]


func _init() -> void:
	var temp_property_list: Array[Dictionary] = ClassDB.class_get_property_list("Range")
	var control_property_list: Array[Dictionary] = ClassDB.class_get_property_list("Control")
	
	for property in control_property_list:
		temp_property_list.erase(property)
	
	for property in temp_property_list:
		_custom_property_list[property.name] = property


func _ready() -> void:
	$HSlider.value_changed.connect(value_changed.emit)


func _get_property_list() -> Array[Dictionary]:
	return _custom_property_list.values()


func _set(property: StringName, value: Variant) -> bool:
	$HSlider.set(property, value)
	return true


func _get(property: StringName) -> Variant:
	return $HSlider.get(property)


func _property_can_revert(property: StringName) -> bool:
	return _custom_property_list.has(property)

func _property_get_revert(property: StringName) -> Variant:
	return ClassDB.class_get_property_default_value("HSlider", property)
