// 팔레트 인덱스 셰이더 (SD-19 §6.7): 스프라이트 R 채널 = 팔레트 인덱스(SD-16 §13.3 슬롯).
// 1~64 마스터, 65~69 피부, 70~73 머리색, 74~77 세력 주색, 78~79 세력 강조. 텍스처 추가 없이 색을 바꾼다.
shader_type canvas_item;

uniform vec4 master[64];
uniform vec4 skin[5];
uniform vec4 hair[4];
uniform vec4 fac[6];
uniform float flash = 0.0;          // 피격 흰 번쩍임(0~1)

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.5) {
		discard;
	}
	int i = int(round(t.r * 255.0));
	vec4 c;
	if (i <= 64) {
		c = master[clamp(i - 1, 0, 63)];
	} else if (i <= 69) {
		c = skin[i - 65];
	} else if (i <= 73) {
		c = hair[i - 70];
	} else {
		c = fac[clamp(i - 74, 0, 5)];
	}
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), 1.0) * tint;
}
