"""
01 — MCA + csMCA of the national organisational field
======================================================
Project: Differential Institutional Simplification (2026_12)

Stage 1 of the analytical pipeline:
  - Global MCA on ~1.2M organisations (4 active variables)
  - Benzécri eigenvalue correction
  - Ward HAC on stratified sample -> cluster assignment for all orgs
  - Class-Specific MCA: concentration ellipses by province type × era
  - Small-multiples panel figure (2×3 or 3×3)

Input:  data/national_orgs_clean.parquet
Output:
    data/national_cluster_assignments.parquet
    tables/tab_eigenvalues.csv
    tables/tab_contributions.csv
    tables/tab_test_values.csv
    figures/fig_mca_biplot_global.png  (Fig 1)
    figures/fig_csmca_panel.png        (Fig 2)

Usage:
    python 01_mca_csmca.py
"""

import warnings
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse
import numpy as np
import pandas as pd
import prince
from scipy.cluster.hierarchy import fcluster, linkage
from scipy.stats import norm as scipy_norm
from sklearn.metrics import silhouette_score
from sklearn.neighbors import NearestCentroid

warnings.filterwarnings("ignore")

PROJECT = Path(__file__).parent
DATA_DIR = PROJECT / "data"
FIG_DIR = PROJECT / "figures"
TAB_DIR = PROJECT / "tables"

SEED = 42
N_MCA_COMPONENTS = 10
HAC_SAMPLE_SIZE = 50_000
SILHOUETTE_SAMPLE = 10_000
TARGET_K = 5  # Override automatic selection for interpretability (companion uses k=5)

ERA_ORDER = ["pre1990", "menem", "crisis", "n_kirchner", "c_kirchner", "macri", "fernandez", "milei"]
ERA_LABELS = {
    "pre1990": "Pre-1990", "menem": "Menem", "crisis": "Crisis",
    "n_kirchner": "N. Kirchner", "c_kirchner": "C. Kirchner",
    "macri": "Macri", "fernandez": "Fernández", "milei": "Milei",
}

PROV_TYPE_ORDER = ["metropolitan", "intermediate", "peripheral"]
PROV_TYPE_LABELS = {"metropolitan": "Metropolitan", "intermediate": "Intermediate", "peripheral": "Peripheral"}

CLUSTER_COLORS = {
    0: "#e41a1c", 1: "#377eb8", 2: "#4daf4a",
    3: "#ff7f00", 4: "#984ea3",
}


# ═════════════════════════════════════════════════════════════════════════════
# Benzécri correction
# ═════════════════════════════════════════════════════════════════════════════

def benzecri_correction(eigenvalues, n_active_vars):
    K = n_active_vars
    threshold = 1.0 / K
    corrected = []
    for lam in eigenvalues:
        if lam > threshold:
            c = ((K / (K - 1)) * (lam - threshold)) ** 2
            corrected.append(c)
    total = sum(corrected) if corrected else 1
    pcts = [c / total * 100 for c in corrected]
    return corrected, pcts


# ═════════════════════════════════════════════════════════════════════════════
# Test-values
# ═════════════════════════════════════════════════════════════════════════════

def compute_test_values(active_df, row_coords, n_axes=5):
    N = len(active_df)
    results = []
    for col in active_df.columns:
        for cat in active_df[col].unique():
            mask = active_df[col] == cat
            nk = mask.sum()
            if nk < 2 or nk >= N - 1:
                continue
            for ax in range(min(n_axes, row_coords.shape[1])):
                mean_cat = row_coords.loc[mask, ax].mean()
                mean_all = row_coords[ax].mean()
                std_all = row_coords[ax].std()
                vtest = (mean_cat - mean_all) / (std_all * np.sqrt((N - nk) / (N * nk)))
                pval = 2 * scipy_norm.sf(abs(vtest))
                results.append({
                    "variable": col, "category": cat,
                    "axis": ax + 1, "n": nk,
                    "mean_cat": mean_cat, "mean_all": mean_all,
                    "v.test": vtest, "p.value": pval,
                })
    return pd.DataFrame(results)


# ═════════════════════════════════════════════════════════════════════════════
# Concentration ellipse (κ=2 -> 86.47%)
# ═════════════════════════════════════════════════════════════════════════════

def concentration_ellipse(x, y, kappa=2):
    """Return Ellipse patch for the concentration ellipse of a point cloud."""
    cx, cy = np.mean(x), np.mean(y)
    cov = np.cov(x, y)
    eigenvals, eigenvecs = np.linalg.eigh(cov)
    order = eigenvals.argsort()[::-1]
    eigenvals = eigenvals[order]
    eigenvecs = eigenvecs[:, order]
    angle = np.degrees(np.arctan2(eigenvecs[1, 0], eigenvecs[0, 0]))
    width = kappa * 2 * np.sqrt(eigenvals[0])
    height = kappa * 2 * np.sqrt(eigenvals[1])
    return Ellipse((cx, cy), width, height, angle=angle)


# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("01 — MCA + csMCA of the national organisational field")
    print("=" * 70)

    # ── Load ─────────────────────────────────────────────────────────────
    print("\n[1/7] Loading data...", flush=True)
    df = pd.read_parquet(DATA_DIR / "national_orgs_clean.parquet")
    print(f"  N = {len(df):,}")

    # ── Prepare active variables ─────────────────────────────────────────
    print("\n[2/7] Preparing active variables...", flush=True)
    active_cols = ["tipo", "subtipo", "era", "estado"]
    active = df[active_cols].copy()

    # Prefix categories for clarity in biplot
    for col in active_cols:
        active[col] = col + ":" + active[col].astype(str)

    print(f"  Active variables: {active_cols}")
    print(f"  Total categories: {sum(active[c].nunique() for c in active_cols)}")

    # ── Run MCA ──────────────────────────────────────────────────────────
    print("\n[3/7] Running MCA...", flush=True)
    mca = prince.MCA(n_components=N_MCA_COMPONENTS, random_state=SEED)
    mca = mca.fit(active)

    row_coords = mca.row_coordinates(active)
    col_coords = mca.column_coordinates(active)
    eigenvalues = mca.eigenvalues_

    # Benzécri correction
    n_active = len(active_cols)
    corrected, corrected_pcts = benzecri_correction(eigenvalues, n_active)

    raw_pcts = eigenvalues / eigenvalues.sum() * 100

    print(f"  Eigenvalues (raw -> Benzecri):")
    for i in range(min(5, len(corrected))):
        print(f"    Axis {i+1}: {eigenvalues[i]:.4f} ({raw_pcts[i]:.1f}%) -> {corrected_pcts[i]:.1f}%")

    # Save eigenvalues table
    eig_df = pd.DataFrame({
        "axis": range(1, len(eigenvalues) + 1),
        "eigenvalue_raw": eigenvalues,
        "pct_raw": raw_pcts,
        "eigenvalue_benzecri": corrected + [0] * (len(eigenvalues) - len(corrected)),
        "pct_benzecri": corrected_pcts + [0] * (len(eigenvalues) - len(corrected)),
    })
    eig_df["cum_benzecri"] = eig_df["pct_benzecri"].cumsum()
    eig_df.to_csv(TAB_DIR / "tab_eigenvalues.csv", index=False)

    # Save contributions
    contributions = mca.column_contributions_
    contributions.to_csv(TAB_DIR / "tab_contributions.csv")

    # Save MCA coordinates for publication figures (script 05)
    row_coords.to_parquet(DATA_DIR / "mca_row_coords.parquet")
    col_coords.to_csv(TAB_DIR / "tab_col_coords.csv")
    print(f"  Saved: data/mca_row_coords.parquet, tables/tab_col_coords.csv")

    # ── Test-values ──────────────────────────────────────────────────────
    print("\n[4/7] Computing test-values...", flush=True)
    vtest_df = compute_test_values(active, row_coords, n_axes=5)
    vtest_df.to_csv(TAB_DIR / "tab_test_values.csv", index=False)
    n_sig = (vtest_df["v.test"].abs() > 2.58).sum()
    print(f"  Significant (|v.test| > 2.58): {n_sig} / {len(vtest_df)}")

    # ── HAC clustering (multi-criteria) ────────────────────────────────
    print("\n[5/7] Clustering (Ward HAC, multi-criteria k selection)...", flush=True)

    # Use axes that exceed the Benzecri threshold (eigenvalue > 1/K)
    # But cap at 5 axes to avoid noise from high-dimensional axes
    n_axes_hac = min(len(corrected), 5)
    print(f"  Using {n_axes_hac} axes for clustering")

    coords_hac = row_coords.iloc[:, :n_axes_hac].values

    # Stratified sample for HAC
    if len(df) > HAC_SAMPLE_SIZE:
        rng = np.random.RandomState(SEED)
        sample_idx = df.groupby("provincia", group_keys=False).apply(
            lambda g: g.sample(
                n=min(len(g), max(100, int(HAC_SAMPLE_SIZE * len(g) / len(df)))),
                random_state=rng,
            )
        ).index
        print(f"  HAC sample: {len(sample_idx):,} / {len(df):,}")
    else:
        sample_idx = df.index

    coords_sample = coords_hac[sample_idx]
    Z = linkage(coords_sample, method="ward")

    # ── Multi-criteria analysis (k=3..10) ────────────────────────────
    from sklearn.metrics import (
        silhouette_score as sk_silhouette,
        calinski_harabasz_score,
        davies_bouldin_score,
    )

    eval_sample_idx = np.random.RandomState(SEED).choice(
        len(coords_sample), size=min(SILHOUETTE_SAMPLE, len(coords_sample)), replace=False
    )
    eval_coords = coords_sample[eval_sample_idx]

    k_range = range(3, 11)
    metrics = {"k": [], "silhouette": [], "calinski_harabasz": [], "davies_bouldin": [],
               "inertia": [], "merge_height": []}

    # Pre-compute: dendrogram merge heights (last N-1 merges)
    # The merge height at step (N-k) gives the cost of going from k+1 to k clusters
    merge_heights = Z[:, 2]

    for k in k_range:
        labels = fcluster(Z, t=k, criterion="maxclust")
        eval_labels = labels[eval_sample_idx]

        sil = sk_silhouette(eval_coords, eval_labels)
        ch = calinski_harabasz_score(eval_coords, eval_labels)
        db = davies_bouldin_score(eval_coords, eval_labels)

        # Within-cluster sum of squares (inertia)
        inertia = 0
        for cl in np.unique(labels):
            cl_points = coords_sample[labels == cl]
            centroid = cl_points.mean(axis=0)
            inertia += np.sum((cl_points - centroid) ** 2)

        # Merge height: cost of the merge that reduces from k+1 to k
        merge_idx = len(Z) - k  # the merge that creates the k-th last cluster
        mh = Z[merge_idx, 2] if merge_idx >= 0 else 0

        metrics["k"].append(k)
        metrics["silhouette"].append(sil)
        metrics["calinski_harabasz"].append(ch)
        metrics["davies_bouldin"].append(db)
        metrics["inertia"].append(inertia)
        metrics["merge_height"].append(mh)

    metrics_df = pd.DataFrame(metrics)
    metrics_df.to_csv(TAB_DIR / "tab_cluster_metrics.csv", index=False)

    print(f"\n  {'k':>3s}  {'Silhouette':>10s}  {'C-H':>10s}  {'D-B':>8s}  {'Inertia':>12s}  {'Merge H':>10s}")
    print("  " + "-" * 62)
    for _, row in metrics_df.iterrows():
        print(f"  {int(row['k']):>3d}  {row['silhouette']:>10.3f}  "
              f"{row['calinski_harabasz']:>10.0f}  {row['davies_bouldin']:>8.3f}  "
              f"{row['inertia']:>12.0f}  {row['merge_height']:>10.1f}")

    # ── Fig: Multi-criteria plot ─────────────────────────────────────
    fig, axes_mc = plt.subplots(2, 3, figsize=(14, 8))

    # Silhouette (higher = better)
    ax = axes_mc[0, 0]
    ax.plot(metrics_df["k"], metrics_df["silhouette"], "o-", color="#e41a1c")
    ax.set_title("Silhouette (higher = better)", fontsize=9)
    ax.set_xlabel("k")
    ax.set_ylabel("Score")
    best_sil_k = metrics_df.loc[metrics_df["silhouette"].idxmax(), "k"]
    ax.axvline(best_sil_k, ls="--", color="grey", alpha=0.5)

    # Calinski-Harabasz (higher = better)
    ax = axes_mc[0, 1]
    ax.plot(metrics_df["k"], metrics_df["calinski_harabasz"], "o-", color="#377eb8")
    ax.set_title("Calinski-Harabasz (higher = better)", fontsize=9)
    ax.set_xlabel("k")

    # Davies-Bouldin (lower = better)
    ax = axes_mc[0, 2]
    ax.plot(metrics_df["k"], metrics_df["davies_bouldin"], "o-", color="#4daf4a")
    ax.set_title("Davies-Bouldin (lower = better)", fontsize=9)
    ax.set_xlabel("k")

    # Inertia / elbow
    ax = axes_mc[1, 0]
    ax.plot(metrics_df["k"], metrics_df["inertia"], "o-", color="#ff7f00")
    ax.set_title("Within-cluster inertia (elbow)", fontsize=9)
    ax.set_xlabel("k")

    # Merge heights (dendrogram jump)
    ax = axes_mc[1, 1]
    ax.plot(metrics_df["k"], metrics_df["merge_height"], "o-", color="#984ea3")
    ax.set_title("Dendrogram merge height", fontsize=9)
    ax.set_xlabel("k")

    # Delta merge height (biggest jump = natural k)
    delta_mh = np.diff(metrics_df["merge_height"].values)
    ax = axes_mc[1, 2]
    ax.bar(metrics_df["k"].values[1:], delta_mh, color="#a65628", alpha=0.8)
    ax.set_title("Delta merge height (peak = best k)", fontsize=9)
    ax.set_xlabel("k")

    plt.suptitle("Multi-criteria cluster validation (k=3..10)", fontsize=11, weight="bold")
    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_cluster_validation.png", dpi=300)
    plt.close(fig)
    print(f"\n  Saved: figures/fig_cluster_validation.png")

    # ── Select optimal k ─────────────────────────────────────────────
    # Scoring: for each metric, rank k values (1=best). Sum ranks.
    ranks = pd.DataFrame({"k": metrics_df["k"]})
    ranks["r_sil"] = metrics_df["silhouette"].rank(ascending=False)
    ranks["r_ch"] = metrics_df["calinski_harabasz"].rank(ascending=False)
    ranks["r_db"] = metrics_df["davies_bouldin"].rank(ascending=True)  # lower=better
    ranks["r_inertia"] = metrics_df["inertia"].rank(ascending=True)    # lower=better
    ranks["total_rank"] = ranks[["r_sil", "r_ch", "r_db"]].sum(axis=1)  # exclude inertia (always favours high k)
    ranks = ranks.sort_values("total_rank")

    print(f"\n  Rank-based consensus (Silhouette + C-H + D-B):")
    for _, row in ranks.iterrows():
        marker = " <-- BEST" if row["total_rank"] == ranks["total_rank"].min() else ""
        print(f"    k={int(row['k']):>2d}  "
              f"Sil={int(row['r_sil'])}  CH={int(row['r_ch'])}  DB={int(row['r_db'])}  "
              f"Total={row['total_rank']:.0f}{marker}")

    best_k = TARGET_K
    best_sil = metrics_df.loc[metrics_df["k"] == best_k, "silhouette"].values[0]
    print(f"\n  Selected k={best_k} (TARGET_K override, silhouette={best_sil:.3f})")

    # ── Assign clusters ──────────────────────────────────────────────
    sample_labels = fcluster(Z, t=best_k, criterion="maxclust") - 1

    clf = NearestCentroid()
    clf.fit(coords_sample, sample_labels)
    all_labels = clf.predict(coords_hac)

    df["cluster"] = all_labels

    # Name clusters by dominant tipo + era profile
    cluster_names = {}
    for cl in sorted(df["cluster"].unique()):
        sub = df[df["cluster"] == cl]
        dom_tipo = sub["tipo"].value_counts().idxmax()
        dom_pct = sub["tipo"].value_counts().iloc[0] / len(sub) * 100
        dom_era = sub["era"].value_counts().idxmax()
        cluster_names[cl] = f"{dom_tipo} ({dom_pct:.0f}%)"

    print(f"\n  Cluster profiles (k={best_k}):")
    for cl in sorted(df["cluster"].unique()):
        sub = df[df["cluster"] == cl]
        n = len(sub)
        tipos = sub["tipo"].value_counts(normalize=True).head(3)
        tipo_str = ", ".join(f"{t} {p*100:.0f}%" for t, p in tipos.items())
        eras = sub["era"].value_counts(normalize=True).head(2)
        era_str = ", ".join(f"{e} {p*100:.0f}%" for e, p in eras.items())
        prov_types = sub["prov_type"].value_counts(normalize=True)
        metro_pct = prov_types.get("metropolitan", 0) * 100
        print(f"    Cluster {cl} (n={n:,}, metro={metro_pct:.0f}%): {tipo_str} | {era_str}")

    df["cluster_name"] = df["cluster"].map(cluster_names)

    # Save
    df.to_parquet(DATA_DIR / "national_cluster_assignments.parquet", index=False)
    print(f"  Saved: data/national_cluster_assignments.parquet")

    # ── Fig 1: Global MCA biplot ─────────────────────────────────────────
    print("\n[6/7] Generating Fig 1 (global biplot)...", flush=True)

    fig, ax = plt.subplots(figsize=(10, 8))

    # Plot organisations (subsample for visibility)
    plot_n = min(30_000, len(df))
    plot_idx = np.random.RandomState(SEED).choice(len(df), size=plot_n, replace=False)
    for cl in sorted(df["cluster"].unique()):
        mask = df.iloc[plot_idx]["cluster"] == cl
        idx = df.iloc[plot_idx][mask].index
        ax.scatter(
            row_coords.loc[idx, 0], row_coords.loc[idx, 1],
            c=CLUSTER_COLORS.get(cl, "#999999"), s=1, alpha=0.15,
            label=cluster_names.get(cl, str(cl)), rasterized=True,
        )

    # Plot category centroids
    var_colors = {"tipo": "#b30000", "subtipo": "#006600", "era": "#000099", "estado": "#993300"}
    for idx_name in col_coords.index:
        x, y = col_coords.loc[idx_name, 0], col_coords.loc[idx_name, 1]
        var = idx_name.split(":")[0] if ":" in str(idx_name) else "other"
        color = var_colors.get(var, "#555555")
        ax.plot(x, y, "ks", ms=5, zorder=5)
        label_text = str(idx_name).split(":")[-1] if ":" in str(idx_name) else str(idx_name)
        ax.annotate(label_text, (x, y), fontsize=6.5, color=color,
                    ha="left", va="bottom", weight="bold",
                    xytext=(3, 3), textcoords="offset points")

    # Supplementary: province centroids
    for prov in df["provincia"].unique():
        mask = df["provincia"] == prov
        cx = row_coords.loc[mask, 0].mean()
        cy = row_coords.loc[mask, 1].mean()
        ax.plot(cx, cy, "^", ms=6, color="#555555", zorder=4)
        ax.annotate(prov, (cx, cy), fontsize=5, color="#555555",
                    ha="center", va="top", style="italic",
                    xytext=(0, -6), textcoords="offset points")

    ax.set_xlabel(f"Axis 1 ({corrected_pcts[0]:.1f}% Benzécri)", fontsize=10)
    ax.set_ylabel(f"Axis 2 ({corrected_pcts[1]:.1f}% Benzécri)", fontsize=10)
    ax.axhline(0, color="grey", lw=0.5, ls="--")
    ax.axvline(0, color="grey", lw=0.5, ls="--")
    ax.legend(loc="upper right", fontsize=7, markerscale=5, framealpha=0.9)
    ax.set_title(f"National organisational space (N = {len(df):,})", fontsize=11)
    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_mca_biplot_global.png", dpi=300)
    plt.close(fig)
    print(f"  Saved: figures/fig_mca_biplot_global.png")

    # ── Fig 2: csMCA — 3 ellipses overlaid per era (1x3 grid) ─────────
    print("\n[7/7] Generating Fig 2 (csMCA overlaid ellipses)...", flush=True)

    era_groups = {
        "Kirchnerism (2003-2015)": ["n_kirchner", "c_kirchner"],
        "Macri-Fernandez (2016-2023)": ["macri", "fernandez"],
        "Milei (2024-2025)": ["milei"],
    }

    # Compute global axis limits
    x_all = row_coords.iloc[plot_idx, 0]
    y_all = row_coords.iloc[plot_idx, 1]
    q = 0.995
    xlim = (x_all.quantile(1 - q), x_all.quantile(q))
    ylim = (y_all.quantile(1 - q), y_all.quantile(q))

    ellipse_colors = {
        "metropolitan": "#e41a1c",
        "intermediate": "#377eb8",
        "peripheral": "#4daf4a",
    }
    ellipse_ls = {
        "metropolitan": "-",
        "intermediate": "--",
        "peripheral": "-.",
    }

    fig, axes_cs = plt.subplots(1, 3, figsize=(15, 5.5), sharex=True, sharey=True)

    for j, (eg_label, eg_eras) in enumerate(era_groups.items()):
        ax = axes_cs[j]

        # Background: all orgs (grey)
        ax.scatter(
            row_coords.iloc[plot_idx, 0], row_coords.iloc[plot_idx, 1],
            c="#e8e8e8", s=0.3, alpha=0.2, rasterized=True,
        )

        # Overlay all 3 province types
        n_labels = []
        for pt in PROV_TYPE_ORDER:
            mask = (df["prov_type"] == pt) & (df["era"].isin(eg_eras))
            sub_idx = df[mask].index
            n_sub = len(sub_idx)
            color = ellipse_colors[pt]

            # Scatter subsample
            if n_sub > 3000:
                sub_plot = np.random.RandomState(SEED + j).choice(
                    sub_idx, size=3000, replace=False)
            else:
                sub_plot = sub_idx

            ax.scatter(
                row_coords.loc[sub_plot, 0], row_coords.loc[sub_plot, 1],
                c=color, s=0.8, alpha=0.15, rasterized=True,
            )

            # Concentration ellipse (kappa=2 -> 86.47%)
            if n_sub >= 30:
                ell = concentration_ellipse(
                    row_coords.loc[sub_idx, 0], row_coords.loc[sub_idx, 1],
                    kappa=2,
                )
                ell.set_facecolor(color)
                ell.set_alpha(0.08)
                ell.set_edgecolor(color)
                ell.set_linewidth(2.0)
                ell.set_linestyle(ellipse_ls[pt])
                ax.add_patch(ell)

            # Centroid cross
            if n_sub > 0:
                cx = row_coords.loc[sub_idx, 0].mean()
                cy = row_coords.loc[sub_idx, 1].mean()
                ax.plot(cx, cy, "+", color=color, ms=10, mew=2, zorder=10)

            n_labels.append(f"{PROV_TYPE_LABELS[pt]}: n={n_sub:,}")

        ax.axhline(0, color="grey", lw=0.4, ls="--")
        ax.axvline(0, color="grey", lw=0.4, ls="--")
        ax.set_xlim(xlim)
        ax.set_ylim(ylim)
        ax.set_title(eg_label, fontsize=10, weight="bold")
        ax.set_xlabel(f"Axis 1 ({corrected_pcts[0]:.0f}%)", fontsize=9)
        if j == 0:
            ax.set_ylabel(f"Axis 2 ({corrected_pcts[1]:.0f}%)", fontsize=9)

        # N annotations
        for k, label in enumerate(n_labels):
            pt_name = PROV_TYPE_ORDER[k]
            ax.text(0.02, 0.98 - k * 0.06, label, transform=ax.transAxes,
                    fontsize=7, va="top", ha="left",
                    color=ellipse_colors[pt_name], weight="bold")

    # Legend
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], color=ellipse_colors["metropolitan"], lw=2,
               ls=ellipse_ls["metropolitan"], label="Metropolitan"),
        Line2D([0], [0], color=ellipse_colors["intermediate"], lw=2,
               ls=ellipse_ls["intermediate"], label="Intermediate"),
        Line2D([0], [0], color=ellipse_colors["peripheral"], lw=2,
               ls=ellipse_ls["peripheral"], label="Peripheral"),
    ]
    axes_cs[2].legend(handles=legend_elements, loc="upper right", fontsize=8,
                      framealpha=0.9)

    plt.suptitle("Concentration ellipses by province type across political eras",
                 fontsize=11, weight="bold")
    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_csmca_panel.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved: figures/fig_csmca_panel.png")

    # ── Class-specific eigenvalues and inertia ────────────────────────
    print("  Computing class-specific eigenvalues...", flush=True)

    cs_era_groups = {
        "Kirchnerism": ["n_kirchner", "c_kirchner"],
        "Macri": ["macri"],
        "Fernandez": ["fernandez"],
        "Milei": ["milei"],
    }

    cs_results = []
    n_axes_cs = min(5, row_coords.shape[1])
    for eg_label, eg_eras in cs_era_groups.items():
        for pt in PROV_TYPE_ORDER:
            mask = (df["prov_type"] == pt) & (df["era"].isin(eg_eras))
            sub_idx = df[mask].index
            n_sub = len(sub_idx)
            if n_sub < 30:
                continue
            sub_coords = row_coords.loc[sub_idx].iloc[:, :n_axes_cs].values
            cov_matrix = np.cov(sub_coords.T)
            cs_eigenvals = np.sort(np.linalg.eigvalsh(cov_matrix))[::-1]
            cs_inertia = cs_eigenvals.sum()
            centroid = sub_coords.mean(axis=0)

            cs_results.append({
                "era_group": eg_label,
                "prov_type": pt,
                "n": n_sub,
                "centroid_ax1": centroid[0],
                "centroid_ax2": centroid[1],
                "cs_inertia": cs_inertia,
                "cs_eigenval_1": cs_eigenvals[0],
                "cs_eigenval_2": cs_eigenvals[1] if len(cs_eigenvals) > 1 else 0,
                "cs_pct_ax1": cs_eigenvals[0] / cs_inertia * 100 if cs_inertia > 0 else 0,
                "cs_pct_ax2": cs_eigenvals[1] / cs_inertia * 100 if cs_inertia > 0 and len(cs_eigenvals) > 1 else 0,
            })

    cs_df = pd.DataFrame(cs_results)
    cs_df.to_csv(TAB_DIR / "tab_csmca_class_specific.csv", index=False)
    print(f"  Saved: tables/tab_csmca_class_specific.csv ({len(cs_df)} classes)")

    # ── Fig 2b: Centroid trajectories (all eras, single plot) ────────
    print("  Generating Fig 2b (centroid trajectories)...", flush=True)

    all_eras_ordered = ERA_ORDER
    fig, ax = plt.subplots(figsize=(9, 7))

    # Background
    ax.scatter(
        row_coords.iloc[plot_idx, 0], row_coords.iloc[plot_idx, 1],
        c="#e8e8e8", s=0.3, alpha=0.15, rasterized=True,
    )

    for pt in PROV_TYPE_ORDER:
        color = ellipse_colors[pt]
        centroids_x, centroids_y, era_labels_plot = [], [], []

        for era in all_eras_ordered:
            mask = (df["prov_type"] == pt) & (df["era"] == era)
            sub_idx = df[mask].index
            if len(sub_idx) < 10:
                continue
            cx = row_coords.loc[sub_idx, 0].mean()
            cy = row_coords.loc[sub_idx, 1].mean()
            centroids_x.append(cx)
            centroids_y.append(cy)
            era_labels_plot.append(ERA_LABELS.get(era, era))

        # Draw trajectory
        ax.plot(centroids_x, centroids_y, "-o", color=color, ms=5, lw=1.5,
                alpha=0.8, label=PROV_TYPE_LABELS[pt])

        # Label start and end
        if len(centroids_x) >= 2:
            ax.annotate(era_labels_plot[0], (centroids_x[0], centroids_y[0]),
                        fontsize=6, color=color, ha="right",
                        xytext=(-6, -3), textcoords="offset points")
            ax.annotate(era_labels_plot[-1], (centroids_x[-1], centroids_y[-1]),
                        fontsize=7, color=color, ha="left", weight="bold",
                        xytext=(4, 3), textcoords="offset points")

    ax.axhline(0, color="grey", lw=0.4, ls="--")
    ax.axvline(0, color="grey", lw=0.4, ls="--")
    ax.set_xlabel(f"Axis 1 ({corrected_pcts[0]:.1f}% Benzecri)", fontsize=10)
    ax.set_ylabel(f"Axis 2 ({corrected_pcts[1]:.1f}% Benzecri)", fontsize=10)
    ax.set_title("Centroid trajectories by province type across 8 political eras",
                 fontsize=11)
    ax.legend(fontsize=9)
    plt.tight_layout()
    fig.savefig(FIG_DIR / "fig_centroid_trajectories.png", dpi=300)
    plt.close(fig)
    print(f"  Saved: figures/fig_centroid_trajectories.png")

    print(f"\n{'=' * 70}")
    print("DONE")


if __name__ == "__main__":
    main()
