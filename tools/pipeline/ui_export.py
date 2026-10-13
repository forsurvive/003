"""핍-보이 3000 화면 그림 내보내기 (SD-12 §3.4, SD-16 §4.6·§9.2, 견본 art/samples/07_pipboy_*.png와 같은 그림).
출력 game/assets/ui/:
  pipboy_bezel.png   640×360 기기 틀(녹슨 금속·리벳·방사능계·손잡이·명판). 화면 자리 (40,28) 560×304는 게임이 그린다.
  pipboy_crt.png     560×304 덮개: 짝수 줄 어둡게(×0.85 ≈ 검정 15%), 둥근 모서리 비네트, 지문 얼룩. 화면 내용 위에 얹는다.
  pipboy_figure.png  S-07 주민 그림(볼트 보이 아님) — 선 U6, 부위 막대는 게임이 그린다.
견본 그림(art/tools/pipboy.py)을 고치면 이것도 다시 돌린다(build_data.sh에 들어 있다)."""
import os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import pipboy as PB

OUT = os.path.join(ROOT, "game", "assets", "ui")


def crt_overlay(w=560, h=304):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(0, h, 2):
        for x in range(w):
            px[x, y] = (0, 0, 0, 38)
    vig = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vig).rounded_rectangle([0, 0, w - 1, h - 1], radius=26, fill=255)
    u0 = PB.U(0)
    vp = vig.load()
    for y in range(h):
        for x in range(w):
            if vp[x, y] == 0:
                px[x, y] = u0 + (255,)
    for cx, cy in [(w - 70, h - 50), (w - 64, h - 44)]:              # 지문 얼룩(견본과 같은 자리)
        for x in range(cx - 10, cx + 10, 3):
            y = cy + (x - cx) ** 2 // 30
            if 0 <= x < w and 0 <= y < h and px[x, y][3] < 255:
                px[x, y] = (0, 0, 0, 77)
    return im


def figure():
    s = PB.Screen()
    s.im = Image.new("RGB", (PB.Screen.W, PB.Screen.H), (255, 0, 255))
    s.d = ImageDraw.Draw(s.im)
    s.d.fontmode = "1"
    PB.resident_figure(s, PB.Screen.X0, PB.Screen.Y0, damaged=())
    fig = s.im.crop((0, 0, 80, 92)).convert("RGBA")
    px = fig.load()
    for y in range(fig.height):
        for x in range(fig.width):
            if px[x, y][:3] == (255, 0, 255):
                px[x, y] = (0, 0, 0, 0)
    return fig


def main():
    os.makedirs(OUT, exist_ok=True)
    PB.bezel().convert("RGBA").save(os.path.join(OUT, "pipboy_bezel.png"))
    crt_overlay().save(os.path.join(OUT, "pipboy_crt.png"))
    figure().save(os.path.join(OUT, "pipboy_figure.png"))
    print("UI 그림: 핍-보이 틀·CRT 덮개·주민 그림")


if __name__ == "__main__":
    main()
