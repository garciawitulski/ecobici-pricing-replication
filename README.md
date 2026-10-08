# Replication package

**From Free to Paid Access: Participation Effects of a Bike-Share Pricing Reform**

Christian García-Witulski and Mariano Rabassa

## Overview

The code in this package rebuilds, from public raw data, every table, figure and number in the paper
and its online appendix. On 13 March 2021 Buenos Aires introduced user fees for weekend and holiday use
of its public bike-share system (Ecobici), while weekday access stayed free for residents. The paper
compares weekend days with weekdays around that date.

Data preparation, estimation and tables are written in **Stata** (`main.do`); figures are drawn in
**R** (`main_figures.R`) from estimates saved by Stata. 

## Data availability

All data are public and were obtained from the sources below between 11 and 16 September 2026, except the SMN weather files, downloaded on 1 October 2026 from the Datos Abiertos section at https://www.smn.gob.ar/descarga-de-datos. The SMN confirmed to the authors that the from-2021 dataset is updated monthly as new observations complete quality control, so later downloads may extend or revise it; the copies used for the paper are the ones whose SHA-256 checksums are recorded in `data/manual/raw_files.csv`. The
authors had legitimate access to all of them, and all may be redistributed under their licences. The
raw files (about 1.2 GB) are not stored in this GitHub repository: `code/stata/01_download_raw.do`
downloads them from the sources. The copies used for the
paper are included in the replication archive deposited with the journal.

| Data | Provider | Files | Licence |
|---|---|---|---|
| Ecobici trip records, 2019–2023 | Gobierno de la Ciudad de Buenos Aires (GCBA), Buenos Aires Data | `ecobici_trips/recorridos-realizados-YYYY.zip` | CC BY 2.5 AR |
| Ecobici user registry, 2015–2023 | GCBA, Buenos Aires Data | `users/usuarios_ecobici_YYYY.csv`, `users/usuarios-ecobici-YYYY.csv` | CC BY 2.5 AR |
| Ecobici stations (dock capacity) | GCBA, Buenos Aires Data | `stations/nuevas-estaciones-bicicletas-publicas.geojson` | CC BY 2.5 AR |
| Subte (subway) turnstile entries, 2021 | SBASE, via Buenos Aires Data | `public_transport/molinetes-2021.zip` | CC BY 2.5 AR |
| City perimeter, comunas, subway and railway stations | GCBA, Buenos Aires Data | `geography/*.geojson` | CC BY 2.5 AR |
| Daily station weather, 1991–2020 and from 2021 | Servicio Meteorológico Nacional (SMN), Argentina | `weather/smn_datos_meteorologicos_1991_2020.rar`, `weather/Datos-diarios-2021-2026-01102026.zip` | SMN open data, attribution required |
| COVID-19 Community Mobility Reports | Google LLC | `mobility/Region_Mobility_Report_CSVs.zip` | Google terms of use (free to use, with attribution) |
| National holidays, 2019–2023 | Ministerio del Interior (argentina.gob.ar, archived by the Internet Archive); Boletín Oficial (Decreto 842/2022) | `holidays/*.html` | Public official documents |

Files in the repository:

- `data/manual/holidays_2019_2023.csv` — the holiday calendar, transcribed from the archived official
  pages in `data/raw/holidays/` (date, name, type, source page).
- `data/manual/raw_files.csv` — URL, size and SHA-256 of every raw file.
- `data/analysis/ecobici_daily_2019_2023` (`.dta` and `.csv`) — the day-level analysis dataset built by
  `06_daily_panel.do`, and `ecobici_daily_primary` — its primary estimation sample (106 days). With
  these files `11_main.do` to `14_falsification.do` and `18_persistence.do` run without the raw data;
  the other do-files need the trip-, station- and user-level files rebuilt from the raw data.

The trip records identify users only by an anonymised numeric id; the registry adds the user's age,
gender, registration date and whether the user holds an Argentine identity document. No other personal
information is used.

## Computational requirements

- **Stata** 15 or later (tested with Stata/MP 15.0 on Windows 11). The user-written packages are
  included in `code/stata/ado/plus` and are used from there, so no installation is needed:
  `reghdfe` 6.13.1, `ftools` 2.50.0, `require`, `ppmlhdfe` 2.3.3, `honestdid` 1.3.0, `xtscc` 1.4.
- **R** 4.6.1 (tested) with `data.table` 1.18.4, `ggplot2` 4.0.3, `patchwork` 1.3.2 and `sf` 1.1.1.
- About 8 GB of memory and 5 GB of free disk space. On a laptop with a 4-core processor:
  `03_trips.do` about 15 minutes, `04_weather.do` a few minutes (it imports a 992,000-row Excel sheet), `13_parallel_trends.do` about 45 minutes, the rest about 20 minutes;
  the figures about 1 minute.
- Random numbers: the seed is 20210313 (wild bootstrap in `11_main.do`, simulated benchmarks in
  `13_parallel_trends.do`).

## Instructions

1. Extract `smn_datos_meteorologicos_1991_2020.xlsx` from the RAR archive into `data/raw/weather`
   (on Windows 10+, `tar -xf` in a terminal reads RAR5; `04_weather.do` also attempts this). The
   `.lst` file is unzipped automatically.
2. Open `main.do`, set `global root` to the folder of this repository, and run it **from the Stata
   window** (the download step may call `curl` through the shell, which Stata ignores in batch mode).
   If `data/raw` already holds the raw files, the download step skips them.
3. Run `main_figures.R` with the repository folder as working directory (`Rscript main_figures.R`).

Tables are written to `output/tables` as LaTeX fragments that the manuscript includes directly;
estimates behind the figures to `output/estimates`; figures to `output/figures` (PDF and PNG); a log
of every do-file to `output/logs`.

## Programs

| Program | What it does |
|---|---|
| `main.do` | Runs every Stata step in order |
| `code/stata/00_setup.do` | Folders, settings, packages and two small helpers that format table cells |
| `code/stata/01_download_raw.do` | Downloads the raw data |
| `code/stata/02_calendar.do` | Calendar 2019–2023 with holidays |
| `code/stata/03_trips.do` | Trip records → one file per year and the daily trip outcomes |
| `code/stata/04_weather.do` | Daily weather from the SMN station records (Observatorio single source; Aeroparque as robustness) |
| `code/stata/05_subte_mobility.do` | Subte entries (resolving the mixed date formats of the source) and Google mobility |
| `code/stata/06_daily_panel.do` | The daily analysis dataset and the primary sample |
| `code/stata/07_users.do` | User registry and the user × day panel |
| `code/stata/08_stations.do` | Station supply, stable stations, commuting profile, distances to subway and rail |
| `code/stata/sample.do` | Keeps the estimation sample around a (true or placebo) threshold; called by the analysis do-files |
| `code/stata/event_dummies.do` | Weekend × week event-study dummies; called by 12 and 13 |
| `code/stata/distance.do` | Distance in metres between two points; called by 08 |
| `code/stata/11_main.do` … `19_spillover.do` | Estimates and tables (see below) |
| `main_figures.R`, `code/r/*.R` | Figures (`fig_theme.R` holds the shared style) |

## Tables and figures

| Exhibit | Program | Output |
|---|---|---|
| Table 1 | `11_main.do` | `output/tables/table1_descriptives.tex` |
| Table 2 | `11_main.do` | `table2_main.tex` |
| Table 3 | `14_falsification.do` (uses `13_parallel_trends.do`) | `table3_identification.tex` |
| Table 4 | `16_cohort.do` | `table4_margins.tex` |
| Figure 1 | `code/r/fig1_daily_use.R` | `output/figures/fig1_daily_use.pdf` |
| Figure 2 | `code/r/fig2_station_map.R` (points from `08_stations.do`) | `fig2_station_map.pdf` |
| Figure 3 | `code/r/fig3_event_study.R` (estimates from `12_event_study.do`) | `fig3_event_study.pdf` |
| Figure 4 | `code/r/fig4_falsification.R` (from `14_falsification.do`, `16_cohort.do`) | `fig4_falsification.pdf` |
| Figure 5 | `code/r/fig5_participation.R` (from `16_cohort.do`) | `fig5_participation.pdf` |
| Figure 6 | `code/r/fig6_persistence.R` (from `18_persistence.do`) | `fig6_persistence.pdf` |
| Table A1, panels A and B | `12_event_study.do` | `tableA1_pretrends.tex`, `tableA1b_weather.tex` |
| Table A2, A3 | `13_parallel_trends.do` | `tableA2_relative_magnitudes.tex`, `tableA3_outer_bounds.tex` |
| Table A4, A5, A8 | `14_falsification.do` | `tableA4_placebo.tex`, `tableA5_falsification.tex`, `tableA8_outcomes.tex` |
| Table A6, A7, A12 | `15_supply_mobility.do` | `tableA6_supply.tex`, `tableA7_mobility.tex`, `tableA12_stable_network.tex` |
| Table A13 | `16_cohort.do` | `tableA13_cohort_robustness.tex` |
| Table A9, A10 | `17_heterogeneity.do` | `tableA9_heterogeneity.tex`, `tableA10_spatial.tex` |
| Table A11 | `18_persistence.do` | `tableA11_persistence.tex` |
| Table A14 | `19_spillover.do` | `tableA14_weekday_spillover.tex` |
| Figure A1 | `code/r/figA1_event_sensitivity.R` (from `12_event_study.do`) | `figA1_event_sensitivity.pdf` |
| Figure A2 | `code/r/figA2_sensitivity.R` (from `13_parallel_trends.do`) | `figA2_sensitivity.pdf` |

Numbers quoted in the text that do not appear in a table (for example raw means, the Poisson estimate,
the wild bootstrap p-value, the residency-field shares and the placebo ranks) are printed in the log of
the do-file that computes them, next to a short description.

## Licence

The code is released under the MIT licence (see `LICENSE`). The derived datasets in `data/analysis`
and `data/manual` are released under CC BY 4.0; the raw data remain under the licences of their
providers listed above. The packages in `code/stata/ado` belong to their authors and are included only
so that the package runs as it did for the paper.

## Data citations

All accessed in September 2026.

- Gobierno de la Ciudad de Buenos Aires. *Bicicletas públicas* (trip records and user registry).
  Buenos Aires Data. https://data.buenosaires.gob.ar/dataset/bicicletas-publicas
- Gobierno de la Ciudad de Buenos Aires. *Estaciones de bicicletas públicas*. Buenos Aires Data.
  https://data.buenosaires.gob.ar/dataset/estaciones-bicicletas-publicas
- Subterráneos de Buenos Aires (SBASE). *Subte: viajes por molinete*. Buenos Aires Data.
  https://data.buenosaires.gob.ar/dataset/subte-viajes-molinetes
- Gobierno de la Ciudad de Buenos Aires. *Perímetro*, *Comunas*, *Estaciones de subte*, *Estaciones de
  ferrocarril*. Buenos Aires Data. https://data.buenosaires.gob.ar
- Servicio Meteorológico Nacional (Argentina). *Datos meteorológicos diarios por estación*,
  1991–2020 and from 2021; stations 87585 (Buenos Aires Observatorio) and 87582 (Aeroparque Aero).
  https://www.smn.gob.ar/descarga-de-datos (accessed 1 October 2026).
- Google LLC. *Google COVID-19 Community Mobility Reports*. https://www.google.com/covid19/mobility/
- Ministerio del Interior, República Argentina. *Feriados nacionales* 2019–2023. argentina.gob.ar,
  archived by the Internet Archive; Decreto 842/2022, Boletín Oficial de la República Argentina.
