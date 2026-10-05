#!/usr/bin/env python3
"""Render SVG charts (pure vector shapes, no raster) from the KPI tables exported by run_pipeline.py."""
import csv, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import svgcharts as S


def rd(t, name):
    with open(pathlib.Path(t) / f"{name}.csv", newline="") as f:
        return list(csv.DictReader(f))


def f(x):
    return float(x) if x not in ("", None) else 0.0


def panels(t):
    k = rd(t, "a_kpi_headline")[0]
    sub = f"{int(f(k['tracks_total'])):,} tracks; overall avg popularity {f(k['avg_popularity']):.1f}"
    genre = sorted(rd(t, "a_genre_summary"), key=lambda r: -f(r["avg_popularity"]))
    subg = sorted(rd(t, "a_subgenre_popularity"), key=lambda r: -f(r["avg_popularity"]))
    corr = sorted(rd(t, "a_feature_popularity_corr"), key=lambda r: -f(r["corr_all"]))
    year = [r for r in sorted(rd(t, "a_trend_by_year"), key=lambda r: int(r["release_year"])) if int(r["release_year"]) >= 1970]
    dec = [r for r in rd(t, "a_genre_by_decade") if 1960 <= int(r["release_decade"]) <= 2010]
    decs = sorted({int(r["release_decade"]) for r in dec})
    genres = sorted({r["primary_genre"] for r in dec})
    share = {(int(r["release_decade"]), r["primary_genre"]): f(r["share_of_decade_pct"]) for r in dec}
    art = sorted([r for r in rd(t, "a_artist_leaderboard") if int(r["rank_by_tracks"]) <= 15], key=lambda r: int(r["rank_by_tracks"]))
    dur = sorted(rd(t, "a_popularity_by_duration"), key=lambda r: r["duration_band"])
    return [
        ("popularity_by_genre", S.vbar("Average popularity by primary genre", [r["primary_genre"] for r in genre],
                                       [f(r["avg_popularity"]) for r in genre], "{:.1f}", sub, ylabel="Avg popularity (0-100)",
                                       notes=[f"hit {f(r['hit_pct']):.1f}%" for r in genre])),
        ("popularity_by_subgenre", S.hbar("Average popularity by sub-genre (playlist memberships)",
                                          [f"{r['genre']} / {r['subgenre']}" for r in subg], [f(r["avg_popularity"]) for r in subg],
                                          "{:.1f}", "24 sub-genres; a track in two playlists counts twice", color=S.PALETTE[1])),
        ("feature_popularity_corr", S.dbar("Audio features vs popularity (Pearson r, track level)", [r["feature"] for r in corr],
                                           [f(r["corr_all"]) for r in corr], "{:+.3f}", "all weak (|r| < 0.15): no single feature makes a hit")),
        ("trend_by_year", S.line("Tracks by release year: popularity and acousticness x100", [r["release_year"] for r in year],
                                 [("avg popularity", [f(r["avg_popularity"]) for r in year]),
                                  ("avg acousticness x100", [100 * f(r["avg_acousticness"]) for r in year])],
                                 "{:.0f}", "release years 1970-2020", every=5)),
        ("genre_mix_by_decade", S.grouped_vbar("Genre mix of tracks by release decade (% of decade)", [str(d) + "s" for d in decs],
                                               [(g, [share.get((d, g), 0.0) for d in decs]) for g in genres], "{:.0f}",
                                               "rock dominates older releases; edm / latin / pop are 2010s", ylabel="% of decade's tracks")),
        ("top_artists", S.hbar("Top 15 artists by tracks in the dataset", [r["artist_name"] for r in art],
                               [f(r["tracks"]) for r in art], "{:.0f}", "label: avg popularity, main genre", color=S.PALETTE[2],
                               notes=[f"pop {f(r['avg_popularity']):.1f}, {r['main_genre']}" for r in art])),
        ("popularity_by_duration", S.vbar("Average popularity by track length", [r["duration_band"][2:] for r in dur],
                                          [f(r["avg_popularity"]) for r in dur], "{:.1f}", sub, color=S.PALETTE[4],
                                          notes=[f"n={int(f(r['tracks'])):,}" for r in dur], ylabel="Avg popularity")),
    ], k


def make_all(tables, out):
    out = pathlib.Path(out); out.mkdir(parents=True, exist_ok=True)
    ps, k = panels(tables)
    for name, p in ps:
        S.save(p, out / f"{name}.svg")
    cards = [("Tracks", f"{int(f(k['tracks_total'])):,}"), ("Artists", f"{int(f(k['artists_total'])):,}"),
             ("Playlists", f"{int(f(k['playlists_total'])):,}"), ("Avg popularity", f"{f(k['avg_popularity']):.1f}"),
             ("Hit rate (>=70)", f"{f(k['hit_pct']):.2f}%"), ("Released 2010+", f"{f(k['released_2010_plus_pct']):.1f}%"),
             ("Avg length", f"{f(k['avg_duration_min']):.2f} min")]
    dash_panels = [p for n, p in ps if n != "popularity_by_duration"]
    S.dashboard(out / "dashboard.svg", "30000 Spotify Songs: genre, popularity drivers, trends and artists",
                "Rendered from results/tables (SQL on DuckDB). Popularity = Spotify score at extraction (Jan 2020).",
                cards, dash_panels, cols=2)
    print("charts ->", out, sorted(p.name for p in out.glob("*.svg")))


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parents[1]
    make_all(root / "results/tables", root / "results/images")
