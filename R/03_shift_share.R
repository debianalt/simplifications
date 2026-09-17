# 03_shift_share.R — Descomposición shift-share de las tasas de creación
# ============================================================================
# Descompone el cambio en las tasas anualizadas de creación organizacional
# entre un período de referencia (kirchnerismo, 2003-2015) y dos períodos de
# comparación (Fernández 2020-2023 y Milei 2024-2025) en tres componentes:
#
#   efecto nacional      NS_jk = e_jk0 * (G - 1)
#   mix estructural      IM_jk = e_jk0 * (G_k - G)
#   diferencial provincial RS_jk = e_jk0 * (g_jk - G_k)
#
# con e_jk0 la tasa anualizada de la forma k en la provincia j durante la
# referencia, G el crecimiento nacional agregado, G_k el de la forma k y g_jk
# el provincial. El diferencial es el componente de interés: aísla la mediación
# provincial del cambio regulatorio nacional.
#
# La SAS se fusiona con la SRL en una única categoría de sociedad de capital
# cerrada antes de descomponer, como en los controles del Theil y del Shannon.
# La razón es un artefacto de base: la forma se creó en 2017, pero 247
# organizaciones del registro la declaran con fecha de constitución anterior
# (sociedades transformadas que conservan la fecha original), 157 de ellas en
# la cohorte de referencia. Tomadas como base, esas transformaciones daban a la
# SAS un crecimiento nacional de ×947 bajo Milei, y cada una inyectaba unas 73
# altas por año al mix estructural de su provincia, que el diferencial devolvía
# con signo negativo (Santa Fe, con 41, recibía +2.982 de mix y −2.750 de
# diferencial). Fusionada con la SRL, la base es la creación de sociedades de
# capital cerradas, que existe en las 24 jurisdicciones.
#
# Las formas sin creaciones en la referencia dentro de una provincia carecen de
# base para calcular una tasa de crecimiento y no reciben asignación, porque su
# e_jk0 es cero y anula los tres términos. Eso deja un residuo igual a la tasa
# de comparación de esas formas, que se reporta aparte (con la fusión es cero).
#
# Salidas en salidas/:
#   shift_share_milei.csv       referencia kirchnerismo, comparación Milei
#   shift_share_fernandez.csv   referencia kirchnerismo, comparación Fernández

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

titulo("03 — Descomposición shift-share")

d <- cargar_registro(c("tipo", "era", "provincia", "region", "year"))
cat("N =", fmt_n(nrow(d)), "organizaciones\n")

shift_share <- function(df, eras_ref, eras_comp) {
  df0 <- df                                  # sin fusionar, para pct_sas
  df$tipo[df$tipo == "SAS"] <- "SRL"         # sociedad de capital cerrada
  ref  <- df[df$era %in% eras_ref, ]
  comp <- df[df$era %in% eras_comp, ]
  comp0 <- df0[df0$era %in% eras_comp, ]
  anios_ref  <- length(unique(ref$year))
  anios_comp <- length(unique(comp$year))
  stopifnot(anios_ref > 0, anios_comp > 0)

  formas <- sort(union(unique(ref$tipo), unique(comp$tipo)))
  tasa <- function(x, anios) {
    tb <- table(factor(x$tipo, levels = formas))
    as.numeric(tb) / anios
  }

  nac_ref  <- tasa(ref, anios_ref)
  nac_comp <- tasa(comp, anios_comp)
  names(nac_ref) <- names(nac_comp) <- formas

  G <- (nrow(comp) / anios_comp) / (nrow(ref) / anios_ref)
  G_k <- ifelse(nac_ref > 0, nac_comp / nac_ref, 0)

  provincias <- sort(unique(df$provincia))
  tipo_de_prov <- tapply(df$region, df$provincia, function(x) x[1])
  filas <- lapply(provincias, function(p) {
    pr <- ref[ref$provincia == p, ]
    pc <- comp[comp$provincia == p, ]
    pc0 <- comp0[comp0$provincia == p, ]
    e0 <- tasa(pr, anios_ref)
    e1 <- tasa(pc, anios_comp)
    names(e0) <- names(e1) <- formas

    g <- ifelse(e0 > 0, e1 / e0, 0)
    NS <- sum(e0 * (G - 1))
    IM <- sum(e0 * (G_k - G))
    RS <- sum(e0 * (g - G_k))

    # Residuo: formas creadas en la comparación que no existían en la referencia
    sin_base <- e0 == 0 & e1 > 0
    data.frame(
      provincia = p,
      region = unname(tipo_de_prov[p]),
      tasa_ref  = sum(e0),
      tasa_comp = sum(e1),
      cambio_real = sum(e1) - sum(e0),
      efecto_nacional = NS,
      mix_estructural = IM,
      diferencial_provincial = RS,
      total_descompuesto = NS + IM + RS,
      residuo = sum(e1[sin_base]),
      formas_sin_base = paste(formas[sin_base], collapse = "; "),
      pct_sas = if (nrow(pc0)) 100 * mean(pc0$tipo == "SAS") else NA_real_,
      pct_coop = if (nrow(pc0)) 100 * mean(pc0$tipo == "Coop") else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, filas)
  out[order(out$diferencial_provincial), ]
}

for (cfg in list(
  list(nombre = "Milei (2024-2025)", eras = "milei", archivo = "shift_share_milei.csv"),
  list(nombre = "Fernández (2020-2023)", eras = "fernandez", archivo = "shift_share_fernandez.csv")
)) {
  titulo(paste("Referencia: kirchnerismo 2003-2015 — Comparación:", cfg$nombre))
  ss <- shift_share(d, KIRCHNERISMO, cfg$eras)
  guardar(ss, cfg$archivo)
  cat(sprintf("  rho de Spearman entre diferencial y participación SAS: %.2f\n",
              cor(ss$diferencial_provincial, ss$pct_sas, method = "spearman")))

  cat(sprintf("  signo del efecto nacional: %s en las 24 jurisdicciones\n",
              if (all(ss$efecto_nacional > 0)) "positivo" else
                if (all(ss$efecto_nacional < 0)) "negativo" else "mixto"))
  cat(sprintf("  residuo total sin base de cálculo: %.1f altas/año, en %d jurisdicciones\n",
              sum(ss$residuo), sum(ss$residuo > 0)))
  con_residuo <- ss[ss$residuo > 0, c("provincia", "residuo", "formas_sin_base")]
  if (nrow(con_residuo)) {
    for (i in seq_len(nrow(con_residuo))) {
      cat(sprintf("    %-22s %7.1f  (%s)\n", con_residuo$provincia[i],
                  con_residuo$residuo[i], con_residuo$formas_sin_base[i]))
    }
  }

  cat("\n  diferencial provincial, extremos:\n")
  ext <- rbind(head(ss, 4), tail(ss, 4))
  for (i in seq_len(nrow(ext))) {
    cat(sprintf("    %-22s %+9.1f  (%s)\n", ext$provincia[i],
                ext$diferencial_provincial[i],
                unname(REGION_ETIQUETA[ext$region[i]])))
  }

  perif_pos <- ss[ss$region %in% c("nea", "noa") & ss$diferencial_provincial > 0, ]
  cat(sprintf("\n  jurisdicciones del norte con diferencial positivo: %s\n",
              if (nrow(perif_pos)) paste(perif_pos$provincia, collapse = ", ") else "ninguna"))
}

# ── Cambio de signo entre ambas comparaciones ───────────────────────────────
titulo("Provincias que invierten el signo del diferencial entre Fernández y Milei")

a <- read.csv(file.path(SALIDAS, "shift_share_fernandez.csv"))
b <- read.csv(file.path(SALIDAS, "shift_share_milei.csv"))
m <- merge(a[, c("provincia", "region", "diferencial_provincial")],
           b[, c("provincia", "diferencial_provincial")],
           by = "provincia", suffixes = c("_fern", "_milei"))
m$invierte <- sign(m$diferencial_provincial_fern) != sign(m$diferencial_provincial_milei)
guardar(m, "shift_share_comparacion.csv")

inv <- m[m$invierte, ]
cat(sprintf("  invierten el signo: %s\n", paste(inv$provincia, collapse = ", ")))
for (i in seq_len(nrow(inv))) {
  cat(sprintf("    %-22s %+8.1f -> %+8.1f\n", inv$provincia[i],
              inv$diferencial_provincial_fern[i], inv$diferencial_provincial_milei[i]))
}

cat("\nlisto.\n")
