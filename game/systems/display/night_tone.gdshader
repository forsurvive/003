// 상황 필터 '밤'(SD-16 §4.7, art/tools/filters.py TONES["밤"]와 같은 식): 휘도로 회색 g/255만큼 섞은 뒤 RGB를 더한다.
// 화면 색조라 결과 색은 팔레트 밖이 정상이다(원본 에셋은 팔레트를 지킨다). 빛 원판은 이 층 위에 가산으로 따로 그린다.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 tone = vec4(-70.0, -55.0, -20.0, 40.0);
uniform float amount = 1.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * 255.0;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = c + (vec3(l) - c) * (tone.a / 255.0) + tone.rgb;
	COLOR = vec4(clamp(mix(c, t, amount) / 255.0, 0.0, 1.0), 1.0);
}
