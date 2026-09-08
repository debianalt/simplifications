# 01_acm.R — Geometría del espacio de formas jurídicas
# ============================================================================
# Construye el espacio sobre dos variables activas, la forma jurídica y la
# sección de actividad, y analiza las subnubes por tipo de provincia y era
# dentro del marco de referencia global, siguiendo a Le Roux y Rouanet (2004,
# cap. 4).
#
# Con dos variables activas el análisis equivale a un análisis de
# correspondencias de la tabla forma jurídica × sección de actividad, y las
# tasas modificadas coinciden con la inercia de esa tabla. El script lo verifica
# y falla si dejan de coincidir.
#
# La era política y el estado fiscal pasaron a suplementarias el 8 sep 2026. La
# era aportaba el 38,7% del primer eje y la SAS existe desde 2017, de modo que
# el eje se construía en parte por antigüedad. El subtipo funcional salió del
# análisis: 1.040.038 de 1.210.044 casos caían en el residual.
#
# El registro no trae la actividad de 30.680 organizaciones, que quedan fuera de
# la geometría y sólo de ella. El resto del artículo corre sobre N = 1.210.044.
#
# Salidas en salidas/:
#   acm_valores_propios.csv    valores propios brutos y tasas modificadas
#   acm_categorias.csv         coordenadas, contribuciones, cos2 y v-test
#   acm_perfiles.csv           perfiles únicos con pesos y coordenadas
#   acm_suplementarias.csv     baricentros de era, estado, tipo de provincia y
#                              las 24 jurisdicciones
#   acm_jurisdicciones_era.csv baricentro de cada jurisdicción en cada era
#   acm_subnubes.csv           centroides, inercias y separaciones por subnube
#   acm_elipses.csv            puntos de las elipses de concentración (k = 2)

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
suppressMessages(library(GDAtools))

titulo("01 — Geometría del espacio de formas jurídicas")

# ── Datos y cadena de exclusión propia de la geometría ──────────────────────
d_todo <- cargar_registro(c("tipo", "clae2", "era", "estado",
                            "provincia", "prov_type", "year"))
cat("N del registro:", fmt_n(nrow(d_todo)), "organizaciones\n")
stopifnot(min(d_todo$year) >= ANIO_MIN, max(d_todo$year) <= ANIO_MAX)

sin_clae <- sum(is.na(d_todo$clae_sec))
d <- d_todo[!is.na(d_todo$clae_sec), ]
cat("  sin actividad declarada:", fmt_n(sin_clae),
    sprintf("(%.1f%%)\n", 100 * sin_clae / nrow(d_todo)))
cat("N de la geometría:", fmt_n(nrow(d)), "organizaciones\n")

d$era_grupo <- factor(ERA_GRUPO[as.character(d$era)], levels = ERA_GRUPO_ORDEN)
d$prov_type <- factor(d$prov_type, levels = TIPO_PROV_ORDEN)

# ── Perfiles únicos ─────────────────────────────────────────────────────────
act_todo <- d[, VARS_ACTIVAS]
act_todo[] <- lapply(act_todo, factor)

perfiles <- act_todo |>
  dplyr::count(dplyr::across(dplyr::all_of(VARS_ACTIVAS)), name = "peso")
cat("perfiles de respuesta distintos:", nrow(perfiles),
    " (pesos suman", fmt_n(sum(perfiles$peso)), ")\n")

act <- as.data.frame(perfiles[, VARS_ACTIVAS])
act[] <- lapply(act, factor)

clave <- function(df) do.call(paste, c(df[VARS_ACTIVAS], sep = "\r"))
idx_perfil <- match(clave(act_todo), clave(act))
stopifnot(!anyNA(idx_perfil))

# ── Análisis ────────────────────────────────────────────────────────────────
Q <- length(VARS_ACTIVAS)
n_cat <- sum(sapply(act, nlevels))
cat("variables activas:", Q, " categorías:", n_cat, "\n")

acm <- speMCA(act, ncp = 5, row.w = perfiles$peso)
tasas <- modif.rate(acm)

cat("\ntasas de inercia (5 primeros ejes):\n")
for (i in 1:5) {
  cat(sprintf("  eje %d: valor propio %.4f  bruto %.2f%%  modificado %.2f%%  acumulado %.2f%%\n",
              i, acm$eig$eigen[i], tasas$raw$rate[i],
              tasas$modif$mrate[i], tasas$modif$cum.mrate[i]))
}

# Con Q = 2 la geometría es la del análisis de correspondencias de la tabla
# forma jurídica × sección de actividad. Se computa esa tabla por separado y se
# comprueba que la inercia coincida con las tasas modificadas: si el conjunto de
# variables activas cambiara, la comprobación falla y avisa.
tab_ca <- table(d[[VARS_ACTIVAS[1]]], d[[VARS_ACTIVAS[2]]])
P  <- tab_ca / sum(tab_ca)
rr <- rowSums(P); cc <- colSums(P)
S  <- (P - outer(rr, cc)) / sqrt(outer(rr, cc))
lam_ca <- svd(S)$d^2
lam_ca <- lam_ca[lam_ca > 1e-12]
pct_ca <- 100 * lam_ca / sum(lam_ca)
cat(sprintf("\ninercia del AC de la tabla %d x %d: eje 1 = %.2f%%, plano = %.2f%%\n",
            nrow(tab_ca), ncol(tab_ca), pct_ca[1], sum(pct_ca[1:2])))
stopifnot(Q == 2, abs(pct_ca[1] - tasas$modif$mrate[1]) < 0.2,
          abs(sum(pct_ca[1:2]) - tasas$modif$cum.mrate[2]) < 0.2)
cat("  coincide con las tasas modificadas\n")

eig <- data.frame(
  eje            = seq_len(nrow(tasas$raw)),
  valor_propio   = tasas$raw$eigen,
  pct_bruto      = tasas$raw$rate,
  pct_acum_bruto = tasas$raw$cum.rate
)
eig$pct_modificado <- c(tasas$modif$mrate,
                        rep(NA_real_, nrow(eig) - nrow(tasas$modif)))
eig$pct_acum_modificado <- c(tasas$modif$cum.mrate,
                             rep(NA_real_, nrow(eig) - nrow(tasas$modif)))
eig$pct_inercia_ca <- c(pct_ca, rep(NA_real_, nrow(eig) - length(pct_ca)))
guardar(eig, "acm_valores_propios.csv")

# ── Categorías: coordenadas, contribuciones, cos2, v-test ───────────────────
etiquetas <- rownames(acm$var$coord)
variable_de <- rep(names(sapply(act, nlevels)), times = sapply(act, nlevels))

cats <- data.frame(
  variable  = variable_de,
  categoria = etiquetas,
  peso      = acm$var$weight,
  stringsAsFactors = FALSE
)
for (k in 1:2) {
  cats[[paste0("coord", k)]]  <- acm$var$coord[, k]
  cats[[paste0("ctr", k)]]    <- acm$var$contrib[, k]
  cats[[paste0("cos2_", k)]]  <- acm$var$cos2[, k]
  cats[[paste0("vtest", k)]]  <- acm$var$v.test[, k]
}
cats <- cats[order(-cats$ctr1), ]
guardar(cats, "acm_categorias.csv")

for (k in 1:2) {
  cat(sprintf("\ncontribuciones al eje %d (media = %.2f%%):\n", k, 100 / n_cat))
  top <- cats[order(-cats[[paste0("ctr", k)]]), ][1:6, ]
  for (i in seq_len(nrow(top))) {
    cat(sprintf("  %-22s ctr %5.2f%%  coord %+.2f  cos2 %.3f\n",
                top$categoria[i], top[[paste0("ctr", k)]][i],
                top[[paste0("coord", k)]][i], top[[paste0("cos2_", k)]][i]))
  }
}
cat("\nposición de las ocho formas jurídicas sobre el eje 1:\n")
formas <- cats[cats$variable == "tipo", ]
formas <- formas[order(formas$coord1), ]
for (i in seq_len(nrow(formas))) {
  cat(sprintf("  %-14s %+6.2f  (ctr %5.2f%%, cos2 %.3f)\n",
              formas$categoria[i], formas$coord1[i], formas$ctr1[i], formas$cos2_1[i]))
}

# ── Coordenadas de los perfiles y de las organizaciones ─────────────────────
N_EJES <- 5L
for (k in seq_len(N_EJES)) {
  perfiles[[paste0("dim", k)]] <- acm$ind$coord[, k]
  d[[paste0("d", k)]] <- perfiles[[paste0("dim", k)]][idx_perfil]
}
guardar(as.data.frame(perfiles), "acm_perfiles.csv")
cols_ejes <- paste0("d", seq_len(N_EJES))

sd_nube <- vapply(cols_ejes, function(cc) stats::sd(d[[cc]]), numeric(1))
cat(sprintf("\ndispersión de la nube: eje 1 = %.3f, eje 2 = %.3f\n",
            sd_nube[1], sd_nube[2]))

# ── Variables suplementarias, por baricentro ────────────────────────────────
# La coordenada principal de una categoría es el baricentro de las coordenadas
# de sus individuos dividido por la raíz del valor propio. La comprobación se
# hace sobre una categoría activa, cuya coordenada ya conocemos.
lambda <- acm$eig$eigen[1:2]

baricentro <- function(valores, k) {
  tapply(d[[paste0("d", k)]], valores, mean) / sqrt(lambda[k])
}

chk <- baricentro(d$tipo, 1)["SAS"]
ref <- cats$coord1[cats$categoria == "tipo.SAS"]
stopifnot(abs(chk - ref) < 1e-6)
cat("  baricentro verificado contra una categoría activa\n")

sup <- do.call(rbind, lapply(VARS_SUP, function(v) {
  vals <- as.character(d[[v]])
  n <- table(vals)
  data.frame(variable = v, categoria = names(n), n = as.integer(n),
             coord1 = unname(baricentro(vals, 1)[names(n)]),
             coord2 = unname(baricentro(vals, 2)[names(n)]),
             row.names = NULL)
}))
guardar(sup, "acm_suplementarias.csv")

cat("\nsuplementarias sobre el eje 1:\n")
for (v in c("era", "prov_type")) {
  s <- sup[sup$variable == v, ]
  cat(" ", v, ":", paste(sprintf("%s %+.2f", s$categoria, s$coord1), collapse = "  "), "\n")
}

# Baricentro de cada jurisdicción en cada agrupación de eras: es la proyección
# del espacio de formas sobre el territorio, jurisdicción por jurisdicción.
jur_era <- d |>
  dplyr::filter(!is.na(era_grupo)) |>
  dplyr::group_by(era_grupo, provincia, prov_type) |>
  dplyr::summarise(n = dplyr::n(),
                   coord1 = mean(d1) / sqrt(lambda[1]),
                   coord2 = mean(d2) / sqrt(lambda[2]), .groups = "drop") |>
  as.data.frame()
guardar(jur_era, "acm_jurisdicciones_era.csv")

ml <- jur_era[jur_era$era_grupo == "Milei", ]
ml <- ml[order(ml$coord1), ]
cat("\njurisdicciones bajo Milei, eje 1 (del polo asociativo al comercial):\n")
cat(" ", paste(sprintf("%s %+.2f", ml$provincia, ml$coord1), collapse = "  "), "\n")

# ── Subnubes por tipo de provincia y era ────────────────────────────────────
momentos_subnube <- function(sub) {
  X <- as.matrix(sub[, cols_ejes])
  S <- stats::cov(X)
  list(n = nrow(X), centro = colMeans(X[, 1:2, drop = FALSE]), S = S[1:2, 1:2],
       inercia = sum(diag(S)), lambda = eigen(S, symmetric = TRUE)$values)
}

combos <- d |>
  dplyr::filter(!is.na(era_grupo)) |>
  dplyr::group_by(era_grupo, prov_type) |>
  dplyr::group_split()

subnubes <- do.call(rbind, lapply(combos, function(sub) {
  m <- momentos_subnube(sub)
  data.frame(
    era_grupo    = as.character(sub$era_grupo[1]),
    tipo_prov    = as.character(sub$prov_type[1]),
    tipo_prov_es = unname(TIPO_PROV_ETIQUETA[as.character(sub$prov_type[1])]),
    n            = m$n,
    centro1      = m$centro[1],
    centro2      = m$centro[2],
    inercia      = m$inercia,
    lambda1      = m$lambda[1],
    lambda2      = m$lambda[2]
  )
}))
subnubes$era_grupo <- factor(subnubes$era_grupo, levels = ERA_GRUPO_ORDEN)
subnubes <- subnubes[order(subnubes$era_grupo, match(subnubes$tipo_prov, TIPO_PROV_ORDEN)), ]

# Separación entre el centroide metropolitano y el periférico sobre el eje 1,
# expresada en desviaciones de la nube: una diferencia de centroides sólo dice
# algo comparada con la dispersión del espacio en que se mide.
sep <- do.call(rbind, lapply(ERA_GRUPO_ORDEN, function(e) {
  s <- subnubes[subnubes$era_grupo == e, ]
  m <- s$centro1[s$tipo_prov == "metropolitan"]
  p <- s$centro1[s$tipo_prov == "peripheral"]
  data.frame(era_grupo = e, centro_metro = m, centro_perif = p,
             separacion = m - p, separacion_sd = (m - p) / sd_nube[1])
}))
subnubes$separacion_sd <- sep$separacion_sd[match(subnubes$era_grupo, sep$era_grupo)]
guardar(subnubes, "acm_subnubes.csv")

cat("\ncentroides e inercias de clase:\n")
for (i in seq_len(nrow(subnubes))) {
  cat(sprintf("  %-13s %-14s n=%9s  centro (%+.3f, %+.3f)  inercia %.3f\n",
              subnubes$era_grupo[i], subnubes$tipo_prov_es[i],
              fmt_n(subnubes$n[i]), subnubes$centro1[i], subnubes$centro2[i],
              subnubes$inercia[i]))
}
cat("\nseparación metropolitana-periférica sobre el eje 1, en desviaciones de la nube:\n")
for (i in seq_len(nrow(sep))) {
  cat(sprintf("  %-13s %+.3f frente a %+.3f   diferencia %.3f = %.2f desviaciones\n",
              sep$era_grupo[i], sep$centro_metro[i], sep$centro_perif[i],
              sep$separacion[i], sep$separacion_sd[i]))
}

# ── Elipses de concentración (kappa = 2) ────────────────────────────────────
# Una elipse de concentración con kappa = 2 cubre el 86,5% de las observaciones
# de una subnube normal bivariada.
KAPPA <- 2
puntos_elipse <- function(centro, S, kappa = KAPPA, n = 200) {
  ev <- eigen(S, symmetric = TRUE)
  ejes <- kappa * sqrt(pmax(ev$values, 0))
  th <- seq(0, 2 * pi, length.out = n)
  circulo <- rbind(cos(th), sin(th))
  P <- ev$vectors %*% diag(ejes) %*% circulo
  data.frame(x = centro[1] + P[1, ], y = centro[2] + P[2, ])
}

elipses <- do.call(rbind, lapply(combos, function(sub) {
  m <- momentos_subnube(sub)
  e <- puntos_elipse(m$centro, m$S)
  e$era_grupo <- as.character(sub$era_grupo[1])
  e$tipo_prov <- as.character(sub$prov_type[1])
  e
}))
elipses$era_grupo <- factor(elipses$era_grupo, levels = ERA_GRUPO_ORDEN)
guardar(elipses, "acm_elipses.csv")

cat(sprintf("\ncobertura de la elipse kappa = %d: %.1f%% de las observaciones\n",
            KAPPA, 100 * (1 - exp(-KAPPA^2 / 2))))

# ── Nube de individuos para la figura 1 ─────────────────────────────────────
set.seed(SEMILLA)
n_puntos <- 40000L
sel <- sample.int(nrow(d), min(n_puntos, nrow(d)))
nube <- d[sel, c("tipo", "clae_sec", "era", "provincia", "prov_type", "d1", "d2")]
names(nube)[match(c("d1", "d2"), names(nube))] <- c("dim1", "dim2")
arrow::write_parquet(nube, file.path(SALIDAS, "acm_nube_individuos.parquet"))
cat("  guardado: acm_nube_individuos.parquet (", nrow(nube), "puntos )\n")

# ── Distribución territorial de las formas ──────────────────────────────────
# Se computa sobre el registro completo, porque no depende de la geometría.
territorio <- d_todo |>
  dplyr::count(tipo, prov_type) |>
  tidyr::pivot_wider(names_from = prov_type, values_from = n, values_fill = 0) |>
  dplyr::mutate(total = metropolitan + intermediate + peripheral,
                pct_metropolitana = 100 * metropolitan / total) |>
  dplyr::arrange(dplyr::desc(pct_metropolitana))
guardar(as.data.frame(territorio), "acm_formas_por_tipo_provincia.csv")

cat("\nconcentración metropolitana por forma jurídica (registro completo):\n")
for (i in seq_len(nrow(territorio))) {
  cat(sprintf("  %-8s %5.1f%% en provincias metropolitanas  (n = %s)\n",
              territorio$tipo[i], territorio$pct_metropolitana[i],
              fmt_n(territorio$total[i])))
}

pct_metro_registro <- 100 * sum(d_todo$prov_type == "metropolitan") / nrow(d_todo)
cat(sprintf("\nlas cuatro jurisdicciones metropolitanas reúnen el %.1f%% del registro\n",
            pct_metro_registro))

cat("\nlisto.\n")
