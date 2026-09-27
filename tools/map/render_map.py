"""Render the Baltic map image from Natural Earth coastline data.

The projection and frame come from data/map.json, the same file the game reads, so city positions
(projected in GameDataLoader / MapDef) line up with the picture exactly.

Usage (needs Pillow and numpy):
    python tools/map/render_map.py path/to/ne_10m_land.geojson

Coastline data: Natural Earth "ne_10m_land" (public domain), https://www.naturalearthdata.com/
The output is written to the image path configured in data/map.json.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
KM_PER_DEGREE = 111.2
PIXELS_PER_KM = 1.75
SUPERSAMPLE = 2

SEA_DEEP = (27, 52, 74)
SEA_SHALLOW = (58, 104, 130)
LAND = (214, 197, 158)
LAND_SHADE = (176, 156, 115)
COAST = (92, 74, 50)
GRID = (255, 255, 255, 22)


def load_map_config():
    return json.loads((ROOT / "data" / "map.json").read_text(encoding="utf-8"))


def projector(config, scale):
    """Returns f(lon, lat) -> (x, y) in pixels, mirroring MapDef.project() in km times scale."""
    cos_ref = math.cos(math.radians(config["reference_lat"]))

    def project(lon, lat):
        x_km = (lon - config["west_lon"]) * KM_PER_DEGREE * cos_ref
        y_km = (config["north_lat"] - lat) * KM_PER_DEGREE
        return (x_km * scale, y_km * scale)

    return project


def frame_size_km(config):
    cos_ref = math.cos(math.radians(config["reference_lat"]))
    width = (config["east_lon"] - config["west_lon"]) * KM_PER_DEGREE * cos_ref
    height = (config["north_lat"] - config["south_lat"]) * KM_PER_DEGREE
    return width, height


def polygons_in_frame(geojson, config, margin_deg=2.0):
    west, east = config["west_lon"] - margin_deg, config["east_lon"] + margin_deg
    south, north = config["south_lat"] - margin_deg, config["north_lat"] + margin_deg
    for feature in geojson["features"]:
        geometry = feature["geometry"]
        polys = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
        for poly in polys:
            outer = poly[0]
            lons = [p[0] for p in outer]
            lats = [p[1] for p in outer]
            if max(lons) < west or min(lons) > east or max(lats) < south or min(lats) > north:
                continue
            yield poly


def render(geojson_path):
    config = load_map_config()
    width_km, height_km = frame_size_km(config)
    scale = PIXELS_PER_KM * SUPERSAMPLE
    size = (round(width_km * scale), round(height_km * scale))
    project = projector(config, scale)

    land_mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(land_mask)
    geojson = json.loads(Path(geojson_path).read_text(encoding="utf-8"))
    for poly in polygons_in_frame(geojson, config):
        draw.polygon([project(lon, lat) for lon, lat in poly[0]], fill=255)
        for hole in poly[1:]:
            draw.polygon([project(lon, lat) for lon, lat in hole], fill=0)

    # Sea: deep colour, lighter near the coast (blurred land mask as a shallow-water band).
    shallow = land_mask.filter(ImageFilter.GaussianBlur(18 * SUPERSAMPLE))
    image = Image.composite(
        Image.new("RGB", size, SEA_SHALLOW), Image.new("RGB", size, SEA_DEEP), shallow
    )

    # Land with a soft darker rim, then a crisp coastline.
    inner = ImageChops.subtract(land_mask, land_mask.filter(ImageFilter.MinFilter(9)))
    inner = inner.filter(ImageFilter.GaussianBlur(4 * SUPERSAMPLE))
    land = Image.composite(Image.new("RGB", size, LAND_SHADE), Image.new("RGB", size, LAND), inner)
    image = Image.composite(land, image, land_mask)
    edges = ImageChops.subtract(land_mask.filter(ImageFilter.MaxFilter(5)), land_mask)
    image = Image.composite(Image.new("RGB", size, COAST), image, edges)

    # Faint graticule every degree.
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    grid = ImageDraw.Draw(overlay)
    for lon in range(math.ceil(config["west_lon"]), math.floor(config["east_lon"]) + 1):
        grid.line([project(lon, config["north_lat"]), project(lon, config["south_lat"])], fill=GRID, width=SUPERSAMPLE)
    for lat in range(math.ceil(config["south_lat"]), math.floor(config["north_lat"]) + 1):
        grid.line([project(config["west_lon"], lat), project(config["east_lon"], lat)], fill=GRID, width=SUPERSAMPLE)
    image = Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")

    image = image.resize((size[0] // SUPERSAMPLE, size[1] // SUPERSAMPLE), Image.LANCZOS)
    out = ROOT / config["image"].removeprefix("res://")
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, optimize=True)
    print(f"wrote {out} ({image.size[0]}x{image.size[1]} px, {width_km:.0f}x{height_km:.0f} km)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    render(sys.argv[1])
