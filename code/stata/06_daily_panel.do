* 06_daily_panel.do
* The day-level analysis dataset, 1 January 2019 to 31 December 2023, and the primary sample.
*
* Input : data/intermediate/calendar.dta, daily_trips.dta, weather.dta, subte.dta, mobility.dta
* Output: data/analysis/ecobici_daily_2019_2023.dta (and .csv)   one row per calendar day
*         data/analysis/ecobici_daily_primary.dta (and .csv)      the primary estimation sample
*
* Primary sample (pre-specified): days within 8 weeks (56 days) of 13 March 2021, excluding
* holidays and general non-working days and excluding the implementation day itself.

capture log close
log using "$logs/06_daily_panel.log", replace text

use "$inter/calendar.dta", clear
merge 1:1 date using "$inter/daily_trips.dta", keep(master match)
tab _merge
drop _merge
merge 1:1 date using "$inter/weather.dta", keep(master match) nogenerate
merge 1:1 date using "$inter/subte.dta", keep(master match) nogenerate
replace subte_date_certain = 0 if missing(subte_date_certain)
merge 1:1 date using "$inter/mobility.dta", keep(master match) nogenerate

* ---- outcomes ------------------------------------------------------------------------------
* every daily count is strictly positive whenever the system operated, so plain logs are used
gen log_trips   = ln(n_trips)
gen log_minutes = ln(total_minutes)
gen log_users   = ln(n_users)
gen log1p_trips = ln(1 + n_trips)
gen female_share = n_trips_female / n_trips
gen log_female  = ln(n_trips_female) if n_trips_female > 0
gen log_male    = ln(n_trips_male) if n_trips_male > 0
gen log_subte   = ln(subte_pax)

* ---- availability flags ------------------------------------------------------------------
gen data_available = !missing(n_trips)
gen prelaunch_2019 = date < td(25feb2019)                                  // before the relaunch
gen system_suspended_covid = inrange(date, td(20mar2020), td(10may2020))   // pandemic suspension
gen low_count_day = !missing(n_trips) & n_trips < 500

label variable n_trips "Ecobici trips starting on the day"
label variable weekend "Saturday or Sunday"
label variable post "on or after 13 March 2021"
compress
sort date
save "$analysis/ecobici_daily_2019_2023.dta", replace
format date %tdCCYY-NN-DD          // ISO dates in the csv files
export delimited using "$analysis/ecobici_daily_2019_2023.csv", replace

* ---- primary sample -------------------------------------------------------------------------
keep if abs(days_from_policy) <= 56
count
keep if data_available == 1
count
list date if holiday_any == 1, noobs
drop if holiday_any == 1
drop if date == $policy
count
save "$analysis/ecobici_daily_primary.dta", replace
export delimited using "$analysis/ecobici_daily_primary.csv", replace

* sample sizes quoted in the paper
count if weekend == 1
count if weekend == 0
count if post == 0
count if post == 1
summarize n_trips
display "Trips in the primary sample: " %12.0fc r(sum)

log close
