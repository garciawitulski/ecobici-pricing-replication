* 01_download_raw.do
* Downloads the raw data from the official sources into data/raw.
*
* The list of files, their URLs and their sizes when they were downloaded for the paper (11 September
* 2026) is in data/manual/raw_files.csv. A file that is already in data/raw with the expected size is
* not downloaded again. If a source has changed the file since then, its size will differ and a
* warning is printed; the copies used in the paper are in the replication archive (see README).
*
* Stata 16 and later download https files with -copy-; older versions fall back on curl, which is
* included in Windows 10 and later, macOS and Linux. Total size: about 1.2 GB.

capture log close
log using "$logs/01_download_raw.log", replace text

import delimited using "$manual/raw_files.csv", varnames(1) stringcols(_all) clear
local n = _N
forvalues i = 1/`n' {
    local url  = url[`i']
    local file = file[`i']
    local bytes = real(bytes[`i'])
    local folder = substr("`file'", 1, strpos("`file'", "/") - 1)
    capture mkdir "$raw"
    capture mkdir "$raw/`folder'"

    * skip files that are already there with the expected size
    capture checksum "$raw/`file'"
    if _rc == 0 & r(filelen) == `bytes' {
        display "already downloaded: `file'"
        continue
    }
    display "downloading `file'"
    capture copy "`url'" "$raw/`file'", replace
    * Stata 15 and older cannot read https addresses: use curl instead (run main.do from the Stata
    * window, not in batch mode, which ignores shell commands)
    if _rc != 0 shell curl -L -s -S -o "$raw/`file'" "`url'"
    capture checksum "$raw/`file'"
    if _rc != 0 display as error "  download failed: `file'"
    else if r(filelen) != `bytes' display as error "  size differs from the paper's copy (" r(filelen) " vs `bytes' bytes): `file'"
}

log close
