# Data

## Raw data source

The primary dataset is the **National Company Registry** (*Registro Nacional de Sociedades*), maintained by ARCA (*Administracion de Recaudacion y Control Aduanero*, formerly AFIP). The registry is publicly available through Argentina's open data portal:

- **URL**: https://datos.gob.ar/dataset/justicia-registro-nacional-sociedades
- **Download date**: 23 February 2026
- **Raw file**: `registro-nacional-sociedades-20260223.csv` (3,050,044 rows)
- **After deduplication by tax identifier**: 1,245,492 unique organisations
- **After exclusions**: *N* = 1,210,044 organisations founded between 1901 and 2025

The raw file is not included in this repository due to size. Download it from the URL above and place it in this directory before running `scripts/00_build_national_dataset.py`.

## Supplementary data sources

| Source | Dataset | Period | URL |
|--------|---------|--------|-----|
| BCRA | Financial Inclusion Report | June 2025 | https://www.bcra.gob.ar/PublicacionesEstadisticas/Informe-Inclusion-Financiera.asp |
| CEP XXI | Formal employment by sector | November 2023 | https://datos.produccion.gob.ar |
| SAGyP | Agricultural estimates | 2024/2025 | https://datos.magyp.gob.ar/dataset/estimaciones-agricolas |
| INDEC | National Census | 2022 | https://censo.gob.ar |

## Provincial context table

`contexto_provincial.csv` holds one row per jurisdiction (24) with the indicators taken from the four supplementary sources. `R/contexto_provincial.R` builds it from the raw files below, placed in the directory named by the `CONTEXTO_CRUDO` environment variable. Each series uses the last period available in its file.

| Column | Definition | Raw file | Period |
|--------|------------|----------|--------|
| `pda_total` | Financial access points, all types | BCRA `1-1-2.xlsx`, sheet 1.1.2 | June 2025 |
| `pct_with_account` | % of adults with at least one account | BCRA `2-1-4.xlsx`, sheet 2.1.4. | June 2025 |
| `pct_borrowers` | % of adults with credit | BCRA `4-1-3.xlsx`, sheet 4.1.3 | June 2025 |
| `hhi_empleo`, `n_sectors`, `puestos_total` | Herfindahl index of registered wage jobs across two-digit activity codes, number of codes, total jobs | CEP XXI `cep_puestos_depto_clae2.csv` (jobs by department and two-digit activity code; suppressed cells, coded −99, excluded) | November 2023 |
| `sown_ha`, `prod_tm`, `n_cultivos`, `agro_hhi` | Sown area, production, number of crops and Herfindahl index of sown area across crops; empty where the campaign records no crops (CABA, Chubut, La Rioja, Mendoza, Neuquén, Río Negro, San Juan, Santa Cruz, Tierra del Fuego) | MAGyP `magyp_estimaciones_depto.csv` (agricultural estimates by department) | 2024/2025 campaign |
| `pob_empleo`, `tasa_empleo`, `tasa_desocupacion` | Population aged 14 and over (the base on which the census measures activity status), employment rate and unemployment rate | INDEC `censo_empleo_depto.csv` (Census 2022, activity status by department) | 2022 |
| `pda_per_100k` | `pda_total` per 100,000 inhabitants aged 14 and over | derived | — |

The institutional-density test in `R/04_bloques_falsacion.R` divides the stock of cooperatives and mutuals founded up to 2015 by `pob_empleo`, so density is also expressed per 100,000 inhabitants aged 14 and over.

## Map boundaries

`argentina_provinces.geojson` holds the 24 Argentine features of the Natural Earth 1:10m *Admin 1 – States, Provinces* layer (`ne_10m_admin_1_states_provinces`), which is in the public domain. Some name fields carry broken accents, so `R/06_figuras.R` joins on the ISO 3166-2 code.

## Processed outputs

The `salidas/` directory contains every output produced by the analytical pipeline, as CSV, plus the individual cloud of the correspondence analysis (`acm_nube_individuos.parquet`) and the supplementary tables in markdown under `salidas/cuadros/`. With the boundaries in this directory, they are sufficient to reproduce the seven figures without the registry.
