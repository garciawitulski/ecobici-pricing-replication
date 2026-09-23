# fig5_participation.R
# Figure 5. Participation and the accounting decomposition in the cohort of pre-reform users.
#   (a) probability of any ride, by day type, before and after the reform (windows of equal length);
#   (b) the decomposition E[Y] = P(any ride) x E[Y | any ride] for trips, minutes ridden and active days.
# Input : output/estimates/cohort_cells.csv, decomposition.csv (16_cohort.do)
# Output: output/figures/fig5_participation.pdf / .png

source("code/r/fig_theme.R")
library(patchwork)

# ---- panel (a) ----------------------------------------------------------------------------------------
cc <- fread("output/estimates/cohort_cells.csv")
pa <- data.table(daytype = factor(ifelse(cc$weekend == 1, "Weekend", "Weekday"), levels = c("Weekday", "Weekend")),
                 period = factor(ifelse(cc$post == 1, "After", "Before"), levels = c("Before", "After")),
                 p_any = cc$p_any)

p5a <- ggplot(pa, aes(period, p_any, group = daytype)) +
  geom_line(aes(colour = daytype, linetype = daytype), linewidth = 0.6) +
  geom_point(aes(colour = daytype, shape = daytype, fill = daytype), size = 2.3, stroke = 0.5) +
  geom_text(data = pa[period == "Before"], aes(label = fmt_num(p_any, 3), colour = daytype),
            hjust = 1.35, size = FIG_ANNOT, show.legend = FALSE) +
  geom_text(data = pa[period == "After"], aes(label = fmt_num(p_any, 3), colour = daytype),
            hjust = -0.35, size = FIG_ANNOT, show.legend = FALSE) +
  geom_text(data = pa[period == "After"], aes(label = daytype, colour = daytype),
            hjust = -0.35, vjust = -1.25, size = FIG_ANNOT, fontface = "bold", show.legend = FALSE) +
  scale_colour_manual(values = COL_DAY) + scale_fill_manual(values = COL_DAY) +
  scale_shape_manual(values = SHP_DAY) + scale_linetype_manual(values = LTY_DAY) +
  scale_x_discrete(expand = expansion(add = 0.55)) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25), expand = c(0, 0), labels = lab_num(2)) +
  labs(x = NULL, y = "Probability of any ride", title = "(a) Participation") +
  theme_fig() + theme(legend.position = "none")

# ---- panel (b): stacked bars, each ending at the total for that outcome -------------------------------
dec <- fread("output/estimates/decomposition.csv")
dec[, xi := match(outcome, c("trips", "minutes", "days"))]
dec[, outcome_lab := c("Trips", "Minutes\nridden", "Active\ndays")[xi]]
bars <- rbind(dec[, .(xi, component = "Participation", value = participation, y_top = 0, y_bot = participation)],
              dec[, .(xi, component = "Intensity among active riders", value = intensity,
                      y_top = participation, y_bot = participation + intensity)])
bars[, component := factor(component, levels = c("Participation", "Intensity among active riders"))]
BW <- 0.28

p5b <- ggplot(bars) +
  geom_hline(yintercept = 0, linewidth = 0.4, colour = "grey45") +
  geom_rect(aes(xmin = xi - BW, xmax = xi + BW, ymin = y_bot, ymax = y_top, fill = component),
            colour = "grey15", linewidth = 0.3) +
  geom_text(aes(x = xi, y = (y_top + y_bot) / 2, label = fmt_num(value, 3), colour = component),
            size = FIG_ANNOT, show.legend = FALSE) +
  geom_text(data = dec, aes(x = xi, y = total - 0.025, label = fmt_num(total, 3)),
            vjust = 1, size = FIG_ANNOT, colour = "grey15", fontface = "bold") +
  geom_text(data = dec, aes(x = xi, y = 0.03, label = sprintf("%s%%", fmt_num(100 * share, 1))),
            vjust = 0, size = FIG_ANNOT, colour = "grey15") +
  scale_fill_manual(values = c(Participation = "grey30", `Intensity among active riders` = "grey82")) +
  scale_colour_manual(values = c(Participation = "white", `Intensity among active riders` = "grey15")) +
  scale_x_continuous(breaks = 1:3, labels = dec[order(xi), outcome_lab], expand = expansion(add = 0.55)) +
  scale_y_continuous(limits = c(-1.15, 0.13), breaks = seq(-1, 0, 0.25), expand = c(0, 0), labels = lab_num(2)) +
  labs(x = NULL, y = "Log points", fill = NULL, title = "(b) Accounting decomposition") +
  theme_fig() + theme(legend.position = "bottom")

save_fig(p5a + p5b + plot_layout(widths = c(1, 1)), "fig5_participation", FIG_W, 3.45)
