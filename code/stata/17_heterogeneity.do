* 17_heterogeneity.do
* Heterogeneity by rider sex and age (Table A10) and by station commuting profile (Table A11).
*
* Each group series is a daily count of trips; the preferred specification is estimated separately for
* each group (Newey-West, lag 14). Differences between two groups are estimated on the daily contrast
* log(trips of group 1) - log(trips of group 2), with the same regressors and standard errors. The joint
* test of equal effects across the four age groups uses a stacked group x day regression in which every
* group has its own week effects, day-of-week effects and weather coefficients, with Driscoll-Kraay
* standard errors (lag 14), which allow for correlation across groups within a day and over time.
*
*   Sex, preferred specification:   trip-record gender (Ecobici trip files)
*   Sex, calendar controls only:    registry gender of the user (linked through the user id)
*   Age:                            registry age of the user; groups 16-24, 25-34, 35-49, 50+
*   Commuting profile:              trips starting at the 100 more and the 100 less commuter-oriented
*                                   stable stations (08_stations.do)
*
* Input : data/analysis/ecobici_daily_2019_2023.dta, data/intermediate/trips_2021.dta, user_day.dta,
*         registry.dta, station_profile.dta, station_distances.dta
* Output: output/tables/tableA10_heterogeneity.tex, tableA11_spatial.tex

capture log close
log using "$logs/17_heterogeneity.log", replace text

local weather "prcp_mm rain_day tmax_c c.tmax_c#c.tmax_c"   // SMN weather is complete (CAF-007): the missing-day indicators are identically zero and leave the controls

* the estimation sample (106 days) and its calendar variables
do "$code/sample.do" 13mar2021 56
keep date tt wk week dow weekend post wknd_post prcp_mm rain_day tmax_c ///
    n_trips n_trips_female n_trips_male
tempfile days
save `days'

* =============================================================================================
* 1. Group series
* =============================================================================================
* age groups (registry age) and registry gender: trips on the sample days of 2021
use uid date using "$inter/trips_2021.dta", clear
merge m:1 date using `days', keep(match) nogenerate keepusing(date)
count
local all_trips = r(N)
merge m:1 uid using "$inter/registry.dta", keep(master match) nogenerate keepusing(age_group sex)
count if !missing(age_group)
local cov_age = 100 * r(N) / `all_trips'
preserve
keep if !missing(age_group)
collapse (count) trips_age = uid, by(date age_group)
reshape wide trips_age, i(date) j(age_group)
tempfile age
save `age'
restore
keep if inlist(sex, "FEMALE", "MALE")
gen reg_female = sex == "FEMALE"
gen reg_male = sex == "MALE"
collapse (sum) reg_female reg_male, by(date)
tempfile regsex
save `regsex'

* commuting-profile groups: trips starting at the stable stations
use st_o date using "$inter/trips_2021.dta", clear
merge m:1 date using `days', keep(match) nogenerate keepusing(date)
rename st_o station
merge m:1 station using "$inter/station_profile.dta", keep(match) nogenerate keepusing(more_commuter)
gen trips_more = more_commuter == 1
gen trips_less = more_commuter == 0
collapse (sum) trips_more trips_less, by(date)
tempfile profile
save `profile'

use `days', clear
merge 1:1 date using `age', nogenerate
merge 1:1 date using `regsex', nogenerate
merge 1:1 date using `profile', nogenerate
sort date
quietly tsset tt
forvalues g = 1/4 {
    replace trips_age`g' = 0 if missing(trips_age`g')
}
foreach v in n_trips_female n_trips_male trips_age1 trips_age2 trips_age3 trips_age4 reg_female reg_male trips_more trips_less {
    gen log_`v' = ln(`v')
}
summarize n_trips_female, meanonly
local f = r(sum)
summarize n_trips_male, meanonly
local m = r(sum)
summarize n_trips, meanonly
local cov_sex = 100 * (`f' + `m') / r(sum)
display "Coverage: trip-record gender " %5.1f `cov_sex' "%, registry age " %5.1f `cov_age' "%"

* =============================================================================================
* 2. Estimates
* =============================================================================================
* preferred specification for each group series (normal reference distribution for the stars)
foreach v in n_trips_female n_trips_male trips_age1 trips_age2 trips_age3 trips_age4 trips_more trips_less {
    newey log_`v' wknd_post i.week i.dow `weather', lag(14)
    local b_`v' = _b[wknd_post]
    local se_`v' = _se[wknd_post]
    local p_`v' = 2 * normal(-abs(_b[wknd_post] / _se[wknd_post]))
}
* calendar controls only (week and day-of-week fixed effects)
foreach v in reg_female reg_male trips_age1 trips_age2 trips_age3 trips_age4 {
    newey log_`v' wknd_post i.week i.dow, lag(14)
    local bc_`v' = _b[wknd_post]
    local sec_`v' = _se[wknd_post]
    local pc_`v' = 2 * ttail(e(df_r), abs(_b[wknd_post] / _se[wknd_post]))
}
* two-group differences: daily contrast series
gen d_sex = log_n_trips_female - log_n_trips_male
gen d_profile = log_trips_less - log_trips_more
foreach d in sex profile {
    newey d_`d' wknd_post i.week i.dow `weather', lag(14)
    local b_d_`d' = _b[wknd_post]
    local se_d_`d' = _se[wknd_post]
    local p_d_`d' = 2 * ttail(e(df_r), abs(_b[wknd_post] / _se[wknd_post]))
    local F_d_`d' = (_b[wknd_post] / _se[wknd_post])^2
}

* joint test of equal effects across the four age groups: stacked group x day regression,
* Driscoll-Kraay standard errors
preserve
keep date tt wk dow wknd_post prcp_mm rain_day tmax_c log_trips_age*
reshape long log_trips_age, i(date) j(grp)
gen tmax_sq = tmax_c^2
forvalues g = 1/4 {
    gen treat_g`g' = wknd_post * (grp == `g')
    foreach v in prcp_mm rain_day tmax_c tmax_sq {
        gen `v'_g`g' = `v' * (grp == `g')
    }
}
egen grp_wk = group(grp wk)
egen grp_dow = group(grp dow)
quietly tab grp_wk, generate(gw_)
quietly tab grp_dow, generate(gd_)
xtset grp tt
xtscc log_trips_age treat_g* prcp_mm_g* rain_day_g* tmax_c_g* tmax_sq_g* gw_* gd_*, lag(14)
test treat_g1 = treat_g2 = treat_g3 = treat_g4
local F_age = r(F)
local p_age = r(p)
restore

* =============================================================================================
* 3. Station-day panel (within-day comparison of the two station groups)
* =============================================================================================
preserve
use st_o date using "$inter/trips_2021.dta", clear
merge m:1 date using `days', keep(match) nogenerate keepusing(date)
rename st_o station
merge m:1 station using "$inter/station_profile.dta", keep(match) nogenerate keepusing(station)
gen trips = 1
collapse (sum) trips, by(station date)
fillin station date
replace trips = 0 if missing(trips)
drop _fillin
merge m:1 date using `days', nogenerate keepusing(weekend post wknd_post)
merge m:1 station using "$inter/station_profile.dta", nogenerate keepusing(more_commuter)
gen less = more_commuter == 0
gen wknd_post_less = wknd_post * less
gen weekend_less = weekend * less
gen post_less = post * less
count
ppmlhdfe trips wknd_post_less weekend_less post_less, absorb(station date) vce(cluster station date)
local b_sd = _b[wknd_post_less]
local se_sd = _se[wknd_post_less]
local p_sd = 2 * normal(-abs(_b[wknd_post_less] / _se[wknd_post_less]))
gen log1p_trips = ln(1 + trips)
reghdfe log1p_trips wknd_post_less weekend_less post_less, absorb(station date) vce(cluster station date)
local b_sl = _b[wknd_post_less]
local se_sl = _se[wknd_post_less]
local p_sl = 2 * ttail(e(df_r), abs(_b[wknd_post_less] / _se[wknd_post_less]))
restore

* =============================================================================================
* Table A10
* =============================================================================================
file open tab using "$tables/tableA10_heterogeneity.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc@{}}" _n "\toprule" _n
file write tab " & \multicolumn{2}{c}{Preferred specification} & \multicolumn{2}{c}{Calendar controls only} \\" _n
file write tab "\cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write tab " & Estimate & Implied change (\%) & Estimate & Implied change (\%) \\" _n "\midrule" _n
local c = string(`cov_sex', "%4.1f")
file write tab "\multicolumn{5}{@{}l}{\textit{Panel A. Sex (trip-record gender, `c'\% of trips)}} \\" _n
* series for the preferred column, for the calendar-only column, and row labels
local pref "n_trips_female n_trips_male trips_age1 trips_age2 trips_age3 trips_age4"
local cal  "reg_female reg_male trips_age1 trips_age2 trips_age3 trips_age4"
local labs `" "Women" "Men" "16--24" "25--34" "35--49" "50 and over" "'
forvalues i = 1/6 {
    local v   : word `i' of `pref'
    local vc  : word `i' of `cal'
    local lab : word `i' of `labs'
    if `i' == 3 {
        local c = string(`cov_age', "%4.1f")
        file write tab "\midrule" _n "\multicolumn{5}{@{}l}{\textit{Panel B. Age (registry linkage, `c'\% of trips)}} \\" _n
    }
    estcell `b_`v'' `se_`v'' `p_`v'' 3
    local e1 "`r(b)'"
    local s1 "`r(se)'"
    local x = 100 * (exp(`b_`v'') - 1)
    fmtnum `x' 1
    local x1 "`r(s)'"
    estcell `bc_`vc'' `sec_`vc'' `pc_`vc'' 3
    local e2 "`r(b)'"
    local s2 "`r(se)'"
    local x = 100 * (exp(`bc_`vc'') - 1)
    fmtnum `x' 1
    file write tab "`lab' & `e1' & `x1' & `e2' & `r(s)' \\" _n " & `s1' &  & `s2' &  \\" _n
    if "`v'" == "n_trips_male" {
        estcell `b_d_sex' `se_d_sex' `p_d_sex' 3
        file write tab "Women \$-\$ men & `r(b)' &  &  &  \\" _n " & `r(se)' &  &  &  \\" _n
        local F = string(`F_d_sex', "%4.2f")
        local p = cond(`p_d_sex' < 0.001, "\(p < 0.001\)", "\(p = " + string(`p_d_sex', "%5.3f") + "\)")
        file write tab "Test of equality & \multicolumn{2}{c}{\(F = `F'\), `p'} & & \\" _n
    }
}
local F = string(`F_age', "%4.2f")
local p = cond(`p_age' < 0.001, "\(p < 0.001\)", "\(p = " + string(`p_age', "%5.3f") + "\)")
file write tab "Joint test of equality & \multicolumn{2}{c}{\(F = `F'\), `p'} & & \\" _n
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* =============================================================================================
* Table A11
* =============================================================================================
use "$inter/station_profile.dta", clear
correlate commuter_score weekend_share
local cor = r(rho)
collapse (count) stations = station (mean) am_share dir_reversal commuter_score weekend_share, by(more_commuter)
foreach v in stations am_share dir_reversal commuter_score weekend_share {
    forvalues g = 0/1 {
        summarize `v' if more_commuter == `g', meanonly
        local `v'`g' = r(mean)
    }
}
use "$inter/station_distances.dta", clear
gen within500 = d_interchange <= 500
foreach v in d_subte d_interchange d_rail d_railhub {
    forvalues g = 0/1 {
        summarize `v' if more_commuter == `g', detail
        * whole metres, truncated as in the original tables
        local `v'`g' = string(floor(r(p50)), "%9.0f")
    }
}
forvalues g = 0/1 {
    summarize within500 if more_commuter == `g', meanonly
    local w500`g' = string(r(mean), "%4.2f")
}

file open tab using "$tables/tableA11_spatial.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{7.00cm}*{2}{>{\centering\arraybackslash}p{3.30cm}}@{}}" _n
file write tab "\toprule" _n " & More commuter-oriented & Less commuter-oriented \\" _n "\midrule" _n
file write tab "\multicolumn{3}{@{}l}{\textit{Panel A. Pre-reform classification inputs, weekday trips}} \\" _n
file write tab "Stations & `stations1' & `stations0' \\" _n
foreach v in am_share dir_reversal commuter_score weekend_share {
    if "`v'" == "am_share"       local lab "Morning peak share, 07:00--09:59"
    if "`v'" == "dir_reversal"   local lab "Morning-to-evening directional reversal"
    if "`v'" == "commuter_score" local lab "Commuting score"
    if "`v'" == "weekend_share"  local lab "Pre-reform weekend share of activity"
    fmtnum ``v'1' 3
    local c1 "`r(s)'"
    fmtnum ``v'0' 3
    file write tab "`lab' & `c1' & `r(s)' \\" _n
}
fmtnum `cor' 3
file write tab "Correlation of score with weekend share & \multicolumn{2}{c}{`r(s)'} \\" _n "\addlinespace[3pt]" _n
file write tab "Median distance to a Subte station (m) & `d_subte1' & `d_subte0' \\" _n
file write tab "Median distance to a Subte interchange (m) & `d_interchange1' & `d_interchange0' \\" _n
file write tab "Within 500 m of a Subte interchange (share) & `w5001' & `w5000' \\" _n
file write tab "Median distance to the Retiro rail complex (m) & `d_railhub1' & `d_railhub0' \\" _n
file write tab "Median distance to any city rail station (m) & `d_rail1' & `d_rail0' \\" _n
file write tab "\midrule" _n "\multicolumn{3}{@{}l}{\textit{Panel B. Effects on weekend trip origins}} \\" _n
estcell `b_trips_more' `se_trips_more' `p_trips_more' 3
local e1 "`r(b)'"
local s1 "`r(se)'"
estcell `b_trips_less' `se_trips_less' `p_trips_less' 3
file write tab "Weekend \$\times\$ Post, group series & `e1' & `r(b)' \\" _n " & `s1' & `r(se)' \\" _n
local x = 100 * (exp(`b_trips_more') - 1)
fmtnum `x' 1
local x1 "`r(s)'"
local x = 100 * (exp(`b_trips_less') - 1)
fmtnum `x' 1
file write tab "Implied change (\%) & `x1' & `r(s)' \\" _n
estcell `b_d_profile' `se_d_profile' `p_d_profile' 3
file write tab "Less \$-\$ more, group series & \multicolumn{2}{c}{`r(b)'} \\" _n " & \multicolumn{2}{c}{`r(se)'} \\" _n
local F = string(`F_d_profile', "%5.2f")
local p = cond(`p_d_profile' < 0.001, "\(p < 0.001\)", "\(p = " + string(`p_d_profile', "%5.3f") + "\)")
file write tab "Test of equality & \multicolumn{2}{c}{\(F = `F'\), `p'} \\" _n
estcell `b_sd' `se_sd' `p_sd' 3
file write tab "Less \$-\$ more, station-day Poisson & \multicolumn{2}{c}{`r(b)'} \\" _n " & \multicolumn{2}{c}{`r(se)'} \\" _n
estcell `b_sl' `se_sl' `p_sl' 3
file write tab "Less \$-\$ more, station-day log(1+trips) & \multicolumn{2}{c}{`r(b)'} \\" _n " & \multicolumn{2}{c}{`r(se)'} \\" _n
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

log close
