# 04_bloques_falsacion.R — Umbral de asociación y prueba del mecanismo cooperativo
# ============================================================================
# Agrupa las formas jurídicas según el umbral de asociación que imponen y sigue
# la participación de cada bloque a lo largo de las eras. El bloque asociativo
# reúne cooperativa, mutual y asociación civil: exigen pluralidad de miembros y
# gobierno por asamblea con un voto por asociado. El de capital reúne SA, SRL y
# SAS. El patrimonial, fundación y residual.
#
# Contrasta además la proposición de que las redes intermediarias densas
# sostienen la variedad organizacional frente a presiones externas, con un
# indicador previo al tratamiento y externo al índice de diversidad, y reporta
# intervalos de confianza porque con 24 jurisdicciones la precisión es baja.
#
# Salidas en salidas/:
#   bloques_por_era.csv        participación y altas anualizadas por bloque
#   bloques_por_region.csv     bloque asociativo por región
#   capital_interno.csv        composición interna del bloque de capital
#   control_seccion_iv.csv     control por la sociedad de la Sección IV
#   densidad_previa.csv        densidad cooperativa previa y resultados
#   correlaciones.csv          correlaciones con intervalos de confianza
#   composicion_milei_provincia.csv  composición por forma bajo Milei (figura 3)
#   contexto_diversidad.csv    contexto provincial y medidas de diversidad (figura S1)

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

titulo("04 — Bloques por umbral de asociación y falsación del mecanismo")

d <- cargar_registro(c("tipo", "era", "provincia", "region", "year", "seccion_iv"))
cat("N =", fmt_n(nrow(d)), "organizaciones\n")

# ── Bloques por era ─────────────────────────────────────────────────────────
titulo("Participación de cada bloque y altas anualizadas por era")

bloques <- do.call(rbind, lapply(ERAS, function(e) {
  sub <- d[d$era == e, ]
  y <- ERA_DURACION[[e]]
  data.frame(
    era = e, era_es = unname(ERA_ETIQUETA[e]), n = nrow(sub), anios = y,
    altas_anio = nrow(sub) / y,
    asoc_anio  = sum(sub$bloque == "asociativa") / y,
    coop_anio  = sum(sub$tipo == "Coop") / y,
    pct_asociativa  = 100 * mean(sub$bloque == "asociativa"),
    pct_capital     = 100 * mean(sub$bloque == "capital"),
    pct_patrimonial = 100 * mean(sub$bloque == "patrimonial")
  )
}))
guardar(bloques, "bloques_por_era.csv")

cat(sprintf("%-13s %11s %10s %13s %12s\n",
            "era", "altas/año", "asoc/año", "% asociativa", "% capital"))
for (i in seq_len(nrow(bloques))) {
  cat(sprintf("%-13s %11.0f %10.0f %12.1f%% %11.1f%%\n",
              bloques$era_es[i], bloques$altas_anio[i], bloques$asoc_anio[i],
              bloques$pct_asociativa[i], bloques$pct_capital[i]))
}

# ── Numerador contra denominador ────────────────────────────────────────────
titulo("La caída está en el numerador: kirchnerismo frente a era Milei")

kir <- d[d$era %in% KIRCHNERISMO, ]
mil <- d[d$era == "milei", ]
DUR_MILEI <- 2

comparar <- function(etiqueta, sel_kir, sel_mil) {
  a <- sum(sel_kir) / DUR_KIRCH
  b <- sum(sel_mil) / DUR_MILEI
  cat(sprintf("  %-24s %8.0f -> %8.0f  %+5.0f%%\n", etiqueta, a, b, 100 * (b / a - 1)))
  data.frame(serie = etiqueta, kirchnerismo = a, milei = b, cambio_pct = 100 * (b / a - 1))
}

numden <- rbind(
  comparar("total de altas",       rep(TRUE, nrow(kir)),         rep(TRUE, nrow(mil))),
  comparar("bloque asociativo",    kir$bloque == "asociativa",   mil$bloque == "asociativa"),
  comparar("cooperativas",         kir$tipo == "Coop",           mil$tipo == "Coop"),
  comparar("asociaciones civiles", kir$tipo == "Asoc",           mil$tipo == "Asoc"),
  comparar("mutuales",             kir$tipo == "Mutual",         mil$tipo == "Mutual")
)
guardar(numden, "numerador_denominador.csv")

pct_kir <- 100 * mean(kir$bloque == "asociativa")
pct_mil <- 100 * mean(mil$bloque == "asociativa")
cat(sprintf("\n  participación asociativa: %.1f%% -> %.1f%%\n", pct_kir, pct_mil))
cat("  el denominador crece, de modo que la contracción está en el numerador\n")

# ── Censura por la derecha sobre el bloque asociativo ───────────────────────
# El registro consigna la fecha de constitución y la organización aparece
# cuando queda inscripta. La SAS se inscribe en veinticuatro horas con estatuto
# modelo, mientras la cooperativa espera la matrícula del INAES. Un corte a
# febrero de 2026 subrepresenta entonces a las formas lentas en el año más
# reciente, y el control por totales no lo detecta porque el total lo domina la
# forma rápida. La prueba pertinente rehace la comparación con la era Milei
# restringida a 2024, el año que ya no puede estar en trámite.
titulo("Censura por la derecha sobre el bloque asociativo")

m24 <- mil[mil$year == 2024, ]
censura_bloque <- data.frame(
  ventana = c("Milei 2024-2025", "Milei sólo 2024"),
  anios   = c(2, 1),
  n       = c(nrow(mil), nrow(m24)),
  pct_asociativa = c(pct_mil, 100 * mean(m24$bloque == "asociativa")),
  asoc_anio = c(sum(mil$bloque == "asociativa") / 2, sum(m24$bloque == "asociativa"))
)
censura_bloque$pct_kirchnerismo <- pct_kir
censura_bloque$retencion <- censura_bloque$pct_asociativa / pct_kir
guardar(censura_bloque, "censura_bloque.csv")

for (i in seq_len(nrow(censura_bloque))) {
  cat(sprintf("  %-18s altas %8s   %% asociativa %5.1f   retiene %.1f%% del nivel kirchnerista\n",
              censura_bloque$ventana[i], fmt_n(censura_bloque$n[i]),
              censura_bloque$pct_asociativa[i], 100 * censura_bloque$retencion[i]))
}
caida <- 100 * (1 - censura_bloque$retencion)
cat(sprintf("\n  caída de la participación asociativa: entre %.0f%% y %.0f%% según la ventana\n",
            min(caida), max(caida)))
if (max(censura_bloque$retencion) > 0.5) {
  cat("  AVISO: con la ventana de 2024 la retención supera la mitad, de modo que\n")
  cat("  «cae a menos de la mitad» no vale para las dos ventanas. Usar una\n")
  cat("  formulación que valga con ambas y declarar la ventana restringida.\n")
}

# La serie anual muestra si el quiebre es demasiado abrupto para ser rezago.
serie_asoc <- d[d$year >= 2020, ] |>
  dplyr::group_by(year) |>
  dplyr::summarise(altas = dplyr::n(),
                   asociativas = sum(bloque == "asociativa"),
                   pct = 100 * mean(bloque == "asociativa"), .groups = "drop") |>
  as.data.frame()
cat("\n  altas asociativas absolutas por año:\n")
for (i in seq_len(nrow(serie_asoc))) {
  cat(sprintf("    %d  altas %8s   asociativas %7s   %5.1f%%\n",
              serie_asoc$year[i], fmt_n(serie_asoc$altas[i]),
              fmt_n(serie_asoc$asociativas[i]), serie_asoc$pct[i]))
}

# ── Bloque asociativo por región ────────────────────────────────────────────
titulo("Bloque asociativo por región")

por_tipo <- do.call(rbind, lapply(REGION_ORDEN, function(tp) {
  k <- kir[kir$region == tp, ]; m <- mil[mil$region == tp, ]
  pk <- 100 * mean(k$bloque == "asociativa"); pm <- 100 * mean(m$bloque == "asociativa")
  cat(sprintf("  %-15s %11.1f%% -> %6.1f%%   retiene %.0f%%\n",
              REGION_ETIQUETA[tp], pk, pm, 100 * pm / pk))
  data.frame(region = tp, region_es = unname(REGION_ETIQUETA[tp]),
             pct_kirchnerismo = pk, pct_milei = pm, retencion = pm / pk)
}))
guardar(por_tipo, "bloques_por_region.csv")

# ── Composición interna del bloque de capital ───────────────────────────────
titulo("Composición interna del bloque de capital")

capital <- do.call(rbind, lapply(ERAS, function(e) {
  sub <- d[d$era == e & d$bloque == "capital", ]
  data.frame(era = e, era_es = unname(ERA_ETIQUETA[e]),
             SA = 100 * mean(sub$tipo == "SA"),
             SAS = 100 * mean(sub$tipo == "SAS"),
             SRL = 100 * mean(sub$tipo == "SRL"))
}))
guardar(capital, "capital_interno.csv")
cat(sprintf("%-13s %8s %8s %8s\n", "era", "SA", "SAS", "SRL"))
for (i in seq_len(nrow(capital))) {
  cat(sprintf("%-13s %7.1f%% %7.1f%% %7.1f%%\n", capital$era_es[i],
              capital$SA[i], capital$SAS[i], capital$SRL[i]))
}

# ── Difusión de la SAS por jurisdicción ─────────────────────────────────────
# La misma ley nacional se inscribe en veinticuatro registros distintos. La
# participación de la SAS en las altas de cada jurisdicción mide hasta dónde
# llegó la reforma en cada una.
titulo("Difusión de la SAS por jurisdicción y era")

ERAS_SAS <- c("macri", "fernandez", "milei")
sas_jur <- d |>
  dplyr::filter(era %in% ERAS_SAS) |>
  dplyr::group_by(provincia, region, era) |>
  dplyr::summarise(pct_sas = 100 * mean(tipo == "SAS"), .groups = "drop") |>
  tidyr::pivot_wider(names_from = era, values_from = pct_sas, names_prefix = "sas_") |>
  dplyr::arrange(dplyr::desc(sas_milei)) |>
  as.data.frame()
guardar(sas_jur, "sas_por_jurisdiccion.csv")

cat(sprintf("  jurisdicciones donde la SAS supera la mitad de las altas bajo Milei: %d de 24\n",
            sum(sas_jur$sas_milei > 50)))
cat(sprintf("  extremos bajo Milei: %s %.1f%% y %s %.1f%%\n",
            sas_jur$provincia[1], sas_jur$sas_milei[1],
            sas_jur$provincia[nrow(sas_jur)], sas_jur$sas_milei[nrow(sas_jur)]))

# Serie anual de las dos jurisdicciones mayores. La de la CABA se
# contrasta contra la posición normativa de su registro, la Inspección General
# de Justicia, que entre 2020 y 2023 sumó requisitos a la SAS y los derogó en
# bloque por la Resolución General 11/2024.
sas_anual <- d |>
  dplyr::filter(year >= 2017, provincia %in% c("CABA", "Buenos Aires")) |>
  dplyr::group_by(provincia, year) |>
  dplyr::summarise(altas = dplyr::n(), pct_sas = 100 * mean(tipo == "SAS"),
                   .groups = "drop") |>
  tidyr::pivot_wider(names_from = provincia, values_from = c(altas, pct_sas)) |>
  as.data.frame()
guardar(sas_anual, "sas_caba_ba_anual.csv")

cat("\n  participación de la SAS en las altas, por año:\n")
cat(sprintf("  %6s %14s %14s\n", "año", "CABA", "Buenos Aires"))
for (i in seq_len(nrow(sas_anual))) {
  cat(sprintf("  %6d %13.1f%% %13.1f%%\n", sas_anual$year[i],
              sas_anual$pct_sas_CABA[i], sas_anual$`pct_sas_Buenos Aires`[i]))
}

# ── Control por la sociedad de la Sección IV ────────────────────────────────
# La reforma de 2015 incorporó esta forma residual, que infla el denominador
# bajo Macri. Excluirla verifica que la comparación principal no dependa de ella.
titulo("Control por la sociedad de la Sección IV de la Ley General de Sociedades")

cat(sprintf("  sociedades de la Sección IV en el universo analizado: %s\n",
            fmt_n(sum(d$seccion_iv))))

control <- do.call(rbind, lapply(ERAS, function(e) {
  sub <- d[d$era == e, ]
  sin <- sub[!sub$seccion_iv, ]
  data.frame(era = e, era_es = unname(ERA_ETIQUETA[e]),
             pct_residual = 100 * mean(sub$seccion_iv),
             asoc_con = 100 * mean(sub$bloque == "asociativa"),
             asoc_sin = 100 * mean(sin$bloque == "asociativa"))
}))
guardar(control, "control_seccion_iv.csv")
cat(sprintf("%-13s %12s %12s %12s\n", "era", "% residual", "asoc con", "asoc sin"))
for (i in seq_len(nrow(control))) {
  cat(sprintf("%-13s %11.1f%% %11.1f%% %11.1f%%\n", control$era_es[i],
              control$pct_residual[i], control$asoc_con[i], control$asoc_sin[i]))
}
k_sin <- 100 * mean(kir$bloque[!kir$seccion_iv] == "asociativa")
m_sin <- 100 * mean(mil$bloque[!mil$seccion_iv] == "asociativa")
cat(sprintf("\n  comparación principal sin la Sección IV: %.1f%% -> %.1f%%\n", k_sin, m_sin))

# ── Densidad institucional previa ───────────────────────────────────────────
# El indicador es previo a la reforma y externo al índice de diversidad: stock
# de cooperativas y mutuales acumulado hasta 2015 por cada cien mil habitantes
# de 14 años o más, la población sobre la que el Censo 2022 mide la condición
# de actividad (data/contexto_provincial.csv, columna pob_empleo).
titulo("Densidad cooperativa previa contra retención asociativa")

ctx <- read.csv(CTX, fileEncoding = "UTF-8")
pob <- ctx[, c("provincia", "pob_empleo")]

stock <- d[d$year <= 2015 & d$tipo %in% c("Coop", "Mutual"), ] |>
  dplyr::count(provincia, name = "stock_coop_mutual")

prov <- d |>
  dplyr::group_by(provincia, region) |>
  dplyr::summarise(.groups = "drop") |>
  dplyr::left_join(stock, by = "provincia") |>
  dplyr::left_join(pob, by = "provincia") |>
  dplyr::mutate(coop_por_100k = 1e5 * stock_coop_mutual / pob_empleo)

res <- d |>
  dplyr::filter(era %in% c(KIRCHNERISMO, "milei")) |>
  dplyr::mutate(periodo = ifelse(era == "milei", "milei", "kirchnerismo")) |>
  dplyr::group_by(provincia, periodo) |>
  dplyr::summarise(pct_asoc = 100 * mean(bloque == "asociativa"), .groups = "drop") |>
  tidyr::pivot_wider(names_from = periodo, values_from = pct_asoc,
                     names_prefix = "asoc_")

h <- read.csv(file.path(SALIDAS, "shannon_milei_provincia.csv"))[, c("provincia", "H_completo")]

pr <- prov |>
  dplyr::left_join(res, by = "provincia") |>
  dplyr::left_join(h, by = "provincia") |>
  dplyr::mutate(retencion = asoc_milei / asoc_kirchnerismo) |>
  dplyr::arrange(dplyr::desc(coop_por_100k)) |>
  as.data.frame()
guardar(pr, "densidad_previa.csv")

# ── Correlaciones con intervalo de confianza ────────────────────────────────
titulo("Correlaciones provinciales, con intervalo de confianza (N = 24)")

pares <- list(
  list("densidad previa", "participación asociativa bajo Milei", pr$coop_por_100k, pr$asoc_milei),
  list("densidad previa", "Shannon H bajo Milei",                pr$coop_por_100k, pr$H_completo),
  list("densidad previa", "retención asociativa",                pr$coop_por_100k, pr$retencion),
  list("composición previa", "participación asociativa bajo Milei", pr$asoc_kirchnerismo, pr$asoc_milei),
  list("densidad previa", "composición previa",                  pr$coop_por_100k, pr$asoc_kirchnerismo)
)

corrs <- do.call(rbind, lapply(pares, function(p) {
  r <- cor_ic(p[[3]], p[[4]])
  cbind(predictor = p[[1]], resultado = p[[2]], r)
}))
guardar(corrs, "correlaciones.csv")

cat(sprintf("%-20s %-36s %7s %18s %8s %8s\n",
            "predictor", "resultado", "r", "IC 95%", "p", "rho"))
for (i in seq_len(nrow(corrs))) {
  cat(sprintf("%-20s %-36s %+7.3f  [%+.2f, %+.2f] %8.3f %+8.2f\n",
              corrs$predictor[i], corrs$resultado[i], corrs$r[i],
              corrs$ic_inf[i], corrs$ic_sup[i], corrs$p[i], corrs$rho[i]))
}

cat("\n  Lectura: la densidad previa no predice la retención, pero el intervalo\n")
cat("  es demasiado ancho para separar ese resultado del de la composición\n")
cat("  previa, y ambos predictores están asociados entre sí. Con 24 unidades el\n")
cat("  nulo es compatible con falta de precisión, no sólo con ausencia de efecto.\n")

# ── Casos que la proposición no explica ─────────────────────────────────────
alta_dens <- pr[pr$coop_por_100k > median(pr$coop_por_100k) &
                  pr$retencion < median(pr$retencion), ]
cat("\n  densidad previa alta y retención baja:\n")
for (i in seq_len(nrow(alta_dens))) {
  cat(sprintf("    %-22s densidad %6.1f   retención %.2f\n",
              alta_dens$provincia[i], alta_dens$coop_por_100k[i], alta_dens$retencion[i]))
}

sde <- pr[pr$provincia == "Santiago del Estero", ]
cat(sprintf("\n  única jurisdicción cuya participación asociativa no cae: %s (%.1f%% -> %.1f%%)\n",
            sde$provincia, sde$asoc_kirchnerismo, sde$asoc_milei))

# ── Datos de las figuras 3 y S1 ─────────────────────────────────────────────
# 06_figuras.R lee sólo salidas/ y data/argentina_provinces.geojson, de modo que
# las figuras se reproducen sin el registro depurado.
titulo("Datos de las figuras 3 y S1")

comp <- d[d$era == "milei", ] |>
  dplyr::count(provincia, region, tipo) |>
  dplyr::group_by(provincia) |>
  dplyr::mutate(pct = 100 * n / sum(n)) |>
  dplyr::ungroup() |>
  as.data.frame()
guardar(comp[order(comp$provincia, comp$tipo), ], "composicion_milei_provincia.csv")

ss_milei <- read.csv(file.path(SALIDAS, "shift_share_milei.csv"), fileEncoding = "UTF-8")
h_milei <- read.csv(file.path(SALIDAS, "shannon_milei_provincia.csv"), fileEncoding = "UTF-8")
ctx_div <- ctx[, c("provincia", "pda_per_100k", "hhi_empleo", "pct_with_account")] |>
  dplyr::left_join(h_milei[, c("provincia", "region", "H_completo")], by = "provincia") |>
  dplyr::left_join(sas_jur[, c("provincia", "sas_milei")], by = "provincia") |>
  dplyr::left_join(ss_milei[, c("provincia", "diferencial_provincial")], by = "provincia") |>
  as.data.frame()
stopifnot(nrow(ctx_div) == 24, !anyNA(ctx_div))
guardar(ctx_div, "contexto_diversidad.csv")

cat("\nlisto.\n")
