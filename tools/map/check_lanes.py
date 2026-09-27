"""Check that sea lanes stay on water, using the rendered map image.

Usage: python tools/map/check_lanes.py
Samples every lane every km; reports samples on land that are farther than HARBOUR_KM from a city
(harbours sit up rivers or inside archipelagos, so the last stretch may cross land). River lanes
("rivers" in data/sea_lanes.json) are exempt: rivers are narrower than the map shows reliably, so
they are drawn in blue and checked by eye. The same check runs in the test suite
(tests/unit/test_sea_lanes.gd); this script prints details and an overlay.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
KM_PER_DEGREE = 111.2
HARBOUR_KM = 30.0


def main():
    config = json.loads((ROOT / "data/map.json").read_text(encoding="utf-8"))
    lanes = json.loads((ROOT / "data/sea_lanes.json").read_text(encoding="utf-8"))
    cities = json.loads((ROOT / "data/cities.json").read_text(encoding="utf-8"))
    terrain = Image.open(ROOT / config["image"].removeprefix("res://")).convert("RGB")
    image = terrain.copy()  # overlay drawn here; samples always come from the untouched terrain
    cos_ref = math.cos(math.radians(config["reference_lat"]))
    width_km = (config["east_lon"] - config["west_lon"]) * KM_PER_DEGREE * cos_ref
    px_per_km = terrain.size[0] / width_km

    def km(lon, lat):
        return ((lon - config["west_lon"]) * KM_PER_DEGREE * cos_ref, (config["north_lat"] - lat) * KM_PER_DEGREE)

    nodes = {c["id"]: km(*c["coordinates"]) for c in cities}
    city_points = list(nodes.values())
    nodes.update({w["id"]: km(*w["coordinates"]) for w in lanes["waypoints"]})
    overlay = ImageDraw.Draw(image)
    bad = 0
    for a, b in lanes.get("rivers", []):
        (ax, ay), (bx, by) = nodes[a], nodes[b]
        overlay.line([(ax * px_per_km, ay * px_per_km), (bx * px_per_km, by * px_per_km)], fill=(90, 160, 255), width=3)
    for a, b in lanes["lanes"]:
        (ax, ay), (bx, by) = nodes[a], nodes[b]
        length = math.hypot(bx - ax, by - ay)
        on_land = 0
        for i in range(int(length) + 1):
            t = i / max(length, 1)
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t
            if min(math.hypot(x - cx, y - cy) for cx, cy in city_points) <= HARBOUR_KM:
                continue
            r, g, b_ = terrain.getpixel((int(x * px_per_km), int(y * px_per_km)))
            if r > b_:
                on_land += 1
        colour = (255, 60, 60) if on_land else (255, 255, 255)
        overlay.line([(ax * px_per_km, ay * px_per_km), (bx * px_per_km, by * px_per_km)], fill=colour, width=3)
        if on_land:
            bad += 1
            print(f"{a} -> {b}: {on_land} km on land")
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "lanes_overlay.png"
    image.save(out)
    print(f"{bad} lanes cross land; overlay written to {out}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
