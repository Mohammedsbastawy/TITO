shader_type canvas_item;
// Cloth sway for hanging curtains: the top edge (UV.y = 0) is pinned to the
// rod, the bottom wanders. Driven purely by TIME so no per-frame GDScript.
uniform float strength = 7.0;
uniform float speed = 1.25;
uniform float phase = 0.0;

void vertex() {
	float loose = UV.y * UV.y; // grows toward the free bottom edge
	VERTEX.x += sin(TIME * speed + phase + UV.y * 4.5 + UV.x * 2.0) * strength * loose;
}
