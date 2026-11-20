shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, blend_mix;

uniform vec4 outline_color : source_color = vec4(1.0, 0.78, 0.14, 0.92);
uniform float outline_thickness : hint_range(0.01, 0.15) = 0.045;
uniform float pulse_speed : hint_range(0.5, 10.0) = 4.2;

void vertex() {
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed);
	VERTEX += NORMAL * (outline_thickness * pulse);
}

void fragment() {
	float pulse = 0.78 + 0.22 * sin(TIME * pulse_speed);
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * pulse;
}
