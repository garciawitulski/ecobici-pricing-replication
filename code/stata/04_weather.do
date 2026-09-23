* 04_weather.do
* Daily Buenos Aires weather 2019-2023 from NOAA NCEI.
*
* Input : data/raw/weather/ghcnd_AR000875850_BuenosAiresObservatorio.csv  GHCN-Daily, Observatorio (primary)
*         data/raw/weather/ghcnd_ARM00087582_Aeroparque.csv               GHCN-Daily, Aeroparque (backup)
*         data/raw/weather/gsod_87585099999_YYYY.csv                      GSOD, Observatorio
*         data/raw/weather/gsod_87582099999_YYYY.csv                      GSOD, Aeroparque
* Output: data/intermediate/weather.dta
*
* Units: GHCN-Daily PRCP in tenths of mm, TMAX/TMIN/TAVG in tenths of degrees C.
*        GSOD temperatures in degrees F (9999.9 = missing), PRCP in inches (99.99 = missing).
* Rule : each variable is taken from the first source that reports it, in the order
*        GHCN Observatorio -> GHCN Aeroparque -> GSOD Aeroparque -> GSOD Observatorio.
*        Days with no precipitation report are set to 0 and flagged (prcp_missing = 1); days with no
*        temperature report get the median of the series and are flagged (temp_missing = 1).

capture log close
log using "$logs/04_weather.log", replace text

* ---- GHCN-Daily ---------------------------------------------------------------
foreach s in obs aero {
    if "`s'" == "obs"  local file "ghcnd_AR000875850_BuenosAiresObservatorio.csv"
    if "`s'" == "aero" local file "ghcnd_ARM00087582_Aeroparque.csv"
    import delimited using "$raw/weather/`file'", varnames(1) stringcols(_all) clear
    rename date date_str
    gen date = date(date_str, "YMD")
    gen double prcp_`s' = real(prcp) / 10
    gen double tmax_`s' = real(tmax) / 10
    gen double tmin_`s' = real(tmin) / 10
    gen double tavg_`s' = real(tavg) / 10
    keep date prcp_`s' tmax_`s' tmin_`s' tavg_`s'
    keep if inrange(date, td(01jan2019), td(31dec2023))
    tempfile ghcn_`s'
    save `ghcn_`s''
}

* ---- GSOD -------------------------------------------------------------------------
foreach s in obs aero {
    if "`s'" == "obs"  local id "87585099999"
    if "`s'" == "aero" local id "87582099999"
    clear
    tempfile gsod_`s'
    forvalues y = 2019/2023 {
        import delimited using "$raw/weather/gsod_`id'_`y'.csv", varnames(1) stringcols(_all) clear
        capture append using `gsod_`s''
        save `gsod_`s'', replace
    }
    rename date date_str
    gen date = date(date_str, "YMD")
    gen double temp_f = real(temp)
    gen double max_f = real(max)
    gen double min_f = real(min)
    gen double prcp_in = real(prcp)
    foreach v in temp_f max_f min_f {
        replace `v' = . if `v' > 9999
    }
    replace prcp_in = . if prcp_in > 99
    gen double prcp_gsod_`s' = prcp_in * 25.4
    gen double tavg_gsod_`s' = (temp_f - 32) * 5 / 9
    gen double tmax_gsod_`s' = (max_f - 32) * 5 / 9
    gen double tmin_gsod_`s' = (min_f - 32) * 5 / 9
    keep date prcp_gsod_`s' tavg_gsod_`s' tmax_gsod_`s' tmin_gsod_`s'
    save `gsod_`s'', replace
}

* ---- combine on the full calendar ----------------------------------------------------
use date using "$inter/calendar.dta", clear
merge 1:1 date using `ghcn_obs', nogenerate keep(master match)
merge 1:1 date using `ghcn_aero', nogenerate keep(master match)
merge 1:1 date using `gsod_aero', nogenerate keep(master match)
merge 1:1 date using `gsod_obs', nogenerate keep(master match)

foreach v in prcp tmax tmin tavg {
    gen double `v' = `v'_obs
    gen `v'_source = "`v'_obs" if !missing(`v'_obs)
    foreach s in aero gsod_aero gsod_obs {
        replace `v'_source = "`v'_`s'" if missing(`v') & !missing(`v'_`s')
        replace `v' = `v'_`s' if missing(`v')
    }
}
rename prcp prcp_mm
rename tmax tmax_c
rename tmin tmin_c
rename tavg tavg_c

* missing precipitation: set to zero and flag
gen prcp_missing = missing(prcp_mm)
replace prcp_mm = 0 if prcp_missing == 1
gen rain_day = prcp_mm >= 1
gen heavy_rain_day = prcp_mm >= 10

* missing temperature: median of the series and flag
gen temp_missing = missing(tmax_c) | missing(tmin_c) | missing(tavg_c)
foreach v in tmax_c tmin_c tavg_c {
    summarize `v', detail
    replace `v' = r(p50) if missing(`v')
}

keep date prcp_mm prcp_source tmax_c tmax_source tmin_c tavg_c rain_day heavy_rain_day ///
     prcp_missing temp_missing
format date %td
compress
save "$inter/weather.dta", replace

* checks: the analysis window (+/- 8 weeks around the reform)
count if prcp_missing == 1 & abs(date - $policy) <= 56
count if temp_missing == 1 & abs(date - $policy) <= 56
tab prcp_source, missing

log close
