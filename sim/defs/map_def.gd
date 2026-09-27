class_name MapDef
extends RefCounted
## The world map frame and projection, loaded from data/map.json.
##
## Map units are kilometres. The projection is equirectangular with longitudes scaled by the
## cosine of reference_lat, origin at the north-west corner of the frame; accurate enough across
## the Baltic. tools/map/render_map.py draws the map image with the same formula.

const KM_PER_DEGREE: float = 111.2

## res:// path of the rendered map image covering exactly this frame.
var image: String
var west_lon: float
var east_lon: float
var south_lat: float
var north_lat: float
var reference_lat: float


func _init(
	p_image: String,
	p_west_lon: float,
	p_east_lon: float,
	p_south_lat: float,
	p_north_lat: float,
	p_reference_lat: float,
) -> void:
	image = p_image
	west_lon = p_west_lon
	east_lon = p_east_lon
	south_lat = p_south_lat
	north_lat = p_north_lat
	reference_lat = p_reference_lat


## Kilometres east and south of the frame's north-west corner.
func project(lon: float, lat: float) -> Vector2:
	var x := (lon - west_lon) * KM_PER_DEGREE * cos(deg_to_rad(reference_lat))
	var y := (north_lat - lat) * KM_PER_DEGREE
	return Vector2(x, y)


## Size of the whole frame in kilometres.
func size_km() -> Vector2:
	return project(east_lon, south_lat)


func contains(lon: float, lat: float) -> bool:
	return lon >= west_lon and lon <= east_lon and lat >= south_lat and lat <= north_lat
