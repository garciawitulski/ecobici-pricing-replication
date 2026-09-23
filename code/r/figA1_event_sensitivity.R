# figA1_event_sensitivity.R
# Figure A1. Event-study estimates under the sample variations of Table A1.
# Input : output/estimates/event_study.csv (12_event_study.do, samples A to F)
# Output: output/figures/figA1_event_sensitivity.pdf / .png

source("code/r/fig_theme.R")

es <- fread("output/estimates/event_study.csv")
PANEL <- c(A = "(a) Primary sample, calendar controls only",
           B = "(b) Excluding long weekends",
           C = "(c) Excluding the Carnaval period",
           D = "(d) Excluding extreme-rainfall days",
           E = "(e) With weather controls (Figure 3)",
           F = "(f) Pre-reform period 1 to 12 March only")
es[, panel := factor(PANEL[sample], levels = unname(PANEL))]

fa1 <- ggplot(es, aes(week, estimate)) +
  geom_hline(yintercept = 0, linewidth = 0.4, colour = "grey45") +
  geom_vline(xintercept = -0.5, linetype = "dashed", linewidth = 0.45, colour = "grey35") +
  geom_errorbar(data = es[week != -1], aes(ymin = ci_lo, ymax = ci_hi), width = 0,
                linewidth = 0.5, colour = "grey15") +
  geom_point(data = es[week != -1], size = 1.5, shape = 21, fill = "grey15", colour = "grey15") +
  geom_point(data = es[week == -1], size = 1.5, shape = 21, fill = "white", colour = "grey15", stroke = 0.6) +
  facet_wrap(~ panel, ncol = 2) +
  scale_x_continuous(breaks = seq(-8, 7, 2), labels = lab_num(0), expand = expansion(add = 0.5)) +
  scale_y_continuous(breaks = seq(-1.5, 0, 0.5), labels = lab_num(1)) +
  coord_cartesian(ylim = c(-1.75, 0.3)) +
  labs(x = "Weeks relative to the reform", y = "Estimate (log points)") +
  theme_fig() +
  theme(strip.background = element_blank(),
        strip.text = element_text(size = FIG_BASE, hjust = 0, margin = margin(b = 3)),
        panel.spacing.x = unit(10, "pt"), panel.spacing.y = unit(8, "pt"))

save_fig(fa1, "figA1_event_sensitivity", FIG_W, 6.2)
