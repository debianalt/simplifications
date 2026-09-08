# 02_theil.R — Diversidad organizacional y desigualdad interprovincial
# ============================================================================
# Descompone la desigualdad en diversidad organizacional entre un componente
# interprovincial y otro intraprovincial a lo largo de ocho eras políticas, y
# calcula el índice de Shannon H por provincia y era.
#
# Incluye los dos controles de artefacto declarados en el artículo:
#   - partición del índice: SAS y SRL fusionadas en una sola sociedad de
#     capital cerrada, porque una forma nueva eleva la entropía por construcción;
#   - censura por la derecha: era Milei restringida a 2024.
#
# Salidas en salidas/:
#   theil_por_era.csv          descomposición por era, índice completo
#   theil_censura.csv          control de censura por la derecha
#   shannon_por_provincia.csv  H por provincia y era
#   shannon_variantes.csv      H nacional por era con las tres particiones
#   serie_anual.csv            H nacional y composición por bloque, 1990-2025

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

titulo("02 — Diversidad organizacional y descomposición de Theil")

d <- cargar_registro(c("tipo", "era", "provincia", "prov_type", "year"))
cat("N =", fmt_n(nrow(d)), "organizaciones\n")

# Una forma jurídica nueva eleva la entropía por construcción, al margen de lo
# que ocurra con las preexistentes. La versión de control fusiona SAS y SRL en
# una única categoría de sociedad de capital cerrada antes del cálculo.
d$tipo_fusion <- ifelse(d$tipo %in% c("SAS", "SRL"), "CapCerrada", d$tipo)

# ── Theil por era ───────────────────────────────────────────────────────────
titulo("Descomposición de Theil por era política")
cat(sprintf("%-13s %10s %10s %10s %12s\n",
            "era", "n", "T total", "% entre", "% nacional"))

theil_eras <- do.call(rbind, lapply(ERAS, function(e) {
  sub <- d[d$era == e, ]
  r <- theil_t(sub)
  cat(sprintf("%-13s %10s %10.4f %9.1f%% %11.1f%%\n",
              ERA_ETIQUETA[e], fmt_n(r$n), r$T_total, r$pct_entre,
              100 - r$pct_entre))
  data.frame(era = e, era_es = unname(ERA_ETIQUETA[e]), n = r$n,
             T_total = r$T_total, T_entre = r$T_entre, T_nacional = r$T_nacional,
             pct_entre = r$pct_entre)
}))
guardar(theil_eras, "theil_por_era.csv")

r_full <- theil_t(d)
cat(sprintf("\nperíodo completo: T = %.4f, entre = %.1f%%\n",
            r_full$T_total, r_full$pct_entre))

# ── Censura por la derecha ──────────────────────────────────────────────────
titulo("Control de censura por la derecha: era Milei restringida a 2024")

milei <- d[d$era == "milei", ]
m24   <- milei[milei$year == 2024, ]
m25   <- milei[milei$year == 2025, ]
fern  <- d[d$era == "fernandez", ]

censura <- do.call(rbind, list(
  cbind(periodo = "fernandez_2020_2023", as.data.frame(theil_t(fern))),
  cbind(periodo = "milei_2024_2025",     as.data.frame(theil_t(milei))),
  cbind(periodo = "milei_solo_2024",     as.data.frame(theil_t(m24))),
  cbind(periodo = "milei_solo_2025",     as.data.frame(theil_t(m25)))
))
guardar(censura, "theil_censura.csv")
for (i in seq_len(nrow(censura))) {
  cat(sprintf("  %-22s T = %.4f  entre = %.1f%%  altas = %s\n",
              censura$periodo[i], censura$T_total[i], censura$pct_entre[i],
              fmt_n(censura$n[i])))
}
cat(sprintf("\n  control de suma: %s + %s = %s (total Milei %s)\n",
            fmt_n(nrow(m24)), fmt_n(nrow(m25)),
            fmt_n(nrow(m24) + nrow(m25)), fmt_n(nrow(milei))))
stopifnot(nrow(m24) + nrow(m25) == nrow(milei))

# ── Shannon por provincia y era ─────────────────────────────────────────────
titulo("Índice de Shannon H por provincia")

shannon_prov <- d |>
  dplyr::count(provincia, prov_type, era, tipo) |>
  dplyr::group_by(provincia, prov_type, era) |>
  dplyr::summarise(H = shannon(n), n = sum(n), .groups = "drop")
guardar(as.data.frame(shannon_prov), "shannon_por_provincia.csv")

# Variante con SAS y SRL fusionadas, sólo para la era Milei
h_milei <- d[d$era == "milei", ] |>
  dplyr::group_by(provincia, prov_type) |>
  dplyr::summarise(
    H_completo = shannon(table(tipo)),
    H_fusion   = shannon(table(tipo_fusion)),
    n = dplyr::n(), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(H_completo)) |>
  as.data.frame()

# Intervalos bootstrap para el H provincial. Con la era Milei restringida a dos
# años, varias jurisdicciones corren sobre doscientas a quinientas altas, de modo
# que el ordenamiento del medio de la tabla no es distinguible del ruido de
# muestreo y el cuadro no debe presentarlo como escala.
N_BOOT <- 2000L
set.seed(SEMILLA)
mil <- d[d$era == "milei", ]
ic <- t(vapply(h_milei$provincia, function(p) {
  x <- mil$tipo[mil$provincia == p]
  vals <- replicate(N_BOOT, shannon(table(sample(x, length(x), replace = TRUE))))
  unname(stats::quantile(vals, c(0.025, 0.975)))
}, numeric(2)))
h_milei$H_ic_inf <- ic[, 1]
h_milei$H_ic_sup <- ic[, 2]
guardar(h_milei, "shannon_milei_provincia.csv")

cat(sprintf("\n  intervalos bootstrap (%d remuestreos):\n", N_BOOT))
for (i in seq_len(nrow(h_milei))) {
  cat(sprintf("  %-20s n=%6s  H = %.3f [%.3f; %.3f]\n",
              h_milei$provincia[i], fmt_n(h_milei$n[i]), h_milei$H_completo[i],
              h_milei$H_ic_inf[i], h_milei$H_ic_sup[i]))
}
solapan <- sum(h_milei$H_ic_inf[-nrow(h_milei)] <= h_milei$H_ic_sup[-1])
cat(sprintf("\n  pares contiguos con intervalos solapados: %d de %d\n",
            solapan, nrow(h_milei) - 1))
cat(sprintf("  extremos: %s [%.3f; %.3f] contra %s [%.3f; %.3f] — %s\n",
            h_milei$provincia[1], h_milei$H_ic_inf[1], h_milei$H_ic_sup[1],
            h_milei$provincia[nrow(h_milei)],
            h_milei$H_ic_inf[nrow(h_milei)], h_milei$H_ic_sup[nrow(h_milei)],
            ifelse(h_milei$H_ic_inf[1] > h_milei$H_ic_sup[nrow(h_milei)],
                   "no se solapan", "SE SOLAPAN")))

rho <- suppressWarnings(cor(h_milei$H_completo, h_milei$H_fusion, method = "spearman"))
cat(sprintf("  H bajo Milei: de %.2f (%s) a %.2f (%s)\n",
            min(h_milei$H_completo), h_milei$provincia[which.min(h_milei$H_completo)],
            max(h_milei$H_completo), h_milei$provincia[which.max(h_milei$H_completo)]))
cat(sprintf("  razón entre extremos: %.2f\n",
            max(h_milei$H_completo) / min(h_milei$H_completo)))
cat(sprintf("  correlación de rangos entre ambas particiones: rho = %.3f\n", rho))

cat("\n  tres de mayor diversidad: ",
    paste(head(h_milei$provincia, 3), collapse = ", "), "\n")
cat("  tres de menor diversidad: ",
    paste(rev(tail(h_milei$provincia, 3)), collapse = ", "), "\n")

# ── Shannon nacional por era, tres particiones ──────────────────────────────
titulo("Shannon H nacional por era: efecto de la partición del índice")

variantes <- do.call(rbind, lapply(ERAS, function(e) {
  sub <- d[d$era == e, ]
  data.frame(
    era = e, era_es = unname(ERA_ETIQUETA[e]), n = nrow(sub),
    H_completo = shannon(table(sub$tipo)),
    H_fusion   = shannon(table(sub$tipo_fusion)),
    H_sin_sas  = shannon(table(sub$tipo[sub$tipo != "SAS"]))
  )
}))
guardar(variantes, "shannon_variantes.csv")
cat(sprintf("%-13s %12s %12s %12s\n", "era", "completo", "SAS+SRL", "sin SAS"))
for (i in seq_len(nrow(variantes))) {
  cat(sprintf("%-13s %12.3f %12.3f %12.3f\n", variantes$era_es[i],
              variantes$H_completo[i], variantes$H_fusion[i], variantes$H_sin_sas[i]))
}
cat("\n  Con el índice completo, H sube bajo Macri y Fernández porque la SAS es\n")
cat("  una categoría nueva. Con SAS y SRL fusionadas, H cae bajo Milei y la\n")
cat("  caída es la mayor de toda la serie.\n")

# ── Serie anual ─────────────────────────────────────────────────────────────
titulo("Serie anual 1990-2025")

anual <- d[d$year >= 1990, ] |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    n = dplyr::n(),
    H = shannon(table(tipo)),
    pct_asociativa = 100 * mean(bloque == "asociativa"),
    pct_capital    = 100 * mean(bloque == "capital"),
    pct_sas        = 100 * mean(tipo == "SAS"),
    .groups = "drop")
guardar(as.data.frame(anual), "serie_anual.csv")

recientes <- anual[anual$year >= 2020, ]
cat(sprintf("%6s %9s %8s %14s %10s\n", "año", "altas", "H", "% asociativa", "% SAS"))
for (i in seq_len(nrow(recientes))) {
  cat(sprintf("%6d %9s %8.3f %13.1f%% %9.1f%%\n",
              recientes$year[i], fmt_n(recientes$n[i]), recientes$H[i],
              recientes$pct_asociativa[i], recientes$pct_sas[i]))
}
cat("\n  El quiebre de la participación asociativa cae en 2024, no en los años\n")
cat("  de mayor tensión macroeconómica que lo preceden.\n")

cat("\nlisto.\n")
