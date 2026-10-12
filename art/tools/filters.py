"""SD-16 §4.7 상황 필터 미리보기 (단계 S 완료 기준: 밤·비·방사능 3종을 걸어도 인물·적·바닥 경계가 판독되는지).
필터는 엔진의 화면 색조(셰이더)라서 결과 색은 팔레트 밖이 정상이다. 원본 에셋은 팔레트를 지키고, 이 미리보기만 예외다.
색조 [R, G, B, 회색]: 회색 g/255만큼 휘도로 섞은 뒤 RGB를 더한다(겹치면 합산, 회색 합 120 제한).
덧씌우기: 밤 = 광원 레이어(§10.6 빛 원판 4단계, 백열 P50) 가산, 비 = 빗줄기 2층, 방사능 = P55 곱하기 비네트(+강: 가로 노이즈 줄).
Writes samples/22_filters_bongcheon.png (1× 3×2), 22_filters_bongcheon_x2.png (crop)."""
import os, sys, random, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import palette as P

ROOT = os.path.dirname(os.path.dirname(__file__))
W, H = 640, 360
TONES = {"낮": (0, 0, 0, 0), "밤": (-70, -55, -20, 40), "비": (-25, -15, 0, 40),
         "방사능 경계": (-10, 15, -15, 30), "방사능 위험": (-30, 40, -35, 80)}


def tone(img, parts):
    r = sum(TONES[p][0] for p in parts); g = sum(TONES[p][1] for p in parts); b = sum(TONES[p][2] for p in parts)
    gray = min(120, sum(TONES[p][3] for p in parts))
    out = img.convert("RGB").copy()
    px = out.load()
    for y in range(H):
        for x in range(W):
            R, G, B = px[x, y]
            L = (R * 299 + G * 587 + B * 114) / 1000
            k = gray / 255
            R, G, B = R + (L - R) * k + r, G + (L - G) * k + g, B + (L - B) * k + b
            px[x, y] = (max(0, min(255, int(R))), max(0, min(255, int(G))), max(0, min(255, int(B))))
    return out


LIGHT_SRC = {P.rgb(t) for t in ("P50", "P49", "P60", "P59")}


def light_layer(day, out):
    """additive light discs (§10.6: 64px radial, 4 steps) centred on clusters of lit pixels in the day frame."""
    px = day.convert("RGB").load()
    seen, centres = set(), []
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            if px[x, y] in LIGHT_SRC and (x // 24, y // 24) not in seen:
                seen.add((x // 24, y // 24))
                centres.append((x, y))
    o = out.load()
    warm = P.rgb("P50")
    for cx, cy in centres[:40]:
        for y in range(max(0, cy - 32), min(H, cy + 32)):
            for x in range(max(0, cx - 32), min(W, cx + 32)):
                d = math.hypot(x - cx, y - cy) / 32
                if d >= 1:
                    continue
                step = (4 - int(d * 4)) / 4 * 0.22                       # 4 radial steps
                R, G, B = o[x, y]
                o[x, y] = (min(255, int(R + warm[0] * step)), min(255, int(G + warm[1] * step)), min(255, int(B + warm[2] * step)))
    return out


def rain(out, seed=3):
    """two streak layers: far (short, dim, steep) and near (longer, brighter); splash dots on the ground band."""
    rnd = random.Random(seed)
    d = ImageDraw.Draw(out)
    far, near = P.rgb("P13"), P.rgb("P15")
    for _ in range(420):
        x, y = rnd.randrange(W + 40) - 20, rnd.randrange(H)
        d.line([x, y, x - 2, y + 6], fill=far)
    for _ in range(140):
        x, y = rnd.randrange(W + 60) - 30, rnd.randrange(H)
        d.line([x, y, x - 4, y + 12], fill=near)
    for _ in range(90):
        x, y = rnd.randrange(W), rnd.randrange(H // 2, H)
        d.point((x, y), fill=near); d.point((x - 1, y + 1), fill=far); d.point((x + 1, y + 1), fill=far)
    return out


def rad(out, strength, seed=9):
    """green vignette (P55 multiply at the edges) + for the strong state 2-4 horizontal 1px noise lines."""
    g = P.rgb("P55")
    o = out.load()
    for y in range(H):
        for x in range(W):
            e = math.hypot((x - W / 2) / (W / 2), (y - H / 2) / (H / 2))
            a = max(0.0, min(1.0, (e - 0.55) / 0.6)) * strength
            if a > 0:
                R, G, B = o[x, y]
                o[x, y] = (int(R * (1 - a) + R * g[0] / 255 * a), int(G * (1 - a) + G * g[1] / 255 * a),
                           int(B * (1 - a) + B * g[2] / 255 * a))
    if strength >= 0.4:
        rnd = random.Random(seed)
        for _ in range(rnd.randint(2, 4)):
            y = rnd.randrange(H)
            x0 = rnd.randrange(W // 2)
            for x in range(x0, min(W, x0 + rnd.randint(120, 400))):
                R, G, B = o[x, y]
                o[x, y] = (min(255, R + 40), min(255, G + 60), min(255, B + 40)) if (x // 3) % 2 else (R // 2, G // 2, B // 2)
    return out


def variants(day):
    out = []
    out.append(("1 낮", day.convert("RGB")))
    n = light_layer(day, tone(day, ["밤"]))
    out.append(("4 밤 (+광원 레이어)", n))
    out.append(("6 비", rain(tone(day, ["비"]))))
    out.append(("9 방사능 경계", rad(tone(day, ["방사능 경계"]), 0.2)))
    out.append(("10 방사능 위험", rad(tone(day, ["방사능 위험"]), 0.4)))
    combo = rad(rain(light_layer(day, tone(day, ["밤", "비", "방사능 경계"]))), 0.2)
    out.append(("겹침: 밤 + 비 + 방사능 경계", combo))
    return out


def main():
    import scene_bongcheon as SB
    day = SB.build(hud=False).convert("RGBA")
    vs = variants(day)
    F = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri11-Bold.ttf"), 12)
    sheet = Image.new("RGB", (W * 3, H * 2), (0, 0, 0))
    for i, (name, im) in enumerate(vs):
        x, y = (i % 3) * W, (i // 3) * H
        sheet.paste(im, (x, y))
        d = ImageDraw.Draw(sheet); d.fontmode = "1"
        d.rectangle([x + 4, y + 4, x + 12 + int(d.textlength(name, font=F)), y + 20], fill=(0, 0, 0))
        d.text((x + 8, y + 5), name, font=F, fill=(233, 228, 216))
    out = os.path.join(ROOT, "samples")
    sheet.save(os.path.join(out, "22_filters_bongcheon.png"))
    crop = Image.new("RGB", (W, H), (0, 0, 0))                      # x2 detail of the 4 key states, centre quarter
    for i, k in enumerate((1, 2, 4, 5)):
        im = vs[k][1].crop((W // 4, H // 4, W * 3 // 4, H * 3 // 4))
        crop.paste(im, ((i % 2) * W // 2, (i // 2) * H // 2))
    crop.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(out, "22_filters_bongcheon_x2.png"))
    print("filters:", [n for n, _ in vs])


if __name__ == "__main__":
    main()
