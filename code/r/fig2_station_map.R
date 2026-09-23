# fig2_station_map.R
# Figure 2. Ecobici stations in the City of Buenos Aires.
#   (a) the stations with a departure before the reform, split into the stable-station sample
#       (active on at least 40 of the 54 pre-reform days) and the rest;
#   (b) the commuting profile of the stable stations, with the subway stations.
# Input : output/estimates/station_map_points.csv (08_stations.do)
#         data/raw/geography/perimetro.geojson, comunas.geojson, estaciones_de_subte.geojson (GCBA)
# Output: output/figures/fig2_station_map.pdf / .png
# Projection: POSGAR 2007 / Argentina 5 (EPSG:5347), in metres.

source("code/r/fig_theme.R")
suppressPackageStartupMessages(library(sf))
library(patchwork)
sf_use_s2(FALSE)
CRS_MAP <- 5347

# ---- layers -----------------------------------------------------------------------------------------
pts <- fread("output/estimates/station_map_points.csv")
psf <- st_transform(st_as_sf(pts, coords = c("lon", "lat"), crs = 4326), CRS_MAP)
peri <- st_transform(st_make_valid(st_read("data/raw/geography/perimetro.geojson", quiet = TRUE)), CRS_MAP)
comu <- st_transform(st_make_valid(st_read("data/raw/geography/comunas.geojson", quiet = TRUE)), CRS_MAP)
sub  <- st_transform(st_read("data/raw/geography/estaciones_de_subte.geojson", quiet = TRUE), CRS_MAP)

n_stable <- pts[universe == "stable", .N]
n_below  <- pts[universe != "stable", .N]
n_more   <- pts[commuter_group == "more commuter-oriented", .N]
n_less   <- pts[commuter_group == "less commuter-oriented", .N]
lab_a <- c(stable = sprintf("Stable-station sample (%d)", n_stable),
           `below threshold` = sprintf("Other pre-reform stations (%d)", n_below))
lab_b <- c(`more commuter-oriented` = sprintf("More commuter-oriented (%d)", n_more),
           `less commuter-oriented` = sprintf("Less commuter-oriented (%d)", n_less),
           subway = sprintf("Subway station (%d)", nrow(sub)))

# both panels share the same extent, so they are drawn at the same scale
bb <- st_bbox(peri)
map_coord <- coord_sf(crs = st_crs(CRS_MAP), datum = NA, expand = FALSE,
                      xlim = c(bb["xmin"] - 300, bb["xmax"] + 300), ylim = c(bb["ymin"] - 300, bb["ymax"] + 300))
PT_SIZE <- 1.45

# scale bar of 4 km in the south-west corner (map units are metres)
SCALE_M <- 4000
x0 <- unname(bb["xmin"]) + 400
y0 <- unname(bb["ymin"]) + 900
BAR_H <- 340
scale_bar <- list(
  annotate("rect", xmin = x0, xmax = x0 + SCALE_M / 2, ymin = y0, ymax = y0 + BAR_H,
           fill = "grey15", colour = "grey15", linewidth = 0.25),
  annotate("rect", xmin = x0 + SCALE_M / 2, xmax = x0 + SCALE_M, ymin = y0, ymax = y0 + BAR_H,
           fill = "white", colour = "grey15", linewidth = 0.25),
  annotate("text", x = c(x0, x0 + SCALE_M / 2, x0 + SCALE_M), y = y0 + BAR_H + 180,
           label = c("0", "2", "4 km"), size = FIG_ANNOT, colour = "grey15", hjust = c(0, 0.5, 0.5), vjust = 0))

base_map <- list(
  geom_sf(data = peri, fill = "grey96", colour = "grey30", linewidth = 0.4),
  geom_sf(data = comu, fill = NA, colour = "grey75", linewidth = 0.2),
  theme_void(base_size = FIG_BASE, base_family = "sans"),
  theme(legend.position = "inside", legend.position.inside = c(0.995, 0.015),
        legend.justification = c(1, 0), legend.direction = "vertical",
        legend.title = element_blank(), legend.background = element_blank(),
        legend.text = element_text(size = FIG_BASE - 1), legend.key.height = unit(10, "pt"),
        legend.key.width = unit(10, "pt"),
        plot.title = element_text(size = FIG_BASE, face = "plain", hjust = 0, margin = margin(b = 3)),
        plot.margin = margin(2, 4, 2, 4)))

# ---- panel (a) ---------------------------------------------------------------------------------------
psf$universe <- factor(psf$universe, levels = c("stable", "below threshold"))
pa <- ggplot() + base_map +
  geom_sf(data = psf[order(psf$universe, decreasing = TRUE), ],
          aes(fill = universe, shape = universe), colour = "grey10", stroke = 0.3, size = PT_SIZE) +
  scale_fill_manual(values = c(stable = "grey20", `below threshold` = "white"), labels = lab_a) +
  scale_shape_manual(values = c(stable = 21, `below threshold` = 21), labels = lab_a) +
  scale_bar +
  labs(title = "(a) Stations active before the reform") + map_coord

# ---- panel (b) ---------------------------------------------------------------------------------------
stb <- psf[psf$universe == "stable", ]
stb$grp <- as.character(stb$commuter_group)
sub$grp <- "subway"
lay <- rbind(sub["grp"], stb["grp"])          # subway first, so the crosses lie under the stations
lay$grp <- factor(lay$grp, levels = c("more commuter-oriented", "less commuter-oriented", "subway"))
pb <- ggplot() + base_map +
  geom_sf(data = lay, aes(fill = grp, shape = grp, size = grp, colour = grp), stroke = 0.35) +
  scale_fill_manual(values = c(`more commuter-oriented` = "#01665E", `less commuter-oriented` = "#DFC27D",
                               subway = NA), labels = lab_b) +
  scale_shape_manual(values = c(`more commuter-oriented` = 24, `less commuter-oriented` = 21, subway = 4),
                     labels = lab_b) +
  scale_size_manual(values = c(`more commuter-oriented` = PT_SIZE + 0.1, `less commuter-oriented` = PT_SIZE + 0.1,
                               subway = 0.95), labels = lab_b) +
  scale_colour_manual(values = c(`more commuter-oriented` = "grey10", `less commuter-oriented` = "grey10",
                                 subway = "grey38"), labels = lab_b) +
  scale_bar +
  labs(title = "(b) Commuting profile of the stable stations") + map_coord

save_fig(pa + pb + plot_layout(ncol = 2), "fig2_station_map", FIG_W, 3.85)
