* 15_supply_mobility.do
* Service supply and contemporaneous mobility.
*   Table A6   preferred specification with service-supply controls measured independently of weekend
*              demand (60-day station roster, docks in service, cumulative station roster)
*   Table A7   preferred specification applied to Google mobility and to Subte (subway) entries
*   Table A13  preferred specification on the 200 stations that already operated before the reform
* Standard errors: Newey-West, lag 14.
*
* Input : data/analysis/ecobici_daily_2019_2023.dta, data/intermediate/station_supply.dta,
*         data/intermediate/stable_network_daily.dta
* Output: output/tables/tableA6_supply.tex, tableA7_mobility.tex, tableA13_stable_network.tex

capture log close
log using "$logs/15_supply_mobility.log", replace text

local weather "prcp_mm rain_day tmax_c c.tmax_c#c.tmax_c"   // SMN weather is complete (CAF-007): the missing-day indicators are identically zero and leave the controls

do "$code/sample.do" 13mar2021 56
merge 1:1 date using "$inter/station_supply.dta", keep(master match) nogenerate
merge 1:1 date using "$inter/stable_network_daily.dta", keep(master match) nogenerate
sort tt
gen log_stations_60d = ln(stations_in_service_60d)
gen log_docks_60d = ln(docks_in_service_60d)

* ---- Table A6: supply controls ---------------------------------------------------------------------
local k = 0
foreach control in "" log_stations_60d log_docks_60d stations_cum_roster {
    local ++k
    newey log_trips wknd_post i.week i.dow `weather' `control', lag(14)
    local b`k' = _b[wknd_post]
    local se`k' = _se[wknd_post]
    local p`k' = 2 * ttail(e(df_r), abs(_b[wknd_post] / _se[wknd_post]))
}
* supply around the reform (quoted in the text)
list date stations_in_service_60d docks_in_service_60d stations_cum_roster ///
    if inlist(date, td(12mar2021), td(15apr2021)), noobs
correlate log_stations_60d post

file open tab using "$tables/tableA6_supply.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{8.20cm}*{2}{>{\centering\arraybackslash}p{2.60cm}}@{}}" _n
file write tab "\toprule" _n "Supply control & Estimate & Std.\ error \\" _n "\midrule" _n
local lab1 "None (preferred specification)"
local lab2 "Log stations in service, 60-day roster"
local lab3 "Log docks in service, 60-day roster"
local lab4 "Cumulative station roster"
forvalues k = 1/4 {
    estcell `b`k'' `se`k'' `p`k'' 3
    file write tab "`lab`k'' & `r(b)' & `r(se)' \\" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* ---- Table A13: the stable pre-reform network -------------------------------------------------------
gen log_st_trips = ln(st_trips)
gen log_st_users = ln(st_users)
gen log_st_minutes = ln(st_minutes)
foreach y in st_trips st_users st_minutes trips users minutes {
    if "`y'" == "trips"   local dep "log_trips"
    if "`y'" == "users"   local dep "log_users"
    if "`y'" == "minutes" local dep "log_minutes"
    if substr("`y'", 1, 3) == "st_" local dep "log_`y'"
    newey `dep' wknd_post i.week i.dow `weather', lag(14)
    local b_`y' = _b[wknd_post]
    local se_`y' = _se[wknd_post]
    local p_`y' = 2 * ttail(e(df_r), abs(_b[wknd_post] / _se[wknd_post]))
}
* share of system trips that start at a stable station: sum of the weekend and weekday means
foreach p in 0 1 {
    local num = 0
    local den = 0
    foreach w in 0 1 {
        summarize st_trips if post == `p' & weekend == `w', meanonly
        local num = `num' + r(mean)
        summarize n_trips if post == `p' & weekend == `w', meanonly
        local den = `den' + r(mean)
    }
    local share`p' = string(100 * `num' / `den', "%5.2f")
}
count
local ndays = r(N)

file open tab using "$tables/tableA13_stable_network.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{4.60cm}*{4}{>{\centering\arraybackslash}p{2.30cm}}@{}}" _n
file write tab "\toprule" _n " & \multicolumn{2}{c}{Stable network, 200 stations} & \multicolumn{2}{c}{Full network} \\" _n
file write tab "\cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write tab " & Estimate & Implied change (\%) & Estimate & Implied change (\%) \\" _n "\midrule" _n
local lab_trips "Trips starting at a station (log)"
local lab_users "Unique riders (log)"
local lab_minutes "Minutes ridden (log)"
foreach y in trips users minutes {
    local line "`lab_`y''"
    local se ""
    foreach net in st_ "" {
        estcell `b_`net'`y'' `se_`net'`y'' `p_`net'`y'' 3
        local cb "`r(b)'"
        local cs "`r(se)'"
        local v = 100 * (exp(`b_`net'`y'') - 1)
        fmtnum `v' 1
        local line "`line' & `cb' & `r(s)'"
        local se "`se' & `cs' & "
    }
    file write tab "`line' \\" _n "`se' \\" _n
}
file write tab "\midrule" _n
file write tab "Share of system trips, before & `share0' &  & 100.00 &  \\" _n
file write tab "Share of system trips, after & `share1' &  & 100.00 &  \\" _n
file write tab "Observations (days) & `ndays' &  & `ndays' &  \\" _n "\bottomrule" _n "\end{tabular*}" _n
file close tab

* ---- Table A7: contemporaneous mobility ---------------------------------------------------------------
local series "mob_transit mob_parks mob_retail_rec mob_workplaces mob_residential log_subte"
foreach y of local series {
    preserve
    keep if !missing(`y')
    if "`y'" == "log_subte" keep if subte_date_certain == 1
    drop tt
    gen tt = _n
    quietly tsset tt
    newey `y' wknd_post i.week i.dow `weather', lag(14)
    local b_`y' = _b[wknd_post]
    local se_`y' = _se[wknd_post]
    local p_`y' = 2 * ttail(e(df_r), abs(_b[wknd_post] / _se[wknd_post]))
    local n_`y' = e(N)
    restore
}
file open tab using "$tables/tableA7_mobility.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{7.40cm}*{3}{>{\centering\arraybackslash}p{2.00cm}}@{}}" _n
file write tab "\toprule" _n "Series & Estimate & Std.\ error & Days \\" _n "\midrule" _n
local lab_mob_transit "Google mobility, transit stations"
local lab_mob_parks "Google mobility, parks"
local lab_mob_retail_rec "Google mobility, retail and recreation"
local lab_mob_workplaces "Google mobility, workplaces"
local lab_mob_residential "Google mobility, residential"
local lab_log_subte "log(subway passengers), dates certain"
foreach y of local series {
    local d = cond("`y'" == "log_subte", 3, 2)
    estcell `b_`y'' `se_`y'' `p_`y'' `d'
    file write tab "`lab_`y'' & `r(b)' & `r(se)' & `n_`y'' \\" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

log close
