* 18_persistence.do
* Is the weekend-specific fall temporary or durable? (Table A12, Figure 6)
*
* Panel A. One regression on every non-holiday day from the 2019 relaunch to 2023 (the reform day
*   excluded) with Weekend x period terms for the first 8 post-reform weeks, the rest of 2021, 2022 and
*   2023; the reference is the 8 pre-reform weeks. Week and day-of-week fixed effects, Newey-West lag 14.
*   Only the first period is read causally: the later ones also reflect the tariff revisions of 2022
*   and 2023, network growth and the pandemic recovery.
* Panel B. Ratio of mean weekend to mean weekday trips (non-holiday days) by regime period.
* Figure 6. The same ratio week by week (Monday-to-Sunday weeks with at least one weekend day and three
*   weekdays).
*
* Input : data/analysis/ecobici_daily_2019_2023.dta
* Output: output/tables/tableA12_persistence.tex
*         output/estimates/weekly_ratio.csv, output/estimates/ratio_by_period.csv (Figure 6)

capture log close
log using "$logs/18_persistence.log", replace text

local P = $policy

* ---- Panel A: period effects -------------------------------------------------------------------------
use "$analysis/ecobici_daily_2019_2023.dta", clear
keep if !missing(n_trips) & holiday_any == 0 & date != `P' & date >= td(25feb2019)
gen period = .
replace period = 0 if date >= `P' - 56 & date < `P'
replace period = 1 if date > `P' & date <= `P' + 56
replace period = 2 if date > `P' + 56 & date <= td(31dec2021)
replace period = 3 if year(date) == 2022
replace period = 4 if year(date) == 2023
keep if !missing(period)
forvalues k = 1/4 {
    gen wxp`k' = weekend * (period == `k')
}
gen week_abs = floor((date - td(25feb2019)) / 7)    // weeks since the relaunch
sort date
gen tt = _n
tsset tt
newey log_trips wxp1 wxp2 wxp3 wxp4 i.week_abs i.dow, lag(14)
forvalues k = 1/4 {
    local b`k' = _b[wxp`k']
    local se`k' = _se[wxp`k']
    local p`k' = 2 * normal(-abs(_b[wxp`k'] / _se[wxp`k']))
}

* ---- Panel B: weekend-to-weekday ratio by regime period ------------------------------------------------
use "$analysis/ecobici_daily_2019_2023.dta", clear
keep if !missing(n_trips) & holiday_any == 0
tempname rp
postfile `rp' from to ratio paid using "$tmp/ratio_by_period.dta", replace
foreach span in "25feb2019 31dec2019 0" "11may2020 31dec2020 0" "01jan2021 12mar2021 0" "14mar2021 30jun2021 1" ///
                "01jul2021 31dec2021 1" "01jan2022 31dec2022 1" "01jan2023 31dec2023 1" {
    tokenize `span'
    summarize n_trips if weekend == 1 & inrange(date, td(`1'), td(`2')), meanonly
    local we = r(mean)
    summarize n_trips if weekend == 0 & inrange(date, td(`1'), td(`2')), meanonly
    post `rp' (td(`1')) (td(`2')) (`we' / r(mean)) (`3')
}
postclose `rp'

* weekly series for Figure 6 (the reform day excluded)
drop if date == `P' | date < td(25feb2019)
gen wk_start = date - dow + 1                       // Monday of the week
format wk_start %tdCCYY-NN-DD
gen trips_we = n_trips if weekend == 1
gen trips_wd = n_trips if weekend == 0
collapse (mean) weekend_trips = trips_we weekday_trips = trips_wd (count) nw = trips_we nd = trips_wd, by(wk_start)
keep if nw >= 1 & nd >= 3
gen ratio = weekend_trips / weekday_trips
export delimited using "$estimates/weekly_ratio.csv", replace

use "$tmp/ratio_by_period.dta", clear
format from to %tdCCYY-NN-DD
export delimited using "$estimates/ratio_by_period.csv", replace
list, noobs

* ---- Table A12 ----------------------------------------------------------------------------------------
file open tab using "$tables/tableA12_persistence.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{6.60cm}*{3}{>{\centering\arraybackslash}p{2.20cm}}@{}}" _n
file write tab "\toprule" _n "Period & Estimate & Std.\ error & Implied change (\%) \\" _n "\midrule" _n
file write tab "\multicolumn{4}{@{}l}{\textit{Panel A. Weekend \$\times\$ period estimates}} \\" _n
local lab1 "Weeks 0 to 7 after the reform"
local lab2 "Rest of 2021"
local lab3 "2022"
local lab4 "2023"
forvalues k = 1/4 {
    estcell `b`k'' `se`k'' `p`k'' 3
    local e "`r(b)'"
    local s "`r(se)'"
    local v = 100 * (exp(`b`k'') - 1)
    fmtnum `v' 1
    file write tab "`lab`k'' & `e' & `s' & `r(s)' \\" _n
}
file write tab "\midrule" _n "\multicolumn{4}{@{}l}{\textit{Panel B. Weekend-to-weekday ratio of mean daily trips}} \\" _n
file write tab " & Ratio & Weekend access & \\" _n
forvalues i = 1/`=_N' {
    * "25 February to 31 December 2019" (same year) or "... 2020 to ... 2021"
    local f = from[`i']
    local t = to[`i']
    local fd = string(day(`f')) + " " + word("`c(Months)'", month(`f'))
    local td = string(day(`t')) + " " + word("`c(Months)'", month(`t'))
    if year(`f') == year(`t') local lab "`fd' to `td' `=year(`t')'"
    else local lab "`fd' `=year(`f')' to `td' `=year(`t')'"
    local r = string(ratio[`i'], "%5.3f")
    local access = cond(paid[`i'] == 1, "Priced", "Free")
    file write tab "`lab' & `r' & `access' &  \\" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

log close
