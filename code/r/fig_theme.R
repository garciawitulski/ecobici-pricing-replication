# fig_theme.R
# Shared settings for all figures: size, fonts, colours and how files are saved.
# Sourced by every figure script.

suppressPackageStartupMessages({ library(data.table); library(ggplot2) })

FIG_W     <- 6.3    # inches: the text width of the manuscript, so figures are included at 100%
FIG_BASE  <- 9      # font size (pt) of axis titles and panel titles
FIG_ANNOT <- 2.75   # size of text inside plots (mm), about 7.8 pt

# Day types: red and blue that stay distinct for colour-blind readers; shape and line type also
# differ, so the series can be told apart in grayscale.
COL_DAY <- c(Weekday = "#4393C3", Weekend = "#B2182B")
SHP_DAY <- c(Weekday = 24, Weekend = 22)          # filled triangle, filled square
LTY_DAY <- c(Weekday = "22", Weekend = "solid")   # dashed weekday line, solid weekend line

# Numbers written with a true minus sign
fmt_num <- function(x, digits) {
  s <- formatC(abs(x), format = "f", digits = digits)
  ifelse(x < 0 & round(abs(x), digits) > 0, paste0("−", s), s)
}
lab_num <- function(digits) function(x) ifelse(is.na(x), NA_character_, fmt_num(x, digits))

theme_fig <- function(base = FIG_BASE) {
  theme_classic(base_size = base, base_family = "sans") +
    theme(axis.line = element_line(linewidth = 0.35, colour = "grey20"),
          axis.ticks = element_line(linewidth = 0.35, colour = "grey20"),
          axis.ticks.length = unit(2.5, "pt"),
          axis.text = element_text(size = base - 1, colour = "grey15"),
          axis.title = element_text(size = base, colour = "grey10"),
          axis.title.y = element_text(margin = margin(r = 4)),
          panel.grid.major.y = element_line(linewidth = 0.25, colour = "grey90"),
          legend.title = element_blank(),
          legend.text = element_text(size = base - 1),
          legend.key.width = unit(18, "pt"), legend.key.height = unit(9, "pt"),
          legend.margin = margin(t = -2, b = 0),
          plot.title = element_text(size = base, face = "plain", hjust = 0, margin = margin(b = 4)),
          plot.title.position = "plot",
          plot.margin = margin(4, 6, 2, 2))
}

# Save a figure as vector PDF and as 600 dpi PNG in output/figures
save_fig <- function(p, name, w, h) {
  ggsave(file.path("output/figures", paste0(name, ".pdf")), p, width = w, height = h,
         device = cairo_pdf, bg = "white")
  ggsave(file.path("output/figures", paste0(name, ".png")), p, width = w, height = h,
         dpi = 600, bg = "white")
}

# English month names on the axes, whatever the language of the computer
invisible(Sys.setlocale("LC_TIME", "C"))
