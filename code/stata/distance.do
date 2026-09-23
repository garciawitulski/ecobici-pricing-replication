* distance.do
* Distance in metres between (lon1, lat1) and (lon2, lat2), in decimal degrees. Creates `dist'.
* Called by 08_stations.do.
*
* The original analysis measured distances in the projected system POSGAR 2007 / Argentina zone 5
* (EPSG:5347, transverse Mercator with central meridian -60). Over a few kilometres that distance
* equals the distance on the GRS80 ellipsoid, computed with the local radii of curvature, times the
* scale factor of the projection (about 1.00026 in Buenos Aires).

local a   = 6378137                 // GRS80 semi-major axis
local e2  = 0.00669438002290        // GRS80 first eccentricity squared
local rad = _pi / 180

gen double phi = (lat1 + lat2) / 2 * `rad'
gen double M   = `a' * (1 - `e2') / (1 - `e2' * sin(phi)^2)^1.5     // meridian radius
gen double N   = `a' / sqrt(1 - `e2' * sin(phi)^2)                  // prime-vertical radius
gen double dx  = N * cos(phi) * (lon2 - lon1) * `rad'
gen double dy  = M * (lat2 - lat1) * `rad'
gen double k   = 1 + (((lon1 + lon2) / 2 + 60) * `rad' * cos(phi))^2 / 2   // projection scale factor
gen double dist = k * sqrt(dx^2 + dy^2)
drop phi M N dx dy k
