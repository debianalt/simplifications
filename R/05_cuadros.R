# 05_cuadros.R — Cuadros complementarios en markdown, desde las salidas de R
# ============================================================================
# Escribe salidas/cuadros/*.md con el cuerpo de cada cuadro complementario, en
# el formato del manuscrito (coma decimal, punto de miles). El script 07 de
# Python los inserta en 08_supplementary.md, de modo que ningún cuadro puede
# quedar desincronizado del análisis.

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

titulo("05 — Cuadros complementarios")

DIR_CUADROS <- file.path(SALIDAS, "cuadros")
dir.create(DIR_CUADROS, showWarnings = FALSE)

# ── Formato castellano ──────────────────────────────────────────────────────
num <- function(x, d = 2) {
  ifelse(is.na(x), "—",
         formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ","))
}
ent <- function(x) {
  ifelse(is.na(x), "—",
         formatC(x, format = "d", big.mark = ".", decimal.mark = ","))
}
sgn <- function(x, d = 2) {
  ifelse(is.na(x), "—",
         paste0(ifelse(x >= 0, "+", "\u2212"),
                formatC(abs(x), format = "f", digits = d, decimal.mark = ",")))
}

escribir <- function(nombre, encabezado, filas) {
  linea <- paste0("| ", paste(encabezado, collapse = " | "), " |")
  sep   <- paste0("|", paste(rep("---", length(encabezado)), collapse = "|"), "|")
  cuerpo <- vapply(filas, function(f) paste0("| ", paste(f, collapse = " | "), " |"),
                   character(1))
  txt <- paste(c(linea, sep, cuerpo), collapse = "\n")
  writeLines(txt, file.path(DIR_CUADROS, paste0(nombre, ".md")), useBytes = TRUE)
  cat("  ", nombre, ":", length(filas), "filas\n")
  invisible(txt)
}

filas_de <- function(df, cols) {
  lapply(seq_len(nrow(df)), function(i) unlist(lapply(cols, function(f) f(df[i, ]))))
}

# ── S1: valores propios ─────────────────────────────────────────────────────
eig <- read.csv(file.path(SALIDAS, "acm_valores_propios.csv"))
e <- head(eig[!is.na(eig$pct_inercia_ca), ], 5)
escribir("S1",
  c("Eje", "Valor propio", "% de inercia", "% acumulado"),
  filas_de(e, list(
    function(r) as.character(r$eje),
    function(r) num(r$valor_propio, 4),
    function(r) num(r$pct_inercia_ca, 2),
    function(r) num(cumsum(e$pct_inercia_ca)[r$eje], 2))))
cat(sprintf("   ejes no triviales: %d; el plano reúne %.1f%% de la inercia\n",
            sum(!is.na(eig$pct_inercia_ca)), sum(e$pct_inercia_ca[1:2])))

# ── S2: Theil por era ───────────────────────────────────────────────────────
th <- read.csv(file.path(SALIDAS, "theil_por_era.csv"))
escribir("S2",
  c("Era", "*N*", "*T* total", "Entre jurisdicciones", "Composición nacional",
    "% entre jurisdicciones"),
  filas_de(th, list(
    function(r) r$era_es,
    function(r) ent(r$n),
    function(r) num(r$T_total, 3),
    function(r) num(r$T_entre, 3),
    function(r) num(r$T_nacional, 3),
    function(r) num(r$pct_entre, 1))))

# ── S3: Shannon por provincia bajo Milei ────────────────────────────────────
h <- read.csv(file.path(SALIDAS, "shannon_milei_provincia.csv"))
d <- cargar_registro(c("tipo", "era", "provincia"))
mil <- d[d$era == "milei", ]
formas_presentes <- tapply(mil$tipo, mil$provincia, function(x) length(unique(x)))
h$S <- as.integer(formas_presentes[h$provincia])
h$equit <- h$H_completo / log(h$S)
h <- h[order(-h$H_completo), ]
escribir("S3",
  c("Provincia", "*n*", "Shannon *H*", "IC 95% de *H*", "Equitatividad",
    "*H* con SAS y SRL fusionadas", "Región"),
  filas_de(h, list(
    function(r) r$provincia,
    function(r) ent(r$n),
    function(r) num(r$H_completo, 2),
    function(r) sprintf("[%s; %s]", num(r$H_ic_inf, 2), num(r$H_ic_sup, 2)),
    function(r) num(r$equit, 2),
    function(r) num(r$H_fusion, 2),
    function(r) unname(REGION_ETIQUETA[r$region]))))

# ── S4 y S4b: shift-share ───────────────────────────────────────────────────
for (cfg in list(list("S4", "shift_share_milei.csv"),
                 list("S4b", "shift_share_fernandez.csv"))) {
  ss <- read.csv(file.path(SALIDAS, cfg[[2]]))
  ss <- ss[order(ss$diferencial_provincial), ]
  escribir(cfg[[1]],
    c("Provincia", "Región", "Tasa de referencia", "Tasa de comparación",
      "Efecto nacional", "Mix estructural", "Diferencial provincial", "SAS (%)"),
    filas_de(ss, list(
      function(r) r$provincia,
      function(r) unname(REGION_ETIQUETA[r$region]),
      function(r) num(r$tasa_ref, 1),
      function(r) num(r$tasa_comp, 1),
      function(r) sgn(r$efecto_nacional, 1),
      function(r) sgn(r$mix_estructural, 1),
      function(r) sgn(r$diferencial_provincial, 1),
      function(r) num(r$pct_sas, 1))))
}

# ── S5: subnubes por región ─────────────────────────────────────────────────
sn <- read.csv(file.path(SALIDAS, "acm_subnubes.csv"))
sn <- sn[sn$era_grupo %in% c("Kirchnerismo", "Macri", "Fernández", "Milei"), ]
sn$era_grupo <- factor(sn$era_grupo, levels = c("Kirchnerismo", "Macri", "Fernández", "Milei"))
sn <- sn[order(sn$era_grupo, match(sn$region, REGION_ORDEN)), ]
escribir("S5",
  c("Era", "Región", "*n*", "Centroide eje 1", "Centroide eje 2",
    "Inercia de clase", "Amplitud entre centroides regionales (desviaciones)"),
  filas_de(sn, list(
    function(r) as.character(r$era_grupo),
    function(r) r$region_es,
    function(r) ent(r$n),
    function(r) sgn(r$centro1, 2),
    function(r) sgn(r$centro2, 2),
    function(r) num(r$inercia, 3),
    function(r) if (r$region == REGION_ORDEN[1]) num(r$amplitud_sd, 2) else "")))

# ── S6: categorías del plano factorial ──────────────────────────────────────────────────
ca <- read.csv(file.path(SALIDAS, "acm_categorias.csv"))
ca$nivel <- sub("^[^.]+\\.", "", ca$categoria)
ETIQ_VAR <- c(tipo = "Forma jurídica", clae_sec = "Sección de actividad")
ETIQ_NIVEL <- c(
  A = "Agricultura, ganadería y pesca", B = "Minas y canteras",
  C = "Industria manufacturera",        D = "Electricidad y gas",
  E = "Agua y saneamiento",             F = "Construcción",
  G = "Comercio",                       H = "Transporte y almacenamiento",
  I = "Alojamiento y gastronomía",      J = "Información y comunicaciones",
  K = "Servicios financieros",          L = "Servicios inmobiliarios",
  M = "Servicios profesionales",        N = "Servicios administrativos",
  O = "Administración pública",         P = "Enseñanza",
  Q = "Salud y servicios sociales",     R = "Artes y recreación",
  S = "Servicios de asociaciones",      T = "Servicios de hogares",
  Z = "Otras actividades")
ca$nivel_es <- ifelse(ca$nivel %in% names(ETIQ_NIVEL), ETIQ_NIVEL[ca$nivel], ca$nivel)
# Media de contribución: 100 / número de categorías
media_ctr <- 100 / nrow(ca)
# Las ocho formas jurídicas entran siempre, porque el argumento es sobre ellas y
# la posición de las que contribuyen poco es parte del resultado. De las
# secciones de actividad entran las que superan la contribución media.
ca <- ca[order(-pmax(ca$ctr1, ca$ctr2)), ]
ca <- ca[ca$variable == "tipo" | ca$ctr1 > media_ctr | ca$ctr2 > media_ctr, ]
escribir("S6",
  c("Variable", "Categoría", "Coord. eje 1", "Contrib. eje 1 (%)", "cos² eje 1",
    "Coord. eje 2", "Contrib. eje 2 (%)", "cos² eje 2"),
  filas_de(ca, list(
    function(r) unname(ETIQ_VAR[r$variable]),
    function(r) r$nivel_es,
    function(r) sgn(r$coord1, 2),
    function(r) num(r$ctr1, 2),
    function(r) num(r$cos2_1, 3),
    function(r) sgn(r$coord2, 2),
    function(r) num(r$ctr2, 2),
    function(r) num(r$cos2_2, 3))))
cat("   contribución media por categoría:", round(media_ctr, 2), "%\n")

# ── S7: bloques ─────────────────────────────────────────────────────────────
bl <- read.csv(file.path(SALIDAS, "bloques_por_era.csv"))
escribir("S7a",
  c("Era", "Altas por año", "Asociativas por año", "% asociativo", "% capital",
    "% patrimonial"),
  filas_de(bl, list(
    function(r) r$era_es,
    function(r) ent(round(r$altas_anio)),
    function(r) ent(round(r$asoc_anio)),
    function(r) num(r$pct_asociativa, 1),
    function(r) num(r$pct_capital, 1),
    function(r) num(r$pct_patrimonial, 1))))

pt <- read.csv(file.path(SALIDAS, "bloques_por_region.csv"))
escribir("S7b",
  c("Región", "% asociativo, kirchnerismo", "% asociativo, era Milei",
    "Proporción retenida"),
  filas_de(pt, list(
    function(r) r$region_es,
    function(r) num(r$pct_kirchnerismo, 1),
    function(r) num(r$pct_milei, 1),
    function(r) num(r$retencion, 2))))

cap <- read.csv(file.path(SALIDAS, "capital_interno.csv"))
escribir("S7c",
  c("Era", "SA (%)", "SAS (%)", "SRL (%)"),
  filas_de(cap, list(
    function(r) r$era_es,
    function(r) num(r$SA, 1),
    function(r) num(r$SAS, 1),
    function(r) num(r$SRL, 1))))

s4 <- read.csv(file.path(SALIDAS, "control_seccion_iv.csv"))
escribir("S7d",
  c("Era", "% Sección IV", "% asociativo con Sección IV", "% asociativo sin Sección IV"),
  filas_de(s4, list(
    function(r) r$era_es,
    function(r) num(r$pct_residual, 1),
    function(r) num(r$asoc_con, 1),
    function(r) num(r$asoc_sin, 1))))

# ── S9: serie anual ─────────────────────────────────────────────────────────
an <- read.csv(file.path(SALIDAS, "serie_anual.csv"))
an <- an[an$year >= 2015, ]
escribir("S8",
  c("Año", "Altas", "Shannon *H*", "% asociativo", "% capital", "% SAS"),
  filas_de(an, list(
    function(r) as.character(r$year),
    function(r) ent(r$n),
    function(r) num(r$H, 3),
    function(r) num(r$pct_asociativa, 1),
    function(r) num(r$pct_capital, 1),
    function(r) num(r$pct_sas, 1))))

# ── S9a: variantes del índice ──────────────────────────────────────────────
va <- read.csv(file.path(SALIDAS, "shannon_variantes.csv"))
escribir("S9a",
  c("Era", "*H* índice completo", "*H* con SAS y SRL fusionadas", "*H* sin SAS"),
  filas_de(va, list(
    function(r) r$era_es,
    function(r) num(r$H_completo, 3),
    function(r) num(r$H_fusion, 3),
    function(r) num(r$H_sin_sas, 3))))

# ── S9b: censura por la derecha ────────────────────────────────────────────
ce <- read.csv(file.path(SALIDAS, "theil_censura.csv"))
ETIQ_PER <- c(fernandez_2020_2023 = "Fernández (2020-2023)",
              milei_2024_2025 = "Milei (2024-2025)",
              milei_solo_2024 = "Milei, sólo 2024",
              milei_solo_2025 = "Milei, sólo 2025")
ce$periodo_es <- unname(ETIQ_PER[ce$periodo])
escribir("S9b",
  c("Período", "Theil *T* total", "% entre provincias", "Altas"),
  filas_de(ce, list(
    function(r) r$periodo_es,
    function(r) num(r$T_total, 3),
    function(r) num(r$pct_entre, 1),
    function(r) ent(r$n))))
suma <- sum(ce$n[ce$periodo %in% c("milei_solo_2024", "milei_solo_2025")])
total <- ce$n[ce$periodo == "milei_2024_2025"]
cat("   control: 2024 + 2025 =", ent(suma), "; total Milei =", ent(total), "\n")
stopifnot(suma == total)

# ── S8b y S8c: difusión de la SAS por jurisdicción ──────────────────────────
sj <- read.csv(file.path(SALIDAS, "sas_por_jurisdiccion.csv"))
escribir("S8b",
  c("Jurisdicción", "Región", "% SAS bajo Macri", "% SAS bajo Fernández",
    "% SAS bajo Milei"),
  filas_de(sj, list(
    function(r) r$provincia,
    function(r) unname(REGION_ETIQUETA[r$region]),
    function(r) num(r$sas_macri, 1),
    function(r) num(r$sas_fernandez, 1),
    function(r) num(r$sas_milei, 1))))
cat(sprintf("   la SAS supera la mitad de las altas en %d de 24 jurisdicciones\n",
            sum(sj$sas_milei > 50)))

sa <- read.csv(file.path(SALIDAS, "sas_caba_ba_anual.csv"), check.names = FALSE)
escribir("S8c",
  c("Año", "% SAS en la CABA", "% SAS en Buenos Aires"),
  filas_de(sa, list(
    function(r) as.character(r$year),
    function(r) num(r$pct_sas_CABA, 1),
    function(r) num(r[["pct_sas_Buenos Aires"]], 1))))

# ── S9c: censura por la derecha sobre el bloque asociativo ──────────────────
cb <- read.csv(file.path(SALIDAS, "censura_bloque.csv"))
nd <- read.csv(file.path(SALIDAS, "numerador_denominador.csv"))
cb_tab <- data.frame(
  ventana   = c("Kirchnerismo (2003-2015)", cb$ventana),
  pct       = c(cb$pct_kirchnerismo[1], cb$pct_asociativa),
  asoc_anio = c(nd$kirchnerismo[nd$serie == "bloque asociativo"], cb$asoc_anio),
  ret       = c(NA_real_, 100 * cb$retencion)
)
escribir("S9c",
  c("Ventana", "% asociativo de las altas", "Altas asociativas por año",
    "Retención respecto del kirchnerismo (%)"),
  filas_de(cb_tab, list(
    function(r) r$ventana,
    function(r) num(r$pct, 1),
    function(r) ent(round(r$asoc_anio)),
    function(r) num(r$ret, 1))))
cat(sprintf("   retención: %.1f%% con 2024-2025 y %.1f%% con 2024 solo\n",
            100 * cb$retencion[1], 100 * cb$retencion[2]))

# ── S9d: correlaciones con intervalo ────────────────────────────────────────
co <- read.csv(file.path(SALIDAS, "correlaciones.csv"))
escribir("S9d",
  c("Predictor previo a la reforma", "Resultado bajo Milei", "*r* de Pearson",
    "IC 95%", "*p*", "rho de Spearman"),
  filas_de(co, list(
    function(r) r$predictor,
    function(r) r$resultado,
    function(r) sgn(r$r, 2),
    function(r) paste0("[", sgn(r$ic_inf, 2), "; ", sgn(r$ic_sup, 2), "]"),
    function(r) num(r$p, 3),
    function(r) sgn(r$rho, 2))))
sig <- co[co$p < 0.05, ]
cat("   alcanzan p < 0,05:", if (nrow(sig)) paste(sig$predictor, "->", sig$resultado,
                                                  collapse = "; ") else "ninguna", "\n")

cat("\nlisto:", length(list.files(DIR_CUADROS)), "cuadros en", DIR_CUADROS, "\n")
