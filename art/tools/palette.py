"""SD-16 §4 palettes. Single source of truth for every art script."""

MASTER = [
    "#0B0A0D", "#1A181D", "#2B2830", "#3E3A40", "#555052", "#6E6966", "#8B857D", "#ABA49A", "#CBC5B9", "#E9E4D8",  # P00-P09 ink/neutral
    "#232A33", "#36404B", "#4D5966", "#687584", "#8E9BA8", "#B7C1C8",  # P10-P15 cool grey-blue
    "#2E2219", "#46331F", "#634A2C", "#826439", "#A2824E", "#C4A56E", "#E0C996",  # P16-P22 earth/ochre
    "#3A1A12", "#5C2716", "#85391C", "#AD5426", "#D27A3A",  # P23-P27 rust
    "#262A18", "#3D4324", "#5A6132", "#7E8448", "#A5A86A",  # P28-P32 olive
    "#14262A", "#1F3D40", "#2F5A58", "#4A7C74", "#79A79A",  # P33-P37 water
    "#3B2220", "#6B3D30", "#9C6248", "#C98E6C", "#EBBE98",  # P38-P42 skin S3
    "#142445", "#1F3A6E", "#2E569C", "#4C7DC8",  # P43-P46 vault blue
    "#6E4E10", "#B08A1C", "#E8C23A", "#FFEC9A",  # P47-P50 vault yellow
    "#3D0E12", "#6E1A1E", "#A82A26", "#E04A35",  # P51-P54 warning red
    "#2F7A1A", "#7CD62B", "#D4FF6A",  # P55-P57 radiation
    "#6A3A08", "#C47A12", "#FFC24A",  # P58-P60 amber
    "#0E4A52", "#1F9AA6", "#7FF0E8",  # P61-P63 teal
]
assert len(MASTER) == 64

NAMED = {f"P{i:02d}": c for i, c in enumerate(MASTER)}

SKIN = {
    "S1": ["#4A2A2A", "#7E4C42", "#B47E68", "#E0AE90", "#F8D8BE"],
    "S2": ["#45261F", "#7A4632", "#AE7452", "#D9A07A", "#F2C9A4"],
    "S3": ["#3B2220", "#6B3D30", "#9C6248", "#C98E6C", "#EBBE98"],
    "S4": ["#34201A", "#5E3626", "#8A563A", "#B47A54", "#D9A27A"],
    "S5": ["#26160F", "#46281B", "#6C4029", "#925C3C", "#B98060"],
    "S6": ["#1A0F0B", "#33201A", "#52321F", "#744A31", "#98694A"],
    "SG1": ["#2E2418", "#4F4230", "#77684A", "#A09270", "#C8BE98"],
    "SG2": ["#26261A", "#44462C", "#6A6C44", "#908F60", "#B4B07E"],
}
HAIR = {
    "H1": ["#0F0D10", "#1E1A1F", "#332C33", "#4A4048"],
    "H2": ["#1C120D", "#352218", "#553624", "#7A5034"],
    "H3": ["#3A2414", "#63401F", "#8E6230", "#B88A4C"],
    "H4": ["#3A3A3E", "#66666A", "#9A9A9C", "#CACAC8"],
    "H5": ["#6E6E70", "#A2A2A2", "#CFCFCC", "#F0F0EC"],
    "H6": ["#6A5020", "#A08038", "#CCAE60", "#EED896"],
    "H7": ["#3E1410", "#6E2418", "#9C3A22", "#C85E36"],
    "H8": ["#0E2A30", "#1A4A52", "#2C7480", "#4FA6AE"],
}
REGION = {
    "R01": ["#D8D4CC", "#4F5A3A", "#5E7A8C", "#C46A4A"],
    "R02": ["#B8913A", "#5F8C7C", "#F2B866", "#6A5A78"],
    "R03": ["#6B5E3E", "#9AA05A", "#A9B0B4", "#BFE6FF"],
    "R04": ["#3F8FA0", "#6FAE5C", "#D6D9CF", "#2C5E6E"],
    "R05": ["#9A9488", "#2A2F45", "#5C3F2E", "#FF8A1E"],
    "R06": ["#55603A", "#C8C0A8", "#8C3B32", "#3A4A6A"],
    "R07": ["#F05A9A", "#8E1F55", "#C7D3DC", "#2D3B4E"],
    "R08": ["#E07A2A", "#5E6B3A", "#8FA3A0", "#B3423A"],
    "R09": ["#E6EAF0", "#7A2E22", "#2E3A2A", "#9AA3A8"],
    "R10": ["#B7C24A", "#3A3A36", "#D9C27A", "#6E8F2A"],
    "R11": ["#1C2230", "#C9A43A", "#7A8A96", "#4A1E28"],
}
UI_GREEN = ["#050A06", "#0B1F10", "#123A1C", "#1C5E2C", "#2D8C42", "#46C25E", "#7CF08E", "#D2FFD8"]
UI_AMBER = ["#0D0702", "#2A1604", "#4A2A06", "#7A4A0C", "#B06E12", "#E09A1E", "#FFC24A", "#FFE9B0"]

PF = {  # faction swap: main 1-4, accent 1-2 (SD-16 §4.5)
    "PF-01": ["#1C2230", "#2A3346", "#3E4A62", "#5A6A86", NAMED["P48"], NAMED["P49"]],
    "PF-11": [NAMED["P43"], NAMED["P44"], NAMED["P45"], NAMED["P46"], NAMED["P48"], NAMED["P49"]],
    "PF-12": [NAMED["P17"], NAMED["P18"], NAMED["P19"], NAMED["P20"], NAMED["P27"], NAMED["P45"]],
}


def resolve(token):
    """Color token -> '#RRGGBB'. Accepts P00..P63, U0..U7, A0..A7, S3.2, H1.3, R01.a, PF-01.0, #hex."""
    if token.startswith("#"):
        return token.upper()
    if token in NAMED:
        return NAMED[token]
    if len(token) == 2 and token[0] in "UA" and token[1].isdigit():
        return (UI_GREEN if token[0] == "U" else UI_AMBER)[int(token[1])]
    if "." in token:
        fam, idx = token.split(".")
        if fam in SKIN:
            return SKIN[fam][int(idx) - 1]
        if fam in HAIR:
            return HAIR[fam][int(idx) - 1]
        if fam in REGION:
            return REGION[fam]["abcd".index(idx)]
        if fam in PF:
            return PF[fam][int(idx)]
    raise KeyError(token)


def rgb(token):
    h = resolve(token)
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def allowed_set(*families):
    """Set of RGB tuples allowed for an asset class (SD-16 §13.5)."""
    out = {rgb(f"P{i:02d}") for i in range(64)}
    for fam in families:
        if fam in SKIN:
            out |= {rgb(c) for c in SKIN[fam]}
        elif fam in HAIR:
            out |= {rgb(c) for c in HAIR[fam]}
        elif fam in REGION:
            out |= {rgb(c) for c in REGION[fam]}
        elif fam == "UI":
            out |= {rgb(c) for c in UI_GREEN + UI_AMBER}
        elif fam in PF:
            out |= {rgb(c) for c in PF[fam]}
    return out
