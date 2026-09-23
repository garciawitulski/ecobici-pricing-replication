* event_dummies.do
* Event-study regressors: one Weekend x week dummy for every event week except the reference week -1.
* A week enters only if it contains both weekend days and weekdays (otherwise it cannot identify a
* weekend-weekday gap). Called after sample.do by 12_event_study.do and 13_parallel_trends.do.
*
* Creates es_m8 ... es_m2 (weeks -8 to -2) and es_0 ... es_7 (weeks 0 to 7), and the globals
*   $esvars   names of the dummies, in week order
*   $esweeks  the corresponding event weeks
*   $prevars  the dummies of the pre-reform weeks

capture drop es_*
global esvars ""
global esweeks ""
global prevars ""
levelsof wk, local(weeks)
foreach w of local weeks {
    if `w' == -1 continue
    quietly count if wk == `w' & weekend == 1
    local n_weekend = r(N)
    quietly count if wk == `w' & weekend == 0
    local n_weekday = r(N)
    if `n_weekend' > 0 & `n_weekday' > 0 {
        if `w' < 0 local name = "es_m" + string(-`w')
        else local name = "es_" + string(`w')
        gen `name' = weekend * (wk == `w')
        global esvars "$esvars `name'"
        global esweeks "$esweeks `w'"
        if `w' < 0 global prevars "$prevars `name'"
    }
}
display "event-study weeks: $esweeks"
