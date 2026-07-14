#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    if edge0 == edge1:
        return 1.0 if x >= edge1 else 0.0
    t = clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        round(a[0] + (b[0] - a[0]) * t),
        round(a[1] + (b[1] - a[1]) * t),
        round(a[2] + (b[2] - a[2]) * t),
    )


def blend(dst: tuple[int, int, int], src: tuple[int, int, int], alpha: float) -> tuple[int, int, int]:
    a = clamp(alpha)
    return (
        round(dst[0] * (1.0 - a) + src[0] * a),
        round(dst[1] * (1.0 - a) + src[1] * a),
        round(dst[2] * (1.0 - a) + src[2] * a),
    )


def sd_round_rect(px: float, py: float, cx: float, cy: float, hw: float, hh: float, radius: float) -> float:
    qx = abs(px - cx) - hw + radius
    qy = abs(py - cy) - hh + radius
    ax = max(qx, 0.0)
    ay = max(qy, 0.0)
    outside = math.hypot(ax, ay)
    inside = min(max(qx, qy), 0.0)
    return outside + inside - radius


def rect_alpha(px: float, py: float, x0: float, y0: float, x1: float, y1: float, radius: float = 0.0, aa: float = 1.5) -> float:
    cx = (x0 + x1) * 0.5
    cy = (y0 + y1) * 0.5
    hw = (x1 - x0) * 0.5
    hh = (y1 - y0) * 0.5
    d = sd_round_rect(px, py, cx, cy, hw, hh, radius)
    return 1.0 - smoothstep(-aa, aa, d)


def circle_alpha(px: float, py: float, cx: float, cy: float, r: float, aa: float = 1.5) -> float:
    d = math.hypot(px - cx, py - cy) - r
    return 1.0 - smoothstep(-aa, aa, d)


def segment_distance(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    vx = bx - ax
    vy = by - ay
    wx = px - ax
    wy = py - ay
    vv = vx * vx + vy * vy
    if vv == 0:
        return math.hypot(px - ax, py - ay)
    t = clamp((wx * vx + wy * vy) / vv)
    projx = ax + t * vx
    projy = ay + t * vy
    return math.hypot(px - projx, py - projy)


def line_alpha(px: float, py: float, ax: float, ay: float, bx: float, by: float, width: float, aa: float = 1.5) -> float:
    d = segment_distance(px, py, ax, ay, bx, by) - width * 0.5
    return 1.0 - smoothstep(-aa, aa, d)


def draw_mark(width: int, height: int, include_glow: bool) -> list[list[tuple[int, int, int]]]:
    bg_top = (10, 18, 32)
    bg_bottom = (4, 7, 18)
    panel_top = (31, 20, 60)
    panel_bottom = (11, 18, 32)
    ring = (255, 255, 255)
    accent = (203, 166, 255)
    accent2 = (135, 92, 246)
    line_cyan = (106, 232, 249)
    line_pale = (178, 244, 255)
    node_purple = (192, 132, 252)

    pixels: list[list[tuple[int, int, int]]] = []
    for y in range(height):
        row: list[tuple[int, int, int]] = []
        for x in range(width):
            px = x + 0.5
            py = y + 0.5

            base = mix(bg_top, bg_bottom, py / height)

            # Soft top-left glow.
            if include_glow:
                glow = clamp(1.0 - math.hypot(px - width * 0.22, py - height * 0.16) / (width * 0.7))
                base = blend(base, (68, 49, 117), glow * 0.25)

            inset = width * 0.062
            radius = width * 0.18
            card_a = rect_alpha(px, py, inset, inset, width - inset, height - inset, radius)
            panel_fill = mix(panel_top, panel_bottom, py / height)
            base = blend(base, panel_fill, card_a)

            # Inner ring.
            outer = rect_alpha(px, py, inset + 1, inset + 1, width - inset - 1, height - inset - 1, radius - 1.0, aa=1.2)
            inner = rect_alpha(px, py, inset + width * 0.01, inset + width * 0.01, width - inset - width * 0.01, height - inset - width * 0.01, radius - width * 0.01, aa=1.2)
            border = max(outer - inner, 0.0)
            base = blend(base, ring, border * 0.14)

            # Stylized "E" using rounded rectangles.
            left = width * 0.25
            top = height * 0.2
            right = width * 0.75
            bottom = height * 0.8
            arm_h = height * 0.09
            spine_w = width * 0.12
            mid_y = height * 0.47

            e_alpha = 0.0
            e_alpha = max(e_alpha, rect_alpha(px, py, left, top, left + spine_w, bottom, width * 0.025))
            e_alpha = max(e_alpha, rect_alpha(px, py, left, top, right * 0.97, top + arm_h, width * 0.025))
            e_alpha = max(e_alpha, rect_alpha(px, py, left, mid_y - arm_h * 0.5, width * 0.64, mid_y + arm_h * 0.5, width * 0.025))
            e_alpha = max(e_alpha, rect_alpha(px, py, left, bottom - arm_h, right, bottom, width * 0.025))
            e_fill = mix(accent, accent2, (px - left) / max(right - left, 1.0))
            base = blend(base, e_fill, e_alpha)

            # Trend line and nodes.
            a = (width * 0.25, height * 0.68)
            b = (width * 0.50, height * 0.675)
            c = (width * 0.73, height * 0.60)
            line_w = width * 0.036
            l1 = line_alpha(px, py, *a, *b, line_w)
            l2 = line_alpha(px, py, *b, *c, line_w)
            line_a = max(l1, l2)
            line_fill = mix(line_cyan, line_pale, (px - a[0]) / max(c[0] - a[0], 1.0))
            base = blend(base, line_fill, line_a)

            n1 = circle_alpha(px, py, a[0], a[1], width * 0.042)
            n2 = circle_alpha(px, py, b[0], b[1], width * 0.042)
            n3 = circle_alpha(px, py, c[0], c[1], width * 0.042)
            base = blend(base, line_cyan, n1)
            base = blend(base, node_purple, n2)
            base = blend(base, line_pale, n3)

            # Small gloss.
            if include_glow:
                gloss = circle_alpha(px, py, width * 0.34, height * 0.26, width * 0.16, aa=6.0) * 0.11
                base = blend(base, (255, 255, 255), gloss)

            row.append(base)
        pixels.append(row)
    return pixels


def write_ppm(path: Path, pixels: list[list[tuple[int, int, int]]]) -> None:
    height = len(pixels)
    width = len(pixels[0]) if pixels else 0
    with path.open("w", encoding="ascii") as f:
        f.write(f"P3\n{width} {height}\n255\n")
        for row in pixels:
            f.write(" ".join(f"{r} {g} {b}" for r, g, b in row))
            f.write("\n")


def build_icon_ppm(path: Path) -> None:
    write_ppm(path, draw_mark(1024, 1024, include_glow=True))


def build_splash_ppm(path: Path) -> None:
    width = 2732
    height = 2732
    bg_top = (7, 12, 22)
    bg_bottom = (4, 7, 18)
    card = draw_mark(760, 760, include_glow=True)

    pixels: list[list[tuple[int, int, int]]] = []
    offset_x = (width - 760) // 2
    offset_y = (height - 760) // 2 - 120

    for y in range(height):
        row: list[tuple[int, int, int]] = []
        for x in range(width):
            py = y + 0.5
            base = mix(bg_top, bg_bottom, py / height)

            # Ambient glow around icon.
            glow = clamp(1.0 - math.hypot((x + 0.5) - width * 0.5, (y + 0.5) - height * 0.45) / (width * 0.34))
            base = blend(base, (35, 27, 68), glow * 0.18)

            if offset_x <= x < offset_x + 760 and offset_y <= y < offset_y + 760:
                base = card[y - offset_y][x - offset_x]

            row.append(base)
        pixels.append(row)
    write_ppm(path, pixels)


def main() -> None:
    out_dir = Path("/tmp/edgescore-ios-asset-build")
    out_dir.mkdir(parents=True, exist_ok=True)

    build_icon_ppm(out_dir / "app_icon.ppm")
    build_splash_ppm(out_dir / "splash.ppm")
    print(f"Generated PPM sources in {out_dir}")


if __name__ == "__main__":
    main()
