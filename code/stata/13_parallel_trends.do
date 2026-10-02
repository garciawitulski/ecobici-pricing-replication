* 13_parallel_trends.do
* Sensitivity of the event-study estimates to violations of parallel trends.
*
* Three event studies (weekly Weekend x week coefficients, reference week -1, Newey-West lag 14):
*   calendar   week and day-of-week fixed effects only (larger pre-reform deviations: conservative)
*   weather    + weather controls (the preferred specification, Figure 3)
*   wxint      + weather controls and Weekend x weather terms (robustness)
* Targets: week 0 (Sunday 14 March only), week 1 (first full treated weekend), the average of weeks
* 0-1, of weeks 0-3 and of weeks 0-7.
*
* (1) Relative magnitudes (Rambachan and Roth 2023), computed with -honestdid-: the post-reform
*     change in the differential trend is at most Mbar times the largest pre-reform week-to-week
*     change. Robust confidence sets by test inversion (conditional least-favourable method) on a
*     grid of 601 points from -4 to 2; a set that touches the grid limits is recomputed on a wider grid.
* (2) Level restriction, |violation| <= Mbar x B, where B is the mean or the largest absolute
*     pre-reform coefficient. Reported interval: [est - 1.96 se - Mbar B_hi, est + 1.96 se + Mbar B_hi],
*     with B_hi the 97.5th percentile of B over 20,000 draws of the pre-reform coefficients from
*     N(b_pre, V_pre). It ignores the correlation between the two parts and is a conservative outer
*     bound, not a confidence set.
* The magnitudes Mbar = 0.5, 1, ..., 3 were fixed before estimation.
*
* Input : data/analysis/ecobici_daily_2019_2023.dta
* Output: output/tables/tableA2_relative_magnitudes.tex, output/tables/tableA3_outer_bounds.tex
*         output/estimates/parallel_trends.csv  (read by 14_falsification.do for Table 3 and by
*                                                figA2_sensitivity.R)

capture log close
log using "$logs/13_parallel_trends.log", replace text

local weather "prcp_mm rain_day tmax_c c.tmax_c#c.tmax_c"   // SMN weather is complete (CAF-007): the missing-day indicators are identically zero and leave the controls

* the five targets, as weights on the 8 post-reform coefficients (weeks 0 to 7)
matrix L1 = (1, 0, 0, 0, 0, 0, 0, 0)
matrix L2 = (0, 1, 0, 0, 0, 0, 0, 0)
matrix L3 = (0.5, 0.5, 0, 0, 0, 0, 0, 0)
matrix L4 = (0.25, 0.25, 0.25, 0.25, 0, 0, 0, 0)
matrix L5 = J(1, 8, 1 / 8)

tempname pt
postfile `pt' str8 variant str10 framework target mbar estimate lb ub truncated df ///
    using "$tmp/parallel_trends.dta", replace

foreach variant in calendar weather wxint {

    * ---- event study ---------------------------------------------------------------------------
    do "$code/sample.do" 13mar2021 56
    local controls ""
    if "`variant'" != "calendar" local controls "`weather'"
    if "`variant'" == "wxint" {
        gen tmax_sq = tmax_c^2
        foreach v in prcp_mm rain_day tmax_c tmax_sq {
            gen wx_`v' = weekend * `v'
        }
        local controls "`controls' wx_*"
    }
    do "$code/event_dummies.do"
    newey log_trips $esvars i.week i.dow `controls', lag(14)
    local df_es = e(df_r)
    local npre : word count $prevars
    local nall : word count $esvars
    local npost = `nall' - `npre'
    assert `npre' == 7 & `npost' == 8

    matrix b = e(b)
    matrix V = e(V)
    matrix bES = b[1, 1..`nall']
    matrix VES = V[1..`nall', 1..`nall']
    matrix bpost = bES[1, `=`npre' + 1'..`nall']
    matrix Vpost = VES[`=`npre' + 1'..`nall', `=`npre' + 1'..`nall']

    forvalues j = 1/5 {
        * ---- baseline: parallel trends assumed ----------------------------------------------------
        matrix est = L`j' * bpost'
        matrix var = L`j' * Vpost * L`j''
        local est = est[1, 1]
        local se = sqrt(var[1, 1])
        post `pt' ("`variant'") ("baseline") (`j') (0) (`est') (`est' - 1.96 * `se') (`est' + 1.96 * `se') (0) (`df_es')

        * ---- (1) relative magnitudes -----------------------------------------------------------------
        local glo = -4
        local ghi = 2
        local tries = 0
        local truncated = 1
        while `truncated' == 1 & `tries' < 3 {
            local ++tries
            matrix lvec = L`j''
            honestdid, b(bES) vcov(VES) pre(1/`npre') post(`=`npre' + 1'/`nall') l_vec(lvec) ///
                mvec(0.5(0.5)3) delta(rm) gridPoints(601) grid_lb(`glo') grid_ub(`ghi')
            mata: st_matrix("CI", `s(HonestEventStudy)'.CI)
            mata: st_matrix("OPEN", `s(HonestEventStudy)'.open)
            * a set that reaches the grid limits is truncated: widen the grid and recompute
            local truncated = 0
            forvalues r = 1/`=rowsof(OPEN)' {
                forvalues c = 1/`=colsof(OPEN)' {
                    if OPEN[`r', `c'] != 0 local truncated = 1
                }
            }
            local width = `ghi' - `glo'
            local glo = `glo' - `width'
            local ghi = `ghi' + (`ghi' - `glo') / 2
        }
        forvalues r = 1/`=rowsof(CI)' {
            if !missing(CI[`r', 1]) {
                post `pt' ("`variant'") ("rm") (`j') (CI[`r', 1]) (.) (CI[`r', 2]) (CI[`r', 3]) (`truncated') (`df_es')
            }
        }
    }

    * ---- (2) level restriction (calendar and weather event studies) --------------------------------
    if "`variant'" != "wxint" {
        matrix bpre = bES[1, 1..`npre']
        matrix Vpre = VES[1..`npre', 1..`npre']
        * benchmarks from the estimated pre-reform coefficients
        local bmean = 0
        local bmax = 0
        forvalues k = 1/`npre' {
            local bmean = `bmean' + abs(bpre[1, `k']) / `npre'
            local bmax = max(`bmax', abs(bpre[1, `k']))
        }
        * their 97.5th percentiles over 20,000 draws of the pre-reform coefficients
        preserve
        set seed 20210313
        drawnorm d1-d`npre', n(20000) means(bpre) cov(Vpre) clear
        forvalues k = 1/`npre' {
            replace d`k' = abs(d`k')
        }
        egen bmean = rowmean(d*)
        egen bmax = rowmax(d*)
        foreach m in bmean bmax {
            sort `m'
            local h = (_N - 1) * 0.975 + 1
            local lo = floor(`h')
            local `m'_hi = `m'[`lo'] + (`h' - `lo') * (`m'[`lo' + 1] - `m'[`lo'])
        }
        restore
        display "`variant': mean |pre| = " %6.4f `bmean' " (97.5th pct " %6.4f `bmean_hi' "), largest |pre| = " %6.4f `bmax' " (97.5th pct " %6.4f `bmax_hi' ")"

        forvalues j = 1/5 {
            matrix est = L`j' * bpost'
            matrix var = L`j' * Vpost * L`j''
            local est = est[1, 1]
            local se = sqrt(var[1, 1])
            foreach m in bmean bmax {
                local fw = cond("`m'" == "bmean", "level_mean", "level_max")
                forvalues M = 0.5(0.5)3 {
                    post `pt' ("`variant'") ("`fw'") (`j') (`M') (`est') ///
                        (`est' - 1.96 * `se' - `M' * ``m'_hi') (`est' + 1.96 * `se' + `M' * ``m'_hi') (0) (`df_es')
                }
            }
        }
    }
}
postclose `pt'

* ---- results file ------------------------------------------------------------------------------------
use "$tmp/parallel_trends.dta", clear
label define target 1 "week 0" 2 "week 1" 3 "weeks 0-1" 4 "weeks 0-3" 5 "weeks 0-7"
label values target target
gen excludes_zero = ub < 0 | lb > 0
assert truncated == 0
export delimited using "$estimates/parallel_trends.csv", replace nolabel
save "$tmp/parallel_trends.dta", replace

* ---- breakdown values: largest Mbar at which zero is still excluded ---------------------------------
* stored as text for the tables: "x.x", "<0.5" (zero included already at 0.5) or ">=3.0" (never included)
keep if framework != "baseline"
bysort variant framework target: egen largest = max(cond(excludes_zero, mbar, .))
bysort variant framework target: egen first_incl = min(cond(!excludes_zero, mbar, .))
bysort variant framework target: keep if _n == 1
gen breakdown = string(largest, "%3.1f")
replace breakdown = "\$<\$0.5" if missing(largest)
replace breakdown = "\$\geq\$" + string(largest, "%3.1f") if missing(first_incl) & !missing(largest)
keep variant framework target breakdown
export delimited using "$estimates/parallel_trends_breakdown.csv", replace nolabel
tempfile bd
save `bd'

* ---- Table A2: relative-magnitudes robust sets ------------------------------------------------------------
use "$tmp/parallel_trends.dta", clear
file open tab using "$tables/tableA2_relative_magnitudes.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{3.00cm}*{3}{>{\centering\arraybackslash}p{3.40cm}}@{}}" _n
file write tab "\toprule" _n "\$\bar{M}\$ & Week 0 & Mean of weeks 0--3 & Mean of weeks 0--7 \\" _n "\midrule" _n
local p = 0
foreach variant in calendar weather wxint {
    local ++p
    if `p' == 1 local title "Panel A. Calendar controls only"
    if `p' == 2 local title "Panel B. Common weather coefficients (preferred specification)"
    if `p' == 3 local title "Panel C. Weekend-specific weather coefficients"
    file write tab "\multicolumn{4}{@{}l}{\textit{`title'}} \\" _n
    forvalues M = 0.5(0.5)3 {
        local line = string(`M', "%3.1f")
        foreach j in 1 4 5 {
            summarize lb if variant == "`variant'" & framework == "rm" & target == `j' & abs(mbar - `M') < 1e-9, meanonly
            fmtnum `r(mean)' 2
            local l "`r(s)'"
            summarize ub if variant == "`variant'" & framework == "rm" & target == `j' & abs(mbar - `M') < 1e-9, meanonly
            fmtnum `r(mean)' 2
            local line "`line' & [`l', `r(s)']"
        }
        file write tab "`line' \\" _n
    }
    preserve
    use `bd', clear
    local line "Breakdown \$\bar{M}\$"
    foreach j in 1 4 5 {
        levelsof breakdown if variant == "`variant'" & framework == "rm" & target == `j', local(v) clean
        local line "`line' & `v'"
    }
    restore
    file write tab "`line' \\" _n
    if `p' < 3 file write tab "\midrule" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* ---- Table A3: conservative outer bounds under the level restriction -------------------------------
file open tab using "$tables/tableA3_outer_bounds.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{3.00cm}*{3}{>{\centering\arraybackslash}p{3.40cm}}@{}}" _n
file write tab "\toprule" _n "\$\bar{M}\$ & Week 0 & Mean of weeks 0--3 & Mean of weeks 0--7 \\" _n "\midrule" _n
local p = 0
foreach variant in calendar weather {
    local ++p
    if `p' == 1 local title "Panel A. Calendar controls only"
    if `p' == 2 local title "Panel B. Common weather coefficients (preferred specification)"
    file write tab "\multicolumn{4}{@{}l}{\textit{`title'}} \\" _n
    foreach fw in level_mean level_max {
        if "`fw'" == "level_mean" file write tab "\multicolumn{4}{@{}l}{Benchmark: mean absolute pre-reform deviation} \\" _n
        if "`fw'" == "level_max"  file write tab "\multicolumn{4}{@{}l}{Benchmark: largest absolute pre-reform deviation} \\" _n
        forvalues M = 0.5(0.5)3 {
            local line = "\quad " + string(`M', "%3.1f")
            foreach j in 1 4 5 {
                summarize lb if variant == "`variant'" & framework == "`fw'" & target == `j' & abs(mbar - `M') < 1e-9, meanonly
                fmtnum `r(mean)' 2
                local l "`r(s)'"
                summarize ub if variant == "`variant'" & framework == "`fw'" & target == `j' & abs(mbar - `M') < 1e-9, meanonly
                fmtnum `r(mean)' 2
                local line "`line' & [`l', `r(s)']"
            }
            file write tab "`line' \\" _n
        }
        preserve
        use `bd', clear
        local line "\quad Breakdown \$\bar{M}\$"
        foreach j in 1 4 5 {
            levelsof breakdown if variant == "`variant'" & framework == "`fw'" & target == `j', local(v) clean
            local line "`line' & `v'"
        }
        restore
        file write tab "`line' \\" _n
    }
    if `p' < 2 file write tab "\midrule" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* ---- numbers quoted in the text ----------------------------------------------------------------------
use "$tmp/parallel_trends.dta", clear
list variant target estimate lb ub if framework == "baseline", noobs sepby(variant)
list variant target mbar lb ub if framework == "rm" & inlist(target, 1, 3) & mbar == 1, noobs
use `bd', clear
list, noobs sepby(variant framework)

log close
