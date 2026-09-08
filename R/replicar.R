# replicar.R — corre el análisis completo desde la raíz del repositorio
# ============================================================================
# Uso, desde la raíz del repositorio:
#
#   Rscript R/replicar.R
#
# Requiere que data/national_orgs_clean.parquet exista. Ese archivo lo produce
# scripts/00_build_national_dataset.py a partir del CSV crudo del Registro
# Nacional de Sociedades; ver data/README.md.
#
# Escribe las salidas en salidas/ y las figuras en figures/, sobrescribiendo
# las versiones publicadas en este repositorio.

argumentos <- commandArgs(trailingOnly = FALSE)
ruta_script <- sub("^--file=", "", grep("^--file=", argumentos, value = TRUE))

ES_ROOT <- if (length(ruta_script) == 1) {
  normalizePath(file.path(dirname(ruta_script), ".."), winslash = "/")
} else {
  normalizePath(getwd(), winslash = "/")
}
stopifnot(dir.exists(file.path(ES_ROOT, "R")))

cat("raíz del proyecto:", ES_ROOT, "\n")

for (paso in c("01_acm", "02_theil", "03_shift_share",
               "04_bloques_falsacion", "05_cuadros", "06_figuras")) {
  cat("\n>>>", paso, "\n")
  source(file.path(ES_ROOT, "R", paste0(paso, ".R")), local = new.env())
}

cat("\nlisto: salidas en salidas/ y figuras en figures/\n")
