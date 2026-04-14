"""
03 — Shift-share analysis of organisational change
====================================================
Project: Differential Institutional Simplification (2026_12)

Decomposes the change in organisational composition between a reference
period (pre-SAS: up to C. Kirchner, 2003-2015) and a comparison period
(Milei: 2024-2025) into three components per province:

  - National effect (NS): change due to the national trend
  - Structural mix (IM): change due to pre-existing provincial composition
  - Provincial differential (RS): idiosyncratic provincial effect

Input:  data/national_orgs_clean.parquet
Output:
    tables/tab_shift_share.csv
    figures/fig_shift_share.png  (Fig 5)

Usage:
    python 03_shift_share.py
"""

import warnings
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")

PROJECT = Path(__file__).parent
DATA_DIR = PROJECT / "data"
FIG_DIR = PROJECT / "figures"
TAB_DIR = PROJECT / "tables"


# ═════════════════════════════════════════════════════════════════════════════
# Shift-share decomposition
# ═════════════════════════════════════════════════════════════════════════════

def shift_share_composition(df, ref_eras, comp_eras, group_col="provincia", type_col="tipo"):
    """
    Classical shift-share adapted for organisational composition.

    For each province j and organisational type k:
      - e_jk_0 = share of type k in province j during reference period
      - e_jk_1 = share of type k in province j during comparison period
      - E_k_0 = national share of type k in reference period
      - E_k_1 = national share of type k in comparison period

    Decomposition of total change in province j's diversity:
      delta_j = sum_k (e_jk_1 - e_jk_0)^2 ... but more usefully:

    For each province j and type k:
      NS_jk = e_jk_0 * (G - 1)           [national growth effect]
      IM_jk = e_jk_0 * (G_k - G)         [industry/structural mix]
      RS_jk = e_jk_0 * (g_jk - G_k)      [regional shift/differential]

    where G = national total growth rate, G_k = national growth rate of type k,
    g_jk = provincial growth rate of type k in province j.

    We adapt this to creation rates (orgs per year) rather than levels.
    """
    # Reference and comparison periods
    ref = df[df["era"].isin(ref_eras)]
    comp = df[df["era"].isin(comp_eras)]

    # Duration (years) for annualisation
    ref_years = ref["year"].nunique()
    comp_years = comp["year"].nunique()
    if ref_years == 0 or comp_years == 0:
        raise ValueError("Empty period")

    # National creation rates per type
    nat_ref = ref[type_col].value_counts() / ref_years
    nat_comp = comp[type_col].value_counts() / comp_years
    all_types = sorted(set(nat_ref.index) | set(nat_comp.index))

    # National total growth rate
    G_total_ref = len(ref) / ref_years
    G_total_comp = len(comp) / comp_years
    G = G_total_comp / G_total_ref if G_total_ref > 0 else 0

    # National growth rate per type
    G_k = {}
    for k in all_types:
        r = nat_ref.get(k, 0)
        c = nat_comp.get(k, 0)
        G_k[k] = c / r if r > 0 else (10 if c > 0 else 0)

    results = []
    for prov in df[group_col].unique():
        prov_ref = ref[ref[group_col] == prov]
        prov_comp = comp[comp[group_col] == prov]

        prov_ref_rate = prov_ref[type_col].value_counts() / ref_years
        prov_comp_rate = prov_comp[type_col].value_counts() / comp_years

        NS_j = 0
        IM_j = 0
        RS_j = 0
        total_ref_rate = prov_ref_rate.sum()

        for k in all_types:
            e_jk_0 = prov_ref_rate.get(k, 0)
            e_jk_1 = prov_comp_rate.get(k, 0)

            # Provincial growth rate for type k
            g_jk = e_jk_1 / e_jk_0 if e_jk_0 > 0 else (10 if e_jk_1 > 0 else 0)

            NS_jk = e_jk_0 * (G - 1)
            IM_jk = e_jk_0 * (G_k.get(k, 0) - G)
            RS_jk = e_jk_0 * (g_jk - G_k.get(k, 0))

            NS_j += NS_jk
            IM_j += IM_jk
            RS_j += RS_jk

        actual_change = prov_comp_rate.sum() - prov_ref_rate.sum()

        results.append({
            "provincia": prov,
            "ref_rate": total_ref_rate,
            "comp_rate": prov_comp_rate.sum(),
            "actual_change": actual_change,
            "national_effect": NS_j,
            "structural_mix": IM_j,
            "provincial_diff": RS_j,
            "decomposed_total": NS_j + IM_j + RS_j,
            # Shares under Milei for context
            "sas_share_milei": (prov_comp[prov_comp[type_col] == "SAS"].shape[0]
                                / len(prov_comp) * 100 if len(prov_comp) > 0 else 0),
            "coop_share_milei": (prov_comp[prov_comp[type_col] == "Coop"].shape[0]
                                 / len(prov_comp) * 100 if len(prov_comp) > 0 else 0),
        })

    return pd.DataFrame(results).sort_values("provincial_diff")


# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("03 -- Shift-share analysis of organisational change")
    print("=" * 70)

    df = pd.read_parquet(DATA_DIR / "national_orgs_clean.parquet")
    print(f"  N = {len(df):,}")

    # Reference: Kirchnerism (2003-2015) — peak cooperative era
    # Comparison: Milei (2024-2025) — SAS dominance
    ref_eras = ["n_kirchner", "c_kirchner"]
    comp_eras = ["milei"]

    print(f"\n  Reference period: {ref_eras}")
    print(f"  Comparison period: {comp_eras}")

    ss = shift_share_composition(df, ref_eras, comp_eras)
    ss.to_csv(TAB_DIR / "tab_shift_share.csv", index=False)

    print(f"\n{'Provincia':>25s}  {'NS':>8s}  {'IM':>8s}  {'RS':>8s}  {'SAS%':>5s}  {'Coop%':>5s}")
    print("-" * 70)
    for _, row in ss.iterrows():
        print(f"{row['provincia']:>25s}  "
              f"{row['national_effect']:>8.1f}  "
              f"{row['structural_mix']:>8.1f}  "
              f"{row['provincial_diff']:>8.1f}  "
              f"{row['sas_share_milei']:>5.1f}  "
              f"{row['coop_share_milei']:>5.1f}")

    # ── Fig 5: Shift-share decomposition ─────────────────────────────────
    print("\n  Generating Fig 5...", flush=True)

    # Sort by provincial differential (most negative = most loss)
    ss_plot = ss.sort_values("provincial_diff")

    fig, ax = plt.subplots(figsize=(10, 8))

    y = range(len(ss_plot))
    provinces = ss_plot["provincia"].values

    # Stacked horizontal bars
    ax.barh(y, ss_plot["national_effect"], height=0.7,
            color="#999999", alpha=0.8, label="National effect")
    ax.barh(y, ss_plot["structural_mix"], height=0.7,
            left=ss_plot["national_effect"],
            color="#377eb8", alpha=0.8, label="Structural mix")
    ax.barh(y, ss_plot["provincial_diff"], height=0.7,
            left=ss_plot["national_effect"] + ss_plot["structural_mix"],
            color="#e41a1c", alpha=0.8, label="Provincial differential")

    ax.set_yticks(list(y))
    ax.set_yticklabels(provinces, fontsize=8)
    ax.set_xlabel("Change in creation rate (orgs/year)", fontsize=10)
    ax.set_title("Shift-share decomposition of organisational change\n"
                 "Reference: Kirchnerism (2003-2015) vs Milei (2024-2025)",
                 fontsize=10)
    ax.axvline(0, color="black", lw=0.8)
    ax.legend(loc="lower right", fontsize=8)
    ax.grid(axis="x", alpha=0.3)

    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_shift_share.png", dpi=300)
    plt.close(fig)
    print(f"  Saved: figures/fig_shift_share.png")

    # ── Kirchnerism -> Fernandez shift-share ───────────────────────────
    print("\n  Additional: Kirchnerism -> Fernandez shift-share...", flush=True)
    ss_kf = shift_share_composition(df, ref_eras, ["fernandez"])
    ss_kf.to_csv(TAB_DIR / "tab_shift_share_kirchner_fernandez.csv", index=False)
    print(f"  Saved: tables/tab_shift_share_kirchner_fernandez.csv")

    # ── Also: shift-share between Fernandez and Milei ────────────────────
    print("\n  Additional: Fernandez -> Milei shift-share...", flush=True)
    ss2 = shift_share_composition(df, ["fernandez"], ["milei"])
    ss2.to_csv(TAB_DIR / "tab_shift_share_fernandez_milei.csv", index=False)
    print(f"  Saved: tables/tab_shift_share_fernandez_milei.csv")

    print(f"\n{'=' * 70}")
    print("DONE")


if __name__ == "__main__":
    main()
