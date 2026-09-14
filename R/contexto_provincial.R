# contexto_provincial.R — Indicadores provinciales de cuatro fuentes públicas
# ============================================================================
# Construye data/contexto_provincial.csv, la tabla de 24 jurisdicciones que usan
# la prueba de densidad institucional (04_bloques_falsacion.R, por la población)
# y la figura S1 (06_figuras.R). La tabla viene publicada; este script sólo hace
# falta para reconstruirla desde los archivos crudos.
#
# Uso:
#   CONTEXTO_CRUDO=/ruta/a/crudos Rscript R/contexto_provincial.R
#
# El directorio CONTEXTO_CRUDO tiene que contener:
#   1-1-2.xlsx, 2-1-4.xlsx, 4-1-3.xlsx   BCRA, anexos del Informe de Inclusión
#                                        Financiera (puntos de acceso, cuentas,
#                                        tomadores de crédito)
#   cep_puestos_depto_clae2.csv          CEP XXI, puestos de trabajo asalariados
#                                        registrados por departamento y CLAE2
#   magyp_estimaciones_depto.csv         MAGyP, estimaciones agrícolas por
#                                        departamento
#   censo_empleo_depto.csv               INDEC, Censo 2022, condición de actividad
#                                        de la población de 14 años o más por
#                                        departamento
#
# De cada serie se toma el último período disponible en el archivo. Si ya existe
# data/contexto_provincial.csv, la tabla nueva se compara con ella y el script se
# detiene ante cualquier diferencia, de modo que una descarga posterior de las
# fuentes no reemplaza en silencio la tabla del artículo.

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
suppressMessages({ library(readxl); library(data.table) })

titulo("Contexto provincial: BCRA, CEP XXI, MAGyP y Censo 2022")

CRUDO <- Sys.getenv("CONTEXTO_CRUDO")
if (!nzchar(CRUDO) || !dir.exists(CRUDO)) {
  stop("Definir CONTEXTO_CRUDO con el directorio de los archivos crudos; ver el encabezado.")
}
crudo <- function(nombre) {
  ruta <- file.path(CRUDO, nombre)
  if (!file.exists(ruta)) stop("falta ", ruta)
  ruta
}

PROVINCIAS <- c("Buenos Aires", "CABA", "Catamarca", "Chaco", "Chubut", "Córdoba",
                "Corrientes", "Entre Ríos", "Formosa", "Jujuy", "La Pampa",
                "La Rioja", "Mendoza", "Misiones", "Neuquén", "Río Negro", "Salta",
                "San Juan", "San Luis", "Santa Cruz", "Santa Fe",
                "Santiago del Estero", "Tierra del Fuego", "Tucumán")

# Nombres de las fuentes: sin tildes, «Capital Federal», Tierra del Fuego completa
NOMBRE_FUENTE <- c(
  "Capital Federal" = "CABA", "Cordoba" = "Córdoba", "Entre Rios" = "Entre Ríos",
  "Neuquen" = "Neuquén", "Rio Negro" = "Río Negro", "Tucuman" = "Tucumán",
  "Tierra del Fuego, Antartida e Islas del Atlantico Sur" = "Tierra del Fuego"
)
normalizar <- function(x) {
  x <- trimws(as.character(x))
  ifelse(x %in% names(NOMBRE_FUENTE), NOMBRE_FUENTE[x], x)
}

CODIGO_INDEC <- c(
  "2" = "CABA", "6" = "Buenos Aires", "10" = "Catamarca", "14" = "Córdoba",
  "18" = "Corrientes", "22" = "Chaco", "26" = "Chubut", "30" = "Entre Ríos",
  "34" = "Formosa", "38" = "Jujuy", "42" = "La Pampa", "46" = "La Rioja",
  "50" = "Mendoza", "54" = "Misiones", "58" = "Neuquén", "62" = "Río Negro",
  "66" = "Salta", "70" = "San Juan", "74" = "San Luis", "78" = "Santa Cruz",
  "82" = "Santa Fe", "86" = "Santiago del Estero", "90" = "Tucumán",
  "94" = "Tierra del Fuego"
)

# Hojas del BCRA: cuatro filas de encabezado, luego una fila de títulos, y los
# valores por período en columnas. readxl descarta la columna A vacía.
hoja_bcra <- function(archivo, hoja) {
  x <- suppressMessages(read_excel(crudo(archivo), sheet = hoja, col_names = FALSE,
                                   skip = 4, .name_repair = "minimal"))
  as.data.frame(x)
}
numero <- function(v) suppressWarnings(as.numeric(as.character(v)))

# ── Puntos de acceso: suma de todos los tipos en el último mes ──────────────
pda <- hoja_bcra("1-1-2.xlsx", "1.1.2")
names(pda)[1:2] <- c("tipo", "provincia")
pda <- pda[!is.na(pda$tipo) & !is.na(pda$provincia), ]
pda$provincia <- normalizar(pda$provincia)
pda <- pda[pda$provincia %in% PROVINCIAS, ]
pda$valor <- numero(pda[[ncol(pda)]])
pda_total <- aggregate(valor ~ provincia, data = transform(pda, valor = ifelse(is.na(valor), 0, valor)),
                       FUN = sum)
names(pda_total)[2] <- "pda_total"

# ── Cuentas: «al menos una cuenta», último trimestre ────────────────────────
cta <- hoja_bcra("2-1-4.xlsx", "2.1.4.")
names(cta)[1:2] <- c("tipo", "provincia")
cta <- cta[!is.na(cta$tipo) & !is.na(cta$provincia), ]
cta$provincia <- normalizar(cta$provincia)
cta <- cta[cta$provincia %in% PROVINCIAS, ]
cta <- cta[grepl("Al menos una cuenta /|At least one account$", cta$tipo, ignore.case = TRUE), ]
cuentas <- data.frame(provincia = cta$provincia, pct_with_account = numero(cta[[ncol(cta)]]))

# ── Tomadores de crédito, último mes ────────────────────────────────────────
tom <- hoja_bcra("4-1-3.xlsx", "4.1.3")
names(tom)[1] <- "provincia"
tom <- tom[!is.na(tom$provincia), ]
tom$provincia <- normalizar(tom$provincia)
tom <- tom[tom$provincia %in% PROVINCIAS, ]
tomadores <- data.frame(provincia = tom$provincia, pct_borrowers = numero(tom[[ncol(tom)]]))

# ── Empleo formal: concentración sectorial en la última fecha ───────────────
cep <- fread(crudo("cep_puestos_depto_clae2.csv"))
cep <- cep[fecha == max(fecha) & puestos > 0]
cep <- cep[, .(puestos = sum(puestos)), by = .(id_provincia_indec, clae2)]
cep[, puestos_total := sum(puestos), by = id_provincia_indec]
empleo <- cep[, .(hhi_empleo = sum((puestos / puestos_total)^2),
                  n_sectors = uniqueN(clae2),
                  puestos_total = puestos_total[1]), by = id_provincia_indec]
empleo[, provincia := CODIGO_INDEC[as.character(id_provincia_indec)]]
empleo <- as.data.frame(empleo[, .(provincia, hhi_empleo, n_sectors, puestos_total)])

# ── Agricultura: última campaña ─────────────────────────────────────────────
mag <- fread(crudo("magyp_estimaciones_depto.csv"), encoding = "UTF-8")
mag <- mag[campania == sort(unique(na.omit(campania)))[uniqueN(na.omit(campania))]]
mag[, provincia := normalizar(provincia)]
agro <- mag[, .(sown_ha = sum(superficie_sembrada_ha, na.rm = TRUE),
                prod_tm = sum(produccion_tm, na.rm = TRUE),
                n_cultivos = uniqueN(cultivo)), by = provincia]
cultivos <- mag[, .(sup = sum(superficie_sembrada_ha, na.rm = TRUE)), by = .(provincia, cultivo)]
cultivos[, total := sum(sup), by = provincia]
agro <- merge(agro, cultivos[, .(agro_hhi = sum((sup / total)^2)), by = provincia], by = "provincia")
agro <- as.data.frame(agro)

# ── Censo 2022: población de 14 años o más y condición de actividad ─────────
censo <- fread(crudo("censo_empleo_depto.csv"))
censo <- censo[!is.na(dpto5)]
censo[, prov := dpto5 %/% 1000]
censo <- censo[, .(ocupados = sum(c22_ocupados), desocupados = sum(c22_desocupados),
                   activos = sum(c22_activos), pob_empleo = sum(c22_pob_empleo)), by = prov]
censo[, `:=`(tasa_empleo = ocupados / pob_empleo, tasa_desocupacion = desocupados / activos,
             provincia = CODIGO_INDEC[as.character(prov)])]
censo <- as.data.frame(censo[, .(provincia, pob_empleo, tasa_empleo, tasa_desocupacion)])

# ── Unión ───────────────────────────────────────────────────────────────────
ctx <- data.frame(provincia = PROVINCIAS)
for (t in list(pda_total, cuentas, tomadores, empleo, agro, censo)) {
  ctx <- merge(ctx, t, by = "provincia", all.x = TRUE)
}
ctx$pda_per_100k <- 1e5 * ctx$pda_total / ctx$pob_empleo
# Las variables agrícolas quedan vacías donde la última campaña no registra
# cultivos en la jurisdicción; todas las demás tienen que estar completas
AGRO <- c("sown_ha", "prod_tm", "n_cultivos", "agro_hhi")
stopifnot(nrow(ctx) == 24, !anyNA(ctx[, setdiff(names(ctx), AGRO)]))
cat("  jurisdicciones sin cultivos en la última campaña:",
    paste(ctx$provincia[is.na(ctx$sown_ha)], collapse = ", "), "\n")

destino <- file.path(DATOS, "contexto_provincial.csv")
if (file.exists(destino)) {
  previa <- read.csv(destino, fileEncoding = "UTF-8")
  previa <- previa[match(ctx$provincia, previa$provincia), names(ctx)]
  dif <- sapply(names(ctx)[-1], function(v) {
    if (any(is.na(ctx[[v]]) != is.na(previa[[v]]))) return(Inf)
    max(c(0, abs(ctx[[v]] - previa[[v]])), na.rm = TRUE)
  })
  print(signif(dif, 3))
  if (any(dif > 1e-9)) stop("la tabla reconstruida difiere de data/contexto_provincial.csv")
  cat("  coincide con data/contexto_provincial.csv\n")
} else {
  utils::write.csv(ctx, destino, row.names = FALSE, fileEncoding = "UTF-8")
  cat("  escrito", destino, "\n")
}
