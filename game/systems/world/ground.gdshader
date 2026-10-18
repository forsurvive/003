// 바닥 합성 셰이더 v2 — 쯔꾸르풍(SD-16 §6.10). art/tools/ground.py GroundSet.render와 정수 단위로 같은 식이다(ground_check로 대조).
// 재질 텍스처를 월드 픽셀 좌표로 읽고, 가까운 타일 중심 4곳의 이중선형 가중치 + 재질별 매끈한 큰 얼룩 잡음으로 재질을 고른다(물결 경계).
// 경계는 쯔꾸르 오토타일처럼: 위 재질은 테두리(rim), 아래 재질은 그늘(shade). 그늘·그림자는 또렷한 띠·타원(디더 없음).
// 색을 섞지 않고 아틀라스 텍셀 하나를 고르므로 결과는 늘 팔레트 안 색이다.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D id_map : filter_nearest;      // RG8: R = 바닥 타일 아틀라스 번호, G = 덮개(0 없음, 1 벽, 2 소품, 3 평평한 구조물). 한 칸 테두리 포함
uniform sampler2D atlas : filter_nearest;       // 재질 × [A, B, A어둠, B어둠, A더어둠, B더어둠], 칸 cell×cell
uniform sampler2D decals : filter_nearest;      // 잔 소품 32×32 가로 줄, 아래 32줄은 어둠 벌
uniform sampler2D noise : filter_nearest;       // 256×256, R 큰 얼룩(경계 물결) · B 아주 큰 얼룩(A·B 벌)
uniform ivec2 origin;                           // id_map (1,1) 칸의 월드 타일
uniform ivec2 map_size;                         // id_map 크기(테두리 포함)
uniform int cell = 256;
uniform int mat_of[64];
uniform int force[64];
uniform int spread[16];
uniform int pri[16];
uniform int rim[16];
uniform int shade[16];
uniform int vthr[16];
uniform int dens[16];
uniform int hard[16];
uniform int soft[16];
uniform int curb[16];                            // 연석 띠(px): 낮은 재질과 만나는 가장자리(보도 — 1-R v2) · 색은 curb_rgb(팔레트 그대로)
uniform ivec3 curb_rgb[8];                            // 자연 재질: 서로 만나면 테 없이 2×2 디더로 섞는다(바이옴 전이)
uniform int boff[32];
uniform int dlist[128];
uniform int dcount[16];

varying vec2 lp;

const int NEG = -1000000000;

void vertex() {
	lp = VERTEX;
}

ivec2 cell_at(int tx, int ty) {
	ivec2 p = clamp(ivec2(tx - origin.x + 1, ty - origin.y + 1), ivec2(0), map_size - ivec2(1));
	vec4 c = texelFetch(id_map, p, 0);
	return ivec2(int(round(c.r * 255.0)), int(round(c.g * 255.0)));
}

ivec2 nz(int x, int y) {
	vec4 c = texelFetch(noise, ivec2(x & 255, y & 255), 0);
	return ivec2(int(round(c.r * 255.0)), int(round(c.b * 255.0)));
}

bool low_nb(int x, int y, int m0) {
	ivec2 c = cell_at(x, y);
	return pri[mat_of[c.x]] < pri[m0] && c.y != 1 && c.y != 3;
}

uint thash(int tx, int ty) {
	uint h = (uint(tx) * 0x8DA6B343u) ^ (uint(ty) * 0xD8163841u);
	h ^= h >> 13u;
	h *= 0x85EBCA6Bu;
	h ^= h >> 16u;
	return h;
}

void fragment() {
	int X = origin.x * 32 + int(floor(lp.x));
	int Y = origin.y * 32 + int(floor(lp.y));
	int tx = X >> 5;
	int ty = Y >> 5;
	int fx = X & 31;
	int fy = Y & 31;
	ivec2 own = cell_at(tx, ty);
	int m0 = mat_of[own.x];
	bool hard0 = hard[m0] == 1;

	int ax = (X - 16) >> 5;
	int ay = (Y - 16) >> 5;
	int u = (X - 16) - ax * 32;
	int v = (Y - 16) - ay * 32;
	int wx1 = 2 * u + 1;
	int wy1 = 2 * v + 1;
	int wx0 = 64 - wx1;
	int wy0 = 64 - wy1;
	int mats[4];
	int ws[4];
	ivec2 cxy[4] = ivec2[](ivec2(ax, ay), ivec2(ax + 1, ay), ivec2(ax, ay + 1), ivec2(ax + 1, ay + 1));
	ws[0] = wx0 * wy0;
	ws[1] = wx1 * wy0;
	ws[2] = wx0 * wy1;
	ws[3] = wx1 * wy1;
	for (int k = 0; k < 4; k++) {
		ivec2 c = cell_at(cxy[k].x, cxy[k].y);
		mats[k] = (c.y == 1 || c.y == 3) ? m0 : mat_of[c.x]; // 벽·구조물에 덮인 바닥은 섞지 않는다
	}
	int raw[4];
	int sc[4];
	for (int k = 0; k < 4; k++) {
		int mk = mats[k];
		int W = 0;
		for (int j = 0; j < 4; j++) {
			W += mats[j] == mk ? ws[j] : 0;
		}
		int n = 3 * (nz(X + ((mk * 73) & 255), Y + ((mk * 151) & 255)).x - 128);
		raw[k] = 3 * W + spread[mk] * n;
		sc[k] = (hard[mk] == 1 && mk != m0) ? NEG : raw[k];
	}
	int best_s = NEG;
	int best_m = 99;
	int own_s = NEG;
	for (int k = 0; k < 4; k++) {
		if (sc[k] > best_s || (sc[k] == best_s && mats[k] < best_m)) {
			best_s = sc[k];
			best_m = mats[k];
		}
		if (mats[k] == m0) {
			own_s = max(own_s, raw[k]);
		}
	}
	int win_m = hard0 ? m0 : best_m;
	int win_s = hard0 ? own_s : best_s;
	int second = NEG;
	int sec_m = 99;
	for (int k = 0; k < 4; k++) {
		if (mats[k] != win_m && (raw[k] > second || (raw[k] == second && mats[k] < sec_m))) {
			second = raw[k];
			sec_m = mats[k];
		}
	}
	bool dark = false;
	bool deep = false;
	bool curb_on = false;
	int ck = 1;
	if (second != NEG) {
		int margin = win_s - second;
		int pw = pri[win_m];
		int ps = pri[sec_m];
		// 쯔꾸르 오토타일: 위 재질은 테두리, 아래 재질은 (위 재질이 테두리를 가질 때만) 그늘, 같은 높이(실내 이음매)는 그늘
		int band = pw > ps ? rim[win_m] : ((pw == ps || rim[sec_m] > 0) ? shade[win_m] : 0);
		bool both_soft = soft[win_m] == 1 && soft[sec_m] == 1;
		if (both_soft) band = 0;
		dark = band > 0 && margin < band * 768 && curb[win_m] == 0;       // 연석 재질은 연석 띠가 테두리를 대신한다

		if (both_soft && margin < 7680) {                                  // 경계에서 10px 안쪽: 50% → 0% 디더 섞기
			int p_mix = ((7680 - margin) * 128) / 7680;
			int hp = int((thash(X >> 1, Y >> 1) >> 5u) & 255u);
			if (hp < p_mix) win_m = sec_m;
		}
	}
	int fn = cell_at(tx, ty - 1).y;
	if (fn == 1 && fy < 2) deep = true;                                // 벽 발치 그늘(또렷한 2단 띠)
	if (fn == 1 && fy < 5) dark = true;
	if (cell_at(tx - 1, ty).y == 1 && fx < 2) dark = true;
	if (cell_at(tx + 1, ty).y == 1 && fx > 29) dark = true;
	int q0 = (fx - 16) * (fx - 16) * 36 + (fy - 29) * (fy - 29) * 169;   // 소품 그림자 타원(아래 타일로 3px 넘친다)
	int q1 = (fx - 16) * (fx - 16) * 36 + (fy + 3) * (fy + 3) * 169;
	if ((own.y == 2 && q0 <= 6084) || (fn == 2 && q1 <= 6084)) dark = true;

	int cw = curb[m0];
	if (cw > 0 && win_m == m0) {                                          // 연석(1-R v2): 낮은 이웃 타일 쪽 가장자리에서 cw px — 곧은 띠 · 바깥 모서리 네모
		int dd = 99;
		bool lN = low_nb(tx, ty - 1, m0);
		bool lS = low_nb(tx, ty + 1, m0);
		bool lW = low_nb(tx - 1, ty, m0);
		bool lE = low_nb(tx + 1, ty, m0);
		if (lN) dd = min(dd, fy);
		if (lS) dd = min(dd, 31 - fy);
		if (lW) dd = min(dd, fx);
		if (lE) dd = min(dd, 31 - fx);
		if (!lN && !lW && low_nb(tx - 1, ty - 1, m0)) dd = min(dd, max(fx, fy));
		if (!lN && !lE && low_nb(tx + 1, ty - 1, m0)) dd = min(dd, max(31 - fx, fy));
		if (!lS && !lW && low_nb(tx - 1, ty + 1, m0)) dd = min(dd, max(fx, 31 - fy));
		if (!lS && !lE && low_nb(tx + 1, ty + 1, m0)) dd = min(dd, max(31 - fx, 31 - fy));
		if (dd < cw) {
			curb_on = true;
			ck = dd == 0 ? 0 : (dd == cw - 1 ? 3 : (int((thash(X, Y) >> 7u) & 7u) == 0 ? 2 : 1));
		}
	}
	bool walld = deep || (fn == 1 && fy < 5) || (cell_at(tx - 1, ty).y == 1 && fx < 2) || (cell_at(tx + 1, ty).y == 1 && fx > 29)
		|| (own.y == 2 && q0 <= 6084) || (fn == 2 && q1 <= 6084);
	int oxw = (win_m * 73) & 255;
	int oyw = (win_m * 151) & 255;
	int var = nz(X + oxw, Y + oyw).y > vthr[win_m] ? 1 : 0;
	int col = var + (deep ? 4 : (dark ? 2 : 0));
	int bx = boff[win_m * 2] * var;
	int by = boff[win_m * 2 + 1] * var;
	vec4 outc = texelFetch(atlas, ivec2(col * cell + ((X + bx) & (cell - 1)), win_m * cell + ((Y + by) & (cell - 1))), 0);
	if (curb_on) {
		ivec3 cc = curb_rgb[ck + (walld ? 4 : 0)];
		outc = vec4(vec3(cc) / 255.0, 1.0);
	}

	uint h = thash(tx, ty);
	int fo = force[own.x];
	bool has = win_m == m0 && (fo >= 0 || (int(h & 255u) < dens[m0] && dcount[m0] > 0));
	if (has) {
		int di = fo;
		int dox = 0;
		int doy = 0;
		int flip = 0;
		if (fo < 0) {
			di = dlist[m0 * 8 + int((h >> 8u) % uint(max(dcount[m0], 1)))];
			dox = int((h >> 16u) & 7u) - 4;
			doy = int((h >> 19u) & 7u) - 4;
			flip = int((h >> 22u) & 1u);
		}
		int sx = fx - dox;
		int sy = fy - doy;
		if (flip == 1) sx = 31 - sx;
		if (sx >= 0 && sx < 32 && sy >= 0 && sy < 32) {
			vec4 dc = texelFetch(decals, ivec2(di * 32 + sx, sy + ((dark || deep) ? 32 : 0)), 0);
			if (dc.a > 0.5) outc = dc;
		}
	}
	COLOR = vec4(outc.rgb, 1.0);
}
