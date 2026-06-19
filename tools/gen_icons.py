#!/usr/bin/env python3
"""
Nex Remote — app icon / adaptive icon / TV banner generator.

Design: a directional D-pad (four teal chevrons in a cross + centre OK button)
encircled by a single orbiting "remap" arrow. Teal gradient glyph on a dark
radial-gradient tile. Matches the app UI (charcoal #121212, tealAccent #64FFDA).

Outputs (relative to nex_remote/android/app/src/main/res):
  mipmap-<d>/ic_launcher.png                legacy square (masked by launcher)
  mipmap-<d>/ic_launcher_round.png          legacy round
  mipmap-<d>/ic_launcher_foreground.png     adaptive foreground (safe-zone)
  mipmap-<d>/ic_launcher_background.png      adaptive background (gradient)
  drawable-xhdpi/tv_banner.png              320x180 Android TV banner
"""

import math
import os
from PIL import Image, ImageDraw

SS = 4  # supersample factor

# ── palette ──────────────────────────────────────────────────────────────────
TEAL_TOP    = (124, 255, 228)   # #7CFFE4
TEAL_BOT    = (24, 217, 192)    # #18D9C0
BG_CENTER   = (30, 44, 44)      # subtle teal-tinted charcoal
BG_EDGE     = (10, 18, 18)      # near-black
GLOW        = (40, 255, 214)    # teal glow


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def radial_bg(size, center=BG_CENTER, edge=BG_EDGE, glow_strength=0.55):
    """Dark radial gradient tile with a soft central teal glow."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    c = (size - 1) / 2.0
    maxd = math.hypot(c, c)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / maxd
            base = lerp(center, edge, min(1.0, d ** 1.15))
            # soft teal glow concentrated in the middle
            g = max(0.0, 1.0 - (d / 0.62)) ** 2 * glow_strength
            base = tuple(min(255, int(base[i] + (GLOW[i] - base[i]) * g * 0.5))
                         for i in range(3))
            px[x, y] = base
    return img


def vgrad(size, top, bot):
    """Vertical gradient RGBA the size of the canvas (used as shape fill)."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        col = lerp(top, bot, y / (size - 1))
        for x in range(size):
            px[x, y] = col
    return img


def rounded_rect_pts(cx, cy, w, h, r, n=8):
    """Polygon points approximating a rounded rectangle centred at (cx, cy)."""
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
    pts = []
    corners = [
        (x1 - r, y1 - r, 0),    # bottom-right
        (x0 + r, y1 - r, 90),   # bottom-left
        (x0 + r, y0 + r, 180),  # top-left
        (x1 - r, y0 + r, 270),  # top-right
    ]
    for ccx, ccy, a0 in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((ccx + r * math.cos(a), ccy + r * math.sin(a)))
    return pts


def chevron(draw, cx, cy, angle_deg, length, width, fill):
    """A bold outward-pointing chevron (arrowhead) centred along `angle`."""
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)      # outward unit
    px, py = -uy, ux                       # perpendicular
    tip = (cx + ux * length, cy + uy * length)
    base_l = (cx - ux * length * 0.15 + px * width, cy - uy * length * 0.15 + py * width)
    base_r = (cx - ux * length * 0.15 - px * width, cy - uy * length * 0.15 - py * width)
    inner  = (cx - ux * length * 0.05, cy - uy * length * 0.05)
    draw.polygon([tip, base_l, inner, base_r], fill=fill)


def draw_symbol(size, outer_r_frac):
    """
    Render the Nex Remote glyph (transparent RGBA).
    `outer_r_frac` = radius of the orbiting remap arrow as a fraction of size,
    letting us shrink the whole mark into an adaptive-icon safe zone.
    """
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2.0
    R = outer_r_frac * S        # orbiting arrow radius

    grad = vgrad(S, TEAL_TOP, TEAL_BOT).convert("RGBA")

    # ── orbiting remap arrow (dim teal, behind the D-pad) ──
    arc_w = int(R * 0.13)
    bbox = [c - R, c - R, c + R, c + R]
    start, end = 130, 360          # ~230° sweep, leaves a gap = motion
    arc_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arc_layer)
    ad.arc(bbox, start, end, fill=(255, 255, 255, 255), width=arc_w)
    # arrowhead at the `end` of the arc
    a_end = math.radians(end)
    hx, hy = c + R * math.cos(a_end), c + R * math.sin(a_end)
    tang = a_end + math.pi / 2     # tangent direction (clockwise flow)
    ah = arc_w * 2.1
    p1 = (hx + ah * math.cos(tang),            hy + ah * math.sin(tang))
    p2 = (hx + ah * math.cos(tang + 2.4),      hy + ah * math.sin(tang + 2.4))
    p3 = (hx + ah * math.cos(tang - 2.4),      hy + ah * math.sin(tang - 2.4))
    ad.polygon([p1, p2, p3], fill=(255, 255, 255, 255))
    tinted = Image.composite(grad, Image.new("RGBA", (S, S), (0, 0, 0, 0)),
                             arc_layer.split()[3])
    tinted.putalpha(Image.eval(arc_layer.split()[3], lambda a: int(a * 0.40)))
    img.alpha_composite(tinted)

    # ── D-pad cross (bright teal gradient) ──
    cross = Image.new("L", (S, S), 0)
    cd = ImageDraw.Draw(cross)
    arm_len = R * 1.18             # tip-to-tip extent of cross
    arm_w   = R * 0.34
    rr      = arm_w * 0.42
    cd.polygon(rounded_rect_pts(c, c, arm_len, arm_w, rr), fill=255)   # horizontal
    cd.polygon(rounded_rect_pts(c, c, arm_w, arm_len, rr), fill=255)   # vertical

    # directional chevrons at the four arm tips
    tip_r = arm_len / 2 * 0.86
    chev_len = arm_w * 0.62
    chev_w = arm_w * 0.46
    for ang in (0, 90, 180, 270):
        ax = c + tip_r * math.cos(math.radians(ang))
        ay = c + tip_r * math.sin(math.radians(ang))
        chevron(cd, ax, ay, ang, chev_len, chev_w, 255)

    cross_rgba = Image.composite(grad, Image.new("RGBA", (S, S), (0, 0, 0, 0)), cross)
    img.alpha_composite(cross_rgba)

    # ── centre OK button: dark hole + teal dot ──
    hole_r = arm_w * 0.62
    d.ellipse([c - hole_r, c - hole_r, c + hole_r, c + hole_r], fill=(12, 20, 20, 255))
    dot_r = arm_w * 0.40
    dot = Image.new("L", (S, S), 0)
    ImageDraw.Draw(dot).ellipse([c - dot_r, c - dot_r, c + dot_r, c + dot_r], fill=255)
    img.alpha_composite(Image.composite(grad, Image.new("RGBA", (S, S), (0, 0, 0, 0)), dot))

    return img.resize((size, size), Image.LANCZOS)


def squircle_mask(size, radius_frac=0.22):
    S = size * SS
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1],
                                        radius=int(S * radius_frac), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def circle_mask(size):
    S = size * SS
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([0, 0, S - 1, S - 1], fill=255)
    return m.resize((size, size), Image.LANCZOS)


def legacy_icon(size, shape="square"):
    bg = radial_bg(size).convert("RGBA")
    sym = draw_symbol(size, outer_r_frac=0.34)
    bg.alpha_composite(sym)
    mask = squircle_mask(size) if shape == "square" else circle_mask(size)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    return out


# ── output plan ──────────────────────────────────────────────────────────────
RES = os.path.join(os.path.dirname(__file__), "..",
                   "nex_remote", "android", "app", "src", "main", "res")
RES = os.path.normpath(RES)

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPT  = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def save(img, *parts):
    path = os.path.join(RES, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, RES))


def main():
    for dens, sz in LEGACY.items():
        save(legacy_icon(sz, "square"), f"mipmap-{dens}", "ic_launcher.png")
        save(legacy_icon(sz, "round"),  f"mipmap-{dens}", "ic_launcher_round.png")

    for dens, sz in ADAPT.items():
        # background: full-bleed gradient
        save(radial_bg(sz).convert("RGBA"), f"mipmap-{dens}", "ic_launcher_background.png")
        # foreground: glyph inside the 66/108 safe zone, transparent elsewhere
        fg = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        fg.alpha_composite(draw_symbol(sz, outer_r_frac=0.235))
        save(fg, f"mipmap-{dens}", "ic_launcher_foreground.png")

    # ── Android TV banner 320x180 ──
    W, H = 320, 180
    banner = radial_bg(max(W, H)).convert("RGBA").crop((0, (max(W, H) - H) // 2,
                                                        W, (max(W, H) - H) // 2 + H))
    # re-render a clean wide gradient instead of a crop artefact
    banner = Image.new("RGB", (W, H))
    bpx = banner.load()
    cx, cy = W * 0.30, H / 2          # glyph sits left-of-centre
    maxd = math.hypot(W, H)
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy) / maxd
            base = lerp(BG_CENTER, BG_EDGE, min(1.0, (d * 1.6) ** 1.1))
            g = max(0.0, 1.0 - d / 0.45) ** 2 * 0.5
            bpx[x, y] = tuple(min(255, int(base[i] + (GLOW[i] - base[i]) * g * 0.45))
                              for i in range(3))
    banner = banner.convert("RGBA")
    gsz = 150
    glyph = draw_symbol(gsz, outer_r_frac=0.40)
    banner.alpha_composite(glyph, (int(cx - gsz / 2), int(cy - gsz / 2)))
    save(banner.convert("RGB").convert("RGBA"), "drawable-xhdpi", "tv_banner.png")

    # ── preview montage ──
    prev = Image.new("RGB", (96 * 3 + 40, 180 + 30), (18, 18, 18))
    prev.paste(legacy_icon(96, "square").convert("RGB"), (10, 10))
    prev.paste(legacy_icon(96, "round").convert("RGB"), (116, 10))
    prev.save(os.path.join(os.path.dirname(__file__), "icon_preview.png"))
    banner.convert("RGB").save(os.path.join(os.path.dirname(__file__), "banner_preview.png"))
    print("wrote previews")


if __name__ == "__main__":
    main()
