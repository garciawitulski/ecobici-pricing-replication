* 07_users.do
* User registry and the user x day panel used in the cohort analysis.
*
* Input : data/raw/users/usuarios_ecobici_YYYY.csv (2019-2023) and usuarios-ecobici-YYYY.csv (2015-2018)
*         data/intermediate/trips_2019.dta ... trips_2021.dta
* Output: data/intermediate/registry.dta   one row per user id: age, sex, residency (DNI) field
*         data/intermediate/user_day.dta   one row per user and day with at least one trip, 2019-2021
*
* Each registry file lists the users who registered in that year.
*   - Age and sex come from the 2019-2023 files only: the ids of the pre-2019 system overlap with the
*     current ones. If an id appears twice, the earliest file is used.
*   - The field "Customer.Has.Dni..Yes...No." (from 2020) records whether the user holds an Argentine
*     identity document, the legal condition for free weekday access. For this field every file from
*     2015 is read and the earliest registration of each id is used, so users registered before 2020
*     are unclassified.

capture log close
log using "$logs/07_users.log", replace text

* ---- registry ----------------------------------------------------------------------------------
clear
tempfile reg
forvalues y = 2015/2023 {
    local f "$raw/users/usuarios_ecobici_`y'.csv"
    capture confirm file "`f'"
    if _rc local f "$raw/users/usuarios-ecobici-`y'.csv"
    import delimited using "`f'", varnames(1) stringcols(_all) encoding("utf-8") clear
    gen reg_year = `y'
    gen dni_raw = ""
    capture confirm variable customerhasdniyesno
    if !_rc replace dni_raw = customerhasdniyesno
    keep id_usuario genero_usuario edad_usuario reg_year dni_raw
    capture append using `reg'
    save `reg', replace
}
gen long uid = real(id_usuario)
drop if missing(uid)
gen age = real(edad_usuario)
gen sex = genero_usuario
gen long row = _n

* residency (DNI) status: earliest registration of each id, 2015-2023
gen dni = ""
replace dni = "resident_dni" if inlist(upper(strtrim(dni_raw)), "YES", "SI", "S", "TRUE", "1")
replace dni = "no_dni" if dni == "" & dni_raw != ""
preserve
sort uid reg_year row
by uid: keep if _n == 1
keep uid dni reg_year
tempfile dni
save `dni'
restore

* age and sex: first record of each id in the 2019-2023 files
keep if reg_year >= 2019
sort uid reg_year row
by uid: keep if _n == 1
keep uid age sex
merge 1:1 uid using `dni', nogenerate
gen age_group = 1 if age <= 24
replace age_group = 2 if age > 24 & age <= 34
replace age_group = 3 if age > 34 & age <= 49
replace age_group = 4 if age > 49 & !missing(age)
label define age_group 1 "16-24" 2 "25-34" 3 "35-49" 4 "50+"
label values age_group age_group
compress
save "$inter/registry.dta", replace
tab reg_year dni, missing

* ---- user x day panel, 2019-2021 ----------------------------------------------------------------
clear
tempfile ud
forvalues y = 2019/2021 {
    use uid date dur_sec using "$inter/trips_`y'.dta", clear
    drop if missing(uid)
    gen trips = 1
    collapse (sum) trips dur_sec, by(uid date)
    capture append using `ud'
    save `ud', replace
}
collapse (sum) trips dur_sec, by(uid date)
gen double minutes = dur_sec / 60
drop dur_sec
merge m:1 date using "$inter/calendar.dta", keep(match) nogenerate keepusing(weekend holiday_any)
compress
save "$inter/user_day.dta", replace
count

log close
