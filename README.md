# Who is left to associate? Company simplification and federalism in Argentina

**Raimundo Elias Gomez**
CONICET / FHyCS, Universidad Nacional de Misiones, Argentina
ORCID: [0000-0002-4468-9618](https://orcid.org/0000-0002-4468-9618)

**María Gabriela Miño**
CONICET / FHyCS, Universidad Nacional de Misiones, Argentina
ORCID: [0000-0002-5057-5158](https://orcid.org/0000-0002-5057-5158)

## Overview

This repository contains the replication materials for a study on the spatially uneven effects of Argentina's *Sociedades por Acciones Simplificadas* law (2017) and Milei-era deregulation on organisational diversity across the country's 24 subnational jurisdictions (23 provinces and the Autonomous City of Buenos Aires). Drawing on the complete National Company Registry (*N* = 1,210,044 unique organisations, 1901-2025), the study develops the concept of *fractured legibility* and applies three complementary decompositions: a correspondence analysis of the space of legal forms, a Theil decomposition of the concentration of provincial compositions, and a shift-share analysis of creation rates.

The central claim is that a nominally uniform national reform is registered through twenty-four registries, twenty-three provincial and, in the capital, a national organ acting as the local registry, whose conduct decides how far it reaches. The simplified form accounts for 83.4% of new registrations in one jurisdiction and 5.1% in another, and in the capital its uptake tracks, year by year, the requirements its own registry imposed between 2020 and 2023 and repealed in April 2024.

## Repository structure

```
simplifications/
|-- README.md
|-- LICENSE
|-- requirements.txt          # Python dependencies for the dataset builder
|-- .gitignore
|-- data/
|   |-- README.md             # Data sources and download instructions
|-- scripts/
|   |-- 00_build_national_dataset.py    # Cleaning, deduplication, exclusion chain
|-- R/
|   |-- replicar.R            # Driver: runs steps 1 to 6 in order
|   |-- 00_comun.R            # Paths, study constants, shared functions
|   |-- 01_acm.R              # Correspondence analysis and subcloud analysis
|   |-- 02_theil.R            # Theil decomposition, Shannon H, annual series
|   |-- 03_shift_share.R      # Shift-share decomposition
|   |-- 04_bloques_falsacion.R          # Association-threshold blocks and tests
|   |-- 05_cuadros.R          # Supplementary tables in markdown
|   |-- 06_figuras.R          # Seven figures at 300 dpi
|-- salidas/                  # All analytical outputs (CSV) and tables (markdown)
|-- figures/                  # Published figures (JPG, 300 dpi)
```

## Data description

| Stage | Rows | Description |
|-------|------|-------------|
| National Company Registry (raw) | 3,050,044 | Activity records for all registered organisations |
| After deduplication by tax identifier | 1,245,492 | Unique organisations |
| After exclusions | 1,210,044 | Analytical universe, 1901-2025 |
| Geometric analysis only | 1,179,364 | Excludes 30,680 organisations without a declared activity |

The exclusion chain is printed by `scripts/00_build_national_dataset.py`: 32,022 organisations without a declared province, 2,046 without a founding date, and 1,380 dated outside the 1901-2025 window.

### Key variables

| Variable | Description | Role | Source |
|----------|-------------|------|--------|
| `tipo` | Legal form (SA, SRL, SAS, Coop, Asoc, Fund, Mutual, Otra) | Active | ARCA registry |
| `clae_sec` | Activity section, 21 categories from two-digit activity codes | Active | ARCA registry |
| `era` | Political period (pre1990 to milei) | Supplementary | Founding year |
| `estado` | Fiscal status (AC = active, BD = cancelled) | Supplementary | ARCA registry |
| `provincia` | Jurisdiction of fiscal domicile (24) | Supplementary | ARCA registry |
| `prov_type` | Jurisdiction type (metropolitan, intermediate, peripheral) | Supplementary | Population and institutional density |

The political era and fiscal status are deliberately kept out of the active set. The simplified form was created in 2017, so its profile is concentrated in the recent periods by construction, and including the era as active would make the first axis partly an axis of vintage.

## Data sources

| Source | Dataset | Period | Access |
|--------|---------|--------|--------|
| ARCA / Ministerio de Justicia | Registro Nacional de Sociedades | 1901-2025 | [datos.gob.ar](https://datos.gob.ar/dataset/justicia-registro-nacional-sociedades) |
| BCRA | Informe de Inclusión Financiera | June 2025 | [bcra.gob.ar](https://www.bcra.gob.ar/PublicacionesEstadisticas/Informe-Inclusion-Financiera.asp) |
| CEP XXI | Formal employment by sector | November 2023 | [datos.produccion.gob.ar](https://datos.produccion.gob.ar) |
| SAGyP | Agricultural estimates | 2024/2025 | [datos.magyp.gob.ar](https://datos.magyp.gob.ar/dataset/estimaciones-agricolas) |
| INDEC | National Census | 2022 | [censo.gob.ar](https://censo.gob.ar) |
| Inspección General de Justicia | Resolución General 9/2020 | March 2020 | [boletinoficial.gob.ar](https://www.boletinoficial.gob.ar/detalleAviso/primera/226763/20200316) |
| Inspección General de Justicia | Resolución General 11/2024 | April 2024 | [boletinoficial.gob.ar](https://www.boletinoficial.gob.ar/detalleAviso/primera/305657/20240411) |
| INAES | Resolución 1000/2021 | August 2021 | [boletinoficial.gob.ar](https://www.boletinoficial.gob.ar/detalleAviso/primera/248024/20210812) |
| INAES | Resolución 2867/2024 | December 2024 | [boletinoficial.gob.ar](https://www.boletinoficial.gob.ar/detalleAviso/primera/318056/20241212) |
| DPPJ, Provincia de Buenos Aires | Disposición 49/2024 | June 2024 | [gba.gob.ar](https://www.gba.gob.ar/dppj/sociedades_por_acciones_simplificadas_sas) |

## Analytical pipeline

Step 0 builds the dataset in Python. Steps 1 to 6 run the analysis in R.

| Step | Script | Method | Output |
|------|--------|--------|--------|
| 0 | `scripts/00_build_national_dataset.py` | Clean, deduplicate and classify 3M records | `data/national_orgs_clean.parquet` |
| 1 | `R/01_acm.R` | Correspondence analysis of the 8 × 21 legal form by activity table; supplementary projection of era, fiscal status, jurisdiction type and the 24 jurisdictions; subcloud analysis with concentration ellipses | Eigenvalues, category coordinates, supplementary barycentres, subclouds |
| 2 | `R/02_theil.R` | Theil decomposition across eight political eras; Shannon *H* by jurisdiction with bootstrap intervals; annual series | Theil tables, Shannon by jurisdiction, annual series |
| 3 | `R/03_shift_share.R` | Shift-share: Kirchnerism against Fernández and against Milei | Provincial differentials for two comparison periods |
| 4 | `R/04_bloques_falsacion.R` | Association-threshold blocks, right-censoring control, SAS diffusion by jurisdiction, institutional-density test | Block series, SAS by jurisdiction, correlations with intervals |
| 5 | `R/05_cuadros.R` | Supplementary tables | `salidas/cuadros/*.md` |
| 6 | `R/06_figuras.R` | Seven figures at 300 dpi | `figures/*.jpg` |

The Theil decomposition is written as an identity that the code checks on every run:

```
sum_j w_j KL(s_j || U)  =  sum_j w_j KL(s_j || S)  +  KL(S || U)
     T_total                    T_entre               T_nacional
```

where `U` is the even spread over the eight legal forms and `S` the national composition. `T_total` is the average concentration of provincial compositions, `T_entre` measures how far they diverge from the national one, and the reported indicator is the share of `T_entre` in the total.

To replicate the full pipeline:

```bash
pip install -r requirements.txt
# Place the raw registry CSV in data/ (see data/README.md)
python scripts/00_build_national_dataset.py
Rscript R/replicar.R
```

To reproduce the figures only, using the outputs already in `salidas/`:

```bash
Rscript R/06_figuras.R
```

## Key findings

- The simplified form did not open a new position in the space of legal forms. It sits where the two commercial forms it replaces already sat, at +0.44 against +0.43 and +0.38 on an axis whose dispersion is 0.946. The first axis carries 83.3% of the inertia and the plane 89.7%.
- Between the Kirchner years and the Milei era the share of associative forms among new registrations falls from 17.6% to 7.9%, and to 9.1% when the era is restricted to 2024 to guard against registration lag. The fall is in the numerator: 4,854 associative registrations per year against 2,568, while total registrations grow 19%.
- The between-jurisdiction component of the Theil decomposition rises from 9.1% in the 1990s to 44.0% under Fernández, then falls to 31.6% under Milei. It falls because the common component grows, not because jurisdictions converge: their divergence holds at 0.290 against 0.278 while the national composition concentrates from 0.369 to 0.601.
- The separation between metropolitan and peripheral subcloud centroids grows from 0.59 to 0.79 standard deviations of the cloud between the 1990s and Fernández, and collapses to 0.30 under Milei.
- The simplified form accounts for 83.4% of new registrations in Mendoza and 5.1% in Buenos Aires province, and exceeds half in eleven of the twenty-four jurisdictions. In the Autonomous City of Buenos Aires it falls from 37.9% in 2019 to 1.2% in 2023 while its registry adds requirements, and recovers to 21.0% in 2025 after they are repealed. Buenos Aires province falls in parallel without an equivalent normative sequence; in June 2024 its registry added the seat and digital-book requirements the capital had just repealed while opening a new digital channel, and its recovery is weaker (6.9% in 2025 against 21.0% in the capital).
- The associative threshold itself moved within the window: INAES lowered the minimum for worker cooperatives from six to three members between August 2021 and December 2024. The 2022-2023 peak of associative registrations coincides with the lower threshold; the 2024 fall precedes its repeal.
- Accumulated cooperative density before the reform does not predict associative retention (*r* = 0.14, 95% CI −0.28 to 0.51, *N* = 24). With twenty-four units the interval is too wide to separate a small effect from its absence.
- Under Milei the most diverse jurisdiction more than doubles the least diverse (Entre Ríos 1.61, 95% CI 1.56 to 1.66; Mendoza 0.69, 95% CI 0.65 to 0.72). Twenty-two of the twenty-three adjacent pairs overlap, so only contrasts between extremes are interpretable.

## Requirements

- Python >= 3.10 for the dataset builder, see `requirements.txt`
- R >= 4.5 with `arrow`, `dplyr`, `tidyr`, `GDAtools`, `ggplot2`, `ggrepel`, `patchwork`, `sf` and `scales`

```r
install.packages(c("arrow", "dplyr", "tidyr", "GDAtools", "ggplot2",
                   "ggrepel", "patchwork", "sf", "scales"))
```

## Citation

Gomez, R. E. and Miño, M. G. (2026). Who is left to associate? Company simplification and federalism in Argentina. Manuscript under review.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
