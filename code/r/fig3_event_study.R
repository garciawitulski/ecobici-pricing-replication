# fig3_event_study.R
# Figure 3. Weekly event-study estimates, preferred specification (weather controls), with 95%
# confidence intervals (Newey-West, lag 14). The reference week -1 is the open circle at zero.
# Input : output/estimates/event_study.csv (12_event_study.do, sample E)
# Output: output/figures/fig3_event_study.pdf / .png

source("code/r/fig_theme.R")

es <- fread("output/estimates/event_study.csv")
es <- es[sample == "E"][order(week)]

f3 <- ggplot(es, aes(week, estimate)) +
  geom_hline(yintercept = 0, linewidth = 0.4, colour = "grey45") +
  geom_vline(xintercept = -0.5, linetype = "dashed", linewidth = 0.45, colour = "grey35") +
  geom_errorbar(data = es[week != -1], aes(ymin = ci_lo, ymax = ci_hi), width = 0,
                linewidth = 0.55, colour = "grey15") +
  geom_point(data = es[week != -1], size = 1.9, shape = 21, fill = "grey15", colour = "grey15") +
  geom_point(data = es[week == -1], size = 1.9, shape = 21, fill = "white", colour = "grey15", stroke = 0.6) +
  scale_x_continuous(breaks = seq(-8, 7, 1), labels = lab_num(0), expand = expansion(add = 0.4)) +
  scale_y_continuous(breaks = seq(-1.5, 0, 0.5), labels = lab_num(1)) +
  coord_cartesian(ylim = c(-1.7, 0.25)) +
  labs(x = "Weeks relative to the reform", y = "Estimate (log points)") +
  theme_fig()

save_fig(f3, "fig3_event_study", FIG_W, 3.1)
