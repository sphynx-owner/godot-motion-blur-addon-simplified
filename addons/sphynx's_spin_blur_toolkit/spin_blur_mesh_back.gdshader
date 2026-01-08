shader_type spatial;

render_mode unshaded, depth_draw_always, fog_disabled, cull_front;

stencil_mode read, compare_not_equal, 2;

#include "spin_blur_shader_include.gdshaderinc"