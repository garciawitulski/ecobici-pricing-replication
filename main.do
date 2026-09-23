* main.do
* Replication package for "From Free to Paid Access: Participation Effects of a Bike-Share Pricing
* Reform" (Garcia-Witulski and Rabassa). Runs every Stata step, from the raw data to the tables.
* The figures are drawn afterwards in R by main_figures.R.
*
* Before running: set the folder of the repository on the next line.
global root "C:/path/to/ecobici-pricing-replication"

do "$root/code/stata/00_setup.do"

* ---- 1. data ------------------------------------------------------------------------------------------
* The raw data (about 1.2 GB) are downloaded once. Comment this line if data/raw is already filled.
do "$code/01_download_raw.do"
do "$code/02_calendar.do"          // holidays and calendar
do "$code/03_trips.do"             // trip records -> daily outcomes (about 15 minutes)
do "$code/04_weather.do"           // NOAA weather
do "$code/05_subte_mobility.do"    // Subte turnstiles and Google mobility
do "$code/06_daily_panel.do"       // the daily panel and the primary sample
do "$code/07_users.do"             // user registry and user x day panel
do "$code/08_stations.do"          // station supply, commuting profile, distances

* ---- 2. estimates and tables ----------------------------------------------------------------------
do "$code/11_main.do"              // Tables 1 and 2
do "$code/12_event_study.do"       // Tables A1 and A1b; Figures 3 and A1
do "$code/13_parallel_trends.do"   // Tables A2 and A3; Figure A2 (about 45 minutes)
do "$code/14_falsification.do"     // Tables 3, A4, A5, A8; Figure 4a
do "$code/15_supply_mobility.do"   // Tables A6, A7, A13
do "$code/16_cohort.do"            // Tables 4, A9, A14; Figures 4b and 5
do "$code/17_heterogeneity.do"     // Tables A10, A11
do "$code/18_persistence.do"       // Table A12; Figure 6
do "$code/19_spillover.do"         // Table A15

display "Done. Tables are in output/tables, logs in output/logs. Now run main_figures.R."
