#!/usr/bin/env python3
"""Generate ConciergeClock's brand artwork (Design/*.svg) and app icon PNGs.

The butler mesh geometry lives in tools/butler_geometry.py and is mirrored by ButlerGeometry
in Packages/GGSBrand/Sources/GGSBrand/ButlerMark.swift — change both together:

    python3 tools/generate_icons.py           # SVGs + PNGs
    python3 tools/generate_icons.py --swift   # prints the Swift tables for ButlerMark.swift

Run from the repository root. PNG rendering needs Node with Playwright (any recent version) and
Pillow; without them only the SVGs are written. Same approach as PrepPilot's generator.
"""
import json, math, pathlib, subprocess, sys, tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from butler_geometry import NODES, EDGES, LINE_WIDTH, bounds  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DESIGN = ROOT / "Design"
ASSETS = ROOT / "ConciergeClock" / "Assets.xcassets"

# Concierge palette (see docs/DECISIONS.md): brass/gold, teal and the shared Greater Good slate.
BRASS, TEAL, SLATE, SLATE_LIGHT = "#C9A44C", "#1FA3A0", "#5B6B78", "#A9BAC6"
BRASS_ON_DARK, TEAL_ON_DARK = "#D9B65E", "#36C2BC"
NAVY_TOP, NAVY_BOTTOM = "#0D3B5C", "#051A2B"

STANDARD = {"g": BRASS, "t": TEAL, "s": SLATE}
ON_DARK = {"g": BRASS_ON_DARK, "t": TEAL_ON_DARK, "s": SLATE_LIGHT}
TINTED = {"g": "#FFFFFF", "t": "#FFFFFF", "s": "#B8B8B8"}


def mark(colors, line=LINE_WIDTH):
    out = []
    for a, b, tone in EDGES:
        (x1, y1, *_), (x2, y2, *_) = NODES[a], NODES[b]
        out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{colors[tone]}" '
                   f'stroke-width="{line}" stroke-linecap="round"/>')
    for x, y, tone, r in NODES:
        out.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{colors[tone]}"/>')
    return "\n".join(out)


def mark_svg(colors, background=None):
    x, y, w, h = bounds(pad=6)
    bg = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{background}"/>' if background else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" width="{w}" height="{h}">{bg}{mark(colors)}</svg>\n'


def bell(cx, cy, size, color):
    """A concierge service bell: dome, knob and base, centred on (cx, cy)."""
    s = size
    dome = (f'<path d="M {cx - s*0.52:.1f} {cy + s*0.18:.1f} A {s*0.52:.1f} {s*0.50:.1f} 0 0 1 {cx + s*0.52:.1f} {cy + s*0.18:.1f} Z" '
            f'fill="{color}"/>')
    knob = f'<circle cx="{cx:.1f}" cy="{cy - s*0.40:.1f}" r="{s*0.10:.1f}" fill="{color}"/>'
    stem = (f'<line x1="{cx:.1f}" y1="{cy - s*0.36:.1f}" x2="{cx:.1f}" y2="{cy - s*0.28:.1f}" stroke="{color}" '
            f'stroke-width="{s*0.08:.1f}" stroke-linecap="round"/>')
    base = (f'<line x1="{cx - s*0.66:.1f}" y1="{cy + s*0.30:.1f}" x2="{cx + s*0.66:.1f}" y2="{cy + s*0.30:.1f}" '
            f'stroke="{color}" stroke-width="{s*0.13:.1f}" stroke-linecap="round"/>')
    return dome + knob + stem + base


def icon_svg(variant):
    """1024×1024 icon: navy background, track, brass→teal ring ending in the bell badge, butler."""
    cx = cy = 512
    r, width = 370, 44
    end = math.radians(-150)  # badge at about 10 o'clock, like the sibling apps
    ex, ey = cx + r * math.cos(end), cy + r * math.sin(end)
    sx, sy = cx, cy - r
    if variant == "light":
        bg = '<rect width="1024" height="1024" fill="#F4F1EA"/>'
        track, ring, colors = "#E2DCCD", "url(#ring)", STANDARD
        badge = f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="50" fill="{TEAL}" stroke="#F4F1EA" stroke-width="10"/>'
        bell_color = "#FFFFFF"
    elif variant == "tinted":
        bg = '<rect width="1024" height="1024" fill="#000000"/>'
        track, ring, colors = "#3A3A3A", "#FFFFFF", TINTED
        badge = f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="50" fill="#FFFFFF" stroke="#000000" stroke-width="10"/>'
        bell_color = "#000000"
    else:
        top, bottom = (NAVY_TOP, NAVY_BOTTOM) if variant == "dark" else ("#092C46", "#020D17")
        bg = (f'<defs><linearGradient id="bg" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
              f'<stop offset="1" stop-color="{bottom}"/></linearGradient></defs><rect width="1024" height="1024" fill="url(#bg)"/>')
        track, ring, colors = "#FFFFFF24", "url(#ring)", ON_DARK
        badge = f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="50" fill="#FFFFFF" stroke="{bottom}" stroke-width="10"/>'
        bell_color = BRASS
    defs = (f'<defs><linearGradient id="ring" x1="1" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{BRASS_ON_DARK}"/><stop offset="1" stop-color="{TEAL}"/></linearGradient></defs>')
    arc = (f'<path d="M {sx} {sy} A {r} {r} 0 1 1 {ex:.1f} {ey:.1f}" fill="none" stroke="{ring}" '
           f'stroke-width="{width}" stroke-linecap="round"/>')
    track_circle = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{track}" stroke-width="{width}"/>'
    bx, by, bw, bh = bounds()
    scale = 1.02
    tx, ty = cx - (bx + bw / 2) * scale, cy + 6 - (by + bh / 2) * scale
    body = f'<g transform="translate({tx:.1f} {ty:.1f}) scale({scale})">{mark(colors, line=11)}</g>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'{defs}{bg}{track_circle}{arc}{body}{badge}{bell(ex, ey + 4, 58, bell_color)}</svg>\n')


def swift_tables():
    tone = {"g": ".brass", "t": ".teal", "s": ".slate"}
    x, y, w, h = bounds()
    lines = [f"    static let bounds = CGRect(x: {x}, y: {y}, width: {w}, height: {h})", "", "    static let nodes: [Node] = ["]
    for nx, ny, t, r in NODES:
        radius = "" if r == 17 else f", radius: {r}"
        lines.append(f"        Node(x: {nx}, y: {ny}, tone: {tone[t]}{radius}),")
    lines += ["    ]", "", "    static let edges: [Edge] = ["]
    for a, b, t in EDGES:
        lines.append(f"        Edge(from: {a}, to: {b}, tone: {tone[t]}),")
    lines.append("    ]")
    return "\n".join(lines)


def main():
    if "--swift" in sys.argv:
        print(swift_tables())
        return
    DESIGN.mkdir(exist_ok=True)
    (DESIGN / "conciergeclock-mark.svg").write_text(mark_svg(STANDARD))
    (DESIGN / "conciergeclock-mark-on-dark.svg").write_text(mark_svg(ON_DARK, "#0D3B5C"))
    icons = {
        "appicon-dark": ("dark", [ASSETS / "AppIcon.appiconset" / "AppIcon-Dark.png",
                                  ASSETS / "ProductIcon-ConciergeClock.imageset" / "ProductIcon-ConciergeClock.png"]),
        "appicon-dark-appearance": ("darkAppearance", [ASSETS / "AppIcon.appiconset" / "AppIcon-DarkAppearance.png"]),
        "appicon-tinted": ("tinted", [ASSETS / "AppIcon.appiconset" / "AppIcon-Tinted.png"]),
        "appicon-light": ("light", [ASSETS / "AppIcon-Light.appiconset" / "AppIcon-Light.png"]),
    }
    targets = []
    for name, (variant, pngs) in icons.items():
        svg = DESIGN / f"{name}.svg"
        svg.write_text(icon_svg(variant))
        for png in pngs + [DESIGN / f"{name}.png"]:
            targets.append((str(svg), str(png)))
    print("SVGs written to Design/")

    script = """
    const { chromium } = require('playwright');
    const fs = require('fs');
    (async () => {
      const jobs = JSON.parse(process.argv[2]);
      const browser = await chromium.launch();
      const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
      for (const [svg, png] of jobs) {
        await page.setContent('<html><body style="margin:0">' + fs.readFileSync(svg, 'utf8') + '</body></html>');
        await page.screenshot({ path: png, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
      }
      await browser.close();
    })();
    """
    with tempfile.TemporaryDirectory() as tmp:
        js = pathlib.Path(tmp) / "render.js"
        js.write_text(script)
        for _, png in targets:
            pathlib.Path(png).parent.mkdir(parents=True, exist_ok=True)
        try:
            subprocess.run(["node", str(js), json.dumps(targets)], check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            sys.exit(f"PNG rendering skipped ({error}); SVGs are up to date.")
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow missing: PNGs keep an alpha channel, which App Store icons must not have.")
    for _, png in targets:
        image = Image.open(png).convert("RGB")
        if "ProductIcon-" in png:  # "Our apps" list in About Greater Good Software: 180 px like the siblings
            image = image.resize((180, 180), Image.LANCZOS)
        image.save(png)
    print("PNGs written to ConciergeClock/Assets.xcassets and Design/")


if __name__ == "__main__":
    main()
