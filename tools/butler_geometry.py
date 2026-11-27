"""The butler mark's node-and-edge mesh: the single source of truth for its geometry.

`tools/generate_icons.py` draws the SVG design files and app icons from it, and
`tools/generate_icons.py --swift` prints the matching `ButlerGeometry` tables for
Packages/GGSBrand/Sources/GGSBrand/ButlerMark.swift. Change the numbers here, then run
`python3 tools/generate_icons.py` and paste the --swift output into ButlerMark.swift.

Coordinates are in a 1024 × 1024 design space. Tones: "g" brass/gold, "t" teal, "s" slate.

The figure: a butler seen from the front, head slightly turned, bow tie at the collar,
tailcoat lapels meeting at a button, his right arm raised and bent so the hand carries a
silver tray at shoulder height with a domed cloche (food cover) on it.
"""

# (x, y, tone, radius)
NODES = [
    # Head 0–6: crown, temples, cheeks, chin, centre
    (430, 252, "t", 17), (376, 282, "t", 17), (484, 282, "t", 17),
    (380, 346, "t", 17), (480, 346, "t", 17), (430, 380, "t", 17), (430, 314, "s", 18),
    # Bow tie 7–11: left wings, right wings, knot
    (384, 420, "g", 15), (384, 462, "g", 15), (476, 420, "g", 15), (476, 462, "g", 15), (430, 441, "g", 21),
    # Shoulders and tailcoat 12–18: left shoulder, right shoulder, lapel button, left hip,
    # right hip, left tail, right tail
    (322, 478, "s", 17), (538, 478, "s", 17), (430, 560, "t", 19),
    (344, 626, "s", 17), (516, 626, "s", 17), (332, 716, "s", 17), (528, 716, "s", 17),
    # Raised right arm 19–20: elbow, hand under the tray
    (624, 540, "s", 17), (690, 476, "t", 17),
    # Left arm folded at the waist, napkin over the forearm 21–22: elbow, hand
    (290, 572, "s", 17), (394, 606, "s", 15),
    # Tray 23–25: left rim, centre, right rim
    (584, 448, "g", 17), (690, 448, "g", 17), (796, 448, "g", 17),
    # Cloche dome 26–32 (left foot … right foot), 33 handle
    (612, 448, "g", 13), (622, 409, "g", 15), (651, 380, "g", 15), (690, 370, "g", 15),
    (729, 380, "g", 15), (758, 409, "g", 15), (768, 448, "g", 13),
    (690, 336, "g", 19),
]

# (from, to, tone)
EDGES = [
    # Head ring and spokes
    (0, 1, "t"), (0, 2, "t"), (1, 3, "t"), (2, 4, "t"), (3, 5, "t"), (4, 5, "t"),
    (6, 0, "s"), (6, 3, "s"), (6, 4, "s"), (6, 5, "s"),
    # Neck to the bow tie knot
    (5, 11, "g"),
    # Bow tie: two triangles meeting at the knot
    (7, 8, "g"), (7, 11, "g"), (8, 11, "g"), (9, 10, "g"), (9, 11, "g"), (10, 11, "g"),
    # Collar to shoulders
    (7, 12, "s"), (9, 13, "s"),
    # Lapels: from the collar down to the button
    (8, 14, "t"), (10, 14, "t"), (12, 14, "s"), (13, 14, "s"),
    # Coat body
    (12, 15, "s"), (13, 16, "s"), (14, 15, "s"), (14, 16, "s"), (15, 16, "s"),
    # Tails
    (15, 17, "s"), (16, 18, "s"), (14, 17, "s"), (14, 18, "s"),
    # Raised arm: shoulder, elbow, hand, tray centre
    (13, 19, "s"), (19, 20, "t"), (20, 24, "t"),
    # Folded arm
    (12, 21, "s"), (21, 22, "s"),
    # Tray
    (23, 26, "g"), (26, 24, "g"), (24, 32, "g"), (32, 25, "g"),
    # Cloche dome, its mesh spokes, and the handle
    (26, 27, "g"), (27, 28, "g"), (28, 29, "g"), (29, 30, "g"), (30, 31, "g"), (31, 32, "g"),
    (24, 28, "g"), (24, 29, "g"), (24, 30, "g"), (29, 33, "g"),
]

LINE_WIDTH = 9


def bounds(pad=0):
    """(x, y, width, height) of the nodes including their radius."""
    xs0 = min(x - r for x, _, _, r in NODES)
    ys0 = min(y - r for _, y, _, r in NODES)
    xs1 = max(x + r for x, _, _, r in NODES)
    ys1 = max(y + r for _, y, _, r in NODES)
    return (xs0 - pad, ys0 - pad, xs1 - xs0 + 2 * pad, ys1 - ys0 + 2 * pad)
