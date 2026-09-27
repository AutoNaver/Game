# Map assets

`baltic.png` is generated. Don't edit it by hand. To regenerate it after changing `data/map.json`:

```bash
python tools/map/render_map.py path/to/ne_10m_land.geojson path/to/ne_10m_lakes.geojson
```

Lakes are drawn as water, and the river lanes in `data/sea_lanes.json` (`rivers`) as narrow
waterways, so re-render after changing them.

After moving waypoints in `data/sea_lanes.json`, check that no lane crosses land. The script also
writes an overlay image:

```bash
python tools/map/check_lanes.py lanes_overlay.png
```

River lanes are drawn in blue on the overlay and exempt from the land check. Check them by eye.

Data: [Natural Earth](https://www.naturalearthdata.com/) `ne_10m_land` and `ne_10m_lakes` (public
domain), from github.com/nvkelso/natural-earth-vector (`geojson/`). The raw data isn't committed.
