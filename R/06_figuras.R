# 06_figuras.R — Las siete figuras del envío, en español y a 300 dpi
# ============================================================================
# Reemplaza a figuras_es.py. Lee las salidas de los scripts 01 a 05 y escribe
# los JPG con los nombres del envío en ES_active/figures/.
#
#   Fig1_biplot.jpg            nube y centroides de categoría del plano factorial
#   Fig2_csmca_panel.jpg       elipses de concentración de subnubes por tipo de provincia
#   Fig3_theil_temporal.jpg    descomposición de Theil a lo largo de ocho eras
#   Fig4_shannon_ranking.jpg   composición por provincia bajo Milei
#   Fig5_shift_share.jpg       diferencial provincial del shift-share
#   FigS1_scatter_context.jpg  correlatos económicos de la diversidad
#   FigS2_choropleth.jpg       mapa del Shannon H, Fernández contra Milei
#
# La figura 1 colorea la nube por forma jurídica. La versión anterior la
# coloreaba por conglomerado; los conglomerados salieron del artículo porque la
# partición dependía de la submuestra con que se construía el árbol.

# La raiz del proyecto es el directorio que contiene R/. Se deduce de la
# ubicacion del propio script, de modo que el arbol es portable.
if (!exists("ES_ROOT")) {
  .argv <- commandArgs(trailingOnly = FALSE)
  .file <- sub("^--file=", "", grep("^--file=", .argv, value = TRUE))
  ES_ROOT <- if (length(.file) == 1) {
    normalizePath(file.path(dirname(.file), ".."), winslash = "/")
  } else {
    normalizePath(getwd(), winslash = "/")
  }
}
source(file.path(ES_ROOT, "R", "00_comun.R"))
suppressMessages({
  library(ggplot2); library(ggrepel); library(patchwork); library(sf); library(scales)
})

titulo("06 — Figuras del envío")

DPI <- 300
BASE_PT <- 9

# ── Paleta y etiquetas ──────────────────────────────────────────────────────
COL_TIPO_PROV <- c(metropolitan = "#e41a1c", intermediate = "#377eb8",
                   peripheral = "#4daf4a")
COL_VAR <- c(tipo = "#8B0000", clae_sec = "#2F4F4F")
FORMA_MARCA <- c(tipo = 16, clae_sec = 15)

COL_FORMA <- c(Asoc = "#e41a1c", Coop = "#377eb8", Mutual = "#4daf4a",
               Fund = "#984ea3", SA = "#ff7f00", SRL = "#a65628",
               SAS = "#f781bf", Otra = "#999999")
FORMA_ORDEN <- c("Coop", "Mutual", "Asoc", "Fund", "SA", "SRL", "SAS", "Otra")

ETIQ_BIPLOT <- c(
  Coop = "Coop", Asoc = "Asoc", Fund = "Fund", Mutual = "Mutual",
  SRL = "SRL", SA = "SA", SAS = "SAS", Otra = "Otra",
  A = "Agropecuaria", B = "Minas", C = "Industria", D = "Energía",
  E = "Agua", F = "Construcción", G = "Comercio", H = "Transporte",
  I = "Gastronomía", J = "Información", K = "Finanzas", L = "Inmobiliario",
  M = "Profesionales", N = "Administrativos", O = "Adm. pública",
  P = "Enseñanza", Q = "Salud", R = "Artes y recreación",
  S = "Asociaciones", T = "Hogares", Z = "Otras actividades"
)

dec <- function(x, d = 1) format(round(x, d), nsmall = d, decimal.mark = ",")

tema_es <- function(base = BASE_PT) {
  theme_minimal(base_size = base) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
      axis.line = element_line(colour = "grey30", linewidth = 0.3),
      plot.title = element_text(face = "bold", size = base + 2),
      legend.key.size = unit(0.8, "lines"),
      strip.text = element_text(face = "bold", size = base + 1)
    )
}

guardar_jpg <- function(p, nombre, ancho, alto) {
  ruta <- file.path(FIGURAS, paste0(nombre, ".jpg"))
  ggsave(ruta, p, width = ancho, height = alto, dpi = DPI,
         units = "in", device = grDevices::jpeg, quality = 95)
  info <- file.info(ruta)
  cat(sprintf("  %s  (%.0f x %.0f px, %.1f MB)\n", basename(ruta),
              ancho * DPI, alto * DPI, info$size / 1e6))
  invisible(ruta)
}

# ── Datos comunes ───────────────────────────────────────────────────────────
eig <- read.csv(file.path(SALIDAS, "acm_valores_propios.csv"))
pct1 <- eig$pct_inercia_ca[1]
pct2 <- eig$pct_inercia_ca[2]
lab_eje1 <- sprintf("Eje 1 (%s%% de la inercia)", dec(pct1))
lab_eje2 <- sprintf("Eje 2 (%s%% de la inercia)", dec(pct2))

# ═══════════════════════════════════════════════════════ Figura 1: biplot ═══
cat("
Figura 1: biplot del plano factorial
")

nube <- as.data.frame(arrow::read_parquet(file.path(SALIDAS, "acm_nube_individuos.parquet")))
nube$tipo <- factor(nube$tipo, levels = FORMA_ORDEN)

cats <- read.csv(file.path(SALIDAS, "acm_categorias.csv"))
cats$nivel <- sub("^[^.]+\\.", "", cats$categoria)
cats$etiqueta <- ifelse(cats$nivel %in% names(ETIQ_BIPLOT),
                        ETIQ_BIPLOT[cats$nivel], cats$nivel)
media_ctr <- 100 / nrow(cats)
cats$mostrar <- cats$variable == "tipo" |
  cats$ctr1 > media_ctr | cats$ctr2 > media_ctr

# Un poco de dispersión para que los perfiles idénticos no se apilen
set.seed(SEMILLA)
jit <- 0.035
nube$x <- nube$dim1 + stats::rnorm(nrow(nube), 0, jit)
nube$y <- nube$dim2 + stats::rnorm(nrow(nube), 0, jit)

etq_cats <- subset(cats, mostrar)
etq_cats$hex <- unname(COL_VAR[etq_cats$variable])

ETIQ_VAR <- c(tipo = "Forma jurídica (activa)",
              clae_sec = "Sección de actividad (activa)")

p1 <- ggplot() +
  geom_point(data = nube, aes(x, y, colour = tipo),
             size = 0.35, alpha = 0.13, stroke = 0) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_point(data = cats, aes(coord1, coord2, shape = variable, fill = variable),
             size = 2.4, colour = "white", stroke = 0.4) +
  geom_text_repel(data = etq_cats, aes(coord1, coord2, label = etiqueta),
                  colour = etq_cats$hex,
                  size = 2.7, fontface = "bold",
                  min.segment.length = 0, segment.size = 0.25,
                  box.padding = 0.55, point.padding = 0.25, force = 4,
                  segment.colour = "grey55", max.overlaps = Inf, seed = SEMILLA) +
  scale_colour_manual(values = COL_FORMA, name = "Forma jurídica\n(nube de organizaciones)",
                      breaks = FORMA_ORDEN,
                      guide = guide_legend(override.aes = list(size = 2.2, alpha = 1),
                                           order = 2)) +
  scale_fill_manual(values = COL_VAR, name = "Centroide de categoría",
                    labels = ETIQ_VAR, guide = guide_legend(order = 1)) +
  scale_shape_manual(values = c(tipo = 21, clae_sec = 22),
                     name = "Centroide de categoría", labels = ETIQ_VAR,
                     guide = guide_legend(order = 1)) +
  labs(x = lab_eje1, y = lab_eje2) +
  coord_fixed() +
  tema_es() +
  theme(legend.position = "right",
        legend.box.background = element_rect(fill = alpha("white", 0.9), colour = NA))

guardar_jpg(p1, "Fig1_biplot", 8.2, 6.4)

# ═════════════════════════════════════════════ Figura 2: elipses de las subnubes ═══
cat("
Figura 2: elipses de concentración de las subnubes
")

elipses <- read.csv(file.path(SALIDAS, "acm_elipses.csv"))
subn <- read.csv(file.path(SALIDAS, "acm_subnubes.csv"))
elipses$era_grupo <- factor(elipses$era_grupo, levels = ERA_GRUPO_ORDEN)
subn$era_grupo <- factor(subn$era_grupo, levels = ERA_GRUPO_ORDEN)
elipses$tipo_prov <- factor(elipses$tipo_prov, levels = TIPO_PROV_ORDEN)
subn$tipo_prov <- factor(subn$tipo_prov, levels = TIPO_PROV_ORDEN)
elipses$grupo <- paste(elipses$era_grupo, elipses$tipo_prov)

letras <- setNames(sprintf("(%s) %s", letters[1:6], ERA_GRUPO_ORDEN), ERA_GRUPO_ORDEN)
elipses$panel <- factor(letras[as.character(elipses$era_grupo)], levels = letras)
subn$panel <- factor(letras[as.character(subn$era_grupo)], levels = letras)

etq_n <- subn
etq_n$texto <- sprintf("%s: n = %s", TIPO_PROV_ETIQUETA[etq_n$tipo_prov], fmt_n(etq_n$n))
etq_n$fila <- match(etq_n$tipo_prov, TIPO_PROV_ORDEN)

p2 <- ggplot() +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.25) +
  geom_vline(xintercept = 0, colour = "grey70", linewidth = 0.25) +
  geom_path(data = elipses, aes(x, y, colour = tipo_prov, group = grupo,
                                linetype = tipo_prov), linewidth = 0.7) +
  geom_point(data = subn, aes(centro1, centro2, colour = tipo_prov),
             shape = 3, size = 2.4, stroke = 0.9, show.legend = FALSE) +
  geom_text(data = etq_n, aes(x = -Inf, y = Inf, label = texto, colour = tipo_prov,
                              vjust = 1.6 + 1.4 * (fila - 1)),
            hjust = -0.08, size = 2.5, fontface = "bold", show.legend = FALSE) +
  facet_wrap(~panel, ncol = 3) +
  scale_colour_manual(values = COL_TIPO_PROV, name = "Tipo de provincia",
                      labels = TIPO_PROV_ETIQUETA, breaks = TIPO_PROV_ORDEN) +
  scale_linetype_manual(values = c(metropolitan = "solid", intermediate = "dashed",
                                   peripheral = "dotdash"),
                        name = "Tipo de provincia", labels = TIPO_PROV_ETIQUETA, breaks = TIPO_PROV_ORDEN) +
  labs(x = sprintf("Eje 1 (%s%% de la inercia)  →  polo comercial", dec(pct1, 0)),
       y = sprintf("Eje 2 (%s%% de la inercia)  →  polo cooperativo", dec(pct2, 0))) +
  coord_fixed() +
  tema_es(10) +
  theme(legend.position = "bottom")

guardar_jpg(p2, "Fig2_csmca_panel", 11.0, 8.0)

# ══════════════════════════════════════════════ Figura 3: Theil temporal ═══
cat("\nFigura 3: descomposición de Theil\n")

th <- read.csv(file.path(SALIDAS, "theil_por_era.csv"))
th$era_es <- factor(th$era_es, levels = ERA_ETIQUETA[ERAS])

apilado <- rbind(
  data.frame(era_es = th$era_es, componente = "Entre jurisdicciones", valor = th$T_entre),
  data.frame(era_es = th$era_es, componente = "Composición nacional", valor = th$T_nacional)
)
apilado$componente <- factor(apilado$componente,
                             levels = c("Composición nacional", "Entre jurisdicciones"))

p3a <- ggplot(apilado, aes(as.numeric(era_es), valor, fill = componente)) +
  geom_area(alpha = 0.85, colour = "white", linewidth = 0.3) +
  geom_line(data = th, aes(as.numeric(era_es), T_total),
            inherit.aes = FALSE, colour = "black", linewidth = 0.7) +
  geom_point(data = th, aes(as.numeric(era_es), T_total),
             inherit.aes = FALSE, colour = "black", size = 1.8) +
  scale_x_continuous(breaks = seq_along(levels(th$era_es)),
                     labels = levels(th$era_es), expand = c(0.01, 0)) +
  scale_fill_manual(values = c("Entre jurisdicciones" = "#e41a1c",
                               "Composición nacional" = "#377eb8"), name = NULL) +
  labs(x = NULL, y = "Concentración (Theil T)", title = "(a)") +
  tema_es(11) +
  theme(legend.position = "top", axis.text.x = element_text(angle = 30, hjust = 1))

p3b <- ggplot(th, aes(as.numeric(era_es), pct_entre)) +
  geom_col(fill = "#e41a1c", alpha = 0.85, width = 0.7) +
  geom_text(aes(label = paste0(dec(pct_entre), "%")), vjust = -0.4, size = 2.8) +
  scale_x_continuous(breaks = seq_along(levels(th$era_es)),
                     labels = levels(th$era_es), expand = c(0.02, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = NULL, y = "Participación entre jurisdicciones (%)", title = "(b)") +
  tema_es(11) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

guardar_jpg(p3a / p3b, "Fig3_theil_temporal", 8.0, 9.0)

# ══════════════════════════════════ Figura 4: composición bajo Milei ═══
cat("\nFigura 4: composición organizacional por provincia bajo Milei\n")

d <- cargar_registro(c("tipo", "era", "provincia", "prov_type"))
comp <- d[d$era == "milei", ] |>
  dplyr::count(provincia, prov_type, tipo) |>
  dplyr::group_by(provincia) |>
  dplyr::mutate(pct = 100 * n / sum(n)) |>
  dplyr::ungroup()

orden <- comp |>
  dplyr::filter(tipo == "SAS") |>
  dplyr::arrange(pct) |>
  dplyr::pull(provincia)
faltan <- setdiff(unique(comp$provincia), orden)
orden <- c(faltan, orden)

comp$provincia <- factor(comp$provincia, levels = orden)
comp$tipo <- factor(comp$tipo, levels = FORMA_ORDEN)

col_ejes <- COL_TIPO_PROV[comp$prov_type[match(levels(comp$provincia), comp$provincia)]]

p4 <- ggplot(comp, aes(pct, provincia, fill = tipo)) +
  geom_col(width = 0.75, colour = "white", linewidth = 0.15) +
  scale_fill_manual(values = COL_FORMA, name = NULL) +
  scale_x_continuous(expand = c(0, 0), breaks = seq(0, 100, 20)) +
  labs(x = "Composición organizacional (%)", y = NULL) +
  guides(fill = guide_legend(nrow = 1)) +
  tema_es(10) +
  theme(legend.position = "bottom",
        axis.text.y = element_text(colour = col_ejes, face = "bold"),
        panel.grid.major.y = element_blank())

guardar_jpg(p4, "Fig4_shannon_ranking", 8.0, 7.0)

# ═════════════════════════════════════════════ Figura 5: shift-share ═══
cat("\nFigura 5: diferencial provincial del shift-share\n")

ssf <- read.csv(file.path(SALIDAS, "shift_share_fernandez.csv"))
ssm <- read.csv(file.path(SALIDAS, "shift_share_milei.csv"))
ssf$panel <- "(a) Fernández (2020-2023)"
ssm$panel <- "(b) Milei (2024-2025)"
ss <- rbind(ssf, ssm)

orden_ss <- ssm$provincia[order(ssm$diferencial_provincial)]
ss$provincia <- factor(ss$provincia, levels = orden_ss)
col_ss <- COL_TIPO_PROV[ssm$prov_type[match(orden_ss, ssm$provincia)]]

p5 <- ggplot(ss, aes(diferencial_provincial, provincia, fill = prov_type)) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.4) +
  geom_col(width = 0.72) +
  facet_wrap(~panel, ncol = 2) +
  scale_fill_manual(values = COL_TIPO_PROV, name = "Tipo de provincia",
                    labels = TIPO_PROV_ETIQUETA, breaks = TIPO_PROV_ORDEN) +
  scale_x_continuous(labels = function(x) format(x, big.mark = ".", scientific = FALSE)) +
  labs(x = "Diferencial provincial (organizaciones por año)", y = NULL) +
  tema_es(10) +
  theme(legend.position = "bottom",
        axis.text.y = element_text(colour = col_ss, face = "bold"),
        panel.grid.major.y = element_blank())

guardar_jpg(p5, "Fig5_shift_share", 11.0, 7.5)

# ═══════════════════════════════ Figura S1: correlatos económicos ═══
cat("\nFigura S1: correlatos económicos de la diversidad provincial\n")

ctx <- read.csv(file.path(RAIZ, "tables", "tab_provincial_context.csv"))
abrev <- c("Buenos Aires" = "BA", "Santiago del Estero" = "SdE",
           "Tierra del Fuego" = "TdF")
ctx$etq <- ifelse(ctx$provincia %in% names(abrev), abrev[ctx$provincia], ctx$provincia)

specs <- list(
  list("pda_per_100k", "shannon_H_milei",
       "Acceso financiero (puntos por 100.000 hab.)", "Shannon H (era Milei)"),
  list("hhi_empleo", "shannon_H_milei",
       "Concentración del empleo (Herfindahl)", "Shannon H (era Milei)"),
  list("pct_with_account", "sas_share_milei",
       "% de adultos con cuenta bancaria", "Participación SAS (era Milei)"),
  list("pda_per_100k", "provincial_diff",
       "Acceso financiero (puntos por 100.000 hab.)", "Diferencial provincial")
)

paneles <- lapply(specs, function(s) {
  ggplot(ctx, aes(.data[[s[[1]]]], .data[[s[[2]]]], colour = prov_type)) +
    geom_point(size = 2.2, alpha = 0.9) +
    geom_text_repel(aes(label = etq), size = 2.2, show.legend = FALSE,
                    max.overlaps = 30, seed = SEMILLA, segment.size = 0.2) +
    scale_colour_manual(values = COL_TIPO_PROV, name = "Tipo de provincia",
                        labels = TIPO_PROV_ETIQUETA, breaks = TIPO_PROV_ORDEN) +
    labs(x = s[[3]], y = s[[4]]) +
    tema_es(9)
})

pS1 <- (paneles[[1]] + paneles[[2]]) / (paneles[[3]] + paneles[[4]]) +
  plot_layout(guides = "collect") & theme(legend.position = "bottom")

guardar_jpg(pS1, "FigS1_scatter_context", 10.0, 9.0)

# ════════════════════════════════════════ Figura S2: coroplético ═══
cat("\nFigura S2: mapa del Shannon H, Fernández contra Milei\n")

# Los nombres del geojson vienen con la codificación rota ("CÃ³rdoba") y
# name_es llama "Buenos Aires" tanto a la provincia como a la CABA. El código
# ISO 3166-2 es ASCII y unívoco, así que el cruce se hace por ahí.
ISO_PROVINCIA <- c(
  "AR-A" = "Salta",       "AR-B" = "Buenos Aires", "AR-C" = "CABA",
  "AR-D" = "San Luis",    "AR-E" = "Entre Ríos",   "AR-F" = "La Rioja",
  "AR-G" = "Santiago del Estero", "AR-H" = "Chaco", "AR-J" = "San Juan",
  "AR-K" = "Catamarca",   "AR-L" = "La Pampa",     "AR-M" = "Mendoza",
  "AR-N" = "Misiones",    "AR-P" = "Formosa",      "AR-Q" = "Neuquén",
  "AR-R" = "Río Negro",   "AR-S" = "Santa Fe",     "AR-T" = "Tucumán",
  "AR-U" = "Chubut",      "AR-V" = "Tierra del Fuego", "AR-W" = "Corrientes",
  "AR-X" = "Córdoba",     "AR-Y" = "Jujuy",        "AR-Z" = "Santa Cruz"
)

gdf <- sf::st_read(GEOJSON, quiet = TRUE)
gdf$provincia <- unname(ISO_PROVINCIA[gdf$iso_3166_2])
stopifnot(!anyNA(gdf$provincia), length(unique(gdf$provincia)) == 24)

sh <- read.csv(file.path(SALIDAS, "shannon_por_provincia.csv"))
sh <- sh[sh$era %in% c("fernandez", "milei"), c("provincia", "era", "H")]

paneles_mapa <- c(fernandez = "(a) Fernández (2020-2023)", milei = "(b) Milei (2024-2025)")
mapa <- do.call(rbind, lapply(names(paneles_mapa), function(e) {
  capa <- gdf[, c("provincia", "geometry")]
  capa$H <- sh$H[sh$era == e][match(capa$provincia, sh$provincia[sh$era == e])]
  capa$panel <- paneles_mapa[[e]]
  capa
}))
cat("  provincias sin dato:", sum(is.na(mapa$H)), "de", nrow(mapa), "\n")
stopifnot(!anyNA(mapa$H))

pS2 <- ggplot(mapa) +
  geom_sf(aes(fill = H), colour = "white", linewidth = 0.15) +
  facet_wrap(~panel, ncol = 2) +
  scale_fill_viridis_c(option = "plasma", name = "Shannon H", direction = -1) +
  coord_sf(datum = NA) +
  tema_es(10) +
  theme(axis.text = element_blank(), panel.grid = element_blank(),
        legend.position = "right")

guardar_jpg(pS2, "FigS2_choropleth", 9.0, 8.0)

cat("\nlisto: 7 figuras en", FIGURAS, "\n")
