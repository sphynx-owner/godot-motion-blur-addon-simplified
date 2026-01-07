shader_type spatial;

render_mode depth_draw_opaque, fog_disabled, cull_back;

stencil_mode write, 2;

#include "spin_blur_shader_include.gdshaderinc"