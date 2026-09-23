* 05_subte_mobility.do
* Two contemporaneous mobility series used as falsification outcomes (Appendix Table A7):
*   (a) daily Subte (subway) turnstile entries, 2021, from SBASE via GCBA open data;
*   (b) Google COVID-19 Community Mobility Reports for the City of Buenos Aires.
*
* Input : data/raw/public_transport/molinetes-2021.zip
*         data/raw/mobility/Region_Mobility_Report_CSVs.zip
* Output: data/intermediate/subte.dta, data/intermediate/mobility.dta
*
* Subte dates. The 2021 file writes dates in three ways: ISO ("2021-03-14"), day/month/year and, for
* some days, month/day/year, all mixed in the same column. A date string is CERTAIN when it is ISO or
* when one of its first two parts is larger than 12 (only one reading exists). Strings such as
* "5/4/2021" are AMBIGUOUS (5 April or 4 May). They are resolved as follows:
*   1. if one reading is a day already taken by another string and the other is not, the free
*      reading is used (repeated until nothing changes); a string such as "5/5/2021" has one reading;
*   2. any string still open is read as day/month/year, the only order with unambiguous evidence in
*      the 2021 file.
* A day is used only if none of its records comes from an ambiguous string (subte_date_certain = 1);
* every other day is left missing. Only 2021 enters the paper (the window is January to May 2021).

capture log close
log using "$logs/05_subte_mobility.log", replace text

* ---- (a) Subte 2021 -------------------------------------------------------------------
cd "$tmp"
unzipfile "$raw/public_transport/molinetes-2021.zip", replace
cd "$root"
import delimited using "$tmp/historico_2021.csv", delimiter(";") varnames(1) stringcols(_all) clear
erase "$tmp/historico_2021.csv"
keep fecha desde linea molinete pax_total
gen double pax = real(pax_total)
drop pax_total
display "Subte 2021: " _N " records"

* map every distinct date string to a date
preserve
keep fecha
duplicates drop
gen iso = regexm(fecha, "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$")
split fecha if iso == 0, parse("/") generate(part) destring
gen date = date(fecha, "YMD") if iso == 1
replace date = mdy(part2, part1, part3) if iso == 0 & part1 > 12     // day/month/year
replace date = mdy(part1, part2, part3) if iso == 0 & part2 > 12     // month/day/year
gen certain = !missing(date)
* both readings of each ambiguous string
gen cand_a = mdy(part2, part1, part3) if certain == 0
gen cand_b = mdy(part1, part2, part3) if certain == 0
format date cand_a cand_b %td
count if certain == 0
display "ambiguous date strings: " r(N)

* step 1: a reading that is already taken is ruled out
gen assigned = date
tempfile taken strings
local changed = 1
while `changed' > 0 {
    save `strings', replace
    keep if !missing(assigned)
    keep assigned
    duplicates drop
    rename assigned day
    save `taken', replace
    use `strings', clear
    gen day = cand_a
    merge m:1 day using `taken', keep(master match)
    gen a_taken = _merge == 3
    drop _merge day
    gen day = cand_b
    merge m:1 day using `taken', keep(master match)
    gen b_taken = _merge == 3
    drop _merge day
    gen open = missing(assigned) & certain == 0
    count if open & (cand_a == cand_b | a_taken != b_taken)
    local changed = r(N)
    replace assigned = cand_a if open & cand_a == cand_b
    replace assigned = cand_b if open & a_taken == 1 & b_taken == 0
    replace assigned = cand_a if open & a_taken == 0 & b_taken == 1
    drop a_taken b_taken open
}
* step 2: strings still open are read as day/month/year
replace assigned = cand_a if missing(assigned) & certain == 0
format assigned %td
tempfile map
save `map'
* days that received records written with an ambiguous string
keep if certain == 0
keep assigned
duplicates drop
rename assigned date
gen inferred = 1
tempfile inferred
save `inferred'
restore

merge m:1 fecha using `map', keep(match) nogenerate keepusing(date certain)
keep if certain == 1
* records written twice under two spellings of the same date are counted once
duplicates drop date desde linea molinete pax, force
collapse (sum) subte_pax = pax (count) subte_records = pax, by(date)
merge 1:1 date using `inferred', keep(master match)
gen subte_date_certain = _merge == 1
drop _merge inferred
keep if subte_date_certain == 1
format date %td
save "$inter/subte.dta", replace
count if abs(date - $policy) <= 56
display "certain Subte days within +/- 8 weeks of the reform: " r(N)

* ---- (b) Google mobility, City of Buenos Aires (ISO code AR-C) -------------------------------
cd "$tmp"
unzipfile "$raw/mobility/Region_Mobility_Report_CSVs.zip", replace
cd "$root"
clear
tempfile mob
* The column names are longer than Stata allows, so columns are read by position:
*  v4 sub_region_2, v6 iso_3166_2_code, v9 date, v10 retail and recreation, v11 grocery and pharmacy,
*  v12 parks, v13 transit stations, v14 workplaces, v15 residential (percent change from baseline)
forvalues y = 2020/2022 {
    import delimited using "$tmp/`y'_AR_Region_Mobility_Report.csv", varnames(nonames) rowrange(2) ///
        stringcols(_all) encoding("utf-8") clear
    keep if v6 == "AR-C" & v4 == ""
    capture append using `mob'
    save `mob', replace
}
* the zip holds one file per country; remove them all
local files : dir "$tmp" files "*_Region_Mobility_Report.csv"
foreach f of local files {
    erase "$tmp/`f'"
}
gen date = date(v9, "YMD")
format date %td
gen mob_retail_rec  = real(v10)
gen mob_grocery     = real(v11)
gen mob_parks       = real(v12)
gen mob_transit     = real(v13)
gen mob_workplaces  = real(v14)
gen mob_residential = real(v15)
keep date mob_*
isid date
sort date
save "$inter/mobility.dta", replace
summarize date, format

log close
