# ADR 0012: More of the Baltic

- Status: accepted (owner decisions on the coastline data and Novgorod, 2026-09-27)
- Date: 2026-09-27
- Code: `data/cities.json`, `data/goods.json`, `data/sea_lanes.json`, `data/map.json`,
  `data/rivals.json`, `tools/map/render_map.py`, `tools/map/check_lanes.py`, `sim/defs/sea_chart.gd`,
  `sim/systems/off_map_trade_system.gd`, `sim/save/save_game.gd`, `ui/map_view.gd`

## Context

M11 grows the world from four cities and ten goods to nine cities and fourteen goods: Stralsund,
Riga, Reval, Bergen and Novgorod, and furs, wax, honey and pitch. Bergen lies outside the old map
frame on the North Sea coast. Novgorod lies about 180 km inland, up the Neva, across Lake Ladoga
and up the Volkhov, where no lane stays on open water.

## Decision

- **Map frame** grows to lon 4°–33°, lat 53.2°–61.5°, rendered from Natural Earth `ne_10m_land`
  plus `ne_10m_lakes` (lakes drawn as water; the owner approved downloading both). At zoom 1 the
  whole map now fits the view instead of covering it, and it sits at the top of the map area so
  the spare sea lies under the log panel. City labels flip left at the view's right edge.
- **Sea lanes** for the new cities go around Møn and through the Øresund narrows to the Kattegat,
  around Læsø and Skagen, and up the Norwegian coast to Bergen. Others go around Fårö and through
  the Irbe Strait to Riga, past Hiiumaa to Reval, and south of Kotlin to the Neva mouth. Every
  sea lane passes `tools/map/check_lanes.py` and `test_sea_lanes.gd`.
- **River lanes** (owner decision): `data/sea_lanes.json` gains an optional `rivers` list, sailed
  like any lane at the ship's speed. The renderer draws them as 2.5 km waterways. They are exempt
  from the automatic land check, because rivers are narrower than the map's coastline is
  reliable, and are checked by eye on the overlay instead. The crossing of Lake Ladoga is an
  ordinary lane and must stay on (lake) water.
- **Goods and production.** Furs (luxury, 260), wax (150), honey (80) and pitch (65) are consumed
  everywhere. Novgorod makes furs, wax and honey; Riga some of each plus pitch; Stockholm and Danzig
  also make pitch. The new cities' production brings total output back to about 1.1× total
  consumption for every good, as in the MVP balance: Stralsund beer, grain and fish; Riga and
  Reval grain; Bergen fish.
- **`import_factor`** (optional per city in `data/cities.json`, default 1) multiplies a city's
  off-map imports. It is the cities' own links beyond the map: Bergen 3 (England and the Low
  Countries) and Novgorod 2.5 (the Russian hinterland). Without it both remote cities starved to
  half their population without the player, because the rival houses rarely sail that far.
- **Two more rival houses**, Hildebrand from Riga and Brandes from Stralsund, so the houses still
  cover the larger sea. Three houses over nine cities left even Lübeck and Stockholm short.
- **Saves.** Version 7 marks the larger world. Older saves hold a leading part of today's cities,
  goods and houses. Whatever they lack is added as a new game starts it (cities at home population
  and target stock, goods at target stock in every city, houses with their starting ship), and
  every added unit is booked in the goods ledger. From version 7 a save must cover the whole
  world. A house missing from a current save is still not revived.

## Balance

Five-year soaks without the player (seeds 1, 2, 3 and 7) end every city between 0.87× and 1.11×
its home population: Bergen at about 0.88×, Novgorod 0.91×, Lübeck 0.89× to 0.92×, Riga 1.10×.
`tools/balance.gd` (seeds 1 to 5) is richer on the larger map. The bot has about 12,800 coins
after a month (M10: 11,400; the ADR 0005 target is about 12,000), 33,200 after 90 days and
108,500 after a year (M10: 89,600). The five houses average 234,000 net worth after a year (M10's
three houses: 179,000). More cities and goods mean more spreads to trade, and the early game is
unchanged.

## Consequences

- Long hauls now exist: a cog takes about 6 days from Lübeck to Bergen, Riga or Reval and 9.5 to
  Novgorod, so spoilage (fish, beer) and storms matter more on them. Furs and wax from Novgorod
  are the classic high-value run.
- More event targets. Harvest failures can hit the new grain producers.
- Any later map growth follows the same pattern: append cities and goods to the data files, and
  saves from before grow into the new world.
