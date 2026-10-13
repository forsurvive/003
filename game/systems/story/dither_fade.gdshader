// 디더 페이드(SD-16 연출 메모 '디더 페이드로 밝아진다'): 반투명 대신 4×4 베이어 문턱으로 화면 픽셀을 덮는다(팔레트 밖 색 없음).
shader_type canvas_item;
uniform vec4 fill : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;
const float B[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
void fragment() {
	ivec2 p = ivec2(floor(FRAGCOORD.xy));
	float th = (B[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
	if (th > amount) discard;
	COLOR = fill;
}
