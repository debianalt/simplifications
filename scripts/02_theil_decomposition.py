"""
02 — Theil decomposition of organisational diversity
=====================================================
Project: Differential Institutional Simplification (2026_12)

Computes:
  - Shannon H per province x era
  - Theil T index of organisational diversity (across tipo categories)
  - Decomposes national Theil into between-province and within-province
  - Tracks decomposition across 8 political eras
  - Choropleth map of provincial diversity under Milei

Input:  data/national_orgs_clean.parquet
Output:
    tables/tab_theil_decomposition.csv
    tables/tab_shannon_by_province_era.csv
    figures/fig_theil_temporal.png  (Fig 3)
    figures/fig_shannon_map.png    (Fig 4)

Usage:
    python 02_theil_decomposition.py
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

ERA_ORDER = ["pre1990", "menem", "crisis", "n_kirchner", "c_kirchner", "macri", "fernandez", "milei"]
ERA_LABELS = {
    "pre1990": "Pre-1990", "menem": "Menem", "crisis": "Crisis",
    "n_kirchner": "N. Kirchner", "c_kirchner": "C. Kirchner",
    "macri": "Macri", "fernandez": "Fernandez", "milei": "Milei",
}


# ═════════════════════════════════════════════════════════════════════════════
# Shannon H
# ═════════════════════════════════════════════════════════════════════════════

def shannon_h(counts):
    """Shannon diversity index (natural log) from a counts series."""
    total = counts.sum()
    if total == 0:
        return 0.0
    props = counts / total
    props = props[props > 0]
    return -(props * np.log(props)).sum()


def shannon_evenness(counts):
    """Shannon evenness = H / ln(S) where S = number of types."""
    S = (counts > 0).sum()
    if S <= 1:
        return 0.0
    H = shannon_h(counts)
    return H / np.log(S)


# ═════════════════════════════════════════════════════════════════════════════
# Theil T decomposition
# ═════════════════════════════════════════════════════════════════════════════

def theil_t_organisational(df, group_col="provincia", type_col="tipo"):
    """
    Theil T index for organisational diversity, decomposed into
    between-group and within-group components.

    The Theil T index here measures inequality in the distribution of
    organisational types across spatial units. Each province has a
    composition vector (shares of SRL, SA, SAS, Coop, etc.).

    The decomposition follows:
        T_total = T_between + T_within

    where:
        T_between = sum_j (n_j/N) * sum_k (s_jk * ln(s_jk / S_k))
        T_within  = sum_j (n_j/N) * T_j

    with s_jk = share of type k in group j, S_k = share of type k nationally,
    n_j = orgs in group j, N = total orgs.
    """
    # National composition
    N = len(df)
    national_counts = df[type_col].value_counts()
    S = national_counts / N  # national shares

    groups = df.groupby(group_col)
    T_between = 0.0
    T_within = 0.0
    group_details = []

    for name, grp in groups:
        n_j = len(grp)
        w_j = n_j / N  # weight

        local_counts = grp[type_col].value_counts()
        s_j = local_counts / n_j  # local shares

        # Between component contribution from this group
        b_j = 0.0
        for k in S.index:
            s_jk = s_j.get(k, 0.0)
            S_k = S[k]
            if s_jk > 0 and S_k > 0:
                b_j += s_jk * np.log(s_jk / S_k)

        T_between += w_j * b_j

        # Within component: Theil T of the group itself
        t_j = 0.0
        K = len(s_j)
        if K > 1:
            uniform = 1.0 / K
            for k_val in s_j.index:
                p = s_j[k_val]
                if p > 0:
                    t_j += p * np.log(p / uniform)
        T_within += w_j * t_j

        # Shannon for this group
        H_j = shannon_h(local_counts)

        group_details.append({
            "group": name, "n": n_j, "weight": w_j,
            "between_contrib": w_j * b_j,
            "within_T": t_j,
            "shannon_H": H_j,
            "dominant_tipo": local_counts.idxmax(),
            "dominant_pct": local_counts.max() / n_j * 100,
        })

    T_total = T_between + T_within

    return {
        "T_total": T_total,
        "T_between": T_between,
        "T_within": T_within,
        "pct_between": T_between / T_total * 100 if T_total > 0 else 0,
        "pct_within": T_within / T_total * 100 if T_total > 0 else 0,
        "details": pd.DataFrame(group_details),
    }


# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("02 -- Theil decomposition of organisational diversity")
    print("=" * 70)

    df = pd.read_parquet(DATA_DIR / "national_orgs_clean.parquet")
    print(f"  N = {len(df):,}")

    # ── Shannon H by province x era ──────────────────────────────────────
    print("\n[1/3] Shannon H by province x era...", flush=True)

    shannon_rows = []
    for era in ERA_ORDER:
        era_df = df[df["era"] == era]
        for prov in df["provincia"].unique():
            sub = era_df[era_df["provincia"] == prov]
            counts = sub["tipo"].value_counts()
            H = shannon_h(counts)
            E = shannon_evenness(counts)
            shannon_rows.append({
                "era": era, "provincia": prov,
                "n": len(sub), "shannon_H": H, "evenness": E,
                "n_types": (counts > 0).sum(),
            })

    shannon_df = pd.DataFrame(shannon_rows)
    shannon_df.to_csv(TAB_DIR / "tab_shannon_by_province_era.csv", index=False)

    # Pivot for display
    pivot = shannon_df.pivot(index="provincia", columns="era", values="shannon_H")
    pivot = pivot[[e for e in ERA_ORDER if e in pivot.columns]]
    print(pivot.round(2).to_string())

    # ── Theil decomposition by era ───────────────────────────────────────
    print("\n[2/3] Theil decomposition by era...", flush=True)

    theil_rows = []
    for era in ERA_ORDER:
        era_df = df[df["era"] == era]
        if len(era_df) < 10:
            continue
        result = theil_t_organisational(era_df, group_col="provincia", type_col="tipo")
        theil_rows.append({
            "era": era,
            "N": len(era_df),
            "T_total": result["T_total"],
            "T_between": result["T_between"],
            "T_within": result["T_within"],
            "pct_between": result["pct_between"],
            "pct_within": result["pct_within"],
        })
        print(f"  {ERA_LABELS.get(era, era):>14s}  N={len(era_df):>8,}  "
              f"T={result['T_total']:.4f}  "
              f"Between={result['pct_between']:.1f}%  "
              f"Within={result['pct_within']:.1f}%")

    theil_df = pd.DataFrame(theil_rows)
    theil_df.to_csv(TAB_DIR / "tab_theil_decomposition.csv", index=False)

    # Also: full-period decomposition
    print(f"\n  Full period:")
    full = theil_t_organisational(df, group_col="provincia", type_col="tipo")
    print(f"    T={full['T_total']:.4f}  "
          f"Between={full['pct_between']:.1f}%  Within={full['pct_within']:.1f}%")

    # Save province details for full period
    full["details"].to_csv(TAB_DIR / "tab_theil_province_details.csv", index=False)

    # ── Fig 3: Theil temporal ────────────────────────────────────────────
    print("\n[3/3] Generating figures...", flush=True)

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

    # Left panel: stacked area (between vs within)
    eras_plot = [ERA_LABELS.get(e, e) for e in theil_df["era"]]
    x = range(len(eras_plot))

    ax1.fill_between(x, 0, theil_df["T_between"], alpha=0.7,
                     color="#e41a1c", label="Between-province")
    ax1.fill_between(x, theil_df["T_between"],
                     theil_df["T_between"] + theil_df["T_within"],
                     alpha=0.7, color="#377eb8", label="Within-province")
    ax1.plot(x, theil_df["T_total"], "k-o", ms=4, lw=1.5, label="Total Theil T")
    ax1.set_xticks(list(x))
    ax1.set_xticklabels(eras_plot, rotation=45, ha="right", fontsize=8)
    ax1.set_ylabel("Theil T index", fontsize=10)
    ax1.set_title("Organisational diversity inequality\nby political era", fontsize=10)
    ax1.legend(fontsize=8)
    ax1.grid(axis="y", alpha=0.3)

    # Right panel: % between over time
    ax2.bar(x, theil_df["pct_between"], color="#e41a1c", alpha=0.8,
            label="% Between-province")
    ax2.set_xticks(list(x))
    ax2.set_xticklabels(eras_plot, rotation=45, ha="right", fontsize=8)
    ax2.set_ylabel("% of total Theil T", fontsize=10)
    ax2.set_title("Between-province share\nof total inequality", fontsize=10)
    ax2.set_ylim(0, 100)
    ax2.grid(axis="y", alpha=0.3)

    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_theil_temporal.png", dpi=300)
    plt.close(fig)
    print(f"  Saved: figures/fig_theil_temporal.png")

    # ── Fig 4: Choropleth Shannon H under Milei ─────────────────────────
    # Simplified: bar chart ranked by Shannon H (choropleth needs shapefiles)
    milei_shannon = shannon_df[shannon_df["era"] == "milei"].copy()
    milei_shannon = milei_shannon.sort_values("shannon_H", ascending=True)

    fig, ax = plt.subplots(figsize=(8, 7))
    colors = []
    prov_types = dict(zip(df["provincia"], df["prov_type"]))
    type_colors = {"metropolitan": "#e41a1c", "intermediate": "#377eb8", "peripheral": "#4daf4a"}
    for _, row in milei_shannon.iterrows():
        pt = prov_types.get(row["provincia"], "intermediate")
        colors.append(type_colors[pt])

    ax.barh(milei_shannon["provincia"], milei_shannon["shannon_H"], color=colors, alpha=0.85)
    ax.set_xlabel("Shannon H (organisational diversity)", fontsize=10)
    ax.set_title("Organisational diversity under Milei (2024-2025)\nby province", fontsize=10)

    # Legend
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor="#e41a1c", alpha=0.85, label="Metropolitan"),
        Patch(facecolor="#377eb8", alpha=0.85, label="Intermediate"),
        Patch(facecolor="#4daf4a", alpha=0.85, label="Peripheral"),
    ]
    ax.legend(handles=legend_elements, loc="lower right", fontsize=8)
    ax.grid(axis="x", alpha=0.3)

    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_shannon_milei.png", dpi=300)
    plt.close(fig)
    print(f"  Saved: figures/fig_shannon_milei.png")

    print(f"\n{'=' * 70}")
    print("DONE")


if __name__ == "__main__":
    main()
