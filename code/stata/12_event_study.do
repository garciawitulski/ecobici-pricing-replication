* 12_event_study.do
* Weekly event studies (reference week -1) under six pre-declared samples, pre-trend diagnostics, and
* the robustness check with weekend-specific weather coefficients.
*
*   A  primary sample, calendar controls only
*   B  excluding weekend days adjacent to a holiday (long weekends)
*   C  excluding the Carnaval long weekend (13-16 February 2021)
*   D  excluding extreme-rainfall days (precipitation at or above the 95th percentile of 2019-2023)
*   E  primary sample with weather controls (the preferred event study, Figure 3)
*   F  pre-reform period restricted to 1-12 March 2021
* For each sample: joint F test that the pre-reform coefficients are zero, the linear pre-trend slope
* (GLS of the pre-reform coefficients on event time, with their Newey-West covariance), and the
* difference-in-differences estimate on the same sample. All standard errors: Newey-West, lag 14.
*
* Input : data/analysis/ecobici_daily_2019_2023.dta
* Output: output/tables/tableA1_pretrends.tex, output/tables/tableA1b_weather.tex
*         output/estimates/event_study.csv   (coefficients behind Figure 3 and Figure A1)

capture log close
log using "$logs/12_event_study.log", replace text

local weather "prcp_mm rain_day tmax_c c.tmax_c#c.tmax_c"   // SMN weather is complete (CAF-007): the missing-day indicators are identically zero and leave the controls

* 95th percentile of daily precipitation, 2019-2023 (days with a report), R's default quantile rule
use "$analysis/ecobici_daily_2019_2023.dta", clear
keep if prcp_missing == 0
sort prcp_mm
local h = (_N - 1) * 0.95 + 1
local lo = floor(`h')
local rain_p95 = prcp_mm[`lo'] + (`h' - `lo') * (prcp_mm[`lo' + 1] - prcp_mm[`lo'])
display "Extreme-rainfall threshold: " %5.1f `rain_p95' " mm"

tempname es
postfile `es' str1 sample week estimate se using "$tmp/event_study.dta", replace

local labels `" "A. Primary sample" "B. Excluding long weekends" "C. Excluding Carnaval" "D. Excluding heavy-rain days" "E. Primary sample" "F. Pre-reform period from 1 March" "'
local i = 0
foreach s in A B C D E F {
    local ++i
    * ---- sample ------------------------------------------------------------------------------
    if "`s'" == "F" do "$code/sample.do" 13mar2021 56 01mar2021 .
    else do "$code/sample.do" 13mar2021 56
    if "`s'" == "B" drop if long_weekend_day == 1
    if "`s'" == "C" drop if inrange(date, td(13feb2021), td(16feb2021))
    if "`s'" == "D" drop if prcp_mm >= `rain_p95'
    drop tt
    gen tt = _n
    quietly tsset tt
    local controls ""
    if "`s'" == "E" local controls "`weather'"

    * ---- event study ---------------------------------------------------------------------------
    do "$code/event_dummies.do"
    newey log_trips $esvars i.week i.dow `controls', lag(14)
    local df_es = e(df_r)
    local k = 0
    foreach v of global esvars {
        local ++k
        local w : word `k' of $esweeks
        post `es' ("`s'") (`w') (_b[`v']) (_se[`v'])
    }
    post `es' ("`s'") (-1) (0) (.)

    * joint test and linear slope of the pre-reform coefficients
    local npre : word count $prevars
    local F "--"
    local Fp "--"
    local slope "--"
    local slope_t "--"
    if `npre' >= 1 {
        test $prevars
        local F = string(r(F), "%5.1f")
        local Fp = cond(r(p) < 0.001, "\$<\$0.001", string(r(p), "%5.3f"))
        if "`s'" == "E" {
            local F_E = r(F)
            local Fp_E = r(p)
        }
    }
    if `npre' >= 3 {
        matrix b = e(b)
        matrix V = e(V)
        matrix bpre = b[1, 1..`npre']'
        matrix Vpre = V[1..`npre', 1..`npre']
        matrix X = J(`npre', 2, 1)
        forvalues j = 1/`npre' {
            local w : word `j' of $esweeks
            matrix X[`j', 2] = `w'
        }
        matrix W = invsym(Vpre)
        matrix A = invsym(X' * W * X)
        matrix g = A * X' * W * bpre
        local sl = g[2, 1]
        local sl_t = g[2, 1] / sqrt(A[2, 2])
        fmtnum `sl' 4
        local slope "`r(s)'"
        fmtnum `sl_t' 2
        local slope_t "`r(s)'"
        if "`s'" == "E" {
            local slope_E = `sl'
            local slope_t_E = `sl_t'
        }
        * largest and mean absolute pre-reform deviation (quoted in the text)
        local maxabs = 0
        local sumabs = 0
        forvalues j = 1/`npre' {
            local maxabs = max(`maxabs', abs(bpre[`j', 1]))
            local sumabs = `sumabs' + abs(bpre[`j', 1])
        }
        display "Sample `s': largest |pre| = " %6.4f `maxabs' ", mean |pre| = " %6.4f `sumabs' / `npre'
    }
    if "`s'" == "E" {
        local w0_E = _b[es_0]
        local w0se_E = _se[es_0]
        local w0p_E = 2 * ttail(`df_es', abs(_b[es_0] / _se[es_0]))
    }

    * ---- difference in differences on the same sample -------------------------------------------------
    newey log_trips wknd_post i.week i.dow `controls', lag(14)
    local b = _b[wknd_post]
    local se = _se[wknd_post]
    local p = 2 * ttail(e(df_r), abs(`b' / `se'))
    local n = e(N)
    if "`s'" == "E" {
        local b_E = `b'
        local se_E = `se'
        local p_E = `p'
    }
    estcell `b' `se' `p' 3
    local lab : word `i' of `labels'
    local wx = cond("`s'" == "E", "Yes", "No")
    local row`i' "`lab' & `wx' & `n' & `F' & `Fp' & `slope' & `slope_t' & `r(b)' & `r(se)' \\"
}
postclose `es'

* ---- event-study coefficients for the figures -----------------------------------------------------
use "$tmp/event_study.dta", clear
gen ci_lo = estimate - 1.96 * se
gen ci_hi = estimate + 1.96 * se
sort sample week
export delimited using "$estimates/event_study.csv", replace
list if sample == "E", noobs

* ---- Table A1 --------------------------------------------------------------------------------------
file open tab using "$tables/tableA1_pretrends.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccccccc@{}}" _n "\toprule" _n
file write tab "Sample & Weather & Days & Joint \$F\$ & \$p\$-value & Slope & \$t\$ & Estimate & Std.\ error \\" _n
file write tab "\midrule" _n
forvalues i = 1/6 {
    file write tab "`row`i''" _n
}
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

* =============================================================================================
* Weekend-specific weather coefficients (Table A1b)
* =============================================================================================
do "$code/sample.do" 13mar2021 56
gen tmax_sq = tmax_c^2
foreach v in prcp_mm rain_day tmax_c tmax_sq {
    gen wx_`v' = weekend * `v'
}

* difference in differences with Weekend x weather terms
newey log_trips wknd_post i.week i.dow `weather' wx_*, lag(14)
local b_I = _b[wknd_post]
local se_I = _se[wknd_post]
local p_I = 2 * ttail(e(df_r), abs(`b_I' / `se_I'))
* joint test of the Weekend x weather terms that can be estimated (a term with no weekend
* variation in the sample is dropped by Stata)
local wxterms ""
foreach v of varlist wx_* {
    if _se[`v'] > 0 local wxterms "`wxterms' `v'"
}
local n_wx : word count `wxterms'
test `wxterms'
local F_wx = r(F)
local Fp_wx = r(p)

* event study with Weekend x weather terms
do "$code/event_dummies.do"
newey log_trips $esvars i.week i.dow `weather' wx_*, lag(14)
local df_I = e(df_r)
local w0_I = _b[es_0]
local w0se_I = _se[es_0]
local w0p_I = 2 * ttail(`df_I', abs(_b[es_0] / _se[es_0]))
test $prevars
local F_I = r(F)
local Fp_I = r(p)
local npre : word count $prevars
matrix b = e(b)
matrix V = e(V)
matrix bpre = b[1, 1..`npre']'
matrix Vpre = V[1..`npre', 1..`npre']
matrix X = J(`npre', 2, 1)
forvalues j = 1/`npre' {
    local w : word `j' of $esweeks
    matrix X[`j', 2] = `w'
}
matrix W = invsym(Vpre)
matrix A = invsym(X' * W * X)
matrix g = A * X' * W * bpre
local slope_I = g[2, 1]
local slope_t_I = g[2, 1] / sqrt(A[2, 2])

* ---- write Table A1b ----------------------------------------------------------------------------------
file open tab using "$tables/tableA1b_weather.tex", write replace
file write tab "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}>{\raggedright\arraybackslash}p{6.60cm}*{2}{>{\centering\arraybackslash}p{3.60cm}}@{}}" _n
file write tab "\toprule" _n " & Common weather coefficients & Weekend-specific weather coefficients \\" _n "\midrule" _n
estcell `b_E' `se_E' `p_E' 3
local c1 "`r(b)'"
local s1 "`r(se)'"
estcell `b_I' `se_I' `p_I' 3
file write tab "Weekend \$\times\$ Post & `c1' & `r(b)' \\" _n " & `s1' & `r(se)' \\" _n
local v1 = 100 * (exp(`b_E') - 1)
local v2 = 100 * (exp(`b_I') - 1)
fmtnum `v1' 1
local c1 "`r(s)'"
fmtnum `v2' 1
file write tab "Implied change (\%) & `c1' & `r(s)' \\" _n
estcell `w0_E' `w0se_E' `w0p_E' 3
local c1 "`r(b)'"
local s1 "`r(se)'"
estcell `w0_I' `w0se_I' `w0p_I' 3
file write tab "Week-0 event-study coefficient & `c1' & `r(b)' \\" _n " & `s1' & `r(se)' \\" _n
foreach m in E I {
    * \( \) is LaTeX inline math, like $ $ (a $ followed by a letter would be read by Stata as a global)
    local Ftxt`m' = "\(F = " + string(`F_`m'', "%5.1f") + "\), "
    if `Fp_`m'' < 0.001 local Ftxt`m' "`Ftxt`m''\(p < 0.001\)"
    else local Ftxt`m' = "`Ftxt`m''\(p = " + string(`Fp_`m'', "%5.3f") + "\)"
}
file write tab "Joint test, pre-reform coefficients & `FtxtE' & `FtxtI' \\" _n
fmtnum `slope_E' 4
local c1 "`r(s)'"
fmtnum `slope_I' 4
file write tab "Pre-reform slope per week & `c1' & `r(s)' \\" _n
fmtnum `slope_t_E' 2
local c1 "`r(s)'"
fmtnum `slope_t_I' 2
file write tab "\$t\$ statistic of the slope & `c1' & `r(s)' \\" _n
local Fwx = "\(F = " + string(`F_wx', "%5.2f") + "\), "
if `Fp_wx' < 0.001 local Fwx "`Fwx'\(p < 0.001\)"
else local Fwx = "`Fwx'\(p = " + string(`Fp_wx', "%5.3f") + "\)"
file write tab "Joint test, `n_wx' weekend \$\times\$ weather terms & -- & `Fwx' \\" _n
file write tab "\bottomrule" _n "\end{tabular*}" _n
file close tab

display "Weekend-specific weather: beta = " %6.3f `b_I' " (SE " %5.3f `se_I' "), " %5.1f 100 * (exp(`b_I') - 1) "%"

log close
