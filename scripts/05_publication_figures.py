"""
05 — Publication-quality figures
=================================
Project: Differential Institutional Simplification (2026_12)

Generates 6 publication-ready figures in TIFF (LZW) + PNG at 300 DPI.
Consistent styling following companion article (2026_11_SR).

Input:
    data/mca_row_coords.parquet
    data/national_cluster_assignments.parquet
    tables/tab_col_coords.csv
    tables/tab_theil_decomposition.csv
    tables/tab_shannon_by_province_era.csv
    tables/tab_shift_share.csv

Output:
    figures/Fig1_biplot.{tiff,png}
    figures/Fig2_csmca_panel.{tiff,png}
    figures/Fig3_theil_temporal.{tiff,png}
    figures/Fig4_shannon_ranking.{tiff,png}
    figures/Fig5_shift_share.{tiff,png}
    figures/Fig6_choropleth.{tiff,png}

Usage:
    python 05_publication_figures.py
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse
from matplotlib.lines import Line2D
from adjustText import adjust_text
import numpy as np
import pandas as pd
import geopandas as gpd
import unicodedata
from matplotlib import patheffects as pe

PROJECT = Path(__file__).parent
DATA_DIR = PROJECT / "data"
FIG_DIR = PROJECT / "figures"
TAB_DIR = PROJECT / "tables"

# ═════════════════════════════════════════════════════════════════════════════
# Style
# ═════════════════════════════════════════════════════════════════════════════

DPI = 300
FONT_SIZE = 9
FONT_FAMILY = "Arial"

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.sans-serif": [FONT_FAMILY, "Helvetica", "DejaVu Sans"],
    "font.size": FONT_SIZE,
    "axes.labelsize": 10,
    "axes.titlesize": 11,
    "xtick.labelsize": 8,
    "ytick.labelsize": 8,
    "legend.fontsize": 8,
    "figure.dpi": DPI,
    "savefig.dpi": DPI,
    "savefig.bbox": "tight",
    "axes.spines.top": False,
    "axes.spines.right": False,
})

# ═════════════════════════════════════════════════════════════════════════════
# Constants
# ═════════════════════════════════════════════════════════════════════════════

SEED = 42

ERA_ORDER = ["pre1990", "menem", "crisis", "n_kirchner", "c_kirchner",
             "macri", "fernandez", "milei"]
ERA_LABELS = {
    "pre1990": "Pre-1990", "menem": "Menem", "crisis": "Crisis",
    "n_kirchner": "N. Kirchner", "c_kirchner": "C. Kirchner",
    "macri": "Macri", "fernandez": "Fernández", "milei": "Milei",
}

PROV_TYPE_ORDER = ["metropolitan", "intermediate", "peripheral"]
PROV_TYPE_LABELS = {
    "metropolitan": "Metropolitan",
    "intermediate": "Intermediate",
    "peripheral": "Peripheral",
}

CLUSTER_COLORS = {
    0: "#e41a1c", 1: "#377eb8", 2: "#4daf4a",
    3: "#ff7f00", 4: "#984ea3",
}

PROV_TYPE_COLORS = {
    "metropolitan": "#e41a1c",
    "intermediate": "#377eb8",
    "peripheral": "#4daf4a",
}

PROV_TYPE_LS = {
    "metropolitan": "-",
    "intermediate": "--",
    "peripheral": "-.",
}

VAR_COLORS = {
    "tipo": "#8B0000", "subtipo": "#2F4F4F",
    "era": "#0066FF", "estado": "#8B4513",
}

# Categories to suppress labels (near origin or low narrative value)
SUPPRESS_LABELS = {"AC", "other", "tourism", "commerce", "health"}

VAR_MARKERS = {
    "tipo": "o", "subtipo": "s",
    "era": "D", "estado": "^",
}

# Label capitalisation for biplot
BIPLOT_LABELS = {
    # eras
    "pre1990": "Pre-1990", "menem": "Menem", "crisis": "Crisis",
    "n_kirchner": "N. Kirchner", "c_kirchner": "C. Kirchner",
    "macri": "Macri", "fernandez": "Fernández", "milei": "Milei",
    # tipos
    "Coop": "Coop", "Asoc": "Asoc", "Fund": "Fund", "Mutual": "Mutual",
    "SRL": "SRL", "SA": "SA", "SAS": "SAS", "Otra": "Otra",
    # estado
    "AC": "AC", "BD": "BD",
}


def save_fig(fig, name):
    """Save figure as TIFF (LZW) + PNG."""
    fig.savefig(FIG_DIR / f"{name}.tiff", dpi=DPI, format="tiff",
                pil_kwargs={"compression": "tiff_lzw"})
    fig.savefig(FIG_DIR / f"{name}.png", dpi=DPI)
    plt.close(fig)
    print(f"  Saved: figures/{name}.tiff + .png")


def concentration_ellipse(x, y, kappa=2):
    """Return Ellipse patch for concentration ellipse (kappa=2 -> 86.47%)."""
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
# Load data
# ═════════════════════════════════════════════════════════════════════════════

def load_data():
    """Load all datasets needed for figures."""
    df = pd.read_parquet(DATA_DIR / "national_cluster_assignments.parquet")
    row_coords = pd.read_parquet(DATA_DIR / "mca_row_coords.parquet")
    col_coords = pd.read_csv(TAB_DIR / "tab_col_coords.csv", index_col=0)
    eig = pd.read_csv(TAB_DIR / "tab_eigenvalues.csv")
    theil = pd.read_csv(TAB_DIR / "tab_theil_decomposition.csv")
    shannon = pd.read_csv(TAB_DIR / "tab_shannon_by_province_era.csv")
    shift = pd.read_csv(TAB_DIR / "tab_shift_share.csv")
    shift_kf = pd.read_csv(TAB_DIR / "tab_shift_share_kirchner_fernandez.csv")
    return df, row_coords, col_coords, eig, theil, shannon, shift, shift_kf


# ═════════════════════════════════════════════════════════════════════════════
# Fig 1: National MCA biplot
# ═════════════════════════════════════════════════════════════════════════════

def fig1_biplot(df, row_coords, col_coords, eig):
    print("\n  Fig 1: National MCA biplot...", flush=True)

    benz_pcts = eig["pct_benzecri"].values

    # Cluster names
    cluster_names = {}
    for cl in sorted(df["cluster"].unique()):
        sub = df[df["cluster"] == cl]
        dom = sub["tipo"].value_counts().idxmax()
        pct = sub["tipo"].value_counts().iloc[0] / len(sub) * 100
        cluster_names[cl] = f"{dom} ({pct:.0f}%)"

    fig, ax = plt.subplots(figsize=(8, 7.5))

    # Subsample for visibility
    rng = np.random.RandomState(SEED)
    plot_n = min(30_000, len(df))
    plot_idx = rng.choice(len(df), size=plot_n, replace=False)

    for cl in sorted(df["cluster"].unique()):
        mask = df.iloc[plot_idx]["cluster"] == cl
        idx = df.iloc[plot_idx][mask].index
        ax.scatter(
            row_coords.loc[idx, 0], row_coords.loc[idx, 1],
            c=CLUSTER_COLORS.get(cl, "#999999"), s=0.8, alpha=0.12,
            label=cluster_names.get(cl, str(cl)), rasterized=True,
        )

    # Category centroids — differentiated by variable type
    # Labels in the crowded lower-left cluster are positioned manually with
    # explicit connecting lines so every point-label link is unambiguous.
    MANUAL_ERA_LABELS = {"crisis", "menem", "c_kirchner", "n_kirchner"}
    manual_points = {}  # raw_label -> (x, y, color)
    texts = []
    for idx_name in col_coords.index:
        x, y = col_coords.loc[idx_name, "0"], col_coords.loc[idx_name, "1"]
        var = str(idx_name).split("__")[0] if "__" in str(idx_name) else "other"
        color = VAR_COLORS.get(var, "#555555")
        marker = VAR_MARKERS.get(var, "o")
        # All markers filled; eras slightly larger
        if var == "era":
            ax.plot(x, y, marker, ms=6, mfc=color, mec="white", mew=0.6, zorder=6)
        else:
            ax.plot(x, y, marker, ms=5, mfc=color, mec="white", mew=0.5, zorder=5)
        raw_label = str(idx_name).split(":")[-1] if ":" in str(idx_name) else str(idx_name)
        # Suppress labels for categories too close to origin
        if raw_label in SUPPRESS_LABELS:
            continue
        label_text = BIPLOT_LABELS.get(raw_label, raw_label.capitalize())
        # Crowded era labels: skip from adjust_text, position manually below
        if raw_label in MANUAL_ERA_LABELS:
            manual_points[raw_label] = (x, y, color)
            continue
        fs = 7.5 if var == "era" else 7
        t = ax.text(x, y, f"  {label_text}", fontsize=fs, color=color,
                    weight="bold", ha="left", va="center", zorder=6)
        texts.append(t)

    # Resolve overlapping labels — lines only where needed, never touching text
    adjust_text(texts, ax=ax,
                arrowprops=dict(arrowstyle="-", color="#cccccc", lw=0.3,
                                shrinkA=8, shrinkB=3),
                min_arrow_len=20,
                expand=(2.0, 2.0),
                force_text=(1.5, 1.5),
                force_points=(1.0, 1.0),
                only_move={"text": "xy"},
                iterations=300)

    # Manual labels for crowded lower-left era cluster.
    # Each label is placed with clear separation and a connecting line to its point.
    MANUAL_OFFSETS = {
        "crisis":      (-1.20,  0.08),
        "menem":       (-1.20, -0.18),
        "c_kirchner":  (-0.85, -0.60),
        "n_kirchner":  (-1.20, -0.78),
    }
    arrow_kw = dict(arrowstyle="-", color="#999999", lw=0.5, shrinkA=3, shrinkB=3)
    for raw_label, (px, py, pcolor) in manual_points.items():
        tx, ty = MANUAL_OFFSETS[raw_label]
        label_text = BIPLOT_LABELS.get(raw_label, raw_label)
        ax.annotate(label_text, xy=(px, py), xytext=(tx, ty),
                    fontsize=7.5, color=pcolor, weight="bold",
                    ha="right", va="center", zorder=6,
                    arrowprops=arrow_kw)

    ax.set_xlabel(f"Axis 1 ({benz_pcts[0]:.1f}% Benzécri)")
    ax.set_ylabel(f"Axis 2 ({benz_pcts[1]:.1f}% Benzécri)")
    ax.axhline(0, color="grey", lw=0.4, ls="--")
    ax.axvline(0, color="grey", lw=0.4, ls="--")
    ax.legend(loc="upper right", fontsize=7, markerscale=8, framealpha=0.95,
              edgecolor="#cccccc")

    save_fig(fig, "Fig1_biplot")


# ═════════════════════════════════════════════════════════════════════════════
# Fig 2: csMCA panel — concentration ellipses by province type × era
# ═════════════════════════════════════════════════════════════════════════════

def fig2_csmca_panel(df, row_coords, eig):
    print("  Fig 2: csMCA concentration ellipses panel (2×3)...", flush=True)

    benz_pcts = eig["pct_benzecri"].values

    era_groups = {
        "Pre-1990": ["pre1990"],
        "Menem/Crisis\n(1990–2002)": ["menem", "crisis"],
        "Kirchnerism\n(2003–2015)": ["n_kirchner", "c_kirchner"],
        "Macri\n(2016–2019)": ["macri"],
        "Fernández\n(2020–2023)": ["fernandez"],
        "Milei\n(2024–2025)": ["milei"],
    }

    # Axis limits based on ellipse extents (centroids ± 2.5σ)
    all_xmin, all_xmax, all_ymin, all_ymax = [], [], [], []
    for eg_eras in era_groups.values():
        for pt in PROV_TYPE_ORDER:
            mask = (df["prov_type"] == pt) & (df["era"].isin(eg_eras))
            sub_idx = df[mask].index
            if len(sub_idx) < 30:
                continue
            cx = row_coords.loc[sub_idx, 0].mean()
            cy = row_coords.loc[sub_idx, 1].mean()
            sx = row_coords.loc[sub_idx, 0].std()
            sy = row_coords.loc[sub_idx, 1].std()
            all_xmin.append(cx - 2.5 * sx)
            all_xmax.append(cx + 2.5 * sx)
            all_ymin.append(cy - 2.5 * sy)
            all_ymax.append(cy + 2.5 * sy)
    margin = 0.15
    x_range = max(all_xmax) - min(all_xmin)
    y_range = max(all_ymax) - min(all_ymin)
    xlim = (min(all_xmin) - margin * x_range, max(all_xmax) + margin * x_range)
    ylim = (min(all_ymin) - margin * y_range, max(all_ymax) + margin * y_range)

    fig, axes = plt.subplots(2, 3, figsize=(18, 11), sharex=True, sharey=True)
    axes_flat = axes.flatten()

    for j, (eg_label, eg_eras) in enumerate(era_groups.items()):
        ax = axes_flat[j]

        n_labels = []
        for pt in PROV_TYPE_ORDER:
            mask = (df["prov_type"] == pt) & (df["era"].isin(eg_eras))
            sub_idx = df[mask].index
            n_sub = len(sub_idx)
            color = PROV_TYPE_COLORS[pt]

            # Concentration ellipse
            if n_sub >= 30:
                ell = concentration_ellipse(
                    row_coords.loc[sub_idx, 0].values,
                    row_coords.loc[sub_idx, 1].values,
                    kappa=2,
                )
                ell.set_facecolor(color)
                ell.set_alpha(0.18)
                ell.set_edgecolor(color)
                ell.set_linewidth(2.5)
                ax.add_patch(ell)

            # Centroid
            if n_sub > 0:
                cx = row_coords.loc[sub_idx, 0].mean()
                cy = row_coords.loc[sub_idx, 1].mean()
                ax.plot(cx, cy, "+", color=color, ms=16, mew=3.5, zorder=10)

            n_labels.append(f"{PROV_TYPE_LABELS[pt]}: n = {n_sub:,}")

        # Reference lines (zero inertia axes)
        ax.axhline(0, color="#555555", lw=1.0, ls="--", zorder=1)
        ax.axvline(0, color="#555555", lw=1.0, ls="--", zorder=1)
        ax.set_xlim(xlim)
        ax.set_ylim(ylim)

        # Panel letter (top-left, well separated from title)
        panel_letter = chr(ord("a") + j)
        ax.text(-0.02, 1.18, f"({panel_letter})", transform=ax.transAxes,
                fontsize=18, weight="bold", va="bottom", ha="left")

        # Era title (centred above panel, separated from letter)
        ax.set_title(eg_label, fontsize=14, fontweight="semibold",
                     loc="center", pad=22)

        ax.tick_params(axis="both", labelsize=12)

        # Axis labels only on edges
        if j >= 3:  # bottom row
            ax.set_xlabel(f"Axis 1 ({benz_pcts[0]:.0f}% Benzécri)",
                          fontsize=14)
        if j % 3 == 0:  # left column
            ax.set_ylabel(f"Axis 2 ({benz_pcts[1]:.0f}% Benzécri)",
                          fontsize=14)

        # N annotations (top-left, inside plot, large and readable)
        for k, label in enumerate(n_labels):
            pt_name = PROV_TYPE_ORDER[k]
            ax.text(0.03, 0.96 - k * 0.07, label, transform=ax.transAxes,
                    fontsize=12, va="top", ha="left",
                    color=PROV_TYPE_COLORS[pt_name], weight="bold")

        # Pole annotations on bottom row only
        if j >= 3:
            ax.text(0.01, 0.02, "\u2190 Coop / Asoc", transform=ax.transAxes,
                    fontsize=11, color="#666666", va="bottom", ha="left",
                    style="italic")
            ax.text(0.99, 0.02, "SAS \u2192", transform=ax.transAxes,
                    fontsize=11, color="#666666", va="bottom", ha="right",
                    style="italic")

    fig.subplots_adjust(hspace=0.35, wspace=0.12)
    save_fig(fig, "Fig2_csmca_panel")


# ═════════════════════════════════════════════════════════════════════════════
# Fig 3: Theil temporal decomposition
# ═════════════════════════════════════════════════════════════════════════════

def fig3_theil_temporal(theil):
    print("  Fig 3: Theil temporal decomposition...", flush=True)

    # Order by era
    theil["era_idx"] = theil["era"].map({e: i for i, e in enumerate(ERA_ORDER)})
    theil = theil.sort_values("era_idx")
    labels = [ERA_LABELS.get(e, e) for e in theil["era"]]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

    x = np.arange(len(theil))

    # Left: stacked area (between/within) + total line
    ax1.fill_between(x, 0, theil["T_between"], alpha=0.6, color="#e41a1c",
                     label="Between provinces")
    ax1.fill_between(x, theil["T_between"], theil["T_total"], alpha=0.6,
                     color="#377eb8", label="Within provinces")
    ax1.plot(x, theil["T_total"], "k-o", ms=4, lw=1.5, label="Total Theil T")

    ax1.set_xticks(x)
    ax1.set_xticklabels(labels, rotation=45, ha="right", fontsize=14)
    ax1.set_ylabel("Theil T index", fontsize=16)
    ax1.tick_params(axis="y", labelsize=14)
    ax1.legend(fontsize=14, loc="upper left", bbox_to_anchor=(0.0, 1.15))
    ax1.text(-0.05, 1.02, "(a)", transform=ax1.transAxes,
             fontsize=18, weight="bold", va="bottom")

    # Right: % between-province
    ax2.bar(x, theil["pct_between"], color="#999999", alpha=0.8, edgecolor="white")
    ax2.set_xticks(x)
    ax2.set_xticklabels(labels, rotation=45, ha="right", fontsize=14)
    ax2.set_ylabel("Between-province share (%)", fontsize=16)
    ax2.tick_params(axis="y", labelsize=14)
    ax2.text(-0.05, 1.02, "(b)", transform=ax2.transAxes,
             fontsize=18, weight="bold", va="bottom")

    plt.tight_layout()
    save_fig(fig, "Fig3_theil_temporal")


# ═════════════════════════════════════════════════════════════════════════════
# Fig 4: Provincial diversity ranking under Milei
# ═════════════════════════════════════════════════════════════════════════════

def fig4_shannon_ranking(shannon, df):
    print("  Fig 4: Organisational composition by province (Milei)...", flush=True)

    # Composition under Milei
    milei = df[df["era"] == "milei"]
    comp = milei.groupby(["provincia", "tipo"]).size().unstack(fill_value=0)
    comp_pct = comp.div(comp.sum(axis=1), axis=0) * 100

    # Order types for stacking: SAS first (leftmost), then commercial, then collective
    tipo_order = ["SAS", "SRL", "SA", "Otra", "Fund", "Mutual", "Coop", "Asoc"]
    tipo_order = [t for t in tipo_order if t in comp_pct.columns]
    comp_pct = comp_pct[tipo_order]

    # Sort by % SAS descending
    sas_col = "SAS" if "SAS" in comp_pct.columns else tipo_order[0]
    comp_pct = comp_pct.sort_values(sas_col, ascending=True)

    # Province type map
    prov_type_map = df.drop_duplicates("provincia").set_index("provincia")["prov_type"]

    # Colour palette for organisational types
    tipo_colors = {
        "SAS": "#e41a1c", "SRL": "#ff7f00", "SA": "#fdbf6f",
        "Otra": "#cccccc", "Fund": "#b2df8a", "Mutual": "#33a02c",
        "Coop": "#1f78b4", "Asoc": "#a6cee3",
    }

    fig, ax = plt.subplots(figsize=(10, 8))

    y_pos = np.arange(len(comp_pct))
    left = np.zeros(len(comp_pct))

    for tipo in tipo_order:
        vals = comp_pct[tipo].values
        color = tipo_colors.get(tipo, "#999999")
        ax.barh(y_pos, vals, left=left, color=color, edgecolor="white",
                linewidth=0.3, height=0.75, label=tipo)
        left += vals

    ax.set_yticks(y_pos)
    # Colour province names by type
    prov_names = list(comp_pct.index)
    ax.set_yticklabels(prov_names, fontsize=12)
    for i, prov in enumerate(prov_names):
        pt = prov_type_map.get(prov, "intermediate")
        ax.get_yticklabels()[i].set_color(PROV_TYPE_COLORS.get(pt, "#333333"))

    ax.set_xlabel("Organisational composition (%)", fontsize=14)
    ax.set_xlim(0, 100)
    ax.tick_params(axis="x", labelsize=12)

    # Legend below the plot in a single row
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.08),
              fontsize=10, ncol=len(tipo_order), frameon=False)

    plt.tight_layout()
    save_fig(fig, "Fig4_shannon_ranking")


# ═════════════════════════════════════════════════════════════════════════════
# Fig 5: Shift-share decomposition
# ═════════════════════════════════════════════════════════════════════════════

def fig5_shift_share(shift_milei, shift_fern, df):
    print("  Fig 5: Provincial differential (dual lollipop)...", flush=True)

    # Province type map
    prov_type_map = df.drop_duplicates("provincia").set_index("provincia")["prov_type"]

    # Sort both by Milei provincial_diff (same province order in both panels)
    ss_m = shift_milei.sort_values("provincial_diff", ascending=True).copy()
    ss_m["prov_type"] = ss_m["provincia"].map(prov_type_map).fillna("intermediate")
    prov_order = list(ss_m["provincia"])

    ss_f = shift_fern.set_index("provincia").loc[prov_order].reset_index().copy()
    ss_f["prov_type"] = ss_f["provincia"].map(prov_type_map).fillna("intermediate")

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 12), sharey=True)

    y_pos = np.arange(len(prov_order))

    for ax, ss, title in [
        (ax1, ss_f, "(a) Kirchnerism \u2192 Fern\u00e1ndez"),
        (ax2, ss_m, "(b) Kirchnerism \u2192 Milei"),
    ]:
        for i, (_, row) in enumerate(ss.iterrows()):
            color = PROV_TYPE_COLORS.get(row["prov_type"], "#999999")
            ax.hlines(y=i, xmin=0, xmax=row["provincial_diff"],
                      color=color, lw=2.8, alpha=0.7)
            ax.plot(row["provincial_diff"], i, "o", color=color, ms=12,
                    mec="white", mew=0.7, zorder=5)

        ax.axvline(0, color="black", lw=1.0)
        # Horizontal guide lines spanning full plot width
        for yy in y_pos:
            ax.axhline(yy, color="#aaaaaa", lw=0.9, ls=(0, (4, 4)), zorder=0)
        ax.set_yticks(y_pos)
        ax.set_xlabel("Provincial differential (orgs/year)", fontsize=20)
        ax.set_title(title, fontsize=20, fontweight="semibold", pad=14)
        ax.tick_params(axis="x", labelsize=18)

    # Y-axis labels only on left panel
    ax1.set_yticklabels(prov_order, fontsize=18)
    for i, prov in enumerate(prov_order):
        pt = prov_type_map.get(prov, "intermediate")
        ax1.get_yticklabels()[i].set_color(PROV_TYPE_COLORS.get(pt, "#333333"))

    # Legend on right panel
    legend_elements = [
        Line2D([0], [0], marker="o", color="w", markerfacecolor=PROV_TYPE_COLORS[pt],
               ms=12, label=PROV_TYPE_LABELS[pt])
        for pt in PROV_TYPE_ORDER
    ]
    ax2.legend(handles=legend_elements, loc="lower right", fontsize=18,
               framealpha=0.95, edgecolor="#cccccc")

    plt.tight_layout()
    save_fig(fig, "Fig5_shift_share")


# ═════════════════════════════════════════════════════════════════════════════
# Fig 6 — Choropleth: Shannon H by province (Fernández vs Milei)
# ═════════════════════════════════════════════════════════════════════════════

PROV_NAME_MAP = {"Ciudad de Buenos Aires": "CABA"}
POSTAL_FIX = {"Ciudad de Buenos Aires": "CABA", "Buenos Aires": "BA"}

def fig6_choropleth(shannon):
    """Two-panel choropleth: Shannon H under Fernández (left) vs Milei (right)."""
    print("  Fig 6: choropleth (Shannon H, Fernández vs Milei)")

    # Load and prepare geodata
    gdf = gpd.read_file(DATA_DIR / "argentina_provinces.geojson")
    # Fix double-encoded UTF-8 in Natural Earth province names
    def _fix_encoding(s):
        try:
            return s.encode("latin-1").decode("utf-8")
        except (UnicodeDecodeError, UnicodeEncodeError):
            return s
    gdf["provincia"] = (gdf["name"]
                        .apply(_fix_encoding)
                        .replace(PROV_NAME_MAP))

    # Normalise province names in Shannon data to match
    shannon = shannon.copy()
    shannon["provincia"] = shannon["provincia"].apply(
        lambda x: unicodedata.normalize("NFC", x))

    # Shannon data for the two eras
    fern = shannon[shannon["era"] == "fernandez"][["provincia", "shannon_H"]].copy()
    mil = shannon[shannon["era"] == "milei"][["provincia", "shannon_H"]].copy()

    gdf_fern = gdf.merge(fern, on="provincia", how="left")
    gdf_mil = gdf.merge(mil, on="provincia", how="left")

    # Shared colour scale
    vmin = min(gdf_fern["shannon_H"].min(), gdf_mil["shannon_H"].min())
    vmax = max(gdf_fern["shannon_H"].max(), gdf_mil["shannon_H"].max())

    cmap = "RdYlGn"

    # Layout: 2 map axes on top, 1 thin colorbar axis below
    fig = plt.figure(figsize=(14, 10))
    gs = fig.add_gridspec(2, 2, height_ratios=[1, 0.04], hspace=0.08,
                          wspace=0.05)
    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1])
    cax = fig.add_subplot(gs[1, :])

    gdf_fern.plot(column="shannon_H", cmap=cmap, vmin=vmin, vmax=vmax,
                  edgecolor="white", linewidth=0.5, ax=ax1, legend=False)
    gdf_mil.plot(column="shannon_H", cmap=cmap, vmin=vmin, vmax=vmax,
                 edgecolor="white", linewidth=0.5, ax=ax2, legend=False)

    # Province abbreviation labels
    for ax, gdf_era in [(ax1, gdf_fern), (ax2, gdf_mil)]:
        for _, row in gdf_era.iterrows():
            centroid = row.geometry.centroid
            label = POSTAL_FIX.get(row["name"], row.get("postal", ""))
            if label:
                ax.text(centroid.x, centroid.y, label,
                        ha="center", va="center",
                        fontsize=7, fontweight="bold", color="#333333",
                        path_effects=[
                            pe.withStroke(linewidth=2, foreground="white")
                        ])

    # Crop to mainland + Tierra del Fuego (exclude Antarctic claims)
    for ax in (ax1, ax2):
        ax.set_xlim(-74, -53)
        ax.set_ylim(-56, -21)
        ax.set_axis_off()

    # Panel labels
    ax1.set_title("(a) Fernández (2020–2023)", fontsize=13,
                  fontweight="semibold", pad=10)
    ax2.set_title("(b) Milei (2024–2025)", fontsize=13,
                  fontweight="semibold", pad=10)

    # Shared colourbar in dedicated axis below maps
    sm = plt.cm.ScalarMappable(cmap=cmap,
                               norm=plt.Normalize(vmin=vmin, vmax=vmax))
    sm._A = []
    cbar = fig.colorbar(sm, cax=cax, orientation="horizontal")
    cbar.set_label("Shannon H (organisational diversity)", fontsize=12)
    cbar.ax.tick_params(labelsize=8)

    plt.tight_layout()
    save_fig(fig, "Fig6_choropleth")


# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("05 — Publication-quality figures")
    print("=" * 70)

    df, row_coords, col_coords, eig, theil, shannon, shift, shift_kf = load_data()
    print(f"  Loaded: {len(df):,} organisations, {len(col_coords)} categories")

    fig1_biplot(df, row_coords, col_coords, eig)
    fig2_csmca_panel(df, row_coords, eig)
    fig3_theil_temporal(theil)
    fig4_shannon_ranking(shannon, df)
    fig5_shift_share(shift, shift_kf, df)
    fig6_choropleth(shannon)

    print(f"\n{'=' * 70}")
    print("DONE — 6 figures saved (TIFF + PNG)")


if __name__ == "__main__":
    main()
