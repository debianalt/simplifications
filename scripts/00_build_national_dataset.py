"""
00 — Build national organisational dataset
============================================
Project: Differential Institutional Simplification (2026_12)

Reads the national company registry (3M rows, 1.24M unique CUITs),
deduplicates, classifies juridical form / functional subtype / political era,
and outputs a clean parquet for downstream analysis.

Input:  gee/arca/data/registro-nacional-sociedades-20260223.csv
Output: data/national_orgs_clean.parquet

Usage:
    python 00_build_national_dataset.py
"""

import re
import warnings
from pathlib import Path

import pandas as pd
import numpy as np

warnings.filterwarnings("ignore", category=FutureWarning)

# ── Paths ────────────────────────────────────────────────────────────────────
PROJECT = Path(__file__).parent
DATA_DIR = PROJECT / "data"
TAB_DIR = PROJECT / "tables"
DATA_DIR.mkdir(exist_ok=True)
TAB_DIR.mkdir(exist_ok=True)

REGISTRY = Path(r"C:\Users\ant\OneDrive\gee\arca\data\registro-nacional-sociedades-20260223.csv")


# ── Classification functions (replicated from 2026_11/acm/03_run_acm.py) ────

def classify_tipo(t):
    """Classify tipo_societario into 7 categories."""
    t = str(t).upper()
    if "COOPERATIVA" in t:
        return "Coop"
    if "ASOCIACION" in t and "MUTUAL" not in t:
        return "Asoc"
    if "FUNDACION" in t:
        return "Fund"
    if "MUTUAL" in t:
        return "Mutual"
    if "RESPONSABILIDAD LIMITADA" in t:
        return "SRL"
    if "ANONIMA" in t and "SIMPLIFICADA" not in t:
        return "SA"
    if "SIMPLIFICADA" in t:
        return "SAS"
    return "Otra"


# Subtipo keywords — same as Misiones article
SUBTIPO_KEYWORDS = {
    "agro": [
        "AGROPECUAR", "AGRO ", "AGRICOL", "GANADER", "YERBA", "TABAC",
        "FORESTAL", "MADERA", "ASERRADERO", "VIVERO", "APICOL", "CITRICOL",
        "AVICOL", "PORCIN", "TAMBERO", "SEMILLER", "OLEAGINOSA",
        "FRUTIHORTICOL", "HORTICOL", "PESQUER", "BODEGA", "VINIC",
    ],
    "religious": [
        "IGLESIA", "EVANGELICA", "PASTORAL", "PARROQUIA", "TEMPLO",
        "CRISTIANA", "ADVENTISTA", "BAUTISTA", "PENTECOSTAL",
        "ASAMBLEA DE DIOS", "METODISTA", "LUTERANA", "MENONITA",
        "CONGREGACION", "MINISTERIO CRISTIAN", "CULTO",
    ],
    "sports": ["CLUB ", "DEPORTIV", "FUTBOL", "ATLETICO"],
    "indigenous": ["COMUNIDAD ABORIGEN", "COMUNIDAD INDIGENA", "MBYA GUARANI",
                   "PUEBLO ORIGINARIO", "COMUNIDAD MAPUCHE", "COMUNIDAD WICHI"],
    "education": ["ESCUELA", "COLEGIO", "INSTITUTO", "EDUCACI", "BIBLIOTECA",
                  "UNIVERSIDAD", "ACADEMIA", "CAPACITACION"],
    "health": ["HOSPITAL", "CLINICA", "SANATORIO", "SALUD", "MEDIC", "FARMAC",
               "ODONTOLOG", "LABORATORIO BIOQUIM"],
    "transport": ["TRANSPORT", "REMIS", "TAXI", "COLECTIV", "CAMION", "LOGISTIC"],
    "construction": ["CONSTRUC", "INMOBILIAR", "INMUEBLE", "VIVIENDA", "ARQUITECT"],
    "commerce": ["COMERCI", "MERCADO", "SUPERMERCADO", "DISTRIBUID", "MAYORIST"],
    "tourism": ["TURIS", "HOTEL", "HOSTEL", "CABANA", "ALOJAMIENTO", "GASTRONOM"],
}

# Exclude false positives for "religious" (e.g. "MISIONERA SA" = not a church)
RELIG_EXCLUDE = re.compile(
    r"MISIONERA\s+S[.\s]|MISIONERO\s+S[.\s]|MISIONERAS\s+SA|ARENERA|AGUAS\s+MISION",
    re.IGNORECASE,
)


def classify_subtipo(rs):
    """Classify functional subtype from razón social via keyword matching."""
    rs = str(rs).upper()
    for sub, kws in SUBTIPO_KEYWORDS.items():
        if any(kw in rs for kw in kws):
            if sub == "religious" and RELIG_EXCLUDE.search(rs):
                continue
            return sub
    return "other"


def political_era(y):
    """Assign political era from founding year."""
    if pd.isna(y):
        return "unknown"
    y = int(y)
    if y <= 1989:
        return "pre1990"
    if y <= 1999:
        return "menem"
    if y <= 2002:
        return "crisis"
    if y <= 2007:
        return "n_kirchner"
    if y <= 2015:
        return "c_kirchner"
    if y <= 2019:
        return "macri"
    if y <= 2023:
        return "fernandez"
    return "milei"


# ── Province name normalisation ──────────────────────────────────────────────

PROVINCE_NORM = {
    "CIUDAD AUTONOMA BUENOS AIRES": "CABA",
    "BUENOS AIRES": "Buenos Aires",
    "CATAMARCA": "Catamarca",
    "CHACO": "Chaco",
    "CHUBUT": "Chubut",
    "CORDOBA": "Córdoba",
    "CORRIENTES": "Corrientes",
    "ENTRE RIOS": "Entre Ríos",
    "FORMOSA": "Formosa",
    "JUJUY": "Jujuy",
    "LA PAMPA": "La Pampa",
    "LA RIOJA": "La Rioja",
    "MENDOZA": "Mendoza",
    "MISIONES": "Misiones",
    "NEUQUEN": "Neuquén",
    "RIO NEGRO": "Río Negro",
    "SALTA": "Salta",
    "SAN JUAN": "San Juan",
    "SAN LUIS": "San Luis",
    "SANTA CRUZ": "Santa Cruz",
    "SANTA FE": "Santa Fe",
    "SANTIAGO DEL ESTERO": "Santiago del Estero",
    "TIERRA DEL FUEGO": "Tierra del Fuego",
    "TUCUMAN": "Tucumán",
}

# Province type classification for csMCA
PROVINCE_TYPE = {
    "CABA": "metropolitan",
    "Buenos Aires": "metropolitan",
    "Córdoba": "metropolitan",
    "Santa Fe": "metropolitan",
    "Mendoza": "intermediate",
    "Tucumán": "intermediate",
    "Salta": "intermediate",
    "Entre Ríos": "intermediate",
    "San Juan": "intermediate",
    "San Luis": "intermediate",
    "Neuquén": "intermediate",
    "Río Negro": "intermediate",
    "Chubut": "intermediate",
    "La Pampa": "intermediate",
    "Tierra del Fuego": "intermediate",
    "Santa Cruz": "intermediate",
    "Misiones": "peripheral",
    "Formosa": "peripheral",
    "Chaco": "peripheral",
    "Corrientes": "peripheral",
    "Santiago del Estero": "peripheral",
    "Jujuy": "peripheral",
    "Catamarca": "peripheral",
    "La Rioja": "peripheral",
}


# ═════════════════════════════════════════════════════════════════════════════
# Main pipeline
# ═════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("00 — Build national organisational dataset")
    print("=" * 70)

    # ── Step 1: Load ─────────────────────────────────────────────────────
    print("\n[1/6] Loading registry...", flush=True)
    cols = [
        "cuit", "razon_social", "fecha_hora_contrato_social",
        "tipo_societario", "dom_fiscal_provincia",
        "actividad_codigo", "actividad_descripcion",
        "actividad_estado", "actividad_orden",
    ]
    df = pd.read_csv(REGISTRY, usecols=cols, low_memory=False)
    print(f"  Raw rows: {len(df):,}")
    print(f"  Unique CUITs: {df['cuit'].nunique():,}")

    # ── Step 2: Derive estado per CUIT ───────────────────────────────────
    print("\n[2/6] Deriving estado per CUIT...", flush=True)
    # A CUIT is AC if ANY of its activities is AC; BD only if ALL are BD
    cuit_estado = (
        df.groupby("cuit")["actividad_estado"]
        .apply(lambda x: "AC" if "AC" in x.values else "BD")
        .reset_index()
        .rename(columns={"actividad_estado": "estado"})
    )
    print(f"  AC: {(cuit_estado['estado'] == 'AC').sum():,}")
    print(f"  BD: {(cuit_estado['estado'] == 'BD').sum():,}")

    # ── Step 3: Deduplicate by CUIT ──────────────────────────────────────
    print("\n[3/6] Deduplicating by CUIT...", flush=True)
    # Keep the row with actividad_orden closest to 1 and estado=AC
    df = df.sort_values(["cuit", "actividad_estado", "actividad_orden"])
    # Prefer AC rows, then lowest actividad_orden
    df["_ac_rank"] = df["actividad_estado"].map({"AC": 0, "BD": 1}).fillna(2)
    df = df.sort_values(["cuit", "_ac_rank", "actividad_orden"])
    df = df.drop_duplicates(subset="cuit", keep="first")
    df = df.drop(columns=["_ac_rank", "actividad_orden"])

    # Merge the derived estado (overrides per-row estado)
    df = df.drop(columns=["actividad_estado"])
    df = df.merge(cuit_estado, on="cuit", how="left")
    print(f"  Deduplicated: {len(df):,} unique organisations")

    # ── Step 4: Classify ─────────────────────────────────────────────────
    print("\n[4/6] Classifying...", flush=True)

    # Province
    df["provincia"] = df["dom_fiscal_provincia"].map(PROVINCE_NORM)
    unmapped_prov = df["provincia"].isna().sum()
    if unmapped_prov > 0:
        print(f"  WARNING: {unmapped_prov} orgs with unmapped province")
        print(f"    {df[df['provincia'].isna()]['dom_fiscal_provincia'].value_counts().head()}")
    df = df.dropna(subset=["provincia"])

    # Province type
    df["prov_type"] = df["provincia"].map(PROVINCE_TYPE)

    # Tipo
    df["tipo"] = df["tipo_societario"].map(classify_tipo)
    print(f"  Tipo distribution:")
    for t, n in df["tipo"].value_counts().items():
        print(f"    {t:8s}: {n:>9,} ({n / len(df) * 100:5.1f}%)")

    # Subtipo
    df["subtipo"] = df["razon_social"].map(classify_subtipo)
    n_classified = (df["subtipo"] != "other").sum()
    print(f"  Subtipo classified: {n_classified:,} / {len(df):,} ({n_classified / len(df) * 100:.1f}%)")

    # Era
    df["fecha"] = pd.to_datetime(df["fecha_hora_contrato_social"], errors="coerce")
    df["year"] = df["fecha"].dt.year
    df["era"] = df["year"].map(political_era)
    n_unknown_era = (df["era"] == "unknown").sum()
    print(f"  Unknown era: {n_unknown_era:,}")

    # CLAE
    df["clae6"] = pd.to_numeric(df["actividad_codigo"], errors="coerce")
    df["clae2"] = (df["clae6"] // 10000).astype("Int64")

    # ── Step 5: Filter and merge rare categories ─────────────────────────
    print("\n[5/6] Filtering and merging rare categories...", flush=True)

    # Exclude unknown era
    n_before = len(df)
    df = df[df["era"] != "unknown"]
    print(f"  Excluded unknown era: {n_before - len(df):,}")

    # Merge rare subtipo (<30 obs)
    sub_counts = df["subtipo"].value_counts()
    rare_sub = sub_counts[sub_counts < 30].index
    if len(rare_sub) > 0:
        df.loc[df["subtipo"].isin(rare_sub), "subtipo"] = "other"
        print(f"  Merged rare subtipos: {list(rare_sub)}")

    # Merge rare tipo (<30 obs)
    tipo_counts = df["tipo"].value_counts()
    rare_tipo = tipo_counts[tipo_counts < 30].index
    if len(rare_tipo) > 0:
        df.loc[df["tipo"].isin(rare_tipo), "tipo"] = "Otra"
        print(f"  Merged rare tipos: {list(rare_tipo)}")

    # ── Step 6: Select output columns and save ───────────────────────────
    print("\n[6/6] Saving...", flush=True)

    out = df[[
        "cuit", "razon_social", "tipo", "subtipo", "era", "estado",
        "provincia", "prov_type", "clae2", "clae6", "year",
    ]].copy()

    out.to_parquet(DATA_DIR / "national_orgs_clean.parquet", index=False)

    # Summary stats
    print(f"\n{'=' * 70}")
    print(f"OUTPUT: {DATA_DIR / 'national_orgs_clean.parquet'}")
    print(f"  N = {len(out):,} organisations")
    print(f"  Provinces: {out['provincia'].nunique()}")
    print(f"  Province types: {out['prov_type'].value_counts().to_dict()}")
    print(f"  Eras: {out['era'].nunique()}")
    print(f"  Tipos: {out['tipo'].nunique()}")
    print(f"  AC: {(out['estado'] == 'AC').sum():,}  BD: {(out['estado'] == 'BD').sum():,}")

    # Quick diagnostic tables
    print(f"\n--- Tipo × Era (creation counts) ---")
    ct = pd.crosstab(out["era"], out["tipo"])
    era_order = ["pre1990", "menem", "crisis", "n_kirchner", "c_kirchner", "macri", "fernandez", "milei"]
    ct = ct.reindex([e for e in era_order if e in ct.index])
    print(ct.to_string())

    print(f"\n--- Tipo × Province type (%) ---")
    ct2 = pd.crosstab(out["prov_type"], out["tipo"], normalize="index") * 100
    print(ct2.round(1).to_string())

    # Save diagnostic tables
    ct.to_csv(TAB_DIR / "tab_tipo_era_counts.csv")
    ct2.round(1).to_csv(TAB_DIR / "tab_tipo_provtype_pct.csv")

    print(f"\n{'=' * 70}")
    print("DONE")


if __name__ == "__main__":
    main()
