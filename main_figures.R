# main_figures.R
# Draws every figure of the paper from the estimates written by the Stata do-files.
# Run it from the root folder of the repository, after main.do:
#     Rscript main_figures.R
# or, in RStudio, set the working directory to this folder and source the file.
#
# Packages: data.table, ggplot2, patchwork, sf (see README for versions).

scripts <- c("fig1_daily_use.R", "fig2_station_map.R", "fig3_event_study.R", "fig4_falsification.R",
             "fig5_participation.R", "fig6_persistence.R", "figA1_event_sensitivity.R", "figA2_sensitivity.R")

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
for (s in scripts) {
  cat("Running", s, "\n")
  source(file.path("code/r", s))
}
cat("Figures written to output/figures\n")
