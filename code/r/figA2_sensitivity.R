# figA2_sensitivity.R
# Figure A2. Robust confidence sets under the relative-magnitudes restriction (Rambachan and Roth 2023),
# preferred specification, for the five post-reform targets. Mbar = 0 shows the conventional interval.
# Input : output/estimates/parallel_trends.csv (13_parallel_trends.do, variant "weather")
# Output: output/figures/figA2_sensitivity.pdf / .png

source("code/r/fig_theme.R")

pt <- fread("output/estimates/parallel_trends.csv")
pt <- pt[variant == "weather" & framework %in% c("baseline", "rm")]
TARG <- c("(a) Week 0, Sunday 14 March only", "(b) Week 1, first complete weekend",
          "(c) Weeks 0 and 1 averaged", "(d) Weeks 0 to 3 averaged", "(e) Weeks 0 to 7 averaged")
pt[, panel := factor(TARG[target], levels = TARG)]
pt[, value := fifelse(framework == "baseline", 0, mbar)]
KIND <- c(conventional = "Conventional 95% interval",
          excl = "Robust set, excludes zero",
          incl = "Robust set, includes zero")
pt[, kind := fifelse(framework == "baseline", "conventional", fifelse(ub < 0, "excl", "incl"))]
pt[, kind := factor(KIND[kind], levels = unname(KIND))]

fa2 <- ggplot(pt, aes(value, colour = kind, linetype = kind)) +
  geom_hline(yintercept = 0, linewidth = 0.4, colour = "grey45") +
  geom_errorbar(aes(ymin = lb, ymax = ub), width = 0.14, linewidth = 0.55) +
  geom_point(data = pt[framework == "baseline"], aes(y = estimate), size = 1.6, shape = 21, fill = "grey15",
             show.legend = FALSE) +
  facet_wrap(~ panel, ncol = 2, scales = "free_y") +
  scale_colour_manual(values = c("grey15", "grey15", "grey62")) +
  scale_linetype_manual(values = c("solid", "solid", "22")) +
  scale_x_continuous(breaks = seq(0, 3, 0.5), labels = lab_num(1), expand = expansion(add = 0.25)) +
  scale_y_continuous(labels = lab_num(1)) +
  labs(x = expression(paste("Allowed post-reform change in the differential trend, ", bar(M),
                            ", as a multiple of the largest pre-reform change")),
       y = "Log points", colour = NULL, linetype = NULL) +
  theme_fig() +
  theme(strip.background = element_blank(),
        strip.text = element_text(size = FIG_BASE, hjust = 0, margin = margin(b = 3)),
        panel.spacing.x = unit(10, "pt"), panel.spacing.y = unit(8, "pt"),
        legend.position = "bottom")

save_fig(fa2, "figA2_sensitivity", FIG_W, 5.8)
