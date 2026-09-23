# fig1_daily_use.R
# Figure 1. Daily Ecobici trips by day type, 16 January to 8 May 2021.
# Input : data/analysis/ecobici_daily_2019_2023.csv (06_daily_panel.do)
# Output: output/figures/fig1_daily_use.pdf / .png

source("code/r/fig_theme.R")

POLICY   <- as.IDate("2021-03-13")    # reform in force
ANNOUNCE <- as.IDate("2021-03-05")    # announcement

d <- fread("data/analysis/ecobici_daily_2019_2023.csv")
d[, date := as.IDate(date)]

# days within 8 weeks of the reform; holidays are shown but were excluded from the estimation
w <- d[abs(date - POLICY) <= 56 & !is.na(n_trips)]
w[, kind := fifelse(holiday_any == 1, "Holiday (excluded)", fifelse(weekend == 1, "Weekend", "Weekday"))]
w[, kind := factor(kind, levels = c("Weekday", "Weekend", "Holiday (excluded)"))]
w[, y := n_trips / 1000]
Y_TOP <- 16

f1 <- ggplot(w, aes(date, y)) +
  geom_vline(xintercept = as.Date(ANNOUNCE), linetype = "dotted", linewidth = 0.45, colour = "grey55") +
  geom_vline(xintercept = as.Date(POLICY), linetype = "solid", linewidth = 0.6, colour = "grey15") +
  geom_line(data = w[kind != "Holiday (excluded)"], aes(group = kind, colour = kind, linetype = kind),
            linewidth = 0.4) +
  geom_point(aes(colour = kind, shape = kind, fill = kind), size = 1.55, stroke = 0.45) +
  annotate("text", x = as.Date(POLICY) + 1.2, y = Y_TOP - 0.15, label = "Reform in force, 13 March",
           hjust = 0, vjust = 1, size = FIG_ANNOT, colour = "grey10") +
  annotate("text", x = as.Date(ANNOUNCE) - 1.2, y = Y_TOP - 0.15, label = "Announcement, 5 March",
           hjust = 1, vjust = 1, size = FIG_ANNOT, colour = "grey45") +
  scale_colour_manual(values = c(COL_DAY, `Holiday (excluded)` = "grey40")) +
  scale_fill_manual(values = c(COL_DAY, `Holiday (excluded)` = "white")) +
  scale_shape_manual(values = c(SHP_DAY, `Holiday (excluded)` = 21)) +
  scale_linetype_manual(values = LTY_DAY, guide = "none") +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%d %b", expand = expansion(mult = 0.01)) +
  scale_y_continuous(limits = c(0, Y_TOP), breaks = seq(0, 15, 5), expand = c(0, 0), labels = lab_num(0)) +
  labs(x = NULL, y = "Trips per day (thousands)") +
  theme_fig() + theme(legend.position = "bottom")

save_fig(f1, "fig1_daily_use", FIG_W, 3.3)
