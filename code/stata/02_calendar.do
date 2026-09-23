* 02_calendar.do
* Day-level calendar 2019-2023 with the official Argentine holidays.
*
* Input : data/manual/holidays_2019_2023.csv (transcribed from the archived official holiday pages
*         in data/raw/holidays and, for 20 December 2022, from Decreto 842/2022)
* Output: data/intermediate/calendar.dta
*
* Holiday classes:
*   feriado            national holiday (inamovible, trasladable, turistico, extraordinary decree);
*                      priced like a weekend after the reform
*   nonworking_general non-working day of general scope (Holy Thursday)
*   religious_only_day applies only to members of a religious group; treated as an ordinary day
*   holiday_any        feriado or nonworking_general; these days are dropped from the analysis samples

capture log close
log using "$logs/02_calendar.log", replace text

* ---- holidays ----------------------------------------------------------------
import delimited using "$manual/holidays_2019_2023.csv", varnames(1) encoding("utf-8") stringcols(_all) clear
rename date date_str
gen date = date(date_str, "YMD")
format date %td
gen feriado = inlist(type, "inamovible", "trasladable", "turistico", "decreto_extraordinario")
gen nonworking_general = type == "no_laborable_general"
gen religious = type == "no_laborable_religioso"
collapse (max) feriado nonworking_general religious, by(date)
gen religious_only_day = religious == 1 & feriado == 0 & nonworking_general == 0
drop religious
tempfile hol
save `hol'

* ---- calendar ------------------------------------------------------------------
clear
set obs 1826
gen date = td(01jan2019) + _n - 1
format date %td
assert date[_N] == td(31dec2023)
gen year = year(date)
gen month = month(date)
gen dow = dow(date)                    // Stata: 0 = Sunday ... 6 = Saturday
replace dow = 7 if dow == 0            // here: 1 = Monday ... 7 = Sunday
gen weekend = dow >= 6

merge 1:1 date using `hol', nogenerate keep(master match)
foreach v in feriado nonworking_general religious_only_day {
    replace `v' = 0 if missing(`v')
}
gen holiday_any = feriado == 1 | nonworking_general == 1

* weekend days within two days of a holiday (long weekends), a pre-specified sensitivity
sort date
gen long_weekend_day = weekend == 1 & (holiday_any[_n-1] == 1 | holiday_any[_n+1] == 1 | ///
                                       holiday_any[_n-2] == 1 | holiday_any[_n+2] == 1)

* event time relative to the reform (Saturday 13 March 2021)
gen days_from_policy = date - $policy
gen post = date >= $policy

label variable dow "day of week, 1 = Monday ... 7 = Sunday"
label variable holiday_any "feriado or general non-working day"
compress
save "$inter/calendar.dta", replace

* checks
tab year feriado
list date dow if holiday_any == 1 & abs(days_from_policy) <= 56, noobs
list date dow if long_weekend_day == 1 & abs(days_from_policy) <= 56, noobs

log close
