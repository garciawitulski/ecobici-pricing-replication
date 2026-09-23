* sample.do
* Loads the daily panel and keeps the estimation sample around a threshold date. It is called by the
* analysis do-files, for the true reform date and for placebo thresholds:
*
*     do "$code/sample.do" 13mar2021 56                   // threshold, half-width in days
*     do "$code/sample.do" 13feb2021 28 . 12mar2021       // optional first and last date to keep
*
* It keeps days within `halfwidth' days of the threshold with trip data, drops holidays and the
* threshold day itself, and creates:
*   t          days from the threshold
*   post       1 on and after the threshold
*   wk         week relative to the threshold (Saturday-to-Friday weeks; week 0 starts on it)
*   wknd_post  weekend x post, the treatment
*   tt         1, 2, 3, ... in date order, used as the time variable for Newey-West standard errors
* A boundary week that contains a single day is pooled into the preceding week, so that it does not
* get a fixed effect of its own.

args threshold halfwidth first last

use "$analysis/ecobici_daily_2019_2023.dta", clear
local thr = td(`threshold')
capture drop post
gen t = date - `thr'
gen post = date >= `thr'
keep if abs(t) <= `halfwidth' & !missing(n_trips) & holiday_any == 0 & date != `thr'
if "`first'" != "" & "`first'" != "." keep if date >= td(`first')
if "`last'" != "" & "`last'" != "." keep if date <= td(`last')

gen wk = floor(t / 7)
forvalues i = 1/3 {
    bysort wk: gen n_in_week = _N
    quietly replace wk = wk - 1 if n_in_week < 2
    drop n_in_week
}
gen wknd_post = weekend * post
gen week = wk + 100          // the same weeks, coded as positive numbers for i.week fixed effects

sort date
gen tt = _n
quietly tsset tt
