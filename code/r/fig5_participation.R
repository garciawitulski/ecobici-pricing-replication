# fig5_participation.R
# Figure 5. Accounting decomposition in the cohort of pre-reform users.
# The decomposition E[Y] = P(any ride) x E[Y | any ride] for trips, minutes ridden and active days.
# Input : output/estimates/decomposition.csv (16_cohort.do)
# Output: output/figures/fig5_participation.pdf / .png

source("code/r/fig_theme.R", encoding = "UTF-8")

# Stacked bars, each ending at the total for that outcome.
dec <- fread("output/estimates/decomposition.csv")
dec[, xi := match(outcome, c("trips", "minutes", "days"))]
stopifnot(nrow(dec) == 3L, !anyNA(dec$xi), uniqueN(dec$xi) == 3L,
          all(abs(dec$total - dec$participation - dec$intensity) < 1e-7),
          all(abs(dec$share - dec$participation / dec$total) < 1e-7))
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
  labs(x = NULL, y = "Log points", fill = NULL) +
  theme_fig() + theme(legend.position = "bottom")

# Use the same vector and raster devices as the manuscript figure.
ggsave("output/figures/fig5_participation.pdf", p5b, width = FIG_W, height = 3.3,
       device = grDevices::cairo_pdf, bg = "white")
ggsave("output/figures/fig5_participation.png", p5b, width = FIG_W, height = 3.3,
       device = grDevices::png, dpi = 600, type = "cairo", bg = "white")
