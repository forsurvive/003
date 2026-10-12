"""그림체 비교: 현행(SD-16) 대 아이작풍 샘플.
① 같은 장소(볼트 S-07 정문 앞) 게임 화면 두 장, ② 인물 3종(주인공·보병 계엄병·큰바퀴) 같은 배율 나란히, ③ 아이작풍 방 시연 GIF.
출력: game/reports/style_isaac_compare.png, game/reports/style_isaac_demo.gif
실행: python3 tools/screens/style_compare.py  (Xvfb + godot 필요. 먼저 python3 art/tools/style_isaac.py)"""
import os, sys, glob, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")
OUT = os.path.join(GAME, "reports")
sys.path.insert(0, os.path.join(ROOT, "art", "tools"))
import style_isaac as I

FONT = ImageFont.truetype(os.path.join(ROOT, "art", "fonts", "Galmuri11.ttf"), 12)
BG = (43, 40, 48)


def godot(args, tmp):
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", "godot", "--path", GAME] + args,
                   check=True, capture_output=True, timeout=300)


def cell(sheet, row, col, fw, fh, rows_name=None):
    im = Image.open(os.path.join(GAME, "assets", "sprites", sheet + ".png")).convert("RGBA")
    return im.crop((col * fw, row * fh, col * fw + fw, row * fh + fh))


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        cur = os.path.join(tmp, "cur.png")
        godot(["--", "--cmd=tp L-R01-01; close", f"--shot={cur}"], tmp)
        frames = os.path.join(tmp, "f.png")
        godot(["res://scenes/style/isaac_room.tscn", "--write-movie", frames, "--fixed-fps", "30", "--quit-after", "330", "--", "--demo"], tmp)
        shots = sorted(glob.glob(os.path.join(tmp, "f*.png")))
        cur_im = Image.open(cur).convert("RGB")
        isa_im = Image.open(shots[200]).convert("RGB")
        # GIF: 15fps, 2배
        gif = [Image.open(f).convert("RGB").resize((960, 540), Image.NEAREST).convert("P", palette=Image.ADAPTIVE, colors=128)
               for f in shots[30:330:2]]
        gif[0].save(os.path.join(OUT, "style_isaac_demo.gif"), save_all=True, append_images=gif[1:], duration=66, loop=0)
    # 인물 비교(각 2배)
    pc_now = cell("pc_comp_t01_pf00_loco", 0, 0, 64, 64)
    so_now = cell("pc_comp_t06_pf01_loco", 0, 0, 64, 64)
    ro_now = cell("cr_cr002_base_loco", 0, 0, 32, 32)
    pc_new = I.actor("S", 0, moving=False)
    so_new = I.actor("SE", 0, "soldier", moving=False, gun_kind="rifle")
    ro_new = I.roach(0)
    lineup = Image.new("RGBA", (640, 150), BG + (255,))
    d = ImageDraw.Draw(lineup); d.fontmode = "1"
    x = 12
    for name, a, b in (("주인공", pc_now, pc_new), ("보병 계엄병", so_now, so_new), ("큰바퀴", ro_now, ro_new)):
        d.text((x, 4), name, font=FONT, fill=(232, 194, 58))
        A = a.resize((a.width * 2, a.height * 2), Image.NEAREST)
        B = b.resize((b.width * 2, b.height * 2), Image.NEAREST)
        lineup.alpha_composite(A, (x, 140 - A.height))
        lineup.alpha_composite(B, (x + A.width + 6, 140 - B.height))
        d.text((x, 18), "현행 / 아이작풍", font=FONT, fill=(203, 197, 185))
        x += A.width + B.width + 40
    W = 640 * 2 + 36
    sheet = Image.new("RGB", (W, 24 + 360 + 30 + 150 + 12), BG)
    d = ImageDraw.Draw(sheet); d.fontmode = "1"
    d.text((12, 6), "현행 그림체(SD-16) — 시험 구역 S-07 정문 앞", font=FONT, fill=(233, 228, 216))
    d.text((24 + 640, 6), "아이작풍 샘플 — 같은 장소를 방 하나로", font=FONT, fill=(233, 228, 216))
    sheet.paste(cur_im, (12, 24))
    sheet.paste(isa_im, (24 + 640, 24))
    d.text((12, 24 + 360 + 8), "인물 비교(2배, 왼쪽 현행 · 오른쪽 아이작풍)", font=FONT, fill=(233, 228, 216))
    sheet.paste(lineup.convert("RGB"), (12, 24 + 360 + 26))
    sheet.save(os.path.join(OUT, "style_isaac_compare.png"))
    print("written:", os.path.join(OUT, "style_isaac_compare.png"), os.path.join(OUT, "style_isaac_demo.gif"))


if __name__ == "__main__":
    main()
