"""종이 기록물 원고(script/notes/*.txt, 1-5) → game/data/notes.json. NoteScreen이 읽는다.
@note ID 제목 / style official|ledger|scrap / head / date / stamp / 본문 줄(빈 줄 = 문단). 표 줄은 '|'로 칸을 나눈다."""
import os, glob, json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "script", "notes")
OUT = os.path.join(ROOT, "game", "data", "notes.json")


def main():
    notes, cur = {}, None
    for path in sorted(glob.glob(os.path.join(SRC, "*.txt"))):
        for ln in open(path, encoding="utf-8").read().split("\n"):
            s = ln.rstrip()
            if s.startswith("#"):
                continue
            if s.startswith("@note "):
                parts = s[6:].split(" ", 1)
                cur = {"id": parts[0], "title": parts[1] if len(parts) > 1 else parts[0], "style": "official", "head": "", "date": "",
                       "stamp": "", "body": []}
                if cur["id"] in notes:
                    raise SystemExit("기록물 ID 겹침: " + cur["id"])
                notes[cur["id"]] = cur
                continue
            if cur is None:
                continue
            key = s.split(" ", 1)[0]
            if key in ("style", "head", "date", "stamp") and not cur["body"]:
                cur[key] = s.split(" ", 1)[1] if " " in s else ""
                if key == "style" and cur[key] not in ("official", "ledger", "scrap"):
                    raise SystemExit(f"{cur['id']}: 모르는 style {cur[key]}")
                continue
            if key == "stamp":
                cur["stamp"] = s.split(" ", 1)[1]
                continue
            cur["body"].append(s)
    for n in notes.values():
        while n["body"] and n["body"][-1] == "":
            n["body"].pop()
    json.dump({"notes": notes}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"기록물: {len(notes)}장 — " + ", ".join(notes))


if __name__ == "__main__":
    main()
