@tool
class_name SpinBlurHelpers
## Uses metadata to generated and keep record of subviewports
## for unique reserved render layers, so that multiple spin blurs
## operating on the same render layer could use the same viewport and camera.

const SPIN_BLUR_META_KEY: StringName = &"spin_blur_metadata"


static func register_spin_blur(spin_blur: SpinBlur) -> void:
	if !spin_blur.is_inside_tree():
		push_error("spin blur %s is not inside tree" % [spin_blur])
		return
	
	var parent_viewport: Viewport = spin_blur.get_viewport()
	
	var meta_object: SpinBlurHelperMetaObject = get_spin_blur_meta(parent_viewport)
	
	var layer: int = spin_blur.reserved_render_layer
	
	if !meta_object.spin_blurs_by_layer.has(layer):
		initialize_new_render_layer(parent_viewport, layer)
	
	meta_object.spin_blurs_by_layer.get(layer)[spin_blur] = true
	
	spin_blur._viewport = get_spin_blur_viewport(spin_blur)
	spin_blur._camera = get_spin_blur_camera(spin_blur)


static func unregister_spin_blur(spin_blur: SpinBlur) -> void:
	var parent_viewport: Viewport = spin_blur.get_viewport()
	
	var meta_object: SpinBlurHelperMetaObject = get_spin_blur_meta(parent_viewport)
	
	var layer: int = spin_blur.reserved_render_layer
	
	if !meta_object.spin_blurs_by_layer.has(layer):
		push_error("spin blurs by layer missing layer %s, cannot remove" % [layer])
		return
	
	meta_object.spin_blurs_by_layer.get(layer).erase(spin_blur)
	
	if meta_object.spin_blurs_by_layer.get(layer).is_empty():
		discard_render_layer(parent_viewport, layer)


static func initialize_new_render_layer(parent_viewport: Viewport, layer: int) -> void:
	var meta_object: SpinBlurHelperMetaObject = get_spin_blur_meta(parent_viewport)
	
	meta_object.spin_blurs_by_layer.set(layer, {} as Dictionary[SpinBlur, bool])
	
	meta_object.camera_cull_mask |= 1 << (layer - 1)
	
	var new_viewport = SpinBlurViewport.new()
	
	new_viewport.parent_viewport = parent_viewport
	
	meta_object.viewports_by_layer.set(layer, new_viewport)
	
	new_viewport.transparent_bg = true
	
	new_viewport.render_target_update_mode = SpinBlurViewport.UPDATE_ALWAYS
	
	new_viewport.use_hdr_2d = true
	
	new_viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
	
	parent_viewport.add_child(new_viewport)
	
	var new_camera = SpinBlurCamera.new()
	
	new_camera.parent_viewport = parent_viewport
	
	meta_object.cameras_by_layer.set(layer, new_camera)
	
	new_camera.cull_mask = meta_object.camera_cull_mask
	
	new_camera.compositor = Compositor.new()
	
	new_camera.compositor.compositor_effects = [DepthCompositorEffect.new()]
	
	new_viewport.add_child(new_camera)


static func discard_render_layer(parent_viewport: Viewport, layer: int) -> void:
	var meta_object: SpinBlurHelperMetaObject = get_spin_blur_meta(parent_viewport)
	
	meta_object.spin_blurs_by_layer.erase(layer)
	
	meta_object.camera_cull_mask &= ~(1 << (layer - 1))
	
	if meta_object.cameras_by_layer.has(layer):
		var camera: Variant = meta_object.cameras_by_layer.get(layer)
		
		if camera:
			camera.queue_free()
		
		meta_object.cameras_by_layer.erase(layer)
	
	if meta_object.viewports_by_layer.has(layer):
		var viewport: Variant = meta_object.viewports_by_layer.get(layer)
		
		if viewport:
			viewport.queue_free()
		
		meta_object.viewports_by_layer.erase(layer)


static func get_spin_blur_meta(viewport: Viewport) -> SpinBlurHelperMetaObject:
	if !viewport.has_meta(SPIN_BLUR_META_KEY) or viewport.get_meta(SPIN_BLUR_META_KEY) is not SpinBlurHelperMetaObject:
		viewport.set_meta(SPIN_BLUR_META_KEY, SpinBlurHelperMetaObject.new())
	
	return viewport.get_meta(SPIN_BLUR_META_KEY)


static func get_spin_blur_viewport(spin_blur: SpinBlur) -> SpinBlurViewport:
	if !spin_blur.is_inside_tree():
		push_error("spin blur %s is not inside tree, cannot get viewport" % [spin_blur])
		return null
	
	var parent_viewport: Viewport = spin_blur.get_viewport()
	
	var meta_object: SpinBlurHelperMetaObject = get_spin_blur_meta(parent_viewport)
	
	var layer: int = spin_blur.reserved_render_layer
	
	if meta_object.viewports_by_layer.has(layer):
		return meta_object.viewports_by_layer.get(layer)
	
	return null


static func get_spin_blur_camera(spin_blur: SpinBlur) -> SpinBlurCamera:
	if !spin_blur.is_inside_tree():
		push_error("spin blur %s is not inside tree, cannot get camera" % [spin_blur])
		return null
	
	var parent_viewport: Viewport = spin_blur.get_viewport()
	
	var meta_object: SpinBlurHelperMetaObject = get_spin_blur_meta(parent_viewport)
	
	var layer: int = spin_blur.reserved_render_layer
	
	if meta_object.cameras_by_layer.has(layer):
		return meta_object.cameras_by_layer.get(layer)
	
	return null


## This is a way of getting non-persistent metadata, by storing values to non-exported
## variables under a resource type object.
class SpinBlurHelperMetaObject extends Resource:
	## All spin blurs by their reserved render layer.
	## @shape: {[layer: int]: {[spin_blur: SpinBlur]: true}}
	var spin_blurs_by_layer: Dictionary[int, Dictionary]
	
	## All spin blur viewports by reserved render layer
	## @shape: {[layer: int]: {[viewport: Viewport]: true}}
	var viewports_by_layer: Dictionary[int, Viewport]
	
	## All spin blur cameras by reserved render layer
	## @shape: {[layer: int]: {[camera: SpinBlurCamera]: true}}
	var cameras_by_layer: Dictionary[int, SpinBlurCamera]
	
	## A mask that non-spin-blur cameras should apply if they want to
	## support spin blur
	var camera_cull_mask: int
