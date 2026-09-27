# Map assets

`baltic.png` is generated. Don't edit it by hand. To regenerate it after changing `data/map.json`:

```bash
python tools/map/render_map.py path/to/ne_10m_land.geojson
```

After moving waypoints in `data/sea_lanes.json`, check that no lane crosses land. The script also
writes an overlay image:

```bash
python tools/map/check_lanes.py lanes_overlay.png
```

Coastline data: [Natural Earth](https://www.naturalearthdata.com/) `ne_10m_land` (public domain),
from github.com/nvkelso/natural-earth-vector. The raw data isn't committed.
