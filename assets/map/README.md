# Map assets

`baltic.png` is generated. Don't edit it by hand. To regenerate it after changing `data/map.json`:

```bash
python tools/map/render_map.py path/to/ne_10m_land.geojson
```

Coastline data: [Natural Earth](https://www.naturalearthdata.com/) `ne_10m_land` (public domain),
from github.com/nvkelso/natural-earth-vector. The raw data isn't committed.
