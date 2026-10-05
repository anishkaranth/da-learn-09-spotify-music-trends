# Results - da-learn-09 Spotify music trends

Run: `python run_pipeline.py --source full` on DuckDB (local, full file, 32,833 raw playlist rows → 28,356 unique tracks). Databricks was skipped because the workspace hit its resource quota, so there is no live dashboard; every number below is in `metrics.json` and `tables/`. Grain is **one row per track** unless stated (32,251 playlist memberships). Popularity is Spotify's 0-100 score at extraction (Jan 2020); **hit = popularity >= 70**.

![Dashboard](images/dashboard.png)

## Headline KPIs
| KPI | Value |
|---|---|
| Unique tracks | 28,356 |
| Playlist memberships | 32,251 |
| Artists / albums / playlists | 10,693 / 22,545 / 471 |
| Genres | 6 |
| Avg popularity | 39.33 |
| Hit rate (popularity >= 70) | 9.29% |
| Zero-popularity tracks | 9.24% |
| Release years | 1957–2020 |
| Released 2010+ | 72.15% |
| Avg duration | 3.776 min |
| Multi-genre tracks | 5.41% |

## Genre (primary genre of each track)
| primary_genre | tracks | share_pct | avg_popularity | hit_pct |
|---|---|---|---|---|
| latin | 4,427 | 15.61 | 43.35 | 13.82 |
| pop | 4,479 | 15.8 | 43.16 | 13.46 |
| rap | 5,018 | 17.7 | 40.27 | 5.96 |
| rock | 4,264 | 15.04 | 39.6 | 8.91 |
| r&b | 4,631 | 16.33 | 36.8 | 8.29 |
| edm | 5,537 | 19.53 | 34.07 | 6.45 |

![genre](images/popularity_by_genre.png)

### Sub-genre (playlist-membership grain)
Top by avg popularity: **pop / post-teen pop** 56.83 (hit 40.12%), **rock / permanent wave** 54.0, **rap / hip hop** 53.77, **latin / reggaeton** 52.87, **pop / dance pop** 52.08. Lowest: edm / progressive electro house 27.71. Full table: `tables/a_subgenre_popularity.csv`.

![subgenre](images/popularity_by_subgenre.png)

## Popularity drivers
Pearson correlation with popularity (track level; `|r| < 0.15` for every feature):

| feature | corr_all | corr_nonzero |
|---|---|---|
| acousticness | 0.0917 | 0.0688 |
| danceability | 0.0466 | 0.0395 |
| loudness | 0.0373 | 0.0516 |
| valence | 0.0226 | 0.0375 |
| speechiness | 0.0052 | 0.0111 |
| tempo | 0.0042 | 0.0094 |
| liveness | -0.0528 | -0.0342 |
| energy | -0.1036 | -0.0772 |
| instrumentalness | -0.1244 | -0.1286 |
| duration_min | -0.1397 | -0.1075 |

![corr](images/feature_popularity_corr.png)

Track length: 2.5–3 min tracks average 42.65 popularity; 5+ min tracks average 31.22. Full bins: `tables/a_popularity_by_duration.csv`, `tables/a_popularity_by_feature_bin.csv`, `tables/a_popularity_band_profile.csv`.

![duration](images/popularity_by_duration.png)

## Trends by release decade
| release_decade | tracks | avg_popularity | hit_pct | avg_acousticness | avg_duration_min |
|---|---|---|---|---|---|
| 1950 | 3 | 44.33 | 33.33 | 0.538 | 2.44 |
| 1960 | 132 | 46.45 | 21.21 | 0.342 | 3.63 |
| 1970 | 783 | 44.26 | 13.28 | 0.244 | 4.28 |
| 1980 | 1,090 | 42.19 | 10.09 | 0.156 | 4.47 |
| 1990 | 2,081 | 37.97 | 6.73 | 0.143 | 4.42 |
| 2000 | 3,807 | 31.93 | 6.3 | 0.164 | 4.13 |
| 2010 | 19,834 | 40.38 | 9.89 | 0.18 | 3.6 |
| 2020 | 626 | 42.78 | 8.15 | 0.211 | 3.24 |

Rock was 88.25% of 1970s tracks and only 6.65% of 2010s tracks; EDM is 26.22% of the 2010s. Per-year figures: `tables/a_trend_by_year.csv`.

![year](images/trend_by_year.png)
![mix](images/genre_mix_by_decade.png)

## Artists (>= 10 tracks)
Top by catalogue size: **Queen** 130 tracks (avg pop 42.4, rock), Martin Garrix 87 (edm), Don Omar 84 (latin), David Guetta 81 (edm), Dimitri Vegas & Like Mike / Drake / Hardwell 68 each. Top by avg popularity (min 10 tracks): **Billie Eilish** 76.96 (26 tracks), Tones and I 74.6, Green Day 73.2, Camila Cabello 72.25, Khalid 71.64. Hit concentration: top 10 artists by hit count hold only 6.64% of all hits; 101+ hold 65.96%.

![artists](images/top_artists.png)

## Data quality (tables/dq_issues.csv, tables/dq_assertions.csv)
| Check | Rows |
|---|---|
| duplicate (track_id, playlist_id) rows dropped | 582 |
| tracks on more than one playlist row | 2,818 |
| tracks under more than one genre (primary assigned) | 1,533 |
| duration outlier (outside Q1/Q3 ± 3·IQR, kept) | 191 |
| missing name / artist / album (NA) | 4 |
| popularity = 0 | 2,620 |
| release date year-month only | 25 |
| release date year-only | 1,656 |
| same name + artist under several track_ids (kept) | 3,943 |
| shorter than 1 minute (kept) | 25 |
| tempo = 0 (set NULL) | 1 |
| **assertions passed** | **13 / 13** |

## Images
How they were made: `run_pipeline.py` queries the `a_*` tables in DuckDB and writes each chart as an SVG with plain vector shapes (`scripts/svgcharts.py`, no embedded rasters); `scripts/render_png.py` then rasterises each SVG at 2x with headless Chrome.

| File | Shows |
|---|---|
| [dashboard.svg](images/dashboard.svg) / [png](images/dashboard.png) | KPI cards + 6 charts |
| [popularity_by_genre.svg](images/popularity_by_genre.svg) / [png](images/popularity_by_genre.png) | avg popularity by primary genre |
| [popularity_by_subgenre.svg](images/popularity_by_subgenre.svg) / [png](images/popularity_by_subgenre.png) | avg popularity by sub-genre |
| [feature_popularity_corr.svg](images/feature_popularity_corr.svg) / [png](images/feature_popularity_corr.png) | Pearson r of audio features vs popularity |
| [trend_by_year.svg](images/trend_by_year.svg) / [png](images/trend_by_year.png) | popularity and acousticness by release year |
| [genre_mix_by_decade.svg](images/genre_mix_by_decade.svg) / [png](images/genre_mix_by_decade.png) | genre mix by release decade |
| [top_artists.svg](images/top_artists.svg) / [png](images/top_artists.png) | top 15 artists by track count |
| [popularity_by_duration.svg](images/popularity_by_duration.svg) / [png](images/popularity_by_duration.png) | avg popularity by track length |

Other files: `metrics.json` (all KPIs, DQ and analysis tables), `JSON.shot` (headline snapshot + run config), `tables/*.csv` (every `a_*` and `dq_*` table).
