* 16_cohort.do
* Participation and intensity in the cohort of pre-reform users.
*
* Cohort: every user id with at least one trip on the non-holiday days of the eight pre-reform weeks
* (16 January - 12 March 2021). Outcomes are measured on windows of EQUAL LENGTH: the pre-reform
* window drops its earliest eligible day of each type (Saturday 16 and Monday 18 January 2021), so
* each period has 15 weekend days and 37 weekdays.
* Panel: one row per user x day type (weekend, weekday) x period (before, after).
*
*   Table 4, Panel B  within-user difference in differences (user, day-type and period fixed effects,
*                     standard errors clustered by user): linear probability of any weekend ride;
*                     Poisson for weekend trips and weekend minutes; Poisson for riders active on that
*                     day type in both periods (descriptive: it conditions on post-reform behaviour)
*   Table 4, Panel C  accounting decomposition E[Y] = P(any ride) x E[Y | any ride], in logs:
*                     DiD log E[Y] = DiD log P(any ride) + DiD log E[Y | any ride]
*   Table A13         the same decomposition for a holdout cohort (membership on weeks -16 to -9) and
*                     for placebo cohorts at the 55 free-access Saturday thresholds of 14_falsification.do
*   In the text       residency (DNI) field of the registry; Poisson with an offset for days at risk
*
* Input : data/intermediate/user_day.dta, calendar.dta, registry.dta, output/estimates/placebo_distribution.csv
* Output: output/tables/table4_margins.tex, tableA13_cohort_robustness.tex
*         output/estimates/cohort_cells.csv (Table 4 cells), decomposition.csv (Figure 5), placebo_cohorts.csv (Figure 4b)

capture log close
log using "$logs/16_cohort.log", replace text

local P = $policy

* =============================================================================================
* 1. The cohort and the equal-exposure panel
* =============================================================================================
* eligible days: non-holiday days within 8 weeks of the reform, the reform day excluded
use "$inter/calendar.dta", clear
keep if holiday_any == 0 & date != `P' & inrange(date, `P' - 56, `P' + 56)
replace post = date > `P'          // after the threshold (the calendar has post for the reform)
tab weekend post
* equal exposure: drop the earliest pre-reform eligible day of each day type
bysort weekend post (date): gen first = _n == 1 & post == 0
list date weekend if first == 1, noobs
gen equal_window = first == 0
keep date post equal_window
tempfile days
save `days'

* cohort members
use "$inter/user_day.dta", clear
merge m:1 date using `days', keep(match) nogenerate
preserve
keep if post == 0
keep uid
duplicates drop
count
local cohort_n = r(N)
tempfile cohort
save `cohort'
restore

* trips, minutes and active days by user, day type and period (equal-exposure windows)
tempfile uday
save `uday'
keep if equal_window == 1
collapse (sum) n_trips = trips minutes (count) active_days = trips, by(uid weekend post)
tempfile agg
save `agg'

* balanced panel: every cohort member in the four cells
use `cohort', clear
expand 4
bysort uid: gen cell = _n
gen weekend = inlist(cell, 2, 4)
gen post = cell >= 3
drop cell
merge 1:1 uid weekend post using `agg', keep(master match) nogenerate
foreach v in n_trips minutes active_days {
    replace `v' = 0 if missing(`v')
}
gen any_ride = n_trips > 0
gen wknd_post = weekend * post
gen n_days = cond(weekend == 1, 15, 37)
tempfile panel
save `panel'

* ---- Panel A: cell means --------------------------------------------------------------------------
preserve
gen trips_if_any = n_trips if any_ride == 1
gen minutes_if_any = minutes if any_ride == 1
gen days_if_any = active_days if any_ride == 1
collapse (count) users = uid (mean) n_days p_any = any_ride mean_trips = n_trips mean_minutes = minutes ///
    mean_days = active_days mean_trips_if_any = trips_if_any mean_minutes_if_any = minutes_if_any ///
    mean_days_if_any = days_if_any, by(weekend post)
gen daytype = cond(weekend == 1, "weekend", "weekday")
gen period = cond(post == 1, "post", "pre")
export delimited using "$estimates/cohort_cells.csv", replace
list, noobs
foreach v in n_days p_any mean_trips mean_trips_if_any mean_minutes mean_minutes_if_any mean_days mean_days_if_any {
    forvalues w = 0/1 {
        forvalues p = 0/1 {
            summarize `v' if weekend == `w' & post == `p', meanonly
            local `v'`w'`p' = r(mean)
        }
    }
}
restore

* ---- Panel B: within-user difference in differences ---------------------------------------------
reghdfe any_ride wknd_post, absorb(uid weekend post) vce(cluster uid)
local b1 = _b[wknd_post]
local se1 = _se[wknd_post]
local n1 = e(N)
ppmlhdfe n_trips wknd_post, absorb(uid weekend post) vce(cluster uid)
local b2 = _b[wknd_post]
local se2 = _se[wknd_post]
local n2 = e(N)
ppmlhdfe minutes wknd_post, absorb(uid weekend post) vce(cluster uid)
local b3 = _b[wknd_post]
local se3 = _se[wknd_post]
local n3 = e(N)
* riders active on that day type both before and after (descriptive, selected on the outcome)
bysort uid weekend: egen both = min(any_ride)
ppmlhdfe n_trips wknd_post if both == 1, absorb(uid weekend post) vce(cluster uid)
local b4 = _b[wknd_post]
local se4 = _se[wknd_post]
local n4 = e(N)
forvalues j = 1/4 {
    local p`j' = 2 * normal(-abs(`b`j'' / `se`j''))
}
display "Poisson, weekend trips: " %7.4f `b2' " (" %5.1f 100 * (exp(`b2') - 1) "%); riders in both periods: " %7.4f `b4' " (" %5.1f 100 * (exp(`b4') - 1) "%)"

* ---- Panel C: accounting decomposition ---------------------------------------------------------------
* DiD in logs of a cell mean m: log(m_weekend,post / m_weekend,pre) - log(m_weekday,post / m_weekday,pre)
local part = ln(`p_any11' / `p_any10') - ln(`p_any01' / `p_any00')
tempname dec
postfile `dec' str8 outcome total participation intensity share using "$tmp/decomposition.dta", replace
foreach o in trips minutes days {
    local tot = ln(`mean_`o'11' / `mean_`o'10') - ln(`mean_`o'01' / `mean_`o'00')
    local int = ln(`mean_`o'_if_any11' / `mean_`o'_if_any10') - ln(`mean_`o'_if_any01' / `mean_`o'_if_any00')
    assert abs(`part' + `int' - `tot') < 1e-10
    post `dec' ("`o'") (`tot') (`part') (`int') (`part' / `tot')
    local tot_`o' = `tot'
    local int_`o' = `int'
}
postclose `dec'
use "$tmp/decomposition.dta", clear
export delimited using "$estimates/decomposition.csv", replace
list, noobs

* ---- write Table 4 ------------------------------------------------------------------------------------
file open tab using "$tables/table4_margins.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{4.60cm}*{4}{>{\centering\arraybackslash}p{2.30cm}}@{}}" _n
file write tab "\toprule" _n "\multicolumn{5}{@{}l}{\textit{Panel A. Cohort means over windows of equal length}} \\" _n
file write tab " & \multicolumn{2}{c}{Weekends} & \multicolumn{2}{c}{Weekdays} \\" _n
file write tab "\cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n " & Before & After & Before & After \\" _n
local vars   "n_days p_any mean_trips mean_trips_if_any mean_minutes mean_minutes_if_any"
local digits "0 3 2 2 1 1"
local labels `" "Days in the window" "Probability of any ride" "Trips per cohort member" "Trips per active rider" "Minutes per cohort member" "Minutes per active rider" "'
forvalues i = 1/6 {
    local v : word `i' of `vars'
    local d : word `i' of `digits'
    local line : word `i' of `labels'
    foreach cell in 10 11 00 01 {
        fmtnum ``v'`cell'' `d'
        local line "`line' & `r(s)'"
    }
    file write tab "`line' \\" _n
}
file write tab "\midrule" _n "\multicolumn{5}{@{}l}{\textit{Panel B. Within-user difference in differences}} \\" _n
file write tab " & Any weekend ride & Weekend trips & Weekend minutes & Weekend trips, riders in both periods \\" _n
file write tab "\cmidrule(lr){2-5}" _n
local est "Weekend \$\times\$ Post"
local se ""
local obs "Observations"
forvalues j = 1/4 {
    estcell `b`j'' `se`j'' `p`j'' 3
    local est "`est' & `r(b)'"
    local se "`se' & `r(se)'"
    fmtnum `n`j'' 0
    local obs "`obs' & `r(s)'"
}
file write tab "`est' \\" _n "`se' \\" _n "Estimator & Linear probability & Poisson & Poisson & Poisson \\" _n "`obs' \\" _n
file write tab "\midrule" _n "\multicolumn{5}{@{}l}{\textit{Panel C. Accounting decomposition of the weekend decline}} \\" _n
file write tab " & Total & Participation & Usage intensity among active riders & Participation share (\%) \\" _n
file write tab "\cmidrule(lr){2-5}" _n
foreach o in trips minutes days {
    if "`o'" == "trips"   local lab "Trips"
    if "`o'" == "minutes" local lab "Minutes ridden"
    if "`o'" == "days"    local lab "Active days"
    fmtnum `tot_`o'' 3
    local c1 "`r(s)'"
    fmtnum `part' 3
    local c2 "`r(s)'"
    fmtnum `int_`o'' 3
    local c3 "`r(s)'"
    local v = 100 * `part' / `tot_`o''
    fmtnum `v' 1
    file write tab "`lab' & `c1' & `c2' & `c3' & `r(s)' \\" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* =============================================================================================
* 2. Poisson with an offset for days at risk, on the original (unequal) windows (quoted in text)
* =============================================================================================
use `uday', clear
collapse (sum) n_trips = trips, by(uid weekend post)
tempfile agg_full
save `agg_full'
use `cohort', clear
expand 4
bysort uid: gen cell = _n
gen weekend = inlist(cell, 2, 4)
gen post = cell >= 3
merge 1:1 uid weekend post using `agg_full', keep(master match) nogenerate
replace n_trips = 0 if missing(n_trips)
gen wknd_post = weekend * post
gen log_days = ln(cond(weekend == 1, cond(post == 0, 16, 15), cond(post == 0, 38, 37)))
ppmlhdfe n_trips wknd_post, absorb(uid weekend post) offset(log_days) vce(cluster uid)
display "Poisson with offset, original windows: " %7.4f _b[wknd_post]

* =============================================================================================
* 3. Residency (DNI) field of the registry, frozen window (quoted in the text)
* =============================================================================================
use `uday', clear
merge m:1 uid using "$inter/registry.dta", keep(master match) nogenerate keepusing(dni)
replace dni = "unclassified" if dni == ""
gen trips_no_dni = trips * (dni == "no_dni")
gen trips_classified = trips * (dni != "unclassified")
collapse (sum) trips trips_no_dni trips_classified, by(weekend post)
gen share_no_dni = 100 * trips_no_dni / trips          // share of all trips on that day type
list, noobs
summarize trips_classified, meanonly
local cl = r(sum)
summarize trips, meanonly
display "Trips whose user carries the DNI field: " %5.1f 100 * `cl' / r(sum) "%"
forvalues w = 0/1 {
    forvalues p = 0/1 {
        summarize share_no_dni if weekend == `w' & post == `p', meanonly
        local s`w'`p' = r(mean)
    }
}
display "Differential change in the non-DNI share (percentage points): " %6.3f (`s11' - `s10') - (`s01' - `s00')

* =============================================================================================
* 4. Holdout and placebo cohorts (Table A13, Figure 4b)
* =============================================================================================
* For each threshold s: members are users with a trip on a non-holiday day of the membership window;
* outcomes are measured over the 8 weeks either side of s (s excluded), keeping in each period the same
* number of weekend days and of weekdays, namely those closest to s. The decomposition only needs the
* cell totals: P(any) = active members / members, E[Y] = total / members, E[Y | any] = total / active.
import delimited using "$estimates/placebo_distribution.csv", varnames(1) clear
gen thr = date(threshold, "YMD")
keep thr span
gen kind = "placebo"
set obs `=_N + 2'
replace thr = `P' in `=_N - 1'/`=_N'
replace kind = "reform" in `=_N - 1'
replace kind = "holdout" in `=_N'
tempfile thresholds
save `thresholds'
local nthr = _N

tempname cr
postfile `cr' thr str8 kind str8 span cohort str8 outcome total participation share ///
    using "$tmp/cohort_robustness.dta", replace
forvalues i = 1/`nthr' {
    use `thresholds', clear
    local s = thr[`i']
    local kind = kind[`i']
    local span = span[`i']
    local mem_from = `s' - 56
    local mem_to = `s' - 1
    if "`kind'" == "holdout" {
        local mem_from = `s' - 112
        local mem_to = `s' - 57
    }
    * outcome days: equal numbers of each day type in the two periods, closest to the threshold
    quietly {
        use "$inter/calendar.dta", clear
        keep if holiday_any == 0 & date != `s' & inrange(date, `s' - 56, `s' + 56)
        replace post = date > `s'          // after the threshold (the calendar has post for the reform)
        gen dist = abs(date - `s')
        bysort weekend post (dist): gen rank = _n
        bysort weekend post: gen N = _N
        bysort weekend: egen keep_n = min(N)
        keep if rank <= keep_n
        keep date post
        tempfile keepdays
        save `keepdays', replace
        * members
        use uid date holiday_any if inrange(date, `mem_from', `mem_to') & holiday_any == 0 using "$inter/user_day.dta", clear
        keep uid
        duplicates drop
        local members = _N
        tempfile mem
        save `mem', replace
        * cell totals among members
        use uid date trips minutes weekend if inrange(date, `s' - 56, `s' + 56) using "$inter/user_day.dta", clear
        merge m:1 date using `keepdays', keep(match) nogenerate
        merge m:1 uid using `mem', keep(match) nogenerate
        collapse (sum) trips minutes (count) days = trips, by(uid weekend post)
        collapse (count) active = uid (sum) trips minutes days, by(weekend post)
    }
    foreach v in active trips minutes days {
        forvalues w = 0/1 {
            forvalues p = 0/1 {
                summarize `v' if weekend == `w' & post == `p', meanonly
                local `v'`w'`p' = r(mean)
            }
        }
    }
    local part = ln(`active11' / `active10') - ln(`active01' / `active00')
    foreach o in trips minutes days {
        local tot = ln(``o'11' / ``o'10') - ln(``o'01' / ``o'00')
        post `cr' (`s') ("`kind'") ("`span'") (`members') ("`o'") (`tot') (`part') (`part' / `tot')
    }
}
postclose `cr'
use "$tmp/cohort_robustness.dta", clear
format thr %tdCCYY-NN-DD
list if kind != "placebo", noobs
preserve
keep if kind == "placebo" & outcome == "trips"
rename thr threshold
export delimited threshold span participation total using "$estimates/placebo_cohorts.csv", replace
restore

* ---- Table A13 ----------------------------------------------------------------------------------------
file open tab using "$tables/tableA13_cohort_robustness.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{5.40cm}*{4}{>{\centering\arraybackslash}p{2.10cm}}@{}}" _n
file write tab "\toprule" _n " & Cohort & Total & Participation & Participation share (\%) \\" _n "\midrule" _n
file write tab "\multicolumn{5}{@{}l}{\textit{Panel A. Alternative cohort definitions, reform of 13 March 2021}} \\" _n
foreach kind in reform holdout {
    if "`kind'" == "holdout" file write tab "\addlinespace[3pt]" _n
    foreach o in trips minutes days {
        if "`o'" == "trips" & "`kind'" == "reform"  local lab "Membership on the eight pre-reform weeks, trips"
        if "`o'" == "trips" & "`kind'" == "holdout" local lab "Holdout membership on weeks \$-\$16 to \$-\$9, trips"
        if "`o'" == "minutes" local lab "\quad minutes ridden"
        if "`o'" == "days"    local lab "\quad active days"
        local cohort ""
        if "`o'" == "trips" {
            summarize cohort if kind == "`kind'" & outcome == "`o'", meanonly
            fmtnum `r(mean)' 0
            local cohort "`r(s)'"
        }
        local line "`lab' & `cohort'"
        foreach v in total participation {
            summarize `v' if kind == "`kind'" & outcome == "`o'", meanonly
            fmtnum `r(mean)' 3
            local line "`line' & `r(s)'"
        }
        summarize share if kind == "`kind'" & outcome == "`o'", meanonly
        local v = 100 * r(mean)
        fmtnum `v' 1
        file write tab "`line' & `r(s)' \\" _n
    }
}
file write tab "\midrule" _n "\multicolumn{5}{@{}l}{\textit{Panel B. Placebo cohorts at free-access thresholds}} \\" _n
file write tab " & Thresholds & Mean & Std.\ dev. & Most negative \\" _n "\cmidrule(lr){2-5}" _n
summarize participation if kind == "placebo" & outcome == "trips"
local npl = r(N)
local line "Participation term & `r(N)'"
foreach v in `r(mean)' `r(sd)' `r(min)' {
    fmtnum `v' 3
    local line "`line' & `r(s)'"
}
file write tab "`line' \\" _n
summarize total if kind == "placebo" & outcome == "trips"
local line "Total, trips & `r(N)'"
foreach v in `r(mean)' `r(sd)' {
    fmtnum `v' 3
    local line "`line' & `r(s)'"
}
file write tab "`line' &  \\" _n
summarize participation if kind == "reform" & outcome == "trips", meanonly
local ref = r(mean)
count if kind == "placebo" & outcome == "trips" & participation <= `ref'
local rank = r(N) + 1
fmtnum `ref' 3
file write tab "Reform participation term &  & `r(s)' &  & rank `rank' of `=`npl' + 1' \\" _n
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

log close
