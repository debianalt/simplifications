"""
04 — Supplementary provincial variables
========================================
Project: Differential Institutional Simplification (2026_12)

Stage 4: Merge organisational diversity metrics with provincial economic
context from BCRA (financial access), CEP (employment), MAGYP (agriculture),
and Census 2022 (labour market).

Input:
    tables/tab_shannon_by_province_era.csv
    tables/tab_theil_province_details.csv
    tables/tab_shift_share.csv
    External: BCRA xlsx, CEP csv, MAGYP csv, Census csv

Output:
    data/provincial_context.parquet
    tables/tab_provincial_context.csv
    tables/tab_correlation_matrix.csv
    figures/fig_scatter_context.png

Usage:
    python 04_supplementary_provincial.py
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

PROJECT = Path(__file__).parent
DATA_DIR = PROJECT / "data"
FIG_DIR = PROJECT / "figures"
TAB_DIR = PROJECT / "tables"

# External data paths
GEE_DIR = Path("C:/Users/ant/OneDrive/gee")
BCRA_DIR = GEE_DIR / "bcra" / "bcra_data"
CEP_PATH = GEE_DIR / "bcra" / "data" / "cep_puestos_depto_clae2.csv"
MAGYP_PATH = GEE_DIR / "bcra" / "data" / "magyp_estimaciones_depto.csv"
CENSO_DIR = Path("C:/Users/ant/OneDrive/articles_2_/2026_3_TS_sent/data/censo")

# ═════════════════════════════════════════════════════════════════════════════
# Province name mappings
# ═════════════════════════════════════════════════════════════════════════════

PROV_TYPE = {
    "Buenos Aires": "metropolitan", "CABA": "metropolitan",
    "Córdoba": "metropolitan", "Santa Fe": "metropolitan",
    "Mendoza": "intermediate", "Tucumán": "intermediate",
    "Salta": "intermediate", "Entre Ríos": "intermediate",
    "San Juan": "intermediate", "San Luis": "intermediate",
    "Neuquén": "intermediate", "Río Negro": "intermediate",
    "Chubut": "intermediate", "La Pampa": "intermediate",
    "Tierra del Fuego": "intermediate", "Santa Cruz": "intermediate",
    "Misiones": "peripheral", "Formosa": "peripheral",
    "Chaco": "peripheral", "Corrientes": "peripheral",
    "Santiago del Estero": "peripheral", "Jujuy": "peripheral",
    "Catamarca": "peripheral", "La Rioja": "peripheral",
}

PROV_TYPE_COLORS = {
    "metropolitan": "#e41a1c",
    "intermediate": "#377eb8",
    "peripheral": "#4daf4a",
}

# BCRA uses these province names
BCRA_TO_STD = {
    "Buenos Aires": "Buenos Aires", "Capital Federal": "CABA",
    "CABA": "CABA",
    "Catamarca": "Catamarca", "Chaco": "Chaco", "Chubut": "Chubut",
    "Cordoba": "Córdoba", "Córdoba": "Córdoba",
    "Corrientes": "Corrientes", "Entre Rios": "Entre Ríos",
    "Entre Ríos": "Entre Ríos",
    "Formosa": "Formosa", "Jujuy": "Jujuy", "La Pampa": "La Pampa",
    "La Rioja": "La Rioja", "Mendoza": "Mendoza", "Misiones": "Misiones",
    "Neuquen": "Neuquén", "Neuquén": "Neuquén",
    "Rio Negro": "Río Negro", "Río Negro": "Río Negro",
    "Salta": "Salta", "San Juan": "San Juan", "San Luis": "San Luis",
    "Santa Cruz": "Santa Cruz", "Santa Fe": "Santa Fe",
    "Santiago del Estero": "Santiago del Estero",
    "Tierra del Fuego": "Tierra del Fuego",
    "Tierra del Fuego, Antartida e Islas del Atlantico Sur": "Tierra del Fuego",
    "Tucuman": "Tucumán", "Tucumán": "Tucumán",
}

# INDEC province codes
INDEC_TO_STD = {
    2: "CABA", 6: "Buenos Aires", 10: "Catamarca", 14: "Córdoba",
    18: "Corrientes", 22: "Chaco", 26: "Chubut", 30: "Entre Ríos",
    34: "Formosa", 38: "Jujuy", 42: "La Pampa", 46: "La Rioja",
    50: "Mendoza", 54: "Misiones", 58: "Neuquén", 62: "Río Negro",
    66: "Salta", 70: "San Juan", 74: "San Luis", 78: "Santa Cruz",
    82: "Santa Fe", 86: "Santiago del Estero", 90: "Tucumán",
    94: "Tierra del Fuego",
}

# MAGYP province names (no accents)
MAGYP_TO_STD = {
    "Buenos Aires": "Buenos Aires", "Catamarca": "Catamarca",
    "Chaco": "Chaco", "Chubut": "Chubut", "Cordoba": "Córdoba",
    "Córdoba": "Córdoba", "Corrientes": "Corrientes",
    "Entre Rios": "Entre Ríos", "Entre Ríos": "Entre Ríos",
    "Formosa": "Formosa", "Jujuy": "Jujuy", "La Pampa": "La Pampa",
    "La Rioja": "La Rioja", "Mendoza": "Mendoza", "Misiones": "Misiones",
    "Neuquen": "Neuquén", "Neuquén": "Neuquén",
    "Rio Negro": "Río Negro", "Río Negro": "Río Negro",
    "Salta": "Salta", "San Juan": "San Juan", "San Luis": "San Luis",
    "Santa Cruz": "Santa Cruz", "Santa Fe": "Santa Fe",
    "Santiago del Estero": "Santiago del Estero",
    "Tierra del Fuego": "Tierra del Fuego",
    "Tucuman": "Tucumán", "Tucumán": "Tucumán",
}


def _standardise_bcra(name):
    """Standardise BCRA province name, stripping whitespace."""
    name = str(name).strip()
    return BCRA_TO_STD.get(name, name)


def _standardise_magyp(name):
    name = str(name).strip()
    return MAGYP_TO_STD.get(name, name)


# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("04 — Supplementary provincial variables")
    print("=" * 70)

    # ── [1/8] Load diversity metrics ────────────────────────────────────
    print("\n[1/8] Loading organisational diversity metrics...", flush=True)

    shannon = pd.read_csv(TAB_DIR / "tab_shannon_by_province_era.csv")
    shannon_milei = shannon[shannon["era"] == "milei"][
        ["provincia", "n", "shannon_H", "evenness"]
    ].rename(columns={"n": "n_orgs_milei", "shannon_H": "shannon_H_milei",
                       "evenness": "evenness_milei"})

    theil = pd.read_csv(TAB_DIR / "tab_theil_province_details.csv")
    theil = theil.rename(columns={"group": "provincia"})[
        ["provincia", "between_contrib", "within_T", "shannon_H", "dominant_tipo", "dominant_pct"]
    ].rename(columns={"shannon_H": "shannon_H_total", "between_contrib": "theil_between_contrib"})

    shift = pd.read_csv(TAB_DIR / "tab_shift_share.csv")
    shift = shift[["provincia", "provincial_diff", "sas_share_milei", "coop_share_milei"]]

    # Merge diversity metrics
    div = shannon_milei.merge(theil, on="provincia", how="outer")
    div = div.merge(shift, on="provincia", how="outer")
    print(f"  Diversity metrics: {len(div)} provinces")

    # ── [2/8] BCRA PDA (financial access points) ───────────────────────
    print("\n[2/8] Parsing BCRA financial access points...", flush=True)

    pda_raw = pd.read_excel(BCRA_DIR / "1-1-2.xlsx", sheet_name="1.1.2",
                            header=None, skiprows=4)
    # Column 1 = PDA type, Column 2 = Province, Columns 3+ = monthly values
    pda_raw.columns = ["idx", "tipo_pda", "provincia"] + list(range(pda_raw.shape[1] - 3))

    # Filter to actual data rows (tipo_pda is not NaN)
    pda_raw = pda_raw.dropna(subset=["tipo_pda"])
    # Remove "Total" rows and keep only known provinces
    pda_raw = pda_raw[pda_raw["provincia"].notna()]
    pda_raw["provincia"] = pda_raw["provincia"].apply(_standardise_bcra)
    pda_raw = pda_raw[pda_raw["provincia"].isin(PROV_TYPE.keys())]

    # Get last column with data
    date_cols = [c for c in pda_raw.columns if isinstance(c, int)]
    last_col = max(date_cols)

    # Sum all PDA types per province (latest month)
    pda_total = pda_raw.groupby("provincia")[last_col].sum().reset_index()
    pda_total.columns = ["provincia", "pda_total"]

    # Also get breakdown by type
    pda_by_type = pda_raw.pivot_table(index="provincia", columns="tipo_pda",
                                       values=last_col, aggfunc="sum").reset_index()
    print(f"  PDA provinces: {len(pda_total)}, PDA types: {pda_raw['tipo_pda'].nunique()}")

    # ── [3/8] BCRA account holdings ────────────────────────────────────
    print("\n[3/8] Parsing BCRA account holdings...", flush=True)

    acct_raw = pd.read_excel(BCRA_DIR / "2-1-4.xlsx", sheet_name="2.1.4.",
                             header=None, skiprows=4)
    # Column 1 = account type, Column 2 = Province, Columns 3+ = quarterly values
    acct_raw.columns = ["idx", "tipo_cuenta", "provincia"] + list(range(acct_raw.shape[1] - 3))
    acct_raw = acct_raw.dropna(subset=["tipo_cuenta"])
    acct_raw = acct_raw[acct_raw["provincia"].notna()]
    acct_raw["provincia"] = acct_raw["provincia"].apply(_standardise_bcra)
    acct_raw = acct_raw[acct_raw["provincia"].isin(PROV_TYPE.keys())]

    # Filter specifically "Al menos una cuenta / At least one account" (broadest)
    acct_mask = acct_raw["tipo_cuenta"].astype(str).str.contains(
        r"Al menos una cuenta /|At least one account$", case=False, na=False, regex=True)
    acct_latest = acct_raw[acct_mask].copy()

    date_cols_a = [c for c in acct_latest.columns if isinstance(c, int)]
    last_col_a = max(date_cols_a)

    acct_prov = acct_latest[["provincia", last_col_a]].copy()
    acct_prov.columns = ["provincia", "pct_with_account"]
    acct_prov["pct_with_account"] = pd.to_numeric(acct_prov["pct_with_account"], errors="coerce")
    print(f"  Account data: {len(acct_prov)} provinces")

    # ── [4/8] BCRA borrowers ──────────────────────────────────────────
    print("\n[4/8] Parsing BCRA borrowers...", flush=True)

    borr_raw = pd.read_excel(BCRA_DIR / "4-1-3.xlsx", sheet_name="4.1.3",
                             header=None, skiprows=4)
    borr_raw.columns = ["idx", "provincia"] + list(range(borr_raw.shape[1] - 2))
    borr_raw = borr_raw.dropna(subset=["provincia"])
    borr_raw["provincia"] = borr_raw["provincia"].apply(_standardise_bcra)
    borr_raw = borr_raw[borr_raw["provincia"].isin(PROV_TYPE.keys())]

    date_cols_b = [c for c in borr_raw.columns if isinstance(c, int)]
    last_col_b = max(date_cols_b)

    borr_prov = borr_raw[["provincia", last_col_b]].copy()
    borr_prov.columns = ["provincia", "pct_borrowers"]
    borr_prov["pct_borrowers"] = pd.to_numeric(borr_prov["pct_borrowers"], errors="coerce")
    print(f"  Borrower data: {len(borr_prov)} provinces")

    # ── [5/8] CEP employment concentration ─────────────────────────────
    print("\n[5/8] Loading CEP employment data...", flush=True)

    cep = pd.read_csv(CEP_PATH, dtype={"puestos": "Int32", "clae2": "Int16",
                                        "id_provincia_indec": "Int16"})
    # Latest date
    cep["fecha"] = pd.to_datetime(cep["fecha"])
    latest_fecha = cep["fecha"].max()
    print(f"  CEP latest date: {latest_fecha.date()}")

    cep_latest = cep[cep["fecha"] == latest_fecha].copy()
    cep_latest = cep_latest[cep_latest["puestos"] > 0]  # drop suppressed (-99)

    # Aggregate to province x sector
    cep_prov = cep_latest.groupby(["id_provincia_indec", "clae2"])["puestos"].sum().reset_index()

    # Compute HHI per province
    cep_totals = cep_prov.groupby("id_provincia_indec")["puestos"].sum().reset_index()
    cep_totals.columns = ["id_provincia_indec", "puestos_total"]

    cep_prov = cep_prov.merge(cep_totals, on="id_provincia_indec")
    cep_prov["share"] = cep_prov["puestos"] / cep_prov["puestos_total"]
    cep_prov["share_sq"] = cep_prov["share"] ** 2

    hhi = cep_prov.groupby("id_provincia_indec").agg(
        hhi_empleo=("share_sq", "sum"),
        n_sectors=("clae2", "nunique"),
    ).reset_index()
    hhi = hhi.merge(cep_totals, on="id_provincia_indec")

    # Map to province names
    hhi["provincia"] = hhi["id_provincia_indec"].map(INDEC_TO_STD)
    hhi = hhi[["provincia", "hhi_empleo", "n_sectors", "puestos_total"]]
    print(f"  CEP provinces: {len(hhi)}")

    # ── [6/8] MAGYP agricultural intensity ─────────────────────────────
    print("\n[6/8] Loading MAGYP agricultural data...", flush=True)

    magyp = pd.read_csv(MAGYP_PATH)
    # Latest complete campaign
    campaigns = sorted(magyp["campania"].dropna().unique())
    latest_camp = campaigns[-1]
    print(f"  MAGYP latest campaign: {latest_camp}")

    magyp_latest = magyp[magyp["campania"] == latest_camp].copy()
    magyp_latest["provincia"] = magyp_latest["provincia"].apply(_standardise_magyp)

    # Aggregate to province
    agro_prov = magyp_latest.groupby("provincia").agg(
        sown_ha=("superficie_sembrada_ha", "sum"),
        prod_tm=("produccion_tm", "sum"),
        n_cultivos=("cultivo", "nunique"),
    ).reset_index()

    # Crop concentration (HHI on sown area)
    crop_shares = magyp_latest.groupby(["provincia", "cultivo"])["superficie_sembrada_ha"].sum().reset_index()
    crop_totals = crop_shares.groupby("provincia")["superficie_sembrada_ha"].sum().reset_index()
    crop_totals.columns = ["provincia", "total_sown"]
    crop_shares = crop_shares.merge(crop_totals, on="provincia")
    crop_shares["share"] = crop_shares["superficie_sembrada_ha"] / crop_shares["total_sown"]
    crop_shares["share_sq"] = crop_shares["share"] ** 2
    agro_hhi = crop_shares.groupby("provincia")["share_sq"].sum().reset_index()
    agro_hhi.columns = ["provincia", "agro_hhi"]

    agro_prov = agro_prov.merge(agro_hhi, on="provincia", how="left")
    print(f"  MAGYP provinces: {len(agro_prov)}")

    # ── [7/8] Census 2022 employment ──────────────────────────────────
    print("\n[7/8] Loading Census 2022 employment data...", flush=True)

    censo = pd.read_csv(CENSO_DIR / "censo_empleo_depto.csv")
    censo = censo.dropna(subset=["dpto5"])
    # Extract province ID from department code (first 2 digits of 5-digit code)
    censo["prov_id"] = (censo["dpto5"] // 1000).astype(int)

    # Aggregate to province
    censo_prov = censo.groupby("prov_id").agg(
        ocupados=("c22_ocupados", "sum"),
        desocupados=("c22_desocupados", "sum"),
        activos=("c22_activos", "sum"),
        pob_empleo=("c22_pob_empleo", "sum"),
    ).reset_index()

    censo_prov["tasa_empleo"] = censo_prov["ocupados"] / censo_prov["pob_empleo"]
    censo_prov["tasa_desocupacion"] = censo_prov["desocupados"] / censo_prov["activos"]
    censo_prov["provincia"] = censo_prov["prov_id"].map(INDEC_TO_STD)
    censo_prov = censo_prov[["provincia", "pob_empleo", "tasa_empleo", "tasa_desocupacion"]]
    print(f"  Census provinces: {len(censo_prov)}")

    # ── [8/8] Merge all and output ─────────────────────────────────────
    print("\n[8/8] Merging all variables...", flush=True)

    ctx = div.copy()
    ctx = ctx.merge(pda_total, on="provincia", how="left")
    ctx = ctx.merge(acct_prov, on="provincia", how="left")
    ctx = ctx.merge(borr_prov, on="provincia", how="left")
    ctx = ctx.merge(hhi, on="provincia", how="left")
    ctx = ctx.merge(agro_prov, on="provincia", how="left")
    ctx = ctx.merge(censo_prov, on="provincia", how="left")

    # Derived: PDA per 100k population
    ctx["pda_per_100k"] = ctx["pda_total"] / ctx["pob_empleo"] * 100_000

    # Province type
    ctx["prov_type"] = ctx["provincia"].map(PROV_TYPE)

    # Sort by shannon_H_milei
    ctx = ctx.sort_values("shannon_H_milei", ascending=False).reset_index(drop=True)

    # Save
    ctx.to_parquet(DATA_DIR / "provincial_context.parquet", index=False)
    ctx.to_csv(TAB_DIR / "tab_provincial_context.csv", index=False)
    print(f"  Saved: {len(ctx)} provinces x {len(ctx.columns)} variables")

    # Correlation matrix (numeric columns only)
    num_cols = ["shannon_H_milei", "evenness_milei", "sas_share_milei", "coop_share_milei",
                "provincial_diff", "pda_per_100k", "pct_with_account", "pct_borrowers",
                "hhi_empleo", "puestos_total", "agro_hhi", "sown_ha",
                "tasa_empleo", "tasa_desocupacion"]
    num_cols = [c for c in num_cols if c in ctx.columns]
    corr = ctx[num_cols].corr()
    corr.to_csv(TAB_DIR / "tab_correlation_matrix.csv")
    print(f"  Saved: correlation matrix ({len(num_cols)} variables)")

    # ── Scatter plots (2x2) ─────────────────────────────────────────
    print("  Generating scatter plots...", flush=True)

    fig, axes = plt.subplots(2, 2, figsize=(11, 10))

    scatter_specs = [
        ("pda_per_100k", "shannon_H_milei",
         "Financial access (PDA per 100k)", "Shannon H (Milei era)"),
        ("hhi_empleo", "shannon_H_milei",
         "Employment concentration (HHI)", "Shannon H (Milei era)"),
        ("pct_with_account", "sas_share_milei",
         "% adults with bank account", "SAS share (Milei era)"),
        ("pda_per_100k", "provincial_diff",
         "Financial access (PDA per 100k)", "Provincial differential (shift-share)"),
    ]

    for ax, (xvar, yvar, xlabel, ylabel) in zip(axes.flat, scatter_specs):
        for pt in ["metropolitan", "intermediate", "peripheral"]:
            mask = ctx["prov_type"] == pt
            ax.scatter(ctx.loc[mask, xvar], ctx.loc[mask, yvar],
                       c=PROV_TYPE_COLORS[pt], s=50, alpha=0.8,
                       label=pt.capitalize(), edgecolors="white", linewidth=0.5)

        # Annotate provinces
        for _, row in ctx.iterrows():
            x_val = row[xvar]
            y_val = row[yvar]
            if pd.notna(x_val) and pd.notna(y_val):
                label = row["provincia"]
                if label == "Buenos Aires":
                    label = "BA"
                elif label == "Santiago del Estero":
                    label = "SdE"
                elif label == "Tierra del Fuego":
                    label = "TdF"
                ax.annotate(label, (x_val, y_val), fontsize=5.5,
                            ha="left", va="bottom",
                            xytext=(3, 2), textcoords="offset points")

        ax.set_xlabel(xlabel, fontsize=9)
        ax.set_ylabel(ylabel, fontsize=9)

    axes[0, 0].legend(fontsize=8, loc="best")
    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_scatter_context.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved: figures/fig_scatter_context.png")

    # ── Summary ──────────────────────────────────────────────────────
    print(f"\n{'=' * 70}")
    print("Provincial context — key statistics:")
    print(f"  Shannon H (Milei): {ctx['shannon_H_milei'].min():.2f} – {ctx['shannon_H_milei'].max():.2f}")
    print(f"  PDA per 100k:      {ctx['pda_per_100k'].min():.0f} – {ctx['pda_per_100k'].max():.0f}")
    print(f"  HHI employment:    {ctx['hhi_empleo'].min():.3f} – {ctx['hhi_empleo'].max():.3f}")
    print(f"  % with account:    {ctx['pct_with_account'].min():.1f}% – {ctx['pct_with_account'].max():.1f}%")

    # Key correlations
    print(f"\nKey correlations with Shannon H (Milei):")
    for var in ["pda_per_100k", "pct_with_account", "pct_borrowers",
                "hhi_empleo", "tasa_empleo", "agro_hhi"]:
        if var in ctx.columns:
            r = ctx["shannon_H_milei"].corr(ctx[var])
            print(f"  {var:25s}: r = {r:+.3f}")

    print(f"\n{'=' * 70}")
    print("DONE")


if __name__ == "__main__":
    main()
