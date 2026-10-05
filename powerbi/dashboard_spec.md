# Dashboard spec - "da-learn-09 Spotify music trends"

One page, 16:9. Filters: primary genre (dim_genre via fact_track), release decade (dim_release_year), popularity band, duration band. Optional second page for playlist / sub-genre (membership grain).

| # | Visual | Fields | Expected (full data, no filters) |
|---|---|---|---|
| 1 | KPI cards | Tracks, Avg Popularity, Hit Rate %, Artists, Playlists, Released 2010+ % | 28,356 / 39.33 / 9.29% / 10,693 / 471 / 72.15% |
| 2 | Bar: avg popularity by primary genre | dim_genre[genre], [Avg Popularity] | latin 43.35, pop 43.16, rap 40.27, rock 39.6, r&b 36.8, edm 34.07 |
| 3 | Bar: avg popularity by sub-genre | dim_subgenre[subgenre] (or genre + subgenre), [Membership Avg Popularity], Top N 12 | post-teen pop 56.83, permanent wave 54.0, hip hop 53.77 |
| 4 | Bar: feature corr (static table or imported a_feature_popularity_corr) | feature, corr_all | duration_min −0.140 … acousticness +0.092 |
| 5 | Line: avg popularity by release year | dim_release_year[release_year] (≥1970), [Avg Popularity] | dip in 2000s (~31.9 decade avg), recover 2010s (~40.4) |
| 6 | 100% stacked / clustered: genre mix by decade | dim_release_year[release_decade], dim_genre[genre], % of [Tracks] | rock 88% of 1970s; edm 26% of 2010s |
| 7 | Bar: top artists by tracks | dim_artist[artist_name], [Tracks], Top N 15 | Queen 130, Martin Garrix 87, Don Omar 84 |
| 8 | Column: avg popularity by duration band | fact_track[duration_band], [Avg Popularity] | 2.5–3 min = 42.65; 5+ min = 31.22 |

Reference render of the same visuals (from DuckDB): `results/images/dashboard.png`.
