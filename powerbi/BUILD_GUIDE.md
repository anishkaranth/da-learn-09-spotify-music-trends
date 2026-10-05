# Build guide (Power BI Desktop, Windows)

No `.pbix` is committed: this repo is built on Linux and Power BI Desktop runs on Windows only.

1. `python scripts/download_full_data.py` then `python run_pipeline.py --source full` (or use the committed `powerbi/data/*.csv`, which are already full size, ~8 MB total).
2. Power BI Desktop > Get data > Text/CSV: load the eight CSVs in `powerbi/data/`. In Power Query set `artist_key`, `primary_genre_key`, `genre_key`, `subgenre_key`, `release_year`, `popularity`, `hit_flag`, `playlist_count`, `genre_count` and the DQ flag columns to Whole number; set audio features and `duration_min` / `tempo` / `loudness` to Decimal.
3. Model view: create the relationships in `model.md`. Set `fact_playlist_track -> fact_track` to cross-filter **Both**.
4. Sort `popularity_band` and `duration_band` by themselves (they already sort alphabetically in the intended order).
5. New measures: paste `measures.dax` one measure at a time into the fact_track table.
6. Build the page in `dashboard_spec.md` and check the cards against the "Expected" column; they come from `results/metrics.json`.
7. Save as `da-learn-09-spotify.pbix` locally (do not commit the binary unless you want to).
