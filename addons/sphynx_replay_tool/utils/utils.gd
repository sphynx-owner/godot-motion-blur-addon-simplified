class_name ReplayUtils

static var class_list_memoization: Dictionary[String, Array]


static func get_native_class_property_list(variant: Variant) -> Array[String]:
	var _class: String
	
	if variant is String:
		_class = variant
		
	elif variant is Object:
		_class = variant.get_class()
	
	if !class_list_memoization.has(_class):
		var new_list: Array[String]
		
		new_list.assign(
			ClassDB.class_get_property_list(_class).map(func(element): return element.name)
		)
		
		new_list.make_read_only()
		
		class_list_memoization[_class] = new_list
	
	return class_list_memoization[_class]
