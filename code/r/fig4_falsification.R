# fig4_falsification.R
# Figure 4. Estimates at the reform date against placebo thresholds.
#   (a) the Weekend x Post estimate at the 55 free-access placebo Saturdays and at the reform date;
#   (b) the participation term of the accounting decomposition for the placebo cohorts and at the reform.
# Input : output/estimates/placebo_distribution.csv, main_estimate.csv (14_falsification.do, 11_main.do)
#         output/estimates/placebo_cohorts.csv, decomposition.csv (16_cohort.do)
# Output: output/figures/fig4_falsification.pdf / .png

source("code/r/fig_theme.R")
library(patchwork)

pl <- fread("output/estimates/placebo_distribution.csv")
main_beta <- fread("output/estimates/main_estimate.csv")$estimate
pc <- fread("output/estimates/placebo_cohorts.csv")
part_reform <- fread("output/estimates/decomposition.csv")[outcome == "trips", participation]

SPAN_LAB <- c(`2019` = sprintf("Thresholds in 2019 (%d)", pl[span == "2019", .N]),
              `2020_21` = sprintf("Thresholds from May 2020 to March 2021 (%d)", pl[span != "2019", .N]))
pl[, span := factor(as.character(span), levels = names(SPAN_LAB))]
pc[, span := factor(as.character(span), levels = names(SPAN_LAB))]

hist_panel <- function(dt, xvar, ref, ylab, ttl) {
  ggplot(dt, aes(x = .data[[xvar]], fill = span)) +
    geom_histogram(binwidth = 0.05, boundary = 0, closed = "left", colour = "grey15", linewidth = 0.25) +
    geom_vline(xintercept = ref, linewidth = 0.7, colour = COL_DAY[["Weekend"]]) +
    annotate("text", x = ref + 0.03, y = Inf, vjust = 1.4, hjust = 0, size = FIG_ANNOT,
             colour = COL_DAY[["Weekend"]], label = sprintf("Reform date, %s", fmt_num(ref, 3))) +
    scale_fill_manual(values = c(`2019` = "grey35", `2020_21` = "grey82"), labels = SPAN_LAB) +
    scale_x_continuous(limits = c(-1.0, 0.5), breaks = seq(-1, 0.5, 0.25), labels = lab_num(2), expand = c(0, 0)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12)), breaks = seq(0, 20, 4)) +
    labs(x = "Log points", y = ylab, fill = NULL, title = ttl) +
    theme_fig() + theme(legend.position = "bottom")
}
p4a <- hist_panel(pl, "estimate", main_beta, "Number of thresholds", "(a) Aggregate estimate, weekend × post")
p4b <- hist_panel(pc, "participation", part_reform, "Number of placebo cohorts",
                  "(b) Participation term of the decomposition")

f4 <- (p4a + p4b) + plot_layout(guides = "collect") & theme(legend.position = "bottom")
save_fig(f4, "fig4_falsification", FIG_W, 3.0)
