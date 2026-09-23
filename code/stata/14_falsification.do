* 14_falsification.do
* Falsification tests, alternative designs and alternative outcomes.
*   - false thresholds and a pseudo-treatment, preferred specification (Table A5, Panel B)
*   - difference in discontinuities, local linear in event time (Table A5, Panel A)
*   - triple difference against the same weeks of 2022 and 2023 (Table A5, Panel C; Table 3)
*   - placebo distributions over Saturday thresholds (Table A4, Table 3, Figure 4a)
*   - other daily outcomes, preferred specification (Table A8, Table 3)
*   - Table 3, which also reads the causal-horizon results of 13_parallel_trends.do
* Standard errors: Newey-West, lag 14.
*
* Input : data/analysis/ecobici_daily_2019_2023.dta, output/estimates/parallel_trends.csv,
*         output/estimates/parallel_trends_breakdown.csv
* Output: output/tables/table3_identification.tex, tableA4_placebo.tex, tableA5_falsification.tex,
*         tableA8_outcomes.tex; output/estimates/placebo_distribution.csv (Figure 4a)

capture log close
log using "$logs/14_falsification.log", replace text

local weather "prcp_mm rain_day tmax_c c.tmax_c#c.tmax_c prcp_missing temp_missing"

* the preferred estimate, the benchmark for every placebo
do "$code/sample.do" 13mar2021 56
newey log_trips wknd_post i.week i.dow `weather', lag(14)
local beta = _b[wknd_post]

* =============================================================================================
* 1. False thresholds and pseudo-treatment, preferred specification
* =============================================================================================
* (1) same weeks of 2022, (2) same weeks of 2023, (3) 4 weeks early, (4) 8 weeks early
local k = 0
foreach spec in "12mar2022 56 ." "11mar2023 56 ." "13feb2021 28 12mar2021" "16jan2021 28 12mar2021" {
    local ++k
    tokenize `spec'
    do "$code/sample.do" `1' `2' . `3'
    newey log_trips wknd_post i.week i.dow `weather', lag(14)
    local pl_b`k' = _b[wknd_post]
    local pl_se`k' = _se[wknd_post]
    local pl_p`k' = 2 * ttail(e(df_r), abs(_b[wknd_post] / _se[wknd_post]))
    local pl_n`k' = e(N)
}
* (5) local linear design at a false threshold before the reform (13 February 2021)
do "$code/sample.do" 13feb2021 28 . 12mar2021
gen wp = weekend * post
gen wt = weekend * t
gen pt = post * t
gen wpt = weekend * post * t
newey log_trips post t wp wt pt wpt i.dow `weather', lag(14)
local pl_b5 = _b[wp]
local pl_se5 = _se[wp]
local pl_p5 = 2 * ttail(e(df_r), abs(_b[wp] / _se[wp]))
local pl_n5 = e(N)
* (6) Fridays against Mondays to Thursdays, weekdays only
do "$code/sample.do" 13mar2021 56
keep if weekend == 0
drop tt
gen tt = _n
quietly tsset tt
gen fri_post = (dow == 5) * post
newey log_trips fri_post i.week i.dow `weather', lag(14)
local pl_b6 = _b[fri_post]
local pl_se6 = _se[fri_post]
local pl_p6 = 2 * ttail(e(df_r), abs(_b[fri_post] / _se[fri_post]))
local pl_n6 = e(N)
forvalues k = 1/6 {
    display "Placebo `k': " %7.4f `pl_b`k'' " (SE " %6.4f `pl_se`k'' ", p = " %6.4f `pl_p`k'' ", n = " `pl_n`k'' ")"
}

* =============================================================================================
* 2. Difference in discontinuities (week fixed effects replaced by local linear trends in event
*    time on each side of the threshold, separately for weekends and weekdays)
* =============================================================================================
* The triangular kernel weights each day by w = 1 - |t| / h (weighted least squares; the two end days
* get zero weight and drop out). With the uniform kernel every day has weight 1.
foreach kernel in uniform triangular {
    foreach h in 28 56 112 {
        do "$code/sample.do" 13mar2021 `h'
        gen wp = weekend * post
        gen wt = weekend * t
        gen pt = post * t
        gen wpt = weekend * post * t
        gen w = 1
        if "`kernel'" == "triangular" replace w = 1 - abs(t) / `h'
        newey log_trips post t wp wt pt wpt i.dow [aweight = w], lag(14)
        local dd_b_`kernel'`h' = _b[wp]
        local dd_se_`kernel'`h' = _se[wp]
        local dd_p_`kernel'`h' = 2 * ttail(e(df_r), abs(_b[wp] / _se[wp]))
        local dd_n_`kernel'`h' = e(N)
    }
}

* =============================================================================================
* 3. Triple difference against the same weeks of 2022 and 2023 (year-specific week fixed effects)
* =============================================================================================
foreach cy in 2022 2023 {
    do "$code/sample.do" 13mar2021 56
    gen treated = 1
    tempfile reform
    save `reform'
    if `cy' == 2022 do "$code/sample.do" 12mar2022 56
    if `cy' == 2023 do "$code/sample.do" 11mar2023 56
    gen treated = 0
    append using `reform'
    gsort -treated date                  // the reform year first, then the comparison year
    drop tt
    gen tt = _n
    quietly tsset tt
    egen wk_yr = group(treated wk)
    gen w_p_y = weekend * post * treated
    gen w_p = weekend * post
    gen w_y = weekend * treated
    gen p_y = post * treated
    newey log_trips w_p_y w_p w_y p_y weekend i.wk_yr i.dow, lag(14)
    local ddd_b`cy' = _b[w_p_y]
    local ddd_se`cy' = _se[w_p_y]
    local ddd_p`cy' = 2 * ttail(e(df_r), abs(_b[w_p_y] / _se[w_p_y]))
    local ddd_n`cy' = e(N)
}

* =============================================================================================
* 4. Placebo distribution over the Saturdays of 2022 (a year with tariff revisions)
* =============================================================================================
tempname p22
postfile `p22' threshold estimate using "$tmp/placebo_2022.dta", replace
forvalues d = `=td(05mar2022)'(7)`=td(29oct2022)' {
    local ds = string(`d', "%td")
    do "$code/sample.do" `ds' 56
    quietly newey log_trips wknd_post i.week i.dow `weather', lag(14)
    post `p22' (`d') (_b[wknd_post])
}
postclose `p22'
use "$tmp/placebo_2022.dta", clear
summarize estimate
local s22 "`r(N)' `r(mean)' `r(sd)' `r(min)' `r(max)'"
count if estimate <= `beta'
local rank22 = r(N) + 1
display "2022 Saturdays: rank of the reform estimate = `rank22' of " _N + 1

* =============================================================================================
* 5. Clean placebo distribution: Saturdays whose whole +/- 56-day window lies in a span with free
*    access on every day (25 Feb - 31 Dec 2019; 11 May 2020 - 12 Mar 2021) and whose 113 days all
*    have usable data. The rule was fixed before these estimates were run.
* =============================================================================================
tempname pc
postfile `pc' threshold str8 span estimate se n using "$tmp/placebo_clean.dta", replace
foreach span in 2019 2020_21 {
    if "`span'" == "2019" {
        local lo = td(25feb2019)
        local hi = td(31dec2019)
    }
    if "`span'" == "2020_21" {
        local lo = td(11may2020)
        local hi = td(12mar2021)
    }
    forvalues d = `lo'/`hi' {
        if dow(`d') != 6 continue
        if `d' - 56 < `lo' | `d' + 56 > `hi' continue
        use "$analysis/ecobici_daily_2019_2023.dta", clear
        quietly count if inrange(date, `d' - 56, `d' + 56) & !missing(n_trips) & prelaunch_2019 == 0 ///
            & system_suspended_covid == 0 & low_count_day == 0
        if r(N) != 113 continue
        local ds = string(`d', "%td")
        do "$code/sample.do" `ds' 56
        quietly newey log_trips wknd_post i.week i.dow `weather', lag(14)
        post `pc' (`d') ("`span'") (_b[wknd_post]) (_se[wknd_post]) (e(N))
    }
}
postclose `pc'
use "$tmp/placebo_clean.dta", clear
format threshold %tdCCYY-NN-DD
export delimited using "$estimates/placebo_distribution.csv", replace
foreach set in pooled 2019 2020_21 {
    if "`set'" == "pooled" local cond "1"
    else local cond `"span == "`set'""'
    summarize estimate if `cond'
    local sc_`set' "`r(N)' `r(mean)' `r(sd)' `r(min)' `r(max)'"
    count if estimate <= `beta' & `cond'
    local rank_`set' = r(N) + 1
}
summarize estimate
display "Clean placebos: n = " r(N) ", mean = " %6.3f r(mean) ", sd = " %6.3f r(sd) "; reform estimate " %6.3f `beta' " is " %4.1f (r(mean) - `beta') / r(sd) " sd below the mean"

* =============================================================================================
* 6. Other daily outcomes, preferred specification
* =============================================================================================
local outcomes "log_trips log_minutes median_dur_min mean_dur_min log_users female_share log_female log_male n_new_users"
do "$code/sample.do" 13mar2021 56
foreach y of local outcomes {
    newey `y' wknd_post i.week i.dow `weather', lag(14)
    local oc_b_`y' = _b[wknd_post]
    local oc_se_`y' = _se[wknd_post]
    local oc_p_`y' = 2 * ttail(e(df_r), abs(_b[wknd_post] / _se[wknd_post]))
}

* =============================================================================================
* Tables
* =============================================================================================
* ---- Table A4: placebo distributions ---------------------------------------------------------------
file open tab using "$tables/tableA4_placebo.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{4.60cm}*{6}{>{\centering\arraybackslash}p{1.45cm}}@{}}" _n
file write tab "\toprule" _n "Span & Thresholds & Mean & Std.\ dev. & Minimum & Maximum & Rank \\" _n "\midrule" _n
file write tab "\multicolumn{7}{@{}l}{\textit{Panel A. Spans with free access on every day}} \\" _n
foreach set in pooled 2019 2020_21 {
    if "`set'" == "pooled"  local lab "Pooled"
    if "`set'" == "2019"    local lab "25 February to 31 December 2019"
    if "`set'" == "2020_21" local lab "11 May 2020 to 12 March 2021"
    tokenize `sc_`set''
    local line "`lab' & `1'"
    foreach v in `2' `3' `4' `5' {
        fmtnum `v' 3
        local line "`line' & `r(s)'"
    }
    file write tab "`line' & `rank_`set'' of `=`1' + 1' \\" _n
}
file write tab "\midrule" _n "\multicolumn{7}{@{}l}{\textit{Panel B. Saturdays in 2022, a year with tariff revisions}} \\" _n
tokenize `s22'
local line "Saturdays in 2022 & `1'"
foreach v in `2' `3' `4' `5' {
    fmtnum `v' 3
    local line "`line' & `r(s)'"
}
file write tab "`line' & `rank22' of `=`1' + 1' \\" _n "\midrule" _n
fmtnum `beta' 3
file write tab "Estimate at the reform date & `r(s)' &  &  &  &  &  \\" _n "\bottomrule" _n "\end{tabular*}" _n
file close tab

* ---- Table A5: secondary design and falsification estimates ------------------------------------------
file open tab using "$tables/tableA5_falsification.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{7.40cm}*{3}{>{\centering\arraybackslash}p{2.00cm}}@{}}" _n
file write tab "\toprule" _n " & Estimate & Std.\ error & Days \\" _n "\midrule" _n
file write tab "\multicolumn{4}{@{}l}{\textit{Panel A. Difference in discontinuities, equation (3) of the main text}} \\" _n
foreach kernel in uniform triangular {
    foreach h in 28 56 112 {
        local Kname = cond("`kernel'" == "uniform", "Uniform", "Triangular")
        estcell `dd_b_`kernel'`h'' `dd_se_`kernel'`h'' `dd_p_`kernel'`h'' 3
        file write tab "`Kname' kernel, bandwidth of `h' days & `r(b)' & `r(se)' & `dd_n_`kernel'`h'' \\" _n
    }
}
file write tab "\midrule" _n "\multicolumn{4}{@{}l}{\textit{Panel B. False thresholds and pseudo-treatment, preferred specification}} \\" _n
local lab1 "Same weeks of 2022"
local lab2 "Same weeks of 2023, which contain a tariff revision"
local lab3 "Threshold four weeks early, 13 February 2021"
local lab4 "Threshold eight weeks early, 16 January 2021"
local lab5 "Local linear design at 13 February 2021"
local lab6 "Fridays against Mondays to Thursdays"
forvalues k = 1/6 {
    estcell `pl_b`k'' `pl_se`k'' `pl_p`k'' 3
    file write tab "`lab`k'' & `r(b)' & `r(se)' & `pl_n`k'' \\" _n
}
file write tab "\midrule" _n "\multicolumn{4}{@{}l}{\textit{Panel C. Triple difference against the same weeks of a later year}} \\" _n
foreach cy in 2022 2023 {
    estcell `ddd_b`cy'' `ddd_se`cy'' `ddd_p`cy'' 3
    file write tab "Comparison year `cy' & `r(b)' & `r(se)' & `ddd_n`cy'' \\" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* ---- Table A8: other daily outcomes ----------------------------------------------------------------------
file open tab using "$tables/tableA8_outcomes.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{7.60cm}*{2}{>{\centering\arraybackslash}p{3.00cm}}@{}}" _n
file write tab "\toprule" _n "Outcome & Estimate & Std.\ error \\" _n "\midrule" _n
local lab_log_trips "log(trips), as in Table 2, column (3)"
local lab_log_minutes "log(minutes ridden)"
local lab_median_dur_min "Median trip duration (minutes)"
local lab_mean_dur_min "Mean trip duration (minutes)"
local lab_log_users "log(unique users)"
local lab_female_share "Female share of trips"
local lab_log_female "log(trips by women)"
local lab_log_male "log(trips by men)"
local lab_n_new_users "New users per day"
local digits "3 3 2 2 3 4 3 3 1"
local k = 0
foreach y of local outcomes {
    local ++k
    local d : word `k' of `digits'
    estcell `oc_b_`y'' `oc_se_`y'' `oc_p_`y'' `d'
    file write tab "`lab_`y'' & `r(b)' & `r(se)' \\" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* ---- Table 3: identification, falsification and alternative outcomes ------------------------------------
import delimited using "$estimates/parallel_trends_breakdown.csv", varnames(1) clear
tempfile bd
save `bd'
import delimited using "$estimates/parallel_trends.csv", varnames(1) clear

file open tab using "$tables/table3_identification.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{4.60cm}*{4}{>{\centering\arraybackslash}p{2.30cm}}@{}}" _n
file write tab "\toprule" _n "\multicolumn{5}{@{}l}{\textit{Panel A. Causal horizon, preferred event study}} \\" _n
file write tab " & Estimate & Implied change (\%) & Robust set, \$\bar{M} = 1\$ & Breakdown \$\bar{M}\$ \\" _n
file write tab "\cmidrule(lr){2-5}" _n
local lab1 "Week 0, Sunday 14 March only"
local lab2 "Week 1, first full treated weekend"
local lab3 "Weeks 0 and 1 averaged"
local lab5 "Weeks 0 to 7 averaged"
local lab6 "\quad Same, weekend-specific weather"
foreach j in 1 2 3 5 6 {
    local variant = cond(`j' == 6, "wxint", "weather")
    local target = cond(`j' == 6, 3, `j')
    if `j' == 6 file write tab "\addlinespace[3pt]" _n
    * baseline estimate; its standard error is recovered from the 95 per cent interval
    summarize estimate if variant == "`variant'" & framework == "baseline" & target == `target', meanonly
    local est = r(mean)
    summarize lb if variant == "`variant'" & framework == "baseline" & target == `target', meanonly
    local lb = r(mean)
    summarize ub if variant == "`variant'" & framework == "baseline" & target == `target', meanonly
    local se = (r(mean) - `lb') / (2 * 1.96)
    summarize df if variant == "`variant'" & framework == "baseline" & target == `target', meanonly
    local p = 2 * ttail(r(mean), abs(`est' / `se'))
    estcell `est' `se' `p' 3
    local c1 "`r(b)'"
    local s1 "`r(se)'"
    local v = 100 * (exp(`est') - 1)
    fmtnum `v' 1
    local c2 "`r(s)'"
    summarize lb if variant == "`variant'" & framework == "rm" & target == `target' & abs(mbar - 1) < 1e-9, meanonly
    fmtnum `r(mean)' 2
    local l "`r(s)'"
    summarize ub if variant == "`variant'" & framework == "rm" & target == `target' & abs(mbar - 1) < 1e-9, meanonly
    fmtnum `r(mean)' 2
    local c3 "[`l', `r(s)']"
    preserve
    use `bd', clear
    levelsof breakdown if variant == "`variant'" & framework == "rm" & target == `target', local(c4) clean
    restore
    file write tab "`lab`j'' & `c1' & `c2' & `c3' & `c4' \\" _n " & `s1' &  &  &  \\" _n
}
file write tab "\midrule" _n "\multicolumn{5}{@{}l}{\textit{Panel B. Falsification and comparison}} \\" _n
file write tab " & Thresholds & Mean & Std.\ dev. & Rank of estimate \\" _n "\cmidrule(lr){2-5}" _n
foreach set in pooled 2020_21 {
    local lab = cond("`set'" == "pooled", "Free-access placebo thresholds", "\quad May 2020 to 12 March 2021")
    tokenize `sc_`set''
    fmtnum `2' 3
    local m "`r(s)'"
    fmtnum `3' 3
    file write tab "`lab' & `1' & `m' & `r(s)' & `rank_`set'' of `=`1' + 1' \\" _n
}
file write tab "\addlinespace[4pt]" _n " & Fridays vs Mon.--Thu. & Triple difference, 2022 & & \\" _n "\cmidrule(lr){2-3}" _n
estcell `pl_b6' `pl_se6' `pl_p6' 3
local c1 "`r(b)'"
local s1 "`r(se)'"
estcell `ddd_b2022' `ddd_se2022' `ddd_p2022' 3
file write tab "Estimate & `c1' & `r(b)' &  &  \\" _n " & `s1' & `r(se)' &  &  \\" _n
file write tab "Observations (days) & `pl_n6' & `ddd_n2022' &  &  \\" _n "\midrule" _n
file write tab "\multicolumn{5}{@{}l}{\textit{Panel C. Alternative outcomes, preferred specification}} \\" _n
file write tab " & Unique users (log) & Minutes ridden (log) & Median duration (min) & New users per day \\" _n "\cmidrule(lr){2-5}" _n
local est "Weekend \$\times\$ Post"
local se ""
local k = 0
foreach y in log_users log_minutes median_dur_min n_new_users {
    local ++k
    local d : word `k' of 3 3 2 1
    estcell `oc_b_`y'' `oc_se_`y'' `oc_p_`y'' `d'
    local est "`est' & `r(b)'"
    local se "`se' & `r(se)'"
}
file write tab "`est' \\" _n "`se' \\" _n "\bottomrule" _n "\end{tabular*}" _n
file close tab

log close
