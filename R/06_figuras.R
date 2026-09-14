# 06_figuras.R — Las siete figuras del envío, en español y a 300 dpi
# ============================================================================
# Reemplaza a figuras_es.py. Lee las salidas de los scripts 01 a 05 y escribe
# los JPG con los nombres del envío en ES_active/figures/.
#
#   Fig1_biplot.jpg            nube de organizaciones y categorías activas del plano factorial
#   Fig2_csmca_panel.jpg       elipses de concentración de subnubes por tipo de provincia
#   Fig3_composicion_sas.jpg   composición por provincia bajo Milei, ordenada por SAS
#   Fig4_theil_temporal.jpg    descomposición de Theil a lo largo de ocho eras
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

# Tipografía en puntos de página. 07_convert_to_docx_ES.py inserta cada JPG a
# su tamaño natural (píxeles / 300), de modo que estos tamaños son los que ve el
# lector en todas las figuras. Ninguna figura puede pasar de ANCHO_MAX: la caja
# de texto de la página carta con márgenes de 2 cm mide 6,93 pulgadas.
TXT_PT  <- 9     # títulos de eje, de leyenda y de panel
TICK_PT <- 8     # marcas de eje y texto de leyenda
ANOT_PT <- 8     # rótulos dentro del gráfico
ANOT_MM <- ANOT_PT / ggplot2::.pt
ANCHO_MAX <- 6.5
BORDE_PX <- 24

# ── Paleta y etiquetas ──────────────────────────────────────────────────────
# Paleta apagada, común a todas las figuras. Las formas jurídicas llevan el
# color de su bloque analítico: capital en azules pizarra (de oscuro a claro,
# SAS, SRL, SA), patrimonial en grises y asociativo en tierras. En el orden de
# apilado de la figura 3 los pares contiguos se separan por ΔE >= 16,8 bajo
# deuteranopía y 17,3 con visión normal (validador de dataviz). El tipo de
# provincia usa tonos que no están entre los de las formas, para que los
# nombres coloreados de la figura 3 no se confundan con los segmentos.
COL_TIPO_PROV <- c(metropolitan = "#3b3b3b", intermediate = "#4f7a41",
                   peripheral = "#7d5a96")
COL_VAR <- c(tipo = "#8B0000", clae_sec = "#2F4F4F")
FORMA_MARCA <- c(tipo = 16, clae_sec = 15)

COL_FORMA <- c(Coop = "#62291c", Mutual = "#9a5a31", Asoc = "#c9964f",
               Fund = "#8f8a80", Otra = "#d4d0c8",
               SA = "#a9c0d8", SRL = "#5f86b0", SAS = "#2b4c74")
FORMA_ORDEN <- c("Coop", "Mutual", "Asoc", "Fund", "SA", "SRL", "SAS", "Otra")
# Apilado de la figura 3, de derecha a izquierda: la SAS queda contra el eje,
# de modo que el ordenamiento por su participación se lee directo
FORMA_APILADO <- c("Coop", "Mutual", "Asoc", "Otra", "Fund", "SA", "SRL", "SAS")

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
# Marcas de eje con coma decimal y punto de miles, como en el texto
num_es <- scales::label_number(big.mark = ".", decimal.mark = ",")

tema_es <- function() {
  theme_minimal(base_size = TXT_PT) +
    theme(
      axis.title = element_text(size = TXT_PT),
      axis.text = element_text(size = TICK_PT),
      legend.title = element_text(size = TXT_PT),
      legend.text = element_text(size = TICK_PT),
      plot.title = element_text(face = "bold", size = TXT_PT),
      strip.text = element_text(face = "bold", size = TXT_PT),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
      axis.line = element_line(colour = "grey30", linewidth = 0.3),
      legend.key.size = unit(0.8, "lines")
    )
}

# Guarda a 300 dpi, recorta el blanco sobrante y deja un borde uniforme. El
# recorte no cambia la escala: sólo quita el margen que coord_fixed deja a los
# costados, así que la figura ocupa menos ancho con la misma letra.
guardar_jpg <- function(p, nombre, ancho, alto) {
  stopifnot(ancho <= ANCHO_MAX)
  ruta <- file.path(FIGURAS, paste0(nombre, ".jpg"))
  tmp <- tempfile(fileext = ".png")
  ggsave(tmp, p, width = ancho, height = alto, dpi = DPI,
         units = "in", device = grDevices::png, bg = "white")
  img <- magick::image_read(tmp)
  img <- magick::image_trim(img, fuzz = 2)
  img <- magick::image_border(img, "white", sprintf("%dx%d", BORDE_PX, BORDE_PX))
  magick::image_write(img, ruta, format = "jpeg", quality = 95, density = "300x300")
  unlink(tmp)
  info <- magick::image_info(img)
  cat(sprintf("  %s  (%d x %d px = %.2f x %.2f in, %.1f MB)\n", basename(ruta),
              info$width, info$height, info$width / DPI, info$height / DPI,
              file.info(ruta)$size / 1e6))
  invisible(ruta)
}

# ── Datos comunes ───────────────────────────────────────────────────────────
eig <- read.csv(file.path(SALIDAS, "acm_valores_propios.csv"))
pct1 <- eig$pct_inercia_ca[1]
pct2 <- eig$pct_inercia_ca[2]
# Los mismos títulos de eje en las figuras 1 y 2
lab_eje1 <- sprintf("Eje 1 (%s%% de la inercia)  →  polo comercial", dec(pct1))
lab_eje2 <- sprintf("Eje 2 (%s%% de la inercia)  →  polo cooperativo", dec(pct2))

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

# Los puntos de categoría están en coordenadas principales: el baricentro de
# sus organizaciones dividido por la raíz del valor propio. No son centroides de
# la nube, y la leyenda no los llama así.
etq_cats <- subset(cats, mostrar)
etq_cats$hex <- unname(COL_VAR[etq_cats$variable])
# Las formas se dibujan después de las secciones, para que ninguna quede tapada
etq_cats <- etq_cats[order(etq_cats$variable == "tipo"), ]
otras_sec <- subset(cats, !mostrar)

ETIQ_VAR <- c(tipo = "Forma jurídica", clae_sec = "Sección de actividad")

p1 <- ggplot() +
  geom_point(data = nube, aes(x, y, colour = tipo),
             size = 0.35, alpha = 0.13, stroke = 0) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_point(data = otras_sec, aes(coord1, coord2),
             shape = 22, size = 1.5, fill = "grey75", colour = "white", stroke = 0.3) +
  geom_point(data = etq_cats, aes(coord1, coord2, shape = variable, fill = variable),
             size = 2.4, colour = "white", stroke = 0.4) +
  geom_text_repel(data = etq_cats, aes(coord1, coord2, label = etiqueta),
                  colour = etq_cats$hex,
                  size = ANOT_MM, fontface = "bold",
                  min.segment.length = 0, segment.size = 0.25,
                  box.padding = 0.5, point.padding = 0.25, force = 4,
                  segment.colour = "grey55", max.overlaps = Inf, seed = SEMILLA) +
  scale_colour_manual(values = COL_FORMA, name = "Forma jurídica\n(nube de organizaciones)",
                      breaks = FORMA_ORDEN,
                      guide = guide_legend(override.aes = list(size = 2.2, alpha = 1),
                                           order = 2)) +
  scale_fill_manual(values = COL_VAR, name = "Categoría activa",
                    breaks = c("tipo", "clae_sec"), labels = ETIQ_VAR,
                    guide = guide_legend(order = 1)) +
  scale_shape_manual(values = c(tipo = 21, clae_sec = 22),
                     breaks = c("tipo", "clae_sec"),
                     name = "Categoría activa", labels = ETIQ_VAR,
                     guide = guide_legend(order = 1)) +
  scale_x_continuous(expand = expansion(mult = c(0.03, 0.12))) +
  labs(x = lab_eje1, y = lab_eje2) +
  coord_fixed() +
  tema_es() +
  theme(legend.position = "right",
        legend.box.spacing = unit(0.3, "in"))

guardar_jpg(p1, "Fig1_biplot", 6.5, 7.0)

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

FRANJA_N <- 1.5

p2 <- ggplot() +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.25) +
  geom_vline(xintercept = 0, colour = "grey70", linewidth = 0.25) +
  geom_path(data = elipses, aes(x, y, colour = tipo_prov, group = grupo,
                                linetype = tipo_prov), linewidth = 0.7) +
  geom_point(data = subn, aes(centro1, centro2, colour = tipo_prov),
             shape = 3, size = 2.4, stroke = 0.9, show.legend = FALSE) +
  geom_text(data = etq_n, aes(x = -Inf, y = Inf, label = texto, colour = tipo_prov,
                              vjust = 1.4 + 1.25 * (fila - 1)),
            hjust = -0.06, size = ANOT_MM, fontface = "bold", show.legend = FALSE) +
  facet_wrap(~panel, ncol = 3) +
  scale_colour_manual(values = COL_TIPO_PROV, name = "Tipo de provincia",
                      labels = TIPO_PROV_ETIQUETA, breaks = TIPO_PROV_ORDEN) +
  scale_linetype_manual(values = c(metropolitan = "solid", intermediate = "dashed",
                                   peripheral = "dotdash"),
                        name = "Tipo de provincia", labels = TIPO_PROV_ETIQUETA, breaks = TIPO_PROV_ORDEN) +
  scale_x_continuous(breaks = -3:2, labels = num_es) +
  scale_y_continuous(breaks = c(-2, 0, 2), labels = num_es) +
  labs(x = lab_eje1, y = lab_eje2) +
  # Franja libre arriba de las elipses para los tamaños de las subnubes
  coord_fixed(ylim = c(min(elipses$y), max(elipses$y) + FRANJA_N)) +
  tema_es() +
  theme(legend.position = "bottom", panel.spacing = unit(0.12, "in"))

guardar_jpg(p2, "Fig2_csmca_panel", 6.5, 6.4)

# ══════════════════════════════════ Figura 3: composición bajo Milei ═══
cat("\nFigura 3: composición organizacional por provincia bajo Milei\n")

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

# Datos de la figura, para el archivo de datos no gráficos del envío
write.csv(comp[order(comp$provincia, comp$tipo), ],
          file.path(SALIDAS, "composicion_milei_provincia.csv"), row.names = FALSE)

comp$provincia <- factor(comp$provincia, levels = orden)
comp$apilado <- factor(comp$tipo, levels = FORMA_APILADO)
comp$tipo <- factor(comp$tipo, levels = FORMA_ORDEN)

col_ejes <- COL_TIPO_PROV[comp$prov_type[match(levels(comp$provincia), comp$provincia)]]

p3 <- ggplot(comp, aes(pct, provincia, fill = tipo, group = apilado)) +
  geom_col(width = 0.75, colour = "white", linewidth = 0.15) +
  scale_fill_manual(values = COL_FORMA, name = NULL, breaks = FORMA_ORDEN) +
  scale_x_continuous(expand = c(0, 0), breaks = seq(0, 100, 20)) +
  labs(x = "Composición organizacional (%)", y = NULL) +
  guides(fill = guide_legend(nrow = 1)) +
  tema_es() +
  theme(legend.position = "bottom", plot.margin = margin(5.5, 14, 5.5, 5.5),
        axis.text.y = element_text(colour = col_ejes, face = "bold"),
        panel.grid.major.y = element_blank())

guardar_jpg(p3, "Fig3_composicion_sas", 6.5, 6.0)

# ══════════════════════════════════════════════ Figura 4: Theil temporal ═══
cat("\nFigura 4: descomposición de Theil\n")

th <- read.csv(file.path(SALIDAS, "theil_por_era.csv"))
th$era_es <- factor(th$era_es, levels = ERA_ETIQUETA[ERAS])

apilado <- rbind(
  data.frame(era_es = th$era_es, componente = "Entre jurisdicciones", valor = th$T_entre),
  data.frame(era_es = th$era_es, componente = "Composición nacional", valor = th$T_nacional)
)
apilado$componente <- factor(apilado$componente,
                             levels = c("Composición nacional", "Entre jurisdicciones"))

p4a <- ggplot(apilado, aes(as.numeric(era_es), valor, fill = componente)) +
  geom_area(alpha = 0.85, colour = "white", linewidth = 0.3) +
  geom_line(data = th, aes(as.numeric(era_es), T_total),
            inherit.aes = FALSE, colour = "black", linewidth = 0.7) +
  geom_point(data = th, aes(as.numeric(era_es), T_total),
             inherit.aes = FALSE, colour = "black", size = 1.8) +
  scale_x_continuous(breaks = seq_along(levels(th$era_es)),
                     labels = levels(th$era_es), expand = c(0.01, 0)) +
  scale_fill_manual(values = c("Entre jurisdicciones" = "#4d4d4d",
                               "Composición nacional" = "#c8c8c8"), name = NULL) +
  scale_y_continuous(labels = num_es) +
  labs(x = NULL, y = "Concentración (Theil T)", title = "(a)") +
  tema_es() +
  theme(legend.position = "top", axis.text.x = element_text(angle = 30, hjust = 1))

p4b <- ggplot(th, aes(as.numeric(era_es), pct_entre)) +
  geom_col(fill = "#4d4d4d", alpha = 0.85, width = 0.7) +
  geom_text(aes(label = paste0(dec(pct_entre), "%")), vjust = -0.4, size = ANOT_MM) +
  scale_x_continuous(breaks = seq_along(levels(th$era_es)),
                     labels = levels(th$era_es), expand = c(0.02, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = NULL, y = "Participación entre jurisdicciones (%)", title = "(b)") +
  tema_es() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

guardar_jpg(p4a / p4b, "Fig4_theil_temporal", 6.5, 7.3)

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
  scale_x_continuous(breaks = c(-2000, 0, 2000),
                     labels = num_es) +
  labs(x = "Diferencial provincial (organizaciones por año)", y = NULL) +
  tema_es() +
  theme(legend.position = "bottom", panel.spacing = unit(0.25, "in"),
        axis.text.y = element_text(colour = col_ss, face = "bold"),
        panel.grid.major.y = element_blank())

guardar_jpg(p5, "Fig5_shift_share", 6.5, 6.3)

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
    geom_text_repel(aes(label = etq), size = ANOT_MM, show.legend = FALSE,
                    max.overlaps = Inf, box.padding = 0.35, point.padding = 0.15, force = 3,
                    max.iter = 1e5, max.time = 3,
                    seed = SEMILLA, segment.size = 0.2) +
    scale_x_continuous(labels = num_es) +
    scale_y_continuous(labels = num_es) +
    scale_colour_manual(values = COL_TIPO_PROV, name = "Tipo de provincia",
                        labels = TIPO_PROV_ETIQUETA, breaks = TIPO_PROV_ORDEN) +
    labs(x = s[[3]], y = s[[4]]) +
    tema_es()
})

pS1 <- (paneles[[1]] + paneles[[2]]) / (paneles[[3]] + paneles[[4]]) +
  plot_layout(guides = "collect") & theme(legend.position = "bottom")

guardar_jpg(pS1, "FigS1_scatter_context", 6.5, 8.0)

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
  # Secuencial de un solo tono: los tonos oscuros indican mayor diversidad
  scale_fill_gradient(low = "#eef2f6", high = "#2b4c74", name = "Shannon H",
                      labels = num_es) +
  coord_sf(datum = NA) +
  tema_es() +
  theme(axis.text = element_blank(), panel.grid = element_blank(),
        legend.position = "right")

guardar_jpg(pS2, "FigS2_choropleth", 6.5, 4.6)

cat("\nlisto: 7 figuras en", FIGURAS, "\n")
