// 상황 필터(SD-16 §4.7, art/tools/filters.py TONES와 같은 식): 휘도로 회색 g/255만큼 섞은 뒤 RGB를 더한다.
// 화면 색조라 결과 색은 팔레트 밖이 정상이다(원본 에셋은 팔레트를 지킨다). 빛 원판은 이 층 위에 가산으로 따로 그린다.
// 새벽 지면 안개(필터 2 덧씌우기, 알파 25%): 세상 좌표에 붙은 값 노이즈 두 겹이 천천히 흐르고, 2×2 픽셀 묶음 · 3단(0 · 12 · 25%)으로 끊어 도트 결을 지킨다.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 tone = vec4(-70.0, -55.0, -20.0, 40.0);
uniform float amount = 1.0;
uniform float fog = 0.0;                    // 0~1(새벽 정도) × 25%
uniform vec2 cam = vec2(0.0);               // 화면 왼쪽 위의 세상 좌표(px)
uniform vec2 view = vec2(640.0, 360.0);     // 화면이 덮는 세상 크기(px)
uniform vec3 fog_col = vec3(0.78, 0.82, 0.86);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * 255.0;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = c + (vec3(l) - c) * (tone.a / 255.0) + tone.rgb;
	vec3 o = mix(c, t, amount) / 255.0;
	if (fog > 0.001) {
		vec2 w = floor((cam + SCREEN_UV * view) / 2.0) * 2.0;                    // 2×2 세상 픽셀 묶음
		float n = vnoise(w / 112.0 + vec2(TIME * 0.035, TIME * 0.012)) * 0.65
			+ vnoise(w / 41.0 - vec2(TIME * 0.06, 0.0)) * 0.35;
		float a = n > 0.62 ? 0.25 : (n > 0.46 ? 0.12 : 0.0);
		o = mix(o, fog_col, a * fog);
	}
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
