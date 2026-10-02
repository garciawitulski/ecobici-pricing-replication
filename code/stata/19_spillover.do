* 19_spillover.do
* Were weekdays really untreated? Diagnostics for displacement of trips onto weekdays (Table A15).
*
* Panel A. Aggregate use at the threshold (local linear in event time, weather controls, Newey-West
*   lag 14): the weekday-only discontinuity; the weekday discontinuity of the difference-in-
*   discontinuities model; and the discontinuity of all days pooled. Displacement would raise weekday
*   use at the threshold.
* Panel B. Cohort members split on their PRE-REFORM day-type mix (weekend-leaning: more weekend than
*   weekday trips per available day). Difference between the two groups in the change of weekday trips
*   per available day (heteroskedasticity-robust standard error). The same comparison at a placebo
*   threshold where access stayed free (16 January 2021) measures reversion to the mean alone.
*
* Input : data/analysis/ecobici_daily_2019_2023.dta, data/intermediate/user_day.dta, calendar.dta
* Output: output/tables/tableA15_weekday_spillover.tex

capture log close
log using "$logs/19_spillover.log", replace text

local weather "prcp_mm rain_day tmax_c c.tmax_c#c.tmax_c"   // SMN weather is complete (CAF-007): the missing-day indicators are identically zero and leave the controls

* ---- Panel A ---------------------------------------------------------------------------------------------
do "$code/sample.do" 13mar2021 56
gen pt = post * t
gen wp = weekend * post
gen wt = weekend * t
gen wpt = weekend * post * t
* (2) weekday discontinuity of the difference-in-discontinuities model
newey log_trips post t pt wp wt wpt i.dow `weather', lag(14)
local b2 = _b[post]
local se2 = _se[post]
local p2 = 2 * ttail(e(df_r), abs(_b[post] / _se[post]))
local n2 = e(N)
* (3) all days pooled
newey log_trips post t pt i.dow `weather', lag(14)
local b3 = _b[post]
local se3 = _se[post]
local p3 = 2 * ttail(e(df_r), abs(_b[post] / _se[post]))
local n3 = e(N)
* (1) weekdays only
keep if weekend == 0
drop tt
gen tt = _n
quietly tsset tt
newey log_trips post t pt i.dow `weather', lag(14)
local b1 = _b[post]
local se1 = _se[post]
local p1 = 2 * ttail(e(df_r), abs(_b[post] / _se[post]))
local n1 = e(N)

* ---- Panel B ---------------------------------------------------------------------------------------------
foreach thr in 13mar2021 16jan2021 {
    local s = td(`thr')
    * outcome days: eligible days, dropping the earliest pre-threshold day of each day type
    use "$inter/calendar.dta", clear
    keep if holiday_any == 0 & date != `s' & inrange(date, `s' - 56, `s' + 56)
    replace post = date > `s'          // after the threshold (the calendar has post for the reform)
    bysort weekend post (date): gen first = _n == 1 & post == 0
    keep if first == 0
    forvalues w = 0/1 {
        forvalues p = 0/1 {
            count if weekend == `w' & post == `p'
            local nd`w'`p' = r(N)
        }
    }
    keep date post
    tempfile days
    save `days'
    * members: a trip on a non-holiday day of the 8 weeks before the threshold
    use uid date holiday_any if inrange(date, `s' - 56, `s' - 1) & holiday_any == 0 using "$inter/user_day.dta", clear
    keep uid
    duplicates drop
    tempfile members
    save `members'
    * trips per available day, by member, day type and period
    use uid date trips weekend if inrange(date, `s' - 56, `s' + 56) using "$inter/user_day.dta", clear
    merge m:1 date using `days', keep(match) nogenerate
    merge m:1 uid using `members', keep(match) nogenerate
    collapse (sum) trips, by(uid weekend post)
    tempfile agg
    save `agg'
    use `members', clear
    expand 4
    bysort uid: gen cell = _n
    gen weekend = inlist(cell, 2, 4)
    gen post = cell >= 3
    drop cell
    merge 1:1 uid weekend post using `agg', keep(master match) nogenerate
    replace trips = 0 if missing(trips)
    gen per_day = .
    forvalues w = 0/1 {
        forvalues p = 0/1 {
            replace per_day = trips / `nd`w'`p'' if weekend == `w' & post == `p'
        }
    }
    * group on the pre-threshold day-type mix
    gen pre_we = per_day if post == 0 & weekend == 1
    gen pre_wd = per_day if post == 0 & weekend == 0
    bysort uid: egen pre_weekend = max(pre_we)
    bysort uid: egen pre_weekday = max(pre_wd)
    gen weekend_leaning = pre_weekend > pre_weekday
    * change in weekday trips per available day
    keep if weekend == 0
    gen wd_pre = per_day if post == 0
    gen wd_post = per_day if post == 1
    collapse (max) wd_pre wd_post weekend_leaning, by(uid)
    gen change = wd_post - wd_pre
    regress change weekend_leaning, vce(robust)
    local name = cond("`thr'" == "13mar2021", "reform", "placebo")
    local b_`name' = _b[weekend_leaning]
    local se_`name' = _se[weekend_leaning]
    local p_`name' = 2 * normal(-abs(_b[weekend_leaning] / _se[weekend_leaning]))
    local n_`name' = e(N)
}

* ---- Table A15 ---------------------------------------------------------------------------------------
file open tab using "$tables/tableA15_weekday_spillover.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{8.00cm}*{3}{>{\centering\arraybackslash}p{2.30cm}}@{}}" _n
file write tab "\toprule" _n " & Estimate & Implied change (\%) & Observations \\" _n "\midrule" _n
file write tab "\multicolumn{4}{@{}l}{\textit{Panel A. Aggregate use at the threshold}} \\" _n
local lab1 "Weekday discontinuity, weekdays only"
local lab2 "Weekday discontinuity, difference-in-discontinuities model"
local lab3 "All days pooled"
forvalues k = 1/3 {
    estcell `b`k'' `se`k'' `p`k'' 3
    local e "`r(b)'"
    local s "`r(se)'"
    local v = 100 * (exp(`b`k'') - 1)
    fmtnum `v' 1
    file write tab "`lab`k'' & `e' & `r(s)' & `n`k'' \\" _n " & `s' &  &  \\" _n
}
file write tab "\midrule" _n "\multicolumn{4}{@{}l}{\textit{Panel B. Weekday trips per day, riders grouped on pre-period day-type mix}} \\" _n
foreach name in reform placebo {
    local lab = cond("`name'" == "reform", "Weekend-leaning minus weekday-leaning, reform", ///
                                            "Weekend-leaning minus weekday-leaning, free-access placebo")
    estcell `b_`name'' `se_`name'' `p_`name'' 3
    local e "`r(b)'"
    local s "`r(se)'"
    fmtnum `n_`name'' 0
    file write tab "`lab' & `e' &  & `r(s)' \\" _n " & `s' &  &  \\" _n
}
local v = `b_reform' - `b_placebo'
fmtnum `v' 3
file write tab "Reform minus placebo & `r(s)' &  &  \\" _n "\bottomrule" _n "\end{tabular*}" _n
file close tab

log close
