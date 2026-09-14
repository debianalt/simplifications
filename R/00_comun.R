# 00_comun.R — rutas, constantes y utilidades compartidas
# ============================================================================
# Proyecto: formas jurídicas en el Registro Nacional de Sociedades, 1901-2025
#
# Todo el análisis del artículo vive en R (regla de la casa, 7 sep 2026).
# Python queda para la generación del DOCX y la verificación de formato.
#
# Este archivo no se ejecuta solo: lo cargan los scripts 01 a 06 con source().

suppressMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
})

# ── Rutas ───────────────────────────────────────────────────────────────────
# ES_ROOT puede fijarse antes del source() para correr desde otro lado. Si no,
# se deduce de la ubicación del propio script: es el directorio que contiene R/.
if (!exists("ES_ROOT")) {
  .argv <- commandArgs(trailingOnly = FALSE)
  .file <- sub("^--file=", "", grep("^--file=", .argv, value = TRUE))
  ES_ROOT <- if (length(.file) == 1) {
    normalizePath(file.path(dirname(.file), ".."), winslash = "/")
  } else {
    normalizePath(getwd(), winslash = "/")
  }
}
stopifnot(dir.exists(file.path(ES_ROOT, "R")))
ES   <- ES_ROOT
RAIZ <- dirname(ES)

# Los parquet viven en la carpeta de datos del proyecto, que está un nivel
# arriba en el árbol de trabajo y dentro del repositorio de replicación.
DATOS <- if (dir.exists(file.path(ES, "data"))) {
  file.path(ES, "data")
} else {
  file.path(RAIZ, "data")
}
PARQUET   <- file.path(DATOS, "national_orgs_clean.parquet")
GEOJSON   <- file.path(DATOS, "argentina_provinces.geojson")
CTX       <- file.path(DATOS, "provincial_context.parquet")
SALIDAS   <- file.path(ES, "salidas")
FIGURAS   <- file.path(ES, "figures")
dir.create(SALIDAS, showWarnings = FALSE)
dir.create(FIGURAS, showWarnings = FALSE)

# ── Constantes del estudio ──────────────────────────────────────────────────
ANIO_MIN <- 1901L
ANIO_MAX <- 2025L

ERAS <- c("pre1990", "menem", "crisis", "n_kirchner", "c_kirchner",
          "macri", "fernandez", "milei")

ERA_ETIQUETA <- c(
  pre1990    = "Pre-1990",   menem      = "Menem",
  crisis     = "Crisis",     n_kirchner = "N. Kirchner",
  c_kirchner = "C. Kirchner", macri     = "Macri",
  fernandez  = "Fernández",  milei      = "Milei"
)

# Años cubiertos por cada era, para anualizar altas
ERA_DURACION <- c(pre1990 = 89, menem = 10, crisis = 3, n_kirchner = 5,
                  c_kirchner = 8, macri = 4, fernandez = 4, milei = 2)

KIRCHNERISMO <- c("n_kirchner", "c_kirchner")   # 2003-2015
DUR_KIRCH    <- 13

# Agrupación de eras para el análisis de subnubes (6 paneles de la figura 2)
ERA_GRUPO <- c(
  pre1990 = "Pre-1990", menem = "Menem/Crisis", crisis = "Menem/Crisis",
  n_kirchner = "Kirchnerismo", c_kirchner = "Kirchnerismo",
  macri = "Macri", fernandez = "Fernández", milei = "Milei"
)
ERA_GRUPO_ORDEN <- c("Pre-1990", "Menem/Crisis", "Kirchnerismo",
                     "Macri", "Fernández", "Milei")

# Bloques por umbral de asociación. El criterio es conjuntivo: pluralidad de
# miembros y gobierno por asamblea con un voto por asociado. La SRL exige dos
# socios pero no lo segundo, de modo que integra el bloque de capital.
BLOQUE <- c(
  Coop = "asociativa", Mutual = "asociativa", Asoc = "asociativa",
  SA = "capital", SRL = "capital", SAS = "capital",
  Fund = "patrimonial", Otra = "patrimonial"
)

TIPO_PROV_ETIQUETA <- c(
  metropolitan = "Metropolitana",
  intermediate = "Intermedia",
  peripheral   = "Periférica"
)
TIPO_PROV_ORDEN <- c("metropolitan", "intermediate", "peripheral")

# Variables activas del análisis geométrico. La era política salió del conjunto
# activo el 8 sep 2026: aportaba el 38,7% del primer eje y la SAS existe desde
# 2017, de modo que el eje que se leía como estructura del espacio de formas era
# en buena parte un eje de antigüedad construido por el propio diseño. El subtipo
# funcional también salió: 1.040.038 de 1.210.044 casos caían en el residual y las
# categorías raras dominaban el segundo eje por masa baja. Con dos variables
# activas las tasas modificadas coinciden con la inercia del análisis de
# correspondencias de la tabla forma jurídica × sección de actividad.
VARS_ACTIVAS <- c("tipo", "clae_sec")
VARS_SUP     <- c("era", "estado", "prov_type", "provincia")

# Secciones de la Clasificación de Actividades Económicas, por rango de dos
# dígitos. La Z reúne los códigos que no caen en ninguna sección declarada.
CLAE_SECCION <- list(
  c(1, 3, "A"),   c(5, 9, "B"),   c(10, 33, "C"), c(35, 35, "D"), c(36, 39, "E"),
  c(41, 43, "F"), c(45, 47, "G"), c(49, 53, "H"), c(55, 56, "I"), c(58, 63, "J"),
  c(64, 66, "K"), c(68, 68, "L"), c(69, 75, "M"), c(77, 82, "N"), c(84, 84, "O"),
  c(85, 85, "P"), c(86, 88, "Q"), c(90, 93, "R"), c(94, 96, "S"), c(97, 99, "T")
)

#' Sección CLAE a partir del código de dos dígitos. NA si el registro no lo trae.
seccion_clae <- function(clae2) {
  c2  <- suppressWarnings(as.integer(clae2))
  out <- rep(NA_character_, length(c2))
  for (r in CLAE_SECCION) {
    en <- !is.na(c2) & c2 >= as.integer(r[1]) & c2 <= as.integer(r[2])
    out[en] <- r[3]
  }
  out[!is.na(c2) & is.na(out)] <- "Z"
  out
}

SEMILLA <- 42L

# ── Utilidades ──────────────────────────────────────────────────────────────

#' Carga el registro depurado con las columnas pedidas.
cargar_registro <- function(columnas = NULL) {
  d <- if (is.null(columnas)) {
    arrow::read_parquet(PARQUET)
  } else {
    arrow::read_parquet(PARQUET, col_select = all_of(columnas))
  }
  d <- as.data.frame(d)
  if ("tipo" %in% names(d)) d$bloque <- unname(BLOQUE[d$tipo])
  if ("era" %in% names(d)) d$era <- factor(d$era, levels = ERAS)
  if ("clae2" %in% names(d)) d$clae_sec <- seccion_clae(d$clae2)
  d
}

#' Índice de Shannon H sobre un vector de recuentos.
shannon <- function(conteos) {
  p <- conteos[conteos > 0]
  p <- p / sum(p)
  -sum(p * log(p))
}

#' Descomposición aditiva de la concentración de las composiciones provinciales.
#'
#' Para la provincia j con n_j organizaciones, participaciones s_jk sobre las K
#' formas del menú, composición nacional S_k, pesos w_j = n_j/N y U la
#' equidistribución sobre esas K formas, vale la identidad
#'
#'   sum_j w_j KL(s_j || U)  =  sum_j w_j KL(s_j || S)  +  KL(S || U)
#'         T_total                    T_entre              T_nacional
#'
#' T_total es la concentración media de las composiciones provinciales, es decir
#' cuánto se apartan en promedio de un reparto parejo entre las formas
#' disponibles. T_entre mide cuánto divergen las composiciones provinciales de la
#' nacional, y es el numerador del indicador del artículo. T_nacional es la
#' concentración de la composición agregada. Sumar a T_entre el promedio de las
#' divergencias respecto de U, como se hacía antes, contaba dos veces a T_entre,
#' porque ese promedio ya lo contiene.
#'
#' La referencia K es fija para todas las provincias y todas las eras. Tomar en
#' cambio el número de formas presentes en cada submuestra rompe la identidad y
#' hace que el denominador dependa de cuántas formas alcanzaron a registrarse.
theil_t <- function(df, col_prov = "provincia", col_tipo = "tipo",
                    K_ref = length(BLOQUE)) {
  tab <- table(df[[col_prov]], df[[col_tipo]])
  tab <- tab[rowSums(tab) > 0, , drop = FALSE]
  n_j <- rowSums(tab)
  N   <- sum(n_j)
  w_j <- n_j / N
  S_k <- colSums(tab) / N
  stopifnot(ncol(tab) <= K_ref)

  s_jk <- sweep(tab, 1, n_j, "/")

  # Divergencia de Kullback-Leibler de p respecto de q, sobre el soporte de p.
  kl <- function(p, q) {
    ok <- p > 0 & q > 0
    sum(p[ok] * log(p[ok] / q[ok]))
  }
  U <- rep(1 / K_ref, ncol(tab))

  T_total    <- sum(w_j * apply(s_jk, 1, kl, q = U))
  T_entre    <- sum(w_j * apply(s_jk, 1, kl, q = S_k))
  T_nacional <- kl(S_k, U)

  # La identidad es exacta con K fijo: sirve de test de regresión.
  stopifnot(abs(T_total - T_entre - T_nacional) < 1e-10)

  list(T_total = T_total, T_entre = T_entre, T_nacional = T_nacional,
       pct_entre = 100 * T_entre / T_total, n = N)
}

#' Correlación de Pearson con intervalo de confianza por transformación z de Fisher.
cor_ic <- function(x, y, conf = 0.95) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]; y <- y[ok]
  n <- length(x)
  ct <- stats::cor.test(x, y, method = "pearson")
  rho <- suppressWarnings(stats::cor(x, y, method = "spearman"))
  data.frame(
    n = n,
    r = unname(ct$estimate),
    ic_inf = ct$conf.int[1],
    ic_sup = ct$conf.int[2],
    t = unname(ct$statistic),
    p = ct$p.value,
    rho = rho
  )
}

#' Guarda un data.frame como CSV en salidas/ y avisa.
guardar <- function(df, nombre) {
  ruta <- file.path(SALIDAS, nombre)
  utils::write.csv(df, ruta, row.names = FALSE, fileEncoding = "UTF-8")
  cat("  guardado:", nombre, sprintf("(%d filas)\n", nrow(df)))
  invisible(ruta)
}

titulo <- function(txt) {
  cat("\n", strrep("=", 78), "\n", txt, "\n", strrep("=", 78), "\n", sep = "")
}

#' Miles con punto, al uso castellano, sin el aviso de prettyNum.
fmt_n <- function(x) formatC(x, format = "d", big.mark = ".", decimal.mark = ",")
