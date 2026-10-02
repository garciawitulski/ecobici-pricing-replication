* 04_weather.do
* Daily Buenos Aires weather 2019-2023 from the SMN (Servicio Meteorologico Nacional, Argentina).
*
* CHANGE (2026-10-01, author-approved; CAF-007 in the project repository): this file replaces the
* NOAA GHCN-Daily/GSOD construction. The SMN daily station records are complete over 2019-2023 for
* both city stations, and the NOAA products dated TMAX and PRCP one calendar day later than the
* SMN climatological day, so the previous controls paired the trips of day d with the previous
* afternoon's maximum. The Observatorio is therefore the single source and no value is imputed.
*
* Input : data/raw/weather/smn_datos_meteorologicos_1991_2020.xlsx   daily data 1991-2020 (from the
*             RAR archive of the same name; extract it next to the archive if not already done)
*         data/raw/weather/smn_datos_meteorologicos_desde_2021.lst   daily data from 2021 (from
*             Datos-diarios-2021-2026-01102026.zip; tab-separated, repeats its header mid-file)
*         Both were downloaded manually from the SMN by the authors on 1 October 2026; they are in
*         the replication archive deposited with the journal. SHA-256 in data/manual/raw_files.csv.
* Output: data/intermediate/weather.dta
*
* Stations: 87585 BUENOS AIRES OBSERVATORIO (Villa Ortuzar; single source for the controls) and
*           87582 AEROPARQUE AERO (riverfront; exported as *_aero for the robustness check).
* Conventions (LEAME sheets inside the archives): 'S/D' = missing; in PRECIP an EMPTY cell means
* no precipitation (0 mm) and a recorded 0 means traces below 0.1 mm; TMEDIA is the mean over the
* synoptic hours. The rain day runs from 12 UTC of the stated date to 12 UTC of the next day, so
* precipitation and the daily maximum carry the date of the local day on which they occurred.

capture log close
log using "$logs/04_weather.log", replace text

* ---- extract the archives if the extracted files are not already present ------------------------
capture confirm file "$raw/weather/smn_datos_meteorologicos_desde_2021.lst"
if _rc {
    cd "$raw/weather"
    unzipfile "Datos-diarios-2021-2026-01102026.zip", replace
    cd "$root"
}
capture confirm file "$raw/weather/smn_datos_meteorologicos_1991_2020.xlsx"
if _rc {
    * Windows 10+ bsdtar reads RAR5 archives; on other systems extract the RAR manually.
    shell tar -xf "$raw/weather/smn_datos_meteorologicos_1991_2020.rar" -C "$raw/weather"
}
capture confirm file "$raw/weather/smn_datos_meteorologicos_1991_2020.xlsx"
if _rc {
    display as error "extract smn_datos_meteorologicos_1991_2020.xlsx from the RAR into data/raw/weather first"
    exit 601
}

* ---- helpers: S/D -> missing; PRECIP blank -> 0 --------------------------------------------------
* (written inline below because the columns arrive as string when any cell holds 'S/D' and as
*  numeric otherwise, depending on the station mix of each file)

* ---- 1991-2020 file (xlsx, first sheet), kept for 2019-2020 --------------------------------------
set excelxlsxlargefile on      // the workbook is 72 MB, above Stata's default 40 MB guard
import excel using "$raw/weather/smn_datos_meteorologicos_1991_2020.xlsx", firstrow clear
keep if inlist(NRO_OMM, 87582, 87585)
display "rows for the two city stations, 1991-2020 file: " _N

* FECHA arrives as a Stata date or datetime depending on the Excel cell format
capture confirm string variable FECHA
if !_rc gen date = date(substr(FECHA, 1, 10), "YMD")
else gen date = cond(FECHA > 1e8, dofc(FECHA), FECHA)
format date %td
keep if year(date) >= 2019

foreach v in TMAX TMIN TMEDIA {
    capture confirm string variable `v'
    if !_rc gen double x_`v' = real(trim(`v'))        // 'S/D' and blanks -> missing
    else gen double x_`v' = `v'
}
capture confirm string variable PRECIP
if !_rc {
    gen double x_PRECIP = real(trim(PRECIP)) if trim(PRECIP) != "" & trim(PRECIP) != "S/D"
    replace x_PRECIP = 0 if trim(PRECIP) == ""        // empty cell = no precipitation (LEAME)
}
else gen double x_PRECIP = cond(missing(PRECIP), 0, PRECIP)
keep NRO_OMM date x_*
rename (NRO_OMM x_TMAX x_TMIN x_TMEDIA x_PRECIP) (station tmax tmin tavg prcp)
tempfile hist
save `hist'

* ---- file from 2021 (.lst, tab-separated; repeats its header and blank lines mid-file) -----------
import delimited using "$raw/weather/smn_datos_meteorologicos_desde_2021.lst", delimiter(tab) ///
    varnames(1) stringcols(_all) encoding("latin1") clear
gen long station = real(trim(nro_omm))
keep if inlist(station, 87582, 87585)
gen date = date(trim(fecha), "DMY")
format date %td
keep if date <= td(31dec2023)
foreach v in tmax tmin tmedia {
    gen double x_`v' = real(trim(`v'))                // 'S/D' and blanks -> missing
}
gen double x_prcp = real(trim(precip)) if trim(precip) != "" & trim(precip) != "S/D"
replace x_prcp = 0 if trim(precip) == ""              // empty field = no precipitation (LEAME)
keep station date x_*
rename (x_tmax x_tmin x_tmedia x_prcp) (tmax tmin tavg prcp)
append using `hist'
isid station date
display "station-days 2019-2023, both stations: " _N

* ---- completeness on the full calendar -----------------------------------------------------------
* every calendar day must be present with every variable for the Observatorio; Aeroparque is the
* robustness gauge and only warns
preserve
keep if station == 87585
merge 1:1 date using "$inter/calendar.dta", keep(match using) nogenerate
keep date tmax tmin tavg prcp
assert _N == 1826                                      // one row per calendar day 2019-2023
quietly count if missing(tmax) | missing(tmin) | missing(tavg) | missing(prcp)
if r(N) > 0 {
    display as error "SMN Observatorio has " r(N) " incomplete day(s); the construction assumes none"
    exit 459
}
assert tmin <= tmax
rename (prcp tmax tmin tavg) (prcp_mm tmax_c tmin_c tavg_c)
gen prcp_source = "smn_obs"
gen tmax_source = "smn_obs"
gen tmin_source = "smn_obs"
gen tavg_source = "smn_obs"
gen rain_day = prcp_mm >= 1
gen heavy_rain_day = prcp_mm >= 10
gen prcp_missing = 0                                   // the SMN series is complete: identically 0
gen temp_missing = 0
keep date prcp_mm prcp_source tmax_c tmax_source tmin_c tmin_source tavg_c tavg_source ///
     rain_day heavy_rain_day prcp_missing temp_missing
tempfile obs
save `obs'
restore

keep if station == 87582
quietly count if missing(tmax) | missing(tmin) | missing(tavg) | missing(prcp)
if r(N) > 0 display as error "warning: SMN Aeroparque (robustness gauge) has " r(N) " incomplete day(s)"
rename (prcp tmax tmin tavg) (prcp_mm_aero tmax_c_aero tmin_c_aero tavg_c_aero)
gen rain_day_aero = prcp_mm_aero >= 1
keep date prcp_mm_aero tmax_c_aero tmin_c_aero tavg_c_aero rain_day_aero
merge 1:1 date using `obs', assert(match) nogenerate
sort date
format date %td
compress
save "$inter/weather.dta", replace

* ---- checks --------------------------------------------------------------------------------------
count
summarize prcp_mm tmax_c tavg_c
correlate tmax_c tmax_c_aero
correlate prcp_mm prcp_mm_aero
count if rain_day != rain_day_aero
display "days on which the two gauges disagree on rain_day (>= 1 mm), 2019-2023: " r(N)
count if abs(date - $policy) <= 56 & rain_day == 1
display "rain days inside the +/- 8 week window (Observatorio): " r(N)

log close
