* 08_stations.do
* Station-level data: service supply, the stable pre-reform network, the station commuting profile,
* station coordinates and distances to the subway and railway networks.
*
* Input : data/intermediate/trips_2020.dta, trips_2021.dta
*         data/analysis/ecobici_daily_primary.dta
*         data/raw/stations/nuevas-estaciones-bicicletas-publicas.geojson  (official dock capacity)
*         data/raw/geography/estaciones_de_subte.geojson, estaciones_ferroviarias.geojson
* Output: data/intermediate/station_supply.dta     daily supply measures, Dec 2020 - Jul 2021
*         data/intermediate/station_profile.dta    the 200 stable stations and their commuting profile
*         data/intermediate/stable_network_daily.dta  daily use of the stable network (primary sample)
*         data/intermediate/station_distances.dta  distance from each stable station to the transport network
*         output/estimates/station_map_points.csv  station points for Figure 2
*
* The commuting profile follows a plan fixed before any heterogeneous effect was estimated. It uses
* only weekday trips on the non-holiday pre-reform days of the primary sample (16 January to
* 12 March 2021):
*   am_share      share of a station's departures and arrivals between 07:00 and 09:59
*   dir_reversal  |imbalance 07-09 - imbalance 17-19| / 2, where imbalance = (O - D) / (O + D)
*   score         mean of the two standardised measures; stations at or above the median are
*                 "more commuter-oriented"
* Stable stations: a departure on at least 40 of the 54 pre-reform sample days.

capture log close
log using "$logs/08_stations.log", replace text

* =============================================================================================
* 1. Service supply around the reform (Appendix Table A6)
* =============================================================================================
* official dock capacity: one feature per line in the GeoJSON file
import delimited using "$raw/stations/nuevas-estaciones-bicicletas-publicas.geojson", ///
    delimiter("~") varnames(nonames) stringcols(_all) bindquote(nobind) stripquote(no) clear
keep if strpos(v1, `""NUMERO""') > 0
gen numero = real(regexs(1)) if regexm(v1, `""NUMERO": ([0-9]+)"')
gen anclajes = real(regexs(1)) if regexm(v1, `""ANCLAJES": ([0-9]+)"')
drop if missing(numero)
collapse (median) anclajes, by(numero)
rename numero station
tempfile capacity
save `capacity'

* station x day presence (at least one departure), 2020-2021
use st_o date using "$inter/trips_2020.dta", clear
append using "$inter/trips_2021.dta", keep(st_o date)
rename st_o station
drop if missing(station)
bysort station date: keep if _n == 1

* capacity by station number; stations not in the official file get the median capacity
preserve
keep station
duplicates drop
merge 1:1 station using `capacity', keep(master match) nogenerate
summarize anclajes, detail
replace anclajes = r(p50) if missing(anclajes)
tempfile cap_matched
save `cap_matched'
restore
merge m:1 station using `cap_matched', nogenerate

* first day on which each station is observed
bysort station: egen first_seen = min(date)
tempfile station_day
save `station_day'

* stations (and docks) with a departure within +/- 30 days of each date
tempname h
postfile `h' date stations_in_service_60d docks_in_service_60d using "$tmp/supply.dta", replace
forvalues d = `=td(01dec2020)'/`=td(31jul2021)' {
    quietly {
        egen in_window = tag(station) if inrange(date, `d' - 30, `d' + 30)
        count if in_window == 1
        local n = r(N)
        summarize anclajes if in_window == 1
        local docks = r(sum)
        drop in_window
    }
    post `h' (`d') (`n') (`docks')
}
postclose `h'

* cumulative roster: stations seen at least once up to each date
use `station_day', clear
bysort station: keep if _n == 1
count if first_seen < td(01dec2020)
local before = r(N)
collapse (count) new_stations = station, by(first_seen)
rename first_seen date
merge 1:1 date using "$tmp/supply.dta", keep(using match) nogenerate
replace new_stations = 0 if missing(new_stations)
sort date
gen stations_cum_roster = sum(new_stations) + `before'
format date %td
save "$inter/station_supply.dta", replace
erase "$tmp/supply.dta"
list if inlist(date, td(15feb2021), td(12mar2021), td(13mar2021), td(15apr2021)), noobs

* =============================================================================================
* 2. Stable stations and the commuting profile (Appendix Table A11, Figure 2)
* =============================================================================================
use date weekend using "$analysis/ecobici_daily_primary.dta", clear
keep if date < $policy
count
gen pre_day = 1
tempfile pre_days
save `pre_days'

* stable stations: departures on at least 40 of the 54 pre-reform days
use st_o date using "$inter/trips_2021.dta", clear
merge m:1 date using `pre_days', keep(match) nogenerate
bysort st_o date: keep if _n == 1
collapse (count) days_active = date, by(st_o)
rename st_o station
count
display "stations with any pre-reform departure: " r(N)
gen stable = days_active >= 40
tempfile active
save `active'

* departures (O) and arrivals (D) on pre-reform weekdays, by hour
use `pre_days', clear
keep if weekend == 0
keep date
tempfile pre_weekdays
save `pre_weekdays'

use st_o hour date using "$inter/trips_2021.dta", clear
merge m:1 date using `pre_weekdays', keep(match) nogenerate
rename (st_o hour) (station hr)
gen origin = 1
tempfile o
save `o'
use st_d d_hour d_date using "$inter/trips_2021.dta", clear
rename (st_d d_hour d_date) (station hr date)
merge m:1 date using `pre_weekdays', keep(match) nogenerate
drop if missing(station) | missing(hr)
gen origin = 0
append using `o'

gen am = inrange(hr, 7, 9)
gen pm = inrange(hr, 17, 19)
gen o_am = am & origin == 1
gen d_am = am & origin == 0
gen o_pm = pm & origin == 1
gen d_pm = pm & origin == 0
gen one = 1
collapse (sum) n_all = one n_am = am o_am d_am o_pm d_pm, by(station)
gen am_share = n_am / n_all
gen imb_am = (o_am - d_am) / (o_am + d_am) if o_am + d_am > 0
gen imb_pm = (o_pm - d_pm) / (o_pm + d_pm) if o_pm + d_pm > 0
gen dir_reversal = abs(imb_am - imb_pm) / 2

merge 1:1 station using `active', keep(match) nogenerate
keep if stable == 1 & !missing(dir_reversal)
count
egen z_am = std(am_share)
egen z_dir = std(dir_reversal)
gen commuter_score = (z_am + z_dir) / 2
summarize commuter_score, detail
gen more_commuter = commuter_score >= r(p50)
label define more_commuter 1 "more commuter-oriented" 0 "less commuter-oriented"
label values more_commuter more_commuter

* pre-reform weekend share of each station's departures (validation only, not used to classify)
preserve
use st_o date using "$inter/trips_2021.dta", clear
merge m:1 date using `pre_days', keep(match) nogenerate
rename st_o station
collapse (mean) weekend_share = weekend, by(station)
tempfile wshare
save `wshare'
restore
merge 1:1 station using `wshare', keep(master match) nogenerate
correlate commuter_score weekend_share
keep station am_share dir_reversal commuter_score more_commuter weekend_share
save "$inter/station_profile.dta", replace
tab more_commuter

* =============================================================================================
* 3. Daily use of the stable network (Appendix Table A13)
* =============================================================================================
use st_o uid dur_sec date using "$inter/trips_2021.dta", clear
merge m:1 date using "$analysis/ecobici_daily_primary.dta", keep(match) nogenerate keepusing(date)
rename st_o station
merge m:1 station using "$inter/station_profile.dta", keep(match) nogenerate keepusing(station)
egen tag_user = tag(date uid)
gen one = 1
collapse (sum) st_trips = one st_users = tag_user st_sec = dur_sec, by(date)
gen double st_minutes = st_sec / 60
drop st_sec
save "$inter/stable_network_daily.dta", replace

* =============================================================================================
* 4. Coordinates of the pre-reform stations and distances to the transport network
* =============================================================================================
* coordinates recorded on the pre-reform trip records (one pair per station)
use st_o lon_o lat_o date using "$inter/trips_2021.dta", clear
merge m:1 date using `pre_days', keep(match) nogenerate
drop if missing(lon_o) | missing(lat_o)
rename st_o station
collapse (median) lon = lon_o lat = lat_o, by(station)
merge 1:1 station using `active', keep(match) nogenerate keepusing(stable)
merge 1:1 station using "$inter/station_profile.dta", keep(master match) nogenerate keepusing(more_commuter)
tempfile coords
save `coords'
gen universe = cond(stable == 1, "stable", "below threshold")
gen commuter_group = ""
replace commuter_group = "more commuter-oriented" if more_commuter == 1
replace commuter_group = "less commuter-oriented" if more_commuter == 0
keep station lon lat universe commuter_group
format lon lat %12.7f
export delimited using "$estimates/station_map_points.csv", replace

* subway stations (one GeoJSON feature per line)
import delimited using "$raw/geography/estaciones_de_subte.geojson", delimiter("~") ///
    varnames(nonames) stringcols(_all) bindquote(nobind) stripquote(no) encoding("utf-8") clear
keep if strpos(v1, `""Feature""') > 0
gen name = regexs(1) if regexm(v1, `""ESTACION": "([^"]*)""')
gen line = regexs(1) if regexm(v1, `""LINEA": "([^"]*)""')
gen double lon = real(regexs(1)) if regexm(v1, `"coordinates": \[ (-?[0-9.]+), (-?[0-9.]+) \]"')
gen double lat = real(regexs(2)) if regexm(v1, `"coordinates": \[ (-?[0-9.]+), (-?[0-9.]+) \]"')
keep name line lon lat
gen id = _n
count
tempfile subte
save `subte'

* railway stations inside the city (the attribute "comuna" is filled only for stations in the city)
import delimited using "$raw/geography/estaciones_ferroviarias.geojson", delimiter("~") ///
    varnames(nonames) stringcols(_all) bindquote(nobind) stripquote(no) encoding("utf-8") clear
keep if strpos(v1, `""Feature""') > 0
gen name = regexs(1) if regexm(v1, `""nombre": "([^"]*)""')
gen line = regexs(1) if regexm(v1, `""linea": "([^"]*)""')
gen in_city = regexm(v1, `""comuna": "Comuna"')
gen double lon = real(regexs(1)) if regexm(v1, `"coordinates": \[ (-?[0-9.]+), (-?[0-9.]+) \]"')
gen double lat = real(regexs(2)) if regexm(v1, `"coordinates": \[ (-?[0-9.]+), (-?[0-9.]+) \]"')
keep if in_city == 1
keep name line lon lat
gen id = _n
count
tempfile rail
save `rail'

* Distances in metres are computed by distance.do from (lon1, lat1) and (lon2, lat2).

* subway interchanges: a subway station within 250 m of a station on a different line
use `subte', clear
rename (id name line lon lat) (id1 name1 line1 lon1 lat1)
cross using `subte'
rename (lon lat) (lon2 lat2)
do "$code/distance.do"
gen other_line_near = dist <= 250 & id1 != id & line1 != line
collapse (max) interchange = other_line_near, by(id1)
rename id1 id
merge 1:1 id using `subte', nogenerate
tab interchange
save `subte', replace

* railway hubs: a railway station within 600 m of a station on a different line
use `rail', clear
rename (id name line lon lat) (id1 name1 line1 lon1 lat1)
cross using `rail'
rename (lon lat) (lon2 lat2)
do "$code/distance.do"
gen other_line_near = dist <= 600 & id1 != id & line1 != line
collapse (max) hub = other_line_near, by(id1)
rename id1 id
merge 1:1 id using `rail', nogenerate
tab hub
save `rail', replace

* nearest subway station, subway interchange, railway station and railway hub for each stable station
use `coords', clear
keep if stable == 1
keep station lon lat more_commuter
rename (lon lat) (lon1 lat1)
tempfile stations
save `stations'
foreach target in subte interchange rail railhub {
    use `stations', clear
    if "`target'" == "subte" | "`target'" == "interchange" cross using `subte'
    if "`target'" == "rail" | "`target'" == "railhub" cross using `rail'
    if "`target'" == "interchange" keep if interchange == 1
    if "`target'" == "railhub" keep if hub == 1
    rename (lon lat) (lon2 lat2)
    do "$code/distance.do"
    collapse (min) d_`target' = dist, by(station)
    tempfile d_`target'
    save `d_`target''
}
use `stations', clear
foreach target in subte interchange rail railhub {
    merge 1:1 station using `d_`target'', nogenerate
}
keep station more_commuter d_*
save "$inter/station_distances.dta", replace
tabstat d_*, by(more_commuter) statistics(median mean) format(%9.1f)

log close
