#!/usr/bin/env python3
"""Generate Pipeestrello-3–inspired bat frames (original art)."""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "enemies", "pipeestrello_3")
SIZE = 36
CX, CY = SIZE // 2, SIZE // 2 + 1


def draw_bat(
	im: Image.Image,
	wing: float,
	scale: float,
	alpha: int,
	tilt_deg: float,
) -> None:
	"""wing: -1..1 flaps wings. tilt_deg: death tumble."""
	draw = ImageDraw.Draw(im)
	s = scale
	a = alpha
	# Combined transform from center
	rad = math.radians(tilt_deg)
	cos_a, sin_a = math.cos(rad), math.sin(rad)

	def tr(x: float, y: float) -> tuple[float, float]:
		dx, dy = (x - CX) * s, (y - CY) * s
		return (CX + dx * cos_a - dy * sin_a, CY + dx * sin_a + dy * cos_a)

	# Wing spread from flap phase
	spread = 0.72 + wing * 0.28
	# Left wing (ellipse)
	wlx, wly = CX - 11 * spread, CY - 1
	draw.polygon(
		[
			tr(wlx - 1, wly),
			tr(wlx - 10, wly - 5),
			tr(wlx - 12, wly + 1),
			tr(wlx - 9, wly + 5),
			tr(CX - 4, CY + 2),
		],
		fill=(38, 24, 52, a),
		outline=(18, 10, 28, min(255, a + 30)),
	)
	# Right wing
	wrx = CX + 11 * spread
	draw.polygon(
		[
			tr(wrx + 1, wly),
			tr(wrx + 10, wly - 5),
			tr(wrx + 12, wly + 1),
			tr(wrx + 9, wly + 5),
			tr(CX + 4, CY + 2),
		],
		fill=(38, 24, 52, a),
		outline=(18, 10, 28, min(255, a + 30)),
	)
	# Body
	draw.ellipse(tr_rect(CX - 5, CY - 7, CX + 5, CY + 5, s, tr), fill=(44, 30, 60, a), outline=(22, 14, 34, min(255, a + 30)))
	# Ears
	draw.polygon([tr(CX - 4, CY - 8), tr(CX - 2, CY - 11), tr(CX, CY - 8)], fill=(44, 30, 60, a))
	draw.polygon([tr(CX, CY - 8), tr(CX + 2, CY - 11), tr(CX + 4, CY - 8)], fill=(44, 30, 60, a))
	# Eyes
	ex, ey = 2.0 * s, 2.5 * s
	draw.ellipse(tr_rect(CX - 4.5, CY - 8, CX - 2.5, CY - 5, s, tr), fill=(230, 45, 60, a))
	draw.ellipse(tr_rect(CX + 2.5, CY - 8, CX + 4.5, CY - 5, s, tr), fill=(230, 45, 60, a))
	draw.rectangle(tr_rect(CX - 4, CY - 8.2, CX - 3, CY - 7, s, tr), fill=(255, 200, 210, a))
	draw.rectangle(tr_rect(CX + 3, CY - 8.2, CX + 4, CY - 7, s, tr), fill=(255, 200, 210, a))


def tr_rect(x0: float, y0: float, x1: float, y1: float, s: float, tr) -> tuple[float, float, float, float]:
	p0 = tr(x0, y0)
	p1 = tr(x1, y1)
	return (min(p0[0], p1[0]), min(p0[1], p1[1]), max(p0[0], p1[0]), max(p0[1], p1[1]))


def frame(wing: float, scale: float, alpha: int, tilt_deg: float) -> Image.Image:
	im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
	draw_bat(im, wing, scale, alpha, tilt_deg)
	return im


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	phases = [-0.85, -0.15, 0.8, 0.0]
	for i, ph in enumerate(phases):
		frame(ph, 1.0, 255, 0.0).save(os.path.join(OUT, "fly_%02d.png" % i))
	death = [
		(0.0, 1.0, 255, 10.0),
		(0.35, 0.9, 220, 25.0),
		(0.6, 0.75, 160, 48.0),
		(0.85, 0.58, 90, 68.0),
		(0.95, 0.42, 35, 85.0),
	]
	for i, (w, sc, a, tilt) in enumerate(death):
		frame(w, sc, a, tilt).save(os.path.join(OUT, "death_%02d.png" % i))
	print("Wrote PNGs to", OUT)


if __name__ == "__main__":
	main()
