"""단계 S 산출물: 기준 샘플 비교 시트 1장 (SD-19 §5.1). 14종을 한 화면에, 모두 1× 실제 크기 잘라내기로 놓는다
(확대 출력은 같은 배율로 줄여 1×로 되돌린다). 1280×720 = 320×180 칸 4×4.
Writes samples/00_reference_compare.png."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))

ROOT = os.path.dirname(os.path.dirname(__file__))
S = os.path.join(ROOT, "samples")
CW, CH = 320, 180
# (label, file, scale of the file, crop box at 1x)
CELLS = [
    ("1 팔레트", "01_palette_sheet.png", 1, (0, 14, 320, 194)),
    ("2 S-07 실내", "11_scene_s07.png", 1, (100, 60, 420, 240)),
    ("3 관악·봉천 외부", "05_scene_bongcheon.png", 1, (160, 90, 480, 270)),
    ("4 주인공 몸 (걷기)", "04_pc_walk_sheet.png", 1, (0, 0, 320, 180)),
    ("5 몸통 4계열", "12_outfits_idle_x4.png", 4, (0, 0, 320, 180)),
    ("6 머리 3슬롯", "13_heads_x6.png", 6, (0, 8, 320, 188)),
    ("7 무기", "14_weapons_x4.png", 4, (0, 0, 320, 180)),
    ("8 크리처", "15_creatures_x3.png", 3, (0, 0, 320, 168)),
    ("9 NPC", "16_npcs_lineup_x4.png", 4, [(0, 0, 320, 92), (320, 0, 640, 92)]),
    ("10 초상화", "17_portraits_unique_x3.png", 3, (110, 0, 430, 180)),
    ("11 UI (대화창)", "18_ui_dialogue.png", 1, (0, 172, 320, 352)),
    ("12 이펙트", "19_fx_sheet_x4.png", 4, (0, 0, 320, 180)),
    ("13 픽처 (키 아트)", "09_keyart_first_seoul.png", 1, (160, 60, 480, 240)),
    ("13 출생 장면 (인게임 컷신)", "21_scene_birth.png", 1, (160, 40, 480, 220)),
    ("14 간판 (봉천 상가)", "20_signs_bongcheon.png", 1, (0, 40, 320, 220)),
    ("14 간판 (S-07 표어)", "20_signs_s07.png", 1, (0, 0, 320, 172)),
]


def main():
    sheet = Image.new("RGB", (CW * 4, CH * 4), (20, 18, 22))
    F = ImageFont.truetype(os.path.join(ROOT, "fonts/Galmuri9.ttf"), 10)
    d = ImageDraw.Draw(sheet); d.fontmode = "1"
    for i, (label, fn, k, box) in enumerate(CELLS):
        im = Image.open(os.path.join(S, fn)).convert("RGB")
        if k > 1:
            im = im.resize((im.width // k, im.height // k), Image.NEAREST)
        cx, cy = (i % 4) * CW, (i // 4) * CH
        boxes = box if isinstance(box, list) else [box]
        y = cy
        for b in boxes:
            part = im.crop(b)
            sheet.paste(part, (cx, y))
            y += part.height
        tw = int(d.textlength(label, font=F))
        d.rectangle([cx, cy, cx + tw + 7, cy + 13], fill=(11, 10, 13))
        d.text((cx + 4, cy + 1), label, font=F, fill=(232, 194, 58))
        d.rectangle([cx, cy, cx + CW - 1, cy + CH - 1], outline=(43, 40, 48))
    sheet.save(os.path.join(S, "00_reference_compare.png"))


if __name__ == "__main__":
    main()
