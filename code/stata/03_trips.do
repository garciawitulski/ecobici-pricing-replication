* 03_trips.do
* Ecobici trip records 2019-2023: one slim trip file per year and the day-level outcomes.
*
* Input : data/raw/ecobici_trips/recorridos-realizados-YYYY.zip (GCBA open data)
* Output: data/intermediate/trips_YYYY.dta     one row per trip (date, hour, user, stations, duration)
*         data/intermediate/daily_trips.dta     one row per day with the daily outcomes
*
* Notes on the raw files (verified for every year):
*   - timestamps are local time (UTC-3); a trip is assigned to the date on which it starts;
*   - duracion_recorrido is in seconds, written with a comma as thousands separator ("2,814");
*   - station and user ids end in "BAEcobici" ("5BAEcobici" -> 5);
*   - gender is in a column "género" (2019-2021) or "Género" (2021-2023); 2021 has both.
* No trip is dropped: daily counts use every recorded trip.

capture log close
log using "$logs/03_trips.log", replace text

forvalues y = 2019/2023 {

    * ---- unzip and read one year ----------------------------------------------------------
    cd "$tmp"
    unzipfile "$raw/ecobici_trips/recorridos-realizados-`y'.zip", replace
    local files : dir "$tmp" files "*.csv"
    local f : word 1 of `files'
    import delimited using "$tmp/`f'", varnames(1) case(preserve) stringcols(_all) ///
        encoding("utf-8") bindquote(strict) clear
    erase "$tmp/`f'"
    cd "$root"
    display "`y': " _N " trips"

    * ---- parse -------------------------------------------------------------------------------
    gen double dur_sec = real(subinstr(duracion_recorrido, ",", "", .))
    gen date = date(substr(fecha_origen_recorrido, 1, 10), "YMD")
    gen hour = real(substr(fecha_origen_recorrido, 12, 2))
    gen d_date = date(substr(fecha_destino_recorrido, 1, 10), "YMD")
    gen d_hour = real(substr(fecha_destino_recorrido, 12, 2))
    format date d_date %td
    gen long uid = real(subinstr(id_usuario, "BAEcobici", "", .))
    gen st_o = real(subinstr(id_estacion_origen, "BAEcobici", "", .))
    gen st_d = real(subinstr(id_estacion_destino, "BAEcobici", "", .))
    gen double lon_o = real(long_estacion_origen)
    gen double lat_o = real(lat_estacion_origen)

    * gender: first non-empty value among the gender columns, in file order
    gen gender = ""
    foreach v in género Género {
        capture confirm variable `v'
        if !_rc replace gender = `v' if gender == "" & !inlist(`v', "", "NA")
    }

    * parsing checks: every row must have a date, a duration and an origin station
    assert !missing(date, dur_sec, st_o)
    count if missing(uid)
    display "`y': trips without a user id = " r(N)

    keep date hour d_date d_hour uid st_o st_d dur_sec gender lon_o lat_o
    compress
    save "$inter/trips_`y'.dta", replace
}

* ---- daily outcomes ---------------------------------------------------------------------------
clear
tempfile daily
forvalues y = 2019/2023 {
    use "$inter/trips_`y'.dta", clear

    * distinct users and stations per day (a missing user id counts as one more user, as in R)
    egen tag_user = tag(date uid), missing
    egen tag_st_o = tag(date st_o)
    gen female = gender == "FEMALE"
    gen male = gender == "MALE"
    gen other = gender == "OTHER"
    gen gender_missing = gender == ""
    gen gt30 = dur_sec > 1800 if !missing(dur_sec)
    gen night = inrange(hour, 0, 5)
    gen h2006 = (hour >= 20 | hour < 6) & !missing(hour)
    gen short_same = dur_sec < 60 & st_o == st_d & !missing(st_d)
    gen one = 1

    collapse (sum) n_trips = one total_sec = dur_sec n_users = tag_user                    ///
             n_trips_female = female n_trips_male = male n_trips_other = other             ///
             n_trips_gender_missing = gender_missing n_trips_night = night                 ///
             n_trips_2006 = h2006 n_short_same_station = short_same                        ///
             n_stations_departure = tag_st_o                                               ///
             (mean) mean_dur_sec = dur_sec share_gt30min = gt30                            ///
             (median) median_dur_sec = dur_sec, by(date)
    capture append using `daily'
    save `daily', replace
}

* stations with any departure or arrival on the day
tempfile st_any origins
forvalues y = 2019/2023 {
    use date st_o using "$inter/trips_`y'.dta", clear
    rename st_o station
    save `origins', replace
    use date st_d using "$inter/trips_`y'.dta", clear
    rename st_d station
    append using `origins'
    drop if missing(station)
    bysort date station: keep if _n == 1
    collapse (count) n_stations_any = station, by(date)
    capture append using `st_any'
    save `st_any', replace
}

* first trip ever observed for each user -> new users per day
tempfile first
forvalues y = 2019/2023 {
    use date uid using "$inter/trips_`y'.dta", clear
    drop if missing(uid)
    collapse (min) first_trip = date, by(uid)
    capture append using `first'
    save `first', replace
}
use `first', clear
collapse (min) first_trip, by(uid)
rename first_trip date
collapse (count) n_new_users = uid, by(date)
tempfile newusers
save `newusers'

use `daily', clear
merge 1:1 date using `st_any', nogenerate
merge 1:1 date using `newusers', nogenerate keep(master match)
replace n_new_users = 0 if missing(n_new_users)
gen double total_minutes = total_sec / 60
gen double mean_dur_min = mean_dur_sec / 60
gen double median_dur_min = median_dur_sec / 60
gen double trips_per_active_station = n_trips / n_stations_departure
drop total_sec mean_dur_sec median_dur_sec
sort date
format date %td
compress
save "$inter/daily_trips.dta", replace

* trips per year (compare with the raw row counts printed above)
gen year = year(date)
tabstat n_trips, by(year) statistics(sum n) format(%12.0fc)

log close
