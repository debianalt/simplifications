# What the state can read: organisational simplification in Argentina's federal system, 1901-2025

**Raimundo Elias Gomez**
CONICET / FHyCS, Universidad Nacional de Misiones, Argentina
ORCID: [0000-0002-4468-9618](https://orcid.org/0000-0002-4468-9618)

**María Gabriela Miño**
CONICET / FHyCS, Universidad Nacional de Misiones, Argentina
ORCID: [0000-0002-5057-5158](https://orcid.org/0000-0002-5057-5158)

## Overview

This repository contains the replication materials for a study on the spatially uneven effects of Argentina's SAS law (2017) and Milei-era deregulation on organisational diversity across all 24 provinces. Drawing on the complete National Company Registry (*N* = 1,211,424 unique organisations, 1901-2025), the study introduces the concept of *fractured legibility* and deploys three complementary decompositions -- multiple correspondence analysis (MCA), Theil index decomposition, and shift-share analysis -- to demonstrate that deregulation in federal systems produces not uniform outcomes but provincially differentiated monocultures.

## Repository structure

```
simplifications-github/
|-- README.md
|-- LICENSE
|-- requirements.txt
|-- .gitignore
|-- data/
|   |-- README.md              # Data sources and download instructions
|-- scripts/
|   |-- 00_build_national_dataset.py
|   |-- 01_mca_csmca.py
|   |-- 02_theil_decomposition.py
|   |-- 03_shift_share.py
|   |-- 04_supplementary_provincial.py
|   |-- 05_publication_figures.py
|-- figures/
|   |-- Fig1_biplot.png
|   |-- Fig2_csmca_panel.png
|   |-- Fig3_theil_temporal.png
|   |-- Fig4_shannon_ranking.png
|   |-- Fig5_shift_share.png
|   |-- Fig6_choropleth.png
|   |-- fig_cluster_validation.png
|   |-- fig_scatter_context.png
|-- tables/
    |-- tab_col_coords.csv
    |-- tab_eigenvalues.csv
    |-- tab_theil_decomposition.csv
    |-- tab_shannon_by_province_era.csv
    |-- tab_shift_share.csv
    |-- (+ additional output tables)
```

## Data description

| File | Rows | Description |
|------|------|-------------|
| National Company Registry (raw) | 3,050,044 | Activity records for all registered organisations |
| After deduplication | 1,211,424 | Unique organisations by CUIT, 24 provinces, 1901-2025 |

### Key variables

| Variable | Description | Source |
|----------|-------------|--------|
| `tipo` | Juridical form (SA, SRL, SAS, Coop, Asoc, Fund, Mutual, Otra) | ARCA registry |
| `subtipo` | Functional subtype (agricultural, religious, sports, etc.) | Keyword matching on business name |
| `era` | Political period (pre1990, menem, crisis, n_kirchner, c_kirchner, macri, fernandez, milei) | Founding year |
| `estado` | Fiscal status (AC = active, BD = cancelled) | ARCA registry |
| `provincia` | Province of fiscal domicile (24 provinces) | ARCA registry |
| `prov_type` | Province classification (metropolitan, intermediate, peripheral) | Population and institutional density |

## Data sources

| Source | Dataset | Period | Access |
|--------|---------|--------|--------|
| ARCA / Ministerio de Justicia | Registro Nacional de Sociedades | 1901-2025 | [datos.gob.ar](https://datos.gob.ar/dataset/justicia-registro-nacional-sociedades) |
| BCRA | Informe de Inclusion Financiera | June 2025 | [bcra.gob.ar](https://www.bcra.gob.ar/PublicacionesEstadisticas/Informe-Inclusion-Financiera.asp) |
| CEP XXI | Formal employment by sector | November 2023 | [datos.produccion.gob.ar](https://datos.produccion.gob.ar) |
| SAGyP | Agricultural estimates | 2024/2025 | [datos.magyp.gob.ar](https://datos.magyp.gob.ar/dataset/estimaciones-agricolas) |
| INDEC | National Census | 2022 | [censo.gob.ar](https://censo.gob.ar) |

## Analytical pipeline

| Step | Script | Method | Output |
|------|--------|--------|--------|
| 0 | `00_build_national_dataset.py` | Clean, deduplicate, classify 3M records | `national_cluster_assignments.parquet` |
| 1 | `01_mca_csmca.py` | MCA + class-specific MCA (k=5 clusters) | Column coordinates, eigenvalues, row coordinates |
| 2 | `02_theil_decomposition.py` | Theil T between/within provinces x 8 eras | Theil decomposition table, Shannon H by province |
| 3 | `03_shift_share.py` | Shift-share: Kirchnerism vs Fernández and vs Milei | Provincial differentials (2 comparison periods) |
| 4 | `04_supplementary_provincial.py` | BCRA/CEP XXI/MAGYP/Census integration | Provincial context variables |
| 5 | `05_publication_figures.py` | Publication-quality figures (300 DPI) | 5 main figures + 1 supplementary choropleth |

To replicate the full pipeline:

```bash
pip install -r requirements.txt
# Place raw ARCA CSV in data/ (see data/README.md)
cd scripts
python 00_build_national_dataset.py
python 01_mca_csmca.py
python 02_theil_decomposition.py
python 03_shift_share.py
python 04_supplementary_provincial.py
python 05_publication_figures.py
```

To reproduce figures only (using pre-computed tables):

```bash
cd scripts
python 05_publication_figures.py
```

## Key findings

- The organisational field is structured by the opposition between collective-solidarity forms (cooperatives, associations) and commercial-simplified forms (SAS, SRL), with 84.7% of corrected inertia on the principal MCA plane.
- Interprovincial diversity inequality tripled from ~10% to 30.6% of total Theil T between the 1990s and the Fernandez period.
- Under Milei, total Theil T reaches its historical maximum (1.149) whilst the between-province share declines to 24.0%, indicating convergence toward uniformly low diversity.
- Metropolitan provinces resist simplification through institutional scale (CABA: +812 orgs/year differential).
- Provinces with cooperative constituencies sustain diversity (Entre Rios: Shannon H = 1.62).
- Intermediate provinces lacking both mechanisms experience the deepest simplification (Mendoza: Shannon H = 0.68, SAS share = 84%).

## Requirements

- Python >= 3.10
- See `requirements.txt` for package dependencies

## Citation

```bibtex
@unpublished{gomez_mino2026legibility,
  author = {Gomez, Raimundo Elias and Mi{\~n}o, Mar{\'i}a Gabriela},
  title = {What the state can read: organisational simplification in {Argentina}'s federal system, 1901--2025},
  year = {2026},
  note = {Manuscript under review}
}
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
