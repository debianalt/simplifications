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

## Processed outputs

The `salidas/` directory contains every output produced by the analytical pipeline, as CSV, plus the supplementary tables in markdown under `salidas/cuadros/`. They are sufficient to reproduce the figures without re-running the full pipeline.
