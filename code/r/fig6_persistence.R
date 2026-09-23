# fig6_persistence.R
# Figure 6. Weekend-to-weekday ratio of daily Ecobici trips, 2019 to 2023. Grey points are weekly
# ratios; black segments are the period means of Table A12.
# Input : output/estimates/weekly_ratio.csv, ratio_by_period.csv (18_persistence.do)
# Output: output/figures/fig6_persistence.pdf / .png

source("code/r/fig_theme.R")

wr  <- fread("output/estimates/weekly_ratio.csv")
per <- fread("output/estimates/ratio_by_period.csv")
wr[, wk_start := as.Date(wk_start)]
per[, `:=`(from = as.Date(from), to = as.Date(to))]

LAUNCH <- as.Date("2019-02-25")                  # system relaunch
SUSP   <- as.Date("2020-03-20")                  # pandemic suspension ...
REOPEN <- as.Date("2020-05-11")                  # ... and reopening
POLICY <- as.Date("2021-03-13")                  # the reform
REV    <- as.Date(c("2022-01-10", "2022-08-05", "2023-02-23"))   # later tariff revisions
wr[, seg := wk_start < SUSP]                     # no line across the weeks without service
Y6 <- 1.75

f6 <- ggplot() +
  annotate("rect", xmin = SUSP, xmax = REOPEN, ymin = 0, ymax = Y6, fill = "grey92", colour = NA) +
  geom_vline(xintercept = POLICY, linewidth = 0.6, colour = "grey15") +
  geom_vline(xintercept = REV, linetype = "dotted", linewidth = 0.45, colour = "grey45") +
  geom_line(data = wr, aes(wk_start, ratio, group = seg), linewidth = 0.3, colour = "grey72") +
  geom_point(data = wr, aes(wk_start, ratio), size = 0.55, colour = "grey55") +
  geom_segment(data = per, aes(x = from, xend = to, y = ratio, yend = ratio),
               linewidth = 1.1, colour = "grey10", lineend = "butt") +
  geom_text(data = per, aes(x = from + (to - from) / 2, y = ratio, label = fmt_num(ratio, 2)),
            vjust = -0.7, size = FIG_ANNOT, colour = "grey10", fontface = "bold") +
  annotate("text", x = POLICY + 12, y = Y6 - 0.03, hjust = 0, vjust = 1, size = FIG_ANNOT,
           colour = "grey10", label = "Weekend pricing reform, 13 March 2021") +
  annotate("text", x = REV[2], y = Y6 - 0.2, hjust = 0.5, vjust = 1, size = FIG_ANNOT,
           colour = "grey45", label = "Later tariff revisions") +
  annotate("text", x = SUSP - 8, y = Y6 - 0.03, hjust = 1, vjust = 1, size = FIG_ANNOT,
           colour = "grey45", label = "Service suspended,\n20 March to 11 May 2020", lineheight = 0.9) +
  scale_x_date(breaks = as.Date(sprintf("%d-01-01", 2019:2024)), date_labels = "%Y",
               limits = c(LAUNCH - 10, as.Date("2024-01-05")), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, Y6), breaks = seq(0, 1.5, 0.5), expand = c(0, 0), labels = lab_num(1)) +
  labs(x = NULL, y = "Weekend trips relative to weekday trips") +
  theme_fig()

save_fig(f6, "fig6_persistence", FIG_W, 3.2)
