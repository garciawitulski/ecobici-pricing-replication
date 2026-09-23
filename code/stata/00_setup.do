* 00_setup.do
* Folders, Stata settings and the user-written packages used by the replication package.
* It is run by main.do after the global $root has been set.

version 15
clear all
set more off
set varabbrev off
set type double        // new variables are stored in double precision
set seed 20210313

* ---- folders ------------------------------------------------------------------
global code      "$root/code/stata"
global raw       "$root/data/raw"
global manual    "$root/data/manual"
global inter     "$root/data/intermediate"
global analysis  "$root/data/analysis"
global tables    "$root/output/tables"
global estimates "$root/output/estimates"
global logs      "$root/output/logs"
global tmp       "$root/data/intermediate/tmp"

foreach f in inter analysis tables estimates logs tmp {
    capture mkdir "${`f'}"
}

* ---- packages ---------------------------------------------------------------
* The packages are stored inside the repository (code/stata/ado/plus), so the exact versions used
* for the paper are the ones that run. To reinstall them from SSC, uncomment the lines below.
sysdir set PLUS "$code/ado/plus"
sysdir set PERSONAL "$code/ado/personal"
mata: mata mlib index          // make Stata see the Mata libraries of these packages
* ssc install ftools,    replace
* ssc install require,   replace
* ssc install reghdfe,   replace
* ssc install ppmlhdfe,  replace
* ssc install honestdid, replace
* ssc install xtscc,     replace

* ---- dates used everywhere -------------------------------------------------------
global policy = td(13mar2021)      // the reform: paid weekend access from Saturday 13 March 2021

* ---- helpers for writing LaTeX tables ---------------------------------------------
* fmtnum x d      -> r(s) = x with d decimals, thousands separators and a LaTeX minus sign
* estcell b se p d -> r(b) = estimate with significance stars, r(se) = standard error in parentheses
*                     (* p<0.10, ** p<0.05, *** p<0.01; no stars when p is missing)
capture program drop fmtnum
program define fmtnum, rclass
    args x d
    local s = strtrim(string(abs(`x'), "%20.`d'fc"))
    if round(`x', 10^(-`d')) < 0 local s = char(36) + "-" + char(36) + "`s'"
    return local s "`s'"
end

capture program drop estcell
program define estcell, rclass
    args b se p d
    fmtnum `b' `d'
    local cell "`r(s)'"
    if `p' < 0.01      local cell "`cell'\$^{***}\$"
    else if `p' < 0.05 local cell "`cell'\$^{**}\$"
    else if `p' < 0.10 local cell "`cell'\$^{*}\$"
    local s = strtrim(string(`se', "%20.`d'fc"))
    return local b "`cell'"
    return local se "(`s')"
end

display "Setup done. Project root: $root"
