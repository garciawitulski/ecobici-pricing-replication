* 11_main.do
* Table 1 (descriptive statistics) and Table 2 (main estimates, alternative windows and inference).
*
* Preferred specification (column 3 of Table 2):
*   log(trips_d) = beta Weekend_d x Post_d + week FE + day-of-week FE + weather_d + e_d
* estimated by OLS on the 106 non-holiday days within 8 weeks of 13 March 2021. Standard errors are
* Newey-West with a Bartlett kernel and a lag of 14 days.
*
* Input : data/analysis/ecobici_daily_primary.dta, data/analysis/ecobici_daily_2019_2023.dta
* Output: output/tables/table1_descriptives.tex, output/tables/table2_main.tex

capture log close
log using "$logs/11_main.log", replace text

local weather "prcp_mm rain_day tmax_c c.tmax_c#c.tmax_c"   // SMN weather is complete (CAF-007): the missing-day indicators are identically zero and leave the controls

* =============================================================================================
* Table 1. Descriptive statistics, reform window
* =============================================================================================
use "$analysis/ecobici_daily_primary.dta", clear
gen minutes_k = total_minutes / 1000

local vars   n_trips n_users minutes_k median_dur_min share_gt30min n_stations_any prcp_mm tmax_c
local digits 0 0 1 1 3 1 1 1
local labels `" "Trips per day" "Unique users per day" "Minutes ridden per day (thousands)" "Median trip duration (minutes)" "Share of trips longer than 30 minutes" "Stations with at least one trip" "Precipitation (mm)" "Maximum temperature (\(^{\circ}\)C)" "'
* (\( \) is LaTeX inline math, like $ $; a $ followed by a letter would be read by Stata as a global)

file open tab using "$tables/table1_descriptives.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc@{}}" _n "\toprule" _n
file write tab " & \multicolumn{2}{c}{Weekends} & \multicolumn{2}{c}{Weekdays} \\" _n
file write tab "\cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n " & Before & After & Before & After \\" _n "\midrule" _n
forvalues i = 1/8 {
    local v   : word `i' of `vars'
    local d   : word `i' of `digits'
    local lab : word `i' of `labels'
    local line "`lab'"
    foreach w in 1 0 {
        foreach p in 0 1 {
            summarize `v' if weekend == `w' & post == `p', meanonly
            fmtnum `r(mean)' `d'
            local line "`line' & `r(s)'"
        }
    }
    file write tab "`line' \\" _n
}
file write tab "\midrule" _n
local days "Days"
local total "Total trips"
foreach w in 1 0 {
    foreach p in 0 1 {
        summarize n_trips if weekend == `w' & post == `p'
        local days "`days' & `r(N)'"
        fmtnum `r(sum)' 0
        local total "`total' & `r(s)'"
    }
}
file write tab "`days' \\" _n "`total' \\" _n "\bottomrule" _n "\end{tabular*}" _n
file close tab

* numbers quoted in the text: raw means and the descriptive ratio of ratios
foreach w in 1 0 {
    foreach p in 0 1 {
        summarize n_trips if weekend == `w' & post == `p', meanonly
        local m`w'`p' = r(mean)
    }
}
display "Weekend trips per day: before " %9.1f `m10' ", after " %9.1f `m11' " (" %5.1f 100 * (`m11' / `m10' - 1) "%)"
display "Weekday trips per day: before " %9.1f `m00' ", after " %9.1f `m01' " (" %5.1f 100 * (`m01' / `m00' - 1) "%)"
display "Ratio of ratios (descriptive): " %6.1f 100 * ((`m11' / `m10') / (`m01' / `m00') - 1) "%"
display "Raw difference in differences (trips per day): " %9.0f (`m11' - `m10') - (`m01' - `m00')
local weekend_pre_mean = `m10'

* =============================================================================================
* Table 2. Main estimates
* =============================================================================================
do "$code/sample.do" 13mar2021 56

* (1) no fixed effects, (2) week and day-of-week fixed effects, (3) + weather: log(trips)
newey log_trips weekend post wknd_post, lag(14)
local b1 = _b[wknd_post]
local se1 = _se[wknd_post]
local p1 = 2 * ttail(e(df_r), abs(`b1' / `se1'))

newey log_trips wknd_post i.week i.dow, lag(14)
local b2 = _b[wknd_post]
local se2 = _se[wknd_post]
local p2 = 2 * ttail(e(df_r), abs(`b2' / `se2'))

newey log_trips wknd_post i.week i.dow `weather', lag(14)
local b3 = _b[wknd_post]
local se3 = _se[wknd_post]
local df3 = e(df_r)
local p3 = 2 * ttail(e(df_r), abs(`b3' / `se3'))
local n3 = e(N)

* (4) trips per day (levels), same specification as (3)
newey n_trips wknd_post i.week i.dow `weather', lag(14)
local b4 = _b[wknd_post]
local se4 = _se[wknd_post]
local p4 = 2 * ttail(e(df_r), abs(`b4' / `se4'))

* the preferred estimate, saved for Figure 4 and quoted in the text
preserve
clear
set obs 1
gen estimate = `b3'
gen se = `se3'
export delimited using "$estimates/main_estimate.csv", replace
restore
display "Preferred estimate: " %12.10f `b3' " (NW-14 SE " %12.10f `se3' "), t = " %8.4f `b3' / `se3' ", df = " `df3' ", p = " %10.4e `p3'
display "95% CI: [" %8.4f `b3' - invttail(`df3', 0.025) * `se3' ", " %8.4f `b3' + invttail(`df3', 0.025) * `se3' "]"
display "Implied change: " %8.4f 100 * (exp(`b3') - 1) "%, 95% CI [" %6.1f 100 * (exp(`b3' - invttail(`df3', 0.025) * `se3') - 1) ", " %6.1f 100 * (exp(`b3' + invttail(`df3', 0.025) * `se3') - 1) "]"
display "Levels: " %9.1f `b4' " trips per day (SE " %6.1f `se4' "), " %5.1f 100 * `b4' / `weekend_pre_mean' "% of the pre-reform weekend mean"
display "95% CI levels: [" %9.0f `b4' - invttail(`df3', 0.025) * `se4' ", " %9.0f `b4' + invttail(`df3', 0.025) * `se4' "]"

* Panel C: alternative inference for column (3)
foreach L in 7 21 28 {
    newey log_trips wknd_post i.week i.dow `weather', lag(`L')
    local se_nw`L' = _se[wknd_post]
}
regress log_trips wknd_post i.week i.dow `weather', vce(robust)
local se_hc1 = _se[wknd_post]
regress log_trips wknd_post i.week i.dow `weather', vce(cluster wk)
local se_cl = _se[wknd_post]
local n_cl = e(N_clust)
* wild cluster bootstrap-t (week clusters): Rademacher weights, null imposed, 9,999 replications.
* Each replication flips the sign of the null-model residuals of a whole week at random, rebuilds
* the outcome and re-estimates the clustered t statistic.
local t_obs = _b[wknd_post] / _se[wknd_post]
regress log_trips i.week i.dow `weather'
predict double y_null, xb
predict double u_null, residuals
set seed 20210313
local reps = 9999
local exceed = 0
forvalues r = 1/`reps' {
    quietly {
        bysort wk: gen w = cond(runiform() < 0.5, -1, 1) if _n == 1
        bysort wk: replace w = w[1]
        gen y_star = y_null + w * u_null
        regress y_star wknd_post i.week i.dow `weather', vce(cluster wk)
        if abs(_b[wknd_post] / _se[wknd_post]) >= abs(`t_obs') local ++exceed
        drop w y_star
    }
}
sort tt
local p_boot = (`exceed' + 1) / (`reps' + 1)
display "Wild cluster bootstrap: `exceed' of `reps' replications exceed |t|; p = " %8.6f `p_boot'

* Robustness quoted in the text: log(1 + trips) and Poisson, same fixed effects and weather controls
newey log1p_trips wknd_post i.week i.dow `weather', lag(14)
ppmlhdfe n_trips wknd_post `weather', absorb(week dow) vce(robust)
display "Poisson: " %8.4f _b[wknd_post] " (" %5.1f 100 * (exp(_b[wknd_post]) - 1) "%)"

* Robustness to the weather gauge (quoted in the appendix): Aeroparque records in place of the
* Observatorio, same specification
newey log_trips wknd_post i.week i.dow prcp_mm_aero rain_day_aero tmax_c_aero ///
    c.tmax_c_aero#c.tmax_c_aero, lag(14)
display "Aeroparque gauge: " %8.4f _b[wknd_post] " (NW-14 SE " %6.4f _se[wknd_post] "), " ///
    %5.1f 100 * (exp(_b[wknd_post]) - 1) "%"

* Panel B: alternative windows, specification (3)
foreach h in 28 42 84 112 {
    do "$code/sample.do" 13mar2021 `h'
    newey log_trips wknd_post i.week i.dow `weather', lag(14)
    local bw`h' = _b[wknd_post]
    local sew`h' = _se[wknd_post]
    local pw`h' = 2 * ttail(e(df_r), abs(`bw`h'' / `sew`h''))
    local nw`h' = e(N)
}

* ---- write Table 2 -------------------------------------------------------------------------------
file open tab using "$tables/table2_main.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc@{}}" _n "\toprule" _n
file write tab " & (1) & (2) & (3) & (4) \\" _n
file write tab " & \multicolumn{3}{c}{\$\log(\text{trips})\$} & Trips per day \\" _n
file write tab "\cmidrule(lr){2-4}\cmidrule(lr){5-5}" _n
file write tab "\multicolumn{5}{@{}l}{\textit{Panel A. Main estimates}} \\" _n
local est "Weekend \$\times\$ Post"
local se ""
local pct "Implied change (\%)"
forvalues j = 1/4 {
    local d = cond(`j' == 4, 0, 3)
    estcell `b`j'' `se`j'' `p`j'' `d'
    local est "`est' & `r(b)'"
    local se "`se' & `r(se)'"
    local v = 100 * (exp(`b`j'') - 1)
    if `j' == 4 local v = 100 * `b4' / `weekend_pre_mean'
    fmtnum `v' 1
    local pct "`pct' & `r(s)'"
}
file write tab "`est' \\" _n "`se' \\" _n "`pct' \\" _n "\addlinespace[3pt]" _n
file write tab "Week fixed effects & No & Yes & Yes & Yes \\" _n
file write tab "Day-of-week fixed effects & No & Yes & Yes & Yes \\" _n
file write tab "Weather controls & No & No & Yes & Yes \\" _n
file write tab "Observations (days) & `n3' & `n3' & `n3' & `n3' \\" _n
file write tab "\midrule" _n
file write tab "\multicolumn{5}{@{}l}{\textit{Panel B. Alternative estimation windows, specification (3)}} \\" _n
file write tab " & \$\pm\$4 weeks & \$\pm\$6 weeks & \$\pm\$12 weeks & \$\pm\$16 weeks \\" _n
local est "Weekend \$\times\$ Post"
local se ""
local obs "Observations (days)"
foreach h in 28 42 84 112 {
    estcell `bw`h'' `sew`h'' `pw`h'' 3
    local est "`est' & `r(b)'"
    local se "`se' & `r(se)'"
    local obs "`obs' & `nw`h''"
}
file write tab "`est' \\" _n "`se' \\" _n "`obs' \\" _n "\midrule" _n
file write tab "\multicolumn{5}{@{}l}{\textit{Panel C. Alternative inference, specification (3)}} \\" _n
foreach L in 7 21 28 {
    local s = string(`se_nw`L'', "%5.3f")
    file write tab "Newey--West, lag of `L' days &  &  & (`s') &  \\" _n
}
local s = string(`se_cl', "%5.3f")
file write tab "Clustered by week (`n_cl' clusters) &  &  & (`s') &  \\" _n
local s = string(`se_hc1', "%5.3f")
file write tab "Heteroskedasticity-robust (HC1) &  &  & (`s') &  \\" _n
if `p_boot' < 0.001 local s "\$<\$0.001"
else local s = string(`p_boot', "%5.3f")
file write tab "Wild cluster bootstrap-\$t\$, \$p\$-value &  &  & `s' &  \\" _n
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

log close
